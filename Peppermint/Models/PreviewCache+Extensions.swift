//
//  PreviewCache+CoreDataClass.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 2 - Foundational: Preview cache management with SHA256 hashing
//

import CoreData
import CryptoKit
import Foundation

// MARK: - PreviewCache Extension

extension PreviewCache {

    // MARK: - Cache Key Generation

    /// Generates a unique cache key based on organizer geometry and pill visualization settings
    ///
    /// **Cache invalidation**: The cache key changes whenever:
    /// - Compartment dimensions change (width, height, depth)
    /// - Compartment positions change (x, y, z)
    /// - Pill visualization is toggled on/off
    /// - Medication data changes (for pill visualization)
    ///
    /// - Parameters:
    ///   - organizer: The organizer design to generate a cache key for
    ///   - includePills: Whether pill visualization is enabled in the preview
    ///
    /// - Returns: SHA256 hash string (64 hex characters) uniquely identifying this geometry configuration
    ///
    /// **Example**: `"a3f2c1...def890"` (64 char hex string)
    static func generateCacheKey(for organizer: OrganizerDesign, includePills: Bool) -> String {
        var hashInput = ""

        // Get sorted compartments for consistent hashing (order matters for reproducibility)
        let compartmentsSet = organizer.compartments as? Set<Compartment> ?? []
        let sortedCompartments = compartmentsSet.sorted { $0.id!.uuidString < $1.id!.uuidString }

        // Include all geometry-affecting properties
        for compartment in sortedCompartments {
            // Compartment ID (ensures uniqueness even if dimensions match)
            hashInput += "\(compartment.id!.uuidString),"

            // Dimensions (width, height, depth in mm)
            hashInput += "\(compartment.width),\(compartment.height),\(compartment.depth),"

            // Position (x, y, z coordinates)
            hashInput += "\(compartment.positionX),\(compartment.positionY),\(compartment.positionZ),"

            // Color (affects STL visualization but not geometry - include for consistency)
            hashInput += "\(compartment.colorHex),"

            // For pill visualization, include medication data in hash
            if includePills, let medication = compartment.medication {
                // Only include if medication.name is filled (FR-017: pill trigger condition)
                if let name = medication.name, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    hashInput += "\(name),"
                    hashInput += "\(medication.pillShape ?? "round"),"
                    hashInput += "\(medication.pillDiameter),"
                    hashInput += "\(medication.pillLength),"
                }
            }
        }

        // Include pill visualization flag in hash
        hashInput += "includePills:\(includePills)"

        // Generate SHA256 hash
        let inputData = Data(hashInput.utf8)
        let hash = SHA256.hash(data: inputData)

        // Convert hash to hex string (64 characters)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Cache Validation

    /// Checks if this cached STL is still valid for the current organizer state
    ///
    /// **Validation logic**:
    /// 1. Regenerate cache key from current organizer geometry
    /// 2. Compare with stored `cacheKey`
    /// 3. Check that `includesPillVisualization` matches request
    ///
    /// - Parameters:
    ///   - organizer: The organizer design to validate against
    ///   - includePills: Whether pill visualization is requested
    ///
    /// - Returns: `true` if cache is valid and can be reused, `false` if regeneration needed
    ///
    /// **Cache miss scenarios**:
    /// - Compartment edited (dimensions/position changed)
    /// - Compartment added/removed
    /// - Medication data changed (for pill previews)
    /// - User toggled pill visualization on/off
    func isValid(for organizer: OrganizerDesign, includePills: Bool) -> Bool {
        let currentKey = Self.generateCacheKey(for: organizer, includePills: includePills)
        return self.cacheKey == currentKey && self.includesPillVisualization == includePills
    }

    // MARK: - Cache Metadata

    /// Returns a human-readable description of cache age
    ///
    /// **Examples**:
    /// - "Generated 5 minutes ago"
    /// - "Generated 2 hours ago"
    /// - "Generated yesterday"
    var cacheAgeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Generated \(formatter.localizedString(for: generatedAt!, relativeTo: Date()))"
    }

    /// Returns file size in human-readable format
    ///
    /// **Examples**:
    /// - "512 KB"
    /// - "1.2 MB"
    /// - "45 bytes"
    var fileSizeFormatted: String {
        let bytes = Double(fileSizeBytes)

        if bytes < 1024 {
            return "\(Int(bytes)) bytes"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }

    /// Returns triangle count in human-readable format
    ///
    /// **Examples**:
    /// - "15K triangles"
    /// - "152K triangles"
    /// - "1.2M triangles"
    var triangleCountFormatted: String {
        let count = Double(triangleCount)

        if count < 1000 {
            return "\(triangleCount) triangles"
        } else if count < 1_000_000 {
            return String(format: "%.1fK triangles", count / 1000)
        } else {
            return String(format: "%.1fM triangles", count / 1_000_000)
        }
    }

    // MARK: - Cache Performance Metrics

    /// Checks if this cache entry is "fresh" (generated within the last hour)
    ///
    /// Fresh cache entries are good candidates for display, while stale entries
    /// might be outdated and should be validated more carefully.
    var isFresh: Bool {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return generatedAt! > oneHourAgo
    }

    /// Checks if this cache entry is "stale" (generated more than 24 hours ago)
    ///
    /// Stale cache entries are candidates for eviction when cache size limit is reached
    var isStale: Bool {
        let oneDayAgo = Date().addingTimeInterval(-86400) // 24 hours
        return generatedAt! < oneDayAgo
    }
}

// MARK: - Debug Description

extension PreviewCache {
    /// Provides a detailed debug description of the cache entry
    ///
    /// Useful for console logging and cache diagnostics
    public override var debugDescription: String {
        return """
        PreviewCache:
          - ID: \(id?.uuidString ?? "nil")
          - Cache Key: \(cacheKey!.prefix(16))... (SHA256)
          - File Size: \(fileSizeFormatted)
          - Triangles: \(triangleCountFormatted)
          - Generated: \(cacheAgeDescription)
          - Pills: \(includesPillVisualization ? "Yes" : "No")
          - Freshness: \(isFresh ? "Fresh" : "Stale")
        """
    }
}
