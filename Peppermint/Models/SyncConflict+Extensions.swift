//
//  SyncConflict+CoreDataClass.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 2 - Foundational: Conflict detection and resolution for multi-device sync
//

import CoreData
import Foundation

// MARK: - Resolution Strategy Enum

/// Strategies for resolving sync conflicts when the same organizer is edited on multiple devices
enum ResolutionStrategy: String, Codable {
    case keepLocal = "keepLocal"       // Force this device's version to CloudKit
    case keepRemote = "keepRemote"     // Overwrite local with CloudKit version
    case merge = "merge"               // Property-level last-write-wins (recommended)
}

// MARK: - Sync Error Types

enum SyncError: Error, LocalizedError {
    case organizerDeleted
    case invalidLocalData
    case invalidRemoteData
    case resolutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .organizerDeleted:
            return "The organizer was deleted before the conflict could be resolved."
        case .invalidLocalData:
            return "Local version data is corrupted and cannot be decoded."
        case .invalidRemoteData:
            return "Remote version data is corrupted and cannot be decoded."
        case .resolutionFailed(let reason):
            return "Conflict resolution failed: \(reason)"
        }
    }
}

// MARK: - Organizer JSON Snapshot

/// Simplified JSON representation of OrganizerDesign for conflict comparison
///
/// This struct captures the essential state of an organizer at a specific point in time.
/// Used for conflict detection and resolution.
struct OrganizerSnapshot: Codable {
    let id: UUID
    let name: String
    let modifiedAt: Date
    let compartmentCount: Int
    let thumbnailData: Data?

    // Simplified compartment data (just IDs and basic properties)
    let compartmentIDs: [UUID]
    let compartmentPositions: [String: [Float]] // [compartmentID: [x, y, z]]
}

// MARK: - SyncConflict Extension

extension SyncConflict {

    // MARK: - Conflict Creation

    /// Creates a new conflict record when multi-device edit is detected
    ///
    /// **Conflict scenario**:
    /// 1. User edits organizer "Vitamin Box" on iPhone (offline)
    /// 2. User edits same organizer on iPad (offline)
    /// 3. Both devices come online
    /// 4. CloudKit detects conflict (same object modified in two places)
    /// 5. This method creates a `SyncConflict` record for user resolution
    ///
    /// - Parameters:
    ///   - organizer: The organizer that has a conflict
    ///   - localVersion: The local (this device's) version of the organizer
    ///   - remoteVersion: The remote (CloudKit) version of the organizer
    ///   - context: The managed object context to create the conflict in
    ///
    /// - Returns: A new `SyncConflict` instance
    ///
    /// - Throws: `SyncError` if JSON encoding fails
    @discardableResult
    static func create(
        for organizer: OrganizerDesign,
        localVersion: OrganizerDesign,
        remoteVersion: OrganizerDesign,
        in context: NSManagedObjectContext
    ) throws -> SyncConflict {
        let conflict = SyncConflict(context: context)
        conflict.id = UUID()
        conflict.detectedAt = Date()
        conflict.organizer = organizer
        conflict.resolved = false

        // Capture local version snapshot
        let localSnapshot = createSnapshot(from: localVersion)
        conflict.localVersionData = try JSONEncoder().encode(localSnapshot)

        // Capture remote version snapshot
        let remoteSnapshot = createSnapshot(from: remoteVersion)
        conflict.remoteVersionData = try JSONEncoder().encode(remoteSnapshot)

        print("⚠️ Conflict detected for organizer '\(organizer.name ?? "Unknown")'")
        print("   Local modified: \(localVersion.modifiedAt)")
        print("   Remote modified: \(remoteVersion.modifiedAt)")

        return conflict
    }

    // MARK: - Snapshot Creation

    /// Creates a lightweight JSON snapshot of an organizer for conflict comparison
    ///
    /// This avoids storing full CoreData objects in binary format, which can be brittle
    /// across model versions.
    private static func createSnapshot(from organizer: OrganizerDesign) -> OrganizerSnapshot {
        let compartmentsSet = organizer.compartments as? Set<Compartment> ?? []
        let compartmentIDs = compartmentsSet.map { $0.id! }

        var positions: [String: [Float]] = [:]
        for compartment in compartmentsSet {
            positions[compartment.id!.uuidString] = [
                compartment.positionX,
                compartment.positionY,
                compartment.positionZ
            ]
        }

        return OrganizerSnapshot(
            id: organizer.id!,
            name: organizer.name ?? "Unnamed",
            modifiedAt: organizer.modifiedAt!,
            compartmentCount: compartmentsSet.count,
            thumbnailData: organizer.thumbnailData,
            compartmentIDs: compartmentIDs,
            compartmentPositions: positions
        )
    }

    // MARK: - Conflict Resolution

