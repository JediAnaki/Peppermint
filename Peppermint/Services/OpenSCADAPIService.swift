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
struct CompartmentGeometry: Codable {
    let id: String
    let width: Float
    let height: Float
    let depth: Float
    let positionX: Float
    let positionY: Float
    let positionZ: Float
    let colorHex: String
}

/// Request payload for OpenSCAD STL generation
struct OpenSCADRequest: Codable {
    let organizerId: String
    let compartments: [CompartmentGeometry]
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

    // MARK: - Configuration

    /// Base URL for OpenSCAD server (from ServerConfig)
    private var baseURL: URL {
        return ServerConfig.openSCADServerURL
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
        // Build request payload
        let compartments = convertToGeometry(organizer: organizer)
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

        print("📡 Sending STL generation request to OpenSCAD server...")
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

    /// Converts OrganizerDesign to array of CompartmentGeometry for API request
    private func convertToGeometry(organizer: OrganizerDesign) -> [CompartmentGeometry] {
        let compartmentsSet = organizer.compartments as? Set<Compartment> ?? []

        return compartmentsSet.map { compartment in
            CompartmentGeometry(
                id: compartment.id!.uuidString,
                width: compartment.width,
                height: compartment.height,
                depth: compartment.depth,
                positionX: compartment.positionX,
                positionY: compartment.positionY,
                positionZ: compartment.positionZ,
                colorHex: compartment.colorHex
            )
        }
    }
}
