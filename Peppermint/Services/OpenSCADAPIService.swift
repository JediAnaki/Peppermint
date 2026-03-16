//
//  OpenSCADAPIService.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 3 - User Story 1: Server communication for high-quality STL generation
//

import Foundation

// MARK: - OpenSCAD API Error Types

/// Errors that can occur during OpenSCAD API communication
enum APIError: Error, LocalizedError {
    case invalidResponse
    case serverError(String)
    case timeout
    case invalidBase64
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenSCAD server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .timeout:
            return "Request timed out after 30 seconds"
        case .invalidBase64:
            return "Failed to decode base64 STL data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Request/Response Models

/// Compartment geometry data sent to OpenSCAD server
struct OpenSCADCompartmentData: Codable {
    let id: String
    let width: Float
    let height: Float
    let depth: Float
    let positionX: Float
    let positionY: Float
    let positionZ: Float
    let colorHex: String

    // T096: Optional medication geometry for pill visualization (P4)
    let medication: MedicationGeometry?
}

/// T096: Medication geometry for pill rendering in OpenSCAD
struct MedicationGeometry: Codable {
    let pillShape: String       // "round", "oblong", "capsule", "oval"
    let pillDiameter: Float     // mm
    let pillLength: Float       // mm
    let pillCount: Int          // Number of pills to render in compartment
}

/// Request payload for OpenSCAD STL generation
struct OpenSCADRequest: Codable {
    let organizerId: String
    let compartments: [OpenSCADCompartmentData]
    let options: GenerationOptions

    struct GenerationOptions: Codable {
        let includePills: Bool
        let includeConnectors: Bool
        let wallThickness: Float

        init(includePills: Bool = false, includeConnectors: Bool = true, wallThickness: Float = 2.0) {
            self.includePills = includePills
            self.includeConnectors = includeConnectors
            self.wallThickness = wallThickness
        }
    }
}

/// Success response from OpenSCAD server
struct OpenSCADSuccessResponse: Codable {
    let stlData: String  // Base64-encoded binary STL
    let metadata: STLMetadata

    struct STLMetadata: Codable {
        let triangleCount: Int
        let fileSizeBytes: Int
        let generationTimeMs: Int
        let serverVersion: String
    }
}

/// Error response from OpenSCAD server
struct OpenSCADErrorResponse: Codable {
    let error: String
    let details: String?
    let code: Int
}

// MARK: - OpenSCAD API Service

/// Service for communicating with OpenSCAD REST API server
final class OpenSCADAPIService {

    // MARK: - Singleton

    static let shared = OpenSCADAPIService()

    private init() {}

    // MARK: - T105: Error Analytics

    /// Tracks server failure count for monitoring fallback usage
    private var serverFailureCount: Int {
        get { UserDefaults.standard.integer(forKey: "openSCADServerFailureCount") }
        set { UserDefaults.standard.set(newValue, forKey: "openSCADServerFailureCount") }
    }

    /// Tracks total request count for success rate calculation
    private var totalRequestCount: Int {
        get { UserDefaults.standard.integer(forKey: "openSCADTotalRequestCount") }
        set { UserDefaults.standard.set(newValue, forKey: "openSCADTotalRequestCount") }
    }

    /// Returns server success rate (0.0 to 1.0)
    var serverSuccessRate: Double {
        guard totalRequestCount > 0 else { return 0.0 }
        return Double(totalRequestCount - serverFailureCount) / Double(totalRequestCount)
    }

    /// Logs analytics for server failure
    private func logServerFailure() {
        serverFailureCount += 1
        print("📊 Server failure #\(serverFailureCount) of \(totalRequestCount) requests (success rate: \(String(format: "%.1f%%", serverSuccessRate * 100)))")
    }

    /// Logs analytics for server success
    private func logServerSuccess() {
        print("📊 Server success (\(String(format: "%.1f%%", serverSuccessRate * 100)) success rate over \(totalRequestCount) requests)")
    }

    // MARK: - Configuration

    /// Base URL for OpenSCAD server (from ServerConfig)
    private var baseURL: URL {
        return ServerConfig.openSCADBaseURL
    }

    /// URLSession with 30-second timeout
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 30.0
        return URLSession(configuration: config)
    }()

    // MARK: - STL Generation

    /// Generates STL file from organizer design using OpenSCAD server
    ///
    /// **Process**:
    /// 1. Convert organizer compartments to CompartmentGeometry array
    /// 2. Send POST request to `/api/generate-stl` endpoint
    /// 3. Decode base64 STL data from response
    /// 4. Return binary STL data + metadata
    ///
    /// - Parameters:
    ///   - organizer: The organizer design to generate STL for
    ///   - includePills: Whether to include pill visualization (default: false)
    ///
    /// - Returns: Tuple of (STL binary data, triangle count)
    ///
    /// - Throws: `APIError` if request fails or response invalid
    func generateSTL(organizer: OrganizerDesign, includePills: Bool = false) async throws -> (Data, Int) {
        // T106: Increment total request count for analytics
        totalRequestCount += 1

        // T106: Retry with exponential backoff (1s, 2s, 4s max 3 attempts)
        let maxAttempts = 3
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                let result = try await attemptGenerateSTL(organizer: organizer, includePills: includePills, attempt: attempt)

                // T105: Log success
                logServerSuccess()

                return result

            } catch {
                lastError = error

                // Don't retry on final attempt
                guard attempt < maxAttempts else { break }

                // T106: Exponential backoff (1s, 2s, 4s)
                let delaySeconds = pow(2.0, Double(attempt - 1))
                print("⚠️ Attempt \(attempt) failed: \(error.localizedDescription)")
                print("   Retrying in \(Int(delaySeconds))s...")

                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }

