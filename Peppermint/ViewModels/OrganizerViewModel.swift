//
//  OrganizerViewModel.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import Foundation
import SwiftUI
import Combine
import CoreData
import SceneKit
import UniformTypeIdentifiers

/// ViewModel managing organizer design state and operations
@MainActor
class OrganizerViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current organizer being edited
    @Published var currentOrganizer: OrganizerDesign?

    /// Array of compartments in the current organizer
    @Published var compartments: [Compartment] = []

    /// Selected compartment for editing/deletion
    @Published var selectedCompartment: Compartment?

    /// Error message to display to user
    @Published var errorMessage: String?

    /// Loading state for async operations
    @Published var isLoading: Bool = false

    /// Export progress (0.0 to 1.0)
    @Published var exportProgress: Double = 0.0

    /// Exported STL file URL for sharing
    @Published var exportedFileURL: URL?

    // MARK: - Private Properties

    private let persistenceService: DataPersistenceService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(persistenceService: DataPersistenceService = DataPersistenceService.shared) {
        self.persistenceService = persistenceService
    }

    // MARK: - Public Methods

    /// Create a new organizer design
    /// - Parameter name: Name for the new organizer
    func createNewOrganizer(name: String) {
        let organizer = OrganizerDesign(context: persistenceService.viewContext)
        organizer.id = UUID()
        organizer.name = name
        organizer.createdAt = Date()
        organizer.modifiedAt = Date()

        self.currentOrganizer = organizer
        self.compartments = []

        do {
            try persistenceService.viewContext.save()
        } catch {
            errorMessage = "Failed to create organizer: \(error.localizedDescription)"
        }
    }

    /// Load an existing organizer
    /// - Parameter organizer: The organizer to load
    func loadOrganizer(_ organizer: OrganizerDesign) {
        self.currentOrganizer = organizer
        self.compartments = Array(organizer.compartmentsArray)
    }

    /// Add a compartment to the current organizer
    /// - Parameters:
    ///   - width: Compartment width in mm (must be multiple of 5)
    ///   - height: Compartment height in mm (must be multiple of 5)
    ///   - depth: Compartment depth in mm (must be multiple of 5)
    ///   - position: 3D position in workspace (will be snapped to grid)
    ///   - colorHex: Hex color string (e.g., "#CCCCCC")
    func addCompartment(width: Float, height: Float, depth: Float, position: SIMD3<Float>, colorHex: String = "#CCCCCC") {
        guard let organizer = currentOrganizer else {
            errorMessage = "No organizer selected"
            return
        }

        // Validate compartment count limit
        if compartments.count >= 50 {
            errorMessage = "Maximum 50 compartments allowed per organizer"
            return
        }

        let compartment = Compartment(context: persistenceService.viewContext)
        compartment.id = UUID()
        compartment.width = SnapToGridCalculator.snap(width)
        compartment.height = SnapToGridCalculator.snap(height)
        compartment.depth = SnapToGridCalculator.snap(depth)
        compartment.positionX = SnapToGridCalculator.snap(position.x)
        compartment.positionY = SnapToGridCalculator.snap(position.y)
        compartment.positionZ = SnapToGridCalculator.snap(position.z)
        compartment.colorHex = colorHex
        compartment.createdAt = Date()
        compartment.organizer = organizer

        // Check for collisions before adding
        if checkCollision(for: compartment, in: organizer) {
            errorMessage = "Compartment would overlap with existing compartment"
            persistenceService.viewContext.delete(compartment)
            return
        }

        // Initialize with empty connector metadata (will be updated by FrictionFitGenerator)
        let emptyMetadata = ConnectorMetadata(edges: [:], tabHeight: 2.0, grooveDepth: 1.2, tolerance: 0.3)
        if let encoded = try? JSONEncoder().encode(emptyMetadata) {
            compartment.connectorMetadata = encoded
        }

        compartments.append(compartment)

        do {
            try persistenceService.viewContext.save()
        } catch {
            errorMessage = "Failed to add compartment: \(error.localizedDescription)"
        }
    }

    /// Check if a compartment would collide with existing compartments
    /// T082: Uses spatial partitioning grid for O(1) neighbor lookup in large organizers
    /// - Parameters:
    ///   - compartment: The compartment to check
    ///   - organizer: The organizer containing existing compartments
    /// - Returns: true if collision detected, false otherwise
    private func checkCollision(for compartment: Compartment, in organizer: OrganizerDesign) -> Bool {
        let newBounds = CompartmentBounds(
            minX: compartment.positionX,
            maxX: compartment.positionX + compartment.width,
            minY: compartment.positionY,
            maxY: compartment.positionY + compartment.height,
            minZ: compartment.positionZ,
            maxZ: compartment.positionZ + compartment.depth
        )

        // T082: Spatial partitioning optimization
        // For small compartment counts (<20), brute force is faster
        if compartments.count < 20 {
            for existing in compartments {
                guard existing.id != compartment.id else { continue }

                let existingBounds = CompartmentBounds(
                    minX: existing.positionX,
                    maxX: existing.positionX + existing.width,
                    minY: existing.positionY,
                    maxY: existing.positionY + existing.height,
                    minZ: existing.positionZ,
                    maxZ: existing.positionZ + existing.depth
                )

                if newBounds.intersects(existingBounds) {
                    return true
                }
            }
            return false
        }

        // For larger counts, use spatial grid (10mm cells)
        // Only check compartments in nearby grid cells
        let gridSize: Float = 10.0
        let nearbyCompartments = getNearbyCompartments(
            position: SIMD3(compartment.positionX, compartment.positionY, compartment.positionZ),
            bounds: newBounds,
            gridSize: gridSize
        )

        for existing in nearbyCompartments {
            guard existing.id != compartment.id else { continue }

            let existingBounds = CompartmentBounds(
                minX: existing.positionX,
                maxX: existing.positionX + existing.width,
                minY: existing.positionY,
                maxY: existing.positionY + existing.height,
                minZ: existing.positionZ,
                maxZ: existing.positionZ + existing.depth
            )

            if newBounds.intersects(existingBounds) {
                return true
            }
        }

        return false
    }

    /// T082: Get compartments in nearby spatial grid cells for optimized collision detection
    private func getNearbyCompartments(position: SIMD3<Float>, bounds: CompartmentBounds, gridSize: Float) -> [Compartment] {
        // Calculate grid cell ranges that overlap with the bounds
        let minCellX = Int(floor(bounds.minX / gridSize))
        let maxCellX = Int(ceil(bounds.maxX / gridSize))
        let minCellY = Int(floor(bounds.minY / gridSize))
        let maxCellY = Int(ceil(bounds.maxY / gridSize))
        let minCellZ = Int(floor(bounds.minZ / gridSize))
        let maxCellZ = Int(ceil(bounds.maxZ / gridSize))

        // Build spatial hash for existing compartments
        var spatialGrid: [String: [Compartment]] = [:]
        for comp in compartments {
            let cellX = Int(floor(comp.positionX / gridSize))
            let cellY = Int(floor(comp.positionY / gridSize))
            let cellZ = Int(floor(comp.positionZ / gridSize))
            let key = "\(cellX),\(cellY),\(cellZ)"

            if spatialGrid[key] == nil {
                spatialGrid[key] = []
            }
            spatialGrid[key]?.append(comp)
        }

        // Collect compartments from overlapping cells
        var nearby: [Compartment] = []
        for x in minCellX...maxCellX {
            for y in minCellY...maxCellY {
                for z in minCellZ...maxCellZ {
                    let key = "\(x),\(y),\(z)"
                    if let cellCompartments = spatialGrid[key] {
                        nearby.append(contentsOf: cellCompartments)
                    }
                }
            }
        }

        return nearby
    }

    /// Remove a compartment from the organizer
    /// - Parameter compartment: The compartment to remove
    func removeCompartment(_ compartment: Compartment) {
        persistenceService.viewContext.delete(compartment)
        compartments.removeAll { $0.id == compartment.id }

        if selectedCompartment?.id == compartment.id {
            selectedCompartment = nil
        }

        do {
            try persistenceService.viewContext.save()
        } catch {
            errorMessage = "Failed to remove compartment: \(error.localizedDescription)"
        }
    }

    /// Save the current organizer state
    func saveOrganizer() {
        guard let organizer = currentOrganizer else {
            errorMessage = "No organizer to save"
            return
        }

        organizer.modifiedAt = Date()

        do {
            try persistenceService.viewContext.save()
        } catch {
            errorMessage = "Failed to save organizer: \(error.localizedDescription)"
        }
    }

    /// Generate thumbnail snapshot for the current organizer
    /// - Parameter sceneView: The SCNView to capture
    /// - Returns: PNG data for the thumbnail
    func generateThumbnail(from sceneView: SCNView) -> Data? {
        // Capture snapshot at 512x512 resolution
        let snapshot = sceneView.snapshot()

        // Resize to 512x512 if needed
        let targetSize = CGSize(width: 512, height: 512)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        snapshot.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // Convert to PNG data
        return resizedImage?.pngData()
    }

    /// Save organizer with thumbnail
    /// - Parameter sceneView: The SCNView to capture thumbnail from
    func saveOrganizerWithThumbnail(from sceneView: SCNView) {
        guard let organizer = currentOrganizer else {
            errorMessage = "No organizer to save"
            return
        }

        // Generate and save thumbnail
        if let thumbnailData = generateThumbnail(from: sceneView) {
            organizer.thumbnailData = thumbnailData
        }

        organizer.modifiedAt = Date()

        do {
            try persistenceService.viewContext.save()
        } catch {
            errorMessage = "Failed to save organizer: \(error.localizedDescription)"
        }
    }

    /// Select a compartment for editing
    /// - Parameter compartment: The compartment to select
    func selectCompartment(_ compartment: Compartment?) {
        self.selectedCompartment = compartment
    }

    // MARK: - STL Export

    /// Export current organizer to STL file
    /// - Returns: true if export succeeded, false otherwise
    func exportToSTL() async -> Bool {
        guard let organizer = currentOrganizer else {
            errorMessage = "No organizer to export"
            return false
        }

        guard !compartments.isEmpty else {
            errorMessage = "Cannot export organizer with no compartments"
            return false
        }

        isLoading = true
        exportProgress = 0.0

        do {
            // Create temporary file URL
            let tempDir = FileManager.default.temporaryDirectory
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let dateString = dateFormatter.string(from: Date())
            let sanitizedName = organizer.name?.replacingOccurrences(of: " ", with: "-") ?? "organizer"
            let fileName = "\(sanitizedName)-\(dateString).stl"
            let fileURL = tempDir.appendingPathComponent(fileName)

            exportProgress = 0.3

            // Export to STL
            let stats = try STLExporter.export(organizer: organizer, to: fileURL)

            exportProgress = 0.7

            // Create export history record
            let exportHistory = ExportHistory(context: persistenceService.viewContext)
            exportHistory.id = UUID()
            exportHistory.exportedAt = Date()
            exportHistory.fileName = fileName
            exportHistory.fileSize = stats.fileSize
            exportHistory.compartmentCount = Int16(stats.compartmentCount)
            exportHistory.exportDuration = stats.duration
            exportHistory.organizer = organizer

            try persistenceService.viewContext.save()

            exportProgress = 1.0
            exportedFileURL = fileURL

            isLoading = false
            return true

        } catch let error as STLExportError {
            isLoading = false
            exportProgress = 0.0
            errorMessage = error.localizedDescription
            if let recovery = error.recoverySuggestion {
                errorMessage = "\(error.localizedDescription)\n\n\(recovery)"
            }
            return false

        } catch {
            isLoading = false
            exportProgress = 0.0
            errorMessage = "Export failed: \(error.localizedDescription)"
            return false
        }
    }

    /// Get shareable items for iOS share sheet
    /// - Returns: Array of shareable items (URL + metadata)
    func getShareItems() -> [Any] {
        guard let fileURL = exportedFileURL else { return [] }

        var items: [Any] = [fileURL]

        // Add metadata text
        if let organizer = currentOrganizer {
            let metadata = """
            Peppermint 3D Pill Organizer
            Name: \(organizer.name ?? "Untitled")
            Compartments: \(compartments.count)
            Exported: \(Date().formatted())

            Ready for 3D printing!
            """
            items.append(metadata)
        }

        return items
    }
}

// MARK: - Supporting Types

/// Connector metadata structure for JSON encoding
struct ConnectorMetadata: Codable {
    struct EdgeConnector: Codable {
        let type: String  // "tab", "groove", or "none"
        let offset: Float
    }

    let edges: [String: EdgeConnector]
    let tabHeight: Float
    let grooveDepth: Float
    let tolerance: Float
}

/// Axis-aligned bounding box for collision detection
struct CompartmentBounds {
    let minX: Float
    let maxX: Float
    let minY: Float
    let maxY: Float
    let minZ: Float
    let maxZ: Float

    func intersects(_ other: CompartmentBounds) -> Bool {
        return !(maxX <= other.minX || minX >= other.maxX ||
                 maxY <= other.minY || minY >= other.maxY ||
                 maxZ <= other.minZ || minZ >= other.maxZ)
    }
}

// MARK: - OrganizerDesign Extension

extension OrganizerDesign {
    /// Helper to get compartments as an array
    var compartmentsArray: [Compartment] {
        let set = compartments as? Set<Compartment> ?? []
        return Array(set).sorted { $0.createdAt ?? Date() < $1.createdAt ?? Date() }
    }
}
