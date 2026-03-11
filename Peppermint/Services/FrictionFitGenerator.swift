//
//  FrictionFitGenerator.swift
//  Peppermint
//
//  Created by Claude on 2026-03-11.
//

import Foundation
import CoreData

/// Service for generating friction-fit connector metadata based on compartment neighbors
class FrictionFitGenerator {

    // MARK: - Constants

    /// Snap-to-grid size in millimeters
    static let gridSize: Float = 5.0

    /// Default tab height in millimeters
    static let defaultTabHeight: Float = 2.0

    /// Default groove depth in millimeters
    static let defaultGrooveDepth: Float = 1.2

    /// Default tolerance for friction-fit (PETG)
    static let defaultTolerance: Float = 0.3

    /// Detection threshold for neighbor proximity (must be within this distance to be considered adjacent)
    static let neighborThreshold: Float = 0.1

    // MARK: - Public Methods

    /// Generate connector metadata for a compartment based on its neighbors
    /// - Parameters:
    ///   - compartment: The compartment to generate connectors for
    ///   - organizer: The organizer design containing all compartments
    /// - Returns: ConnectorMetadata with auto-assigned tabs/grooves
    static func generateConnectorMetadata(for compartment: Compartment, in organizer: OrganizerDesign) -> ConnectorMetadata {
        let neighbors = findNeighbors(for: compartment, in: organizer)
        var edges: [String: ConnectorMetadata.EdgeConnector] = [:]

        // Define edge positions relative to compartment
        let edgeChecks: [(edge: String, checkNeighbor: (Compartment, Compartment) -> Bool)] = [
            ("top", isNeighborOnTop),
            ("bottom", isNeighborOnBottom),
            ("left", isNeighborOnLeft),
            ("right", isNeighborOnRight),
            ("front", isNeighborOnFront),
            ("back", isNeighborOnBack)
        ]

        // For each edge, determine connector type based on neighbors
        for (edge, checkFunction) in edgeChecks {
            let hasNeighbor = neighbors.contains { checkFunction(compartment, $0) }

            if hasNeighbor {
                // Alternate between tab and groove for adjacent compartments
                // Use compartment ID to determine assignment (consistent across saves)
                let shouldBeTab = shouldAssignTab(for: compartment, edge: edge)
                edges[edge] = ConnectorMetadata.EdgeConnector(
                    type: shouldBeTab ? "tab" : "groove",
                    offset: 0.0
                )
            } else {
                // No neighbor = no connector needed
                edges[edge] = ConnectorMetadata.EdgeConnector(
                    type: "none",
                    offset: 0.0
                )
            }
        }

        return ConnectorMetadata(
            edges: edges,
            tabHeight: defaultTabHeight,
            grooveDepth: defaultGrooveDepth,
            tolerance: defaultTolerance
        )
    }

    // MARK: - Private Methods

    /// Find all neighboring compartments (within grid distance on any axis)
    /// - Parameters:
    ///   - compartment: The compartment to find neighbors for
    ///   - organizer: The organizer containing all compartments
    /// - Returns: Array of neighboring compartments
    private static func findNeighbors(for compartment: Compartment, in organizer: OrganizerDesign) -> [Compartment] {
        let allCompartments = organizer.compartmentsArray

        return allCompartments.filter { other in
            guard other.id != compartment.id else { return false }

            // Check if compartments are adjacent on any axis
            return isNeighborOnTop(compartment, other) ||
                   isNeighborOnBottom(compartment, other) ||
                   isNeighborOnLeft(compartment, other) ||
                   isNeighborOnRight(compartment, other) ||
                   isNeighborOnFront(compartment, other) ||
                   isNeighborOnBack(compartment, other)
        }
    }

    /// Check if other compartment is on top (positive Y) of compartment
    private static func isNeighborOnTop(_ compartment: Compartment, _ other: Compartment) -> Bool {
        let expectedY = compartment.positionY + compartment.height
        let actualY = other.positionY

        return abs(expectedY - actualY) < neighborThreshold &&
               compartment.positionX == other.positionX &&
               compartment.positionZ == other.positionZ
    }

    /// Check if other compartment is on bottom (negative Y) of compartment
    private static func isNeighborOnBottom(_ compartment: Compartment, _ other: Compartment) -> Bool {
        let expectedY = compartment.positionY - other.height
        let actualY = other.positionY

        return abs(expectedY - actualY) < neighborThreshold &&
               compartment.positionX == other.positionX &&
               compartment.positionZ == other.positionZ
    }

    /// Check if other compartment is on left (negative X) of compartment
    private static func isNeighborOnLeft(_ compartment: Compartment, _ other: Compartment) -> Bool {
        let expectedX = compartment.positionX - other.width
        let actualX = other.positionX

        return abs(expectedX - actualX) < neighborThreshold &&
               compartment.positionY == other.positionY &&
               compartment.positionZ == other.positionZ
    }

    /// Check if other compartment is on right (positive X) of compartment
    private static func isNeighborOnRight(_ compartment: Compartment, _ other: Compartment) -> Bool {
        let expectedX = compartment.positionX + compartment.width
        let actualX = other.positionX

        return abs(expectedX - actualX) < neighborThreshold &&
               compartment.positionY == other.positionY &&
               compartment.positionZ == other.positionZ
    }

    /// Check if other compartment is on front (negative Z) of compartment
    private static func isNeighborOnFront(_ compartment: Compartment, _ other: Compartment) -> Bool {
        let expectedZ = compartment.positionZ - other.depth
        let actualZ = other.positionZ

        return abs(expectedZ - actualZ) < neighborThreshold &&
               compartment.positionX == other.positionX &&
               compartment.positionY == other.positionY
    }

    /// Check if other compartment is on back (positive Z) of compartment
    private static func isNeighborOnBack(_ compartment: Compartment, _ other: Compartment) -> Bool {
        let expectedZ = compartment.positionZ + compartment.depth
        let actualZ = other.positionZ

        return abs(expectedZ - actualZ) < neighborThreshold &&
               compartment.positionX == other.positionX &&
               compartment.positionY == other.positionY
    }

    /// Determine if a compartment edge should have a tab (vs groove)
    /// Uses deterministic logic based on compartment ID for consistency
    private static func shouldAssignTab(for compartment: Compartment, edge: String) -> Bool {
        // Use hash of compartment ID + edge name to determine tab/groove assignment
        // This ensures consistent assignment across saves
        let combined = "\(compartment.id?.uuidString ?? "")-\(edge)"
        let hash = combined.hash

        // Odd hash = tab, even hash = groove
        return hash % 2 == 1
    }
}
