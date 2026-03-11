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