        // T105: Log failure after all retries exhausted
        logServerFailure()

        // All retries failed - throw last error
        throw lastError ?? APIError.serverError("Unknown error")
    }

    /// T106: Single attempt to generate STL (used by retry logic)
    private func attemptGenerateSTL(organizer: OrganizerDesign, includePills: Bool, attempt: Int) async throws -> (Data, Int) {
        // T095: Build request payload with pill visualization support
        let compartments = convertToGeometry(organizer: organizer, includePills: includePills)
        let options = OpenSCADRequest.GenerationOptions(includePills: includePills)
        let request = OpenSCADRequest(
            organizerId: organizer.id!.uuidString,
            compartments: compartments,
            options: options
        )

        // Create HTTP request
        let endpoint = baseURL.appendingPathComponent("api/generate-stl")
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        print("📡 Sending STL generation request to OpenSCAD server (attempt \(attempt)/3)...")
        print("   URL: \(endpoint)")
        print("   Compartments: \(compartments.count)")
        print("   Include pills: \(includePills)")

        // Send request
        let (data, response) = try await session.data(for: urlRequest)

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        print("📡 Received response: HTTP \(httpResponse.statusCode)")

        // Handle error responses
        if httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(OpenSCADErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            } else {
                throw APIError.serverError("HTTP \(httpResponse.statusCode)")
            }
        }

        // Decode success response
        let successResponse = try JSONDecoder().decode(OpenSCADSuccessResponse.self, from: data)

        print("✅ STL generated successfully")
        print("   Triangles: \(successResponse.metadata.triangleCount)")
        print("   File size: \(successResponse.metadata.fileSizeBytes) bytes")
        print("   Generation time: \(successResponse.metadata.generationTimeMs)ms")

        // Decode base64 STL data
        guard let stlData = Data(base64Encoded: successResponse.stlData) else {
            throw APIError.invalidBase64
        }

        return (stlData, successResponse.metadata.triangleCount)
    }

    // MARK: - Helper Methods

    /// T097-T098: Converts OrganizerDesign to array of OpenSCADCompartmentData for API request
    ///
    /// - Parameters:
    ///   - organizer: The organizer to convert
    ///   - includePills: Whether to include medication pill geometry (default: false)
    ///
    /// - Returns: Array of compartment data with optional medication geometry
    private func convertToGeometry(organizer: OrganizerDesign, includePills: Bool = false) -> [OpenSCADCompartmentData] {
        let compartmentsSet = organizer.compartments as? Set<Compartment> ?? []

        return compartmentsSet.map { compartment in
            // T097: Only populate medication when shouldVisualize == true (FR-017: medication.name filled)
            var medicationGeometry: MedicationGeometry? = nil

            if includePills, let medication = compartment.medication, medication.shouldVisualize {
                // T098: Send pillShape, pillDiameter, pillLength to server
                medicationGeometry = MedicationGeometry(
                    pillShape: medication.pillShape ?? "round",
                    pillDiameter: medication.pillDiameter,
                    pillLength: medication.pillLength,
                    pillCount: calculatePillCount(compartment: compartment)
                )
            }

            return OpenSCADCompartmentData(
                id: compartment.id!.uuidString,
                width: compartment.width,
                height: compartment.height,
                depth: compartment.depth,
                positionX: compartment.positionX,
                positionY: compartment.positionY,
                positionZ: compartment.positionZ,
                colorHex: compartment.colorHex ?? "#CCCCCC",
                medication: medicationGeometry
            )
        }
    }

    /// Calculates reasonable number of pills to render in compartment
    ///
    /// **Logic**: Based on compartment volume and pill diameter
    /// - Small compartments (< 1000mm³): 1-3 pills
    /// - Medium compartments (1000-5000mm³): 4-8 pills
    /// - Large compartments (> 5000mm³): 9-15 pills
    ///
    /// - Parameter compartment: The compartment to calculate for
    /// - Returns: Number of pills to render (1-15)
    private func calculatePillCount(compartment: Compartment) -> Int {
        let volume = compartment.width * compartment.height * compartment.depth

        if volume < 1000 {
            return 2  // Small compartment
        } else if volume < 5000 {
            return 5  // Medium compartment
        } else {
            return 8  // Large compartment
        }
    }
}