    /// Applies the user's chosen resolution strategy to resolve the conflict
    ///
    /// **Resolution strategies**:
    /// - `.keepLocal`: Force this device's version to CloudKit (overwrite remote)
    /// - `.keepRemote`: Discard local changes and use CloudKit version
    /// - `.merge`: Use property-level last-write-wins (recommended - preserves most changes)
    ///
    /// - Parameters:
    ///   - strategy: The resolution strategy chosen by the user
    ///   - context: The managed object context to perform resolution in
    ///
    /// - Throws: `SyncError` if organizer is deleted or resolution fails
    func resolve(strategy: ResolutionStrategy, in context: NSManagedObjectContext) throws {
        guard let organizer = self.organizer else {
            throw SyncError.organizerDeleted
        }

        print("🔧 Resolving conflict for '\(organizer.name ?? "Unknown")' using strategy: \(strategy.rawValue)")

        switch strategy {
        case .keepLocal:
            // Force local version to CloudKit (mark as pending sync)
            organizer.syncStatusEnum = .pending
            organizer.conflictVersion += 1
            print("   ✅ Keeping local version - will push to CloudKit")

        case .keepRemote:
            // Overwrite local with remote data
            guard let remoteSnapshot = try? JSONDecoder().decode(OrganizerSnapshot.self, from: remoteVersionData!) else {
                throw SyncError.invalidRemoteData
            }

            // Apply remote changes
            organizer.name = remoteSnapshot.name
            organizer.modifiedAt = remoteSnapshot.modifiedAt
            organizer.thumbnailData = remoteSnapshot.thumbnailData
            organizer.syncStatusEnum = .synced
            organizer.conflictVersion += 1

            print("   ✅ Applied remote version from CloudKit")

        case .merge:
            // Property-level last-write-wins
            // NSMergeByPropertyObjectTrumpMergePolicy already configured in PersistenceController
            // For each property, newest timestamp wins automatically
            organizer.syncStatusEnum = .synced
            organizer.conflictVersion += 1

            print("   ✅ Merged using property-level last-write-wins")
        }

        // Mark conflict as resolved
        self.resolved = true
        self.resolutionStrategy = strategy.rawValue
        self.resolvedAt = Date()

        // Save context
        try context.save()

        print("✅ Conflict resolved successfully")
    }

    // MARK: - Conflict Information

    /// Returns the local version snapshot (decoded from JSON)
    ///
    /// - Returns: The local organizer snapshot, or `nil` if data is corrupted
    var localSnapshot: OrganizerSnapshot? {
        return try? JSONDecoder().decode(OrganizerSnapshot.self, from: localVersionData!)
    }

    /// Returns the remote version snapshot (decoded from JSON)
    ///
    /// - Returns: The remote organizer snapshot, or `nil` if data is corrupted
    var remoteSnapshot: OrganizerSnapshot? {
        return try? JSONDecoder().decode(OrganizerSnapshot.self, from: remoteVersionData!)
    }

    /// Returns a human-readable description of the conflict
    ///
    /// **Example**: "Conflict detected 5 minutes ago - not resolved"
    var conflictDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        let timeAgo = formatter.localizedString(for: detectedAt!, relativeTo: Date())

        if resolved {
            if let resolvedTime = resolvedAt {
                let resolvedTimeAgo = formatter.localizedString(for: resolvedTime, relativeTo: Date())
                return "Resolved \(resolvedTimeAgo) using '\(resolutionStrategy ?? "unknown")'"
            }
            return "Resolved"
        } else {
            return "Conflict detected \(timeAgo) - not resolved"
        }
    }

    /// Returns a user-friendly comparison of local vs remote changes
    ///
    /// **Example**:
    /// ```
    /// Local:  Modified 2 hours ago, 5 compartments
    /// Remote: Modified 1 hour ago, 6 compartments
    /// Recommendation: Use Remote (newer)
    /// ```
    var comparisonDescription: String {
        guard let local = localSnapshot, let remote = remoteSnapshot else {
            return "Unable to compare versions (corrupted data)"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        let localTime = formatter.localizedString(for: local.modifiedAt, relativeTo: Date())
        let remoteTime = formatter.localizedString(for: remote.modifiedAt, relativeTo: Date())

        var description = """
        Local Version:
          - Modified: \(localTime)
          - Compartments: \(local.compartmentCount)

        Remote Version (iCloud):
          - Modified: \(remoteTime)
          - Compartments: \(remote.compartmentCount)
        """

        // Recommendation based on timestamps
        if remote.modifiedAt > local.modifiedAt {
            description += "\n\nRecommendation: Use Remote (newer)"
        } else if local.modifiedAt > remote.modifiedAt {
            description += "\n\nRecommendation: Use Local (newer)"
        } else {
            description += "\n\nRecommendation: Merge (same timestamp)"
        }

        return description
    }
}
