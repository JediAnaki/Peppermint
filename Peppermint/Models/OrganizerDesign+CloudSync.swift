//
//  OrganizerDesign+CloudSync.swift
//  Peppermint
//
//  Created for Feature: OpenSCAD-Based STL Export with Cloud Sync
//  Phase 2 - Foundational: Cloud sync extension for OrganizerDesign entity
//

import CoreData
import Foundation

// MARK: - Cloud Sync Status Enum

/// Represents the current synchronization status of an organizer design
enum SyncStatus: String {
    case local = "local"         // Cloud sync disabled for this organizer
    case synced = "synced"       // Up to date with CloudKit
    case pending = "pending"     // Local changes waiting to sync
    case syncing = "syncing"     // Currently uploading to CloudKit
    case error = "error"         // Sync failed (check error logs)
    case conflict = "conflict"   // Multi-device conflict detected
}

// MARK: - OrganizerDesign Cloud Sync Extension

extension OrganizerDesign {

    /// Computed property for type-safe sync status access
    ///
    /// Converts the string `syncStatus` attribute to a `SyncStatus` enum
    /// Defaults to `.local` if the status string is invalid or nil
    var syncStatusEnum: SyncStatus {
        get {
            guard let statusString = syncStatus else { return .local }
            return SyncStatus(rawValue: statusString) ?? .local
        }
        set {
            syncStatus = newValue.rawValue
        }
    }

    // MARK: - Sync State Management

    /// Marks the organizer as needing synchronization to CloudKit
    ///
    /// This method should be called whenever local changes are made to the organizer
    /// (e.g., adding/editing compartments, changing name, etc.)
    ///
    /// **Only applies if cloud sync is enabled** for this organizer.
    ///
    /// - Note: Sets `syncStatus` to `.pending` and updates `modifiedAt` timestamp
    func markForSync() {
        guard cloudSyncEnabled else { return }
        syncStatusEnum = .pending
        modifiedAt = Date()
    }

    /// Marks the organizer as successfully synchronized with CloudKit
    ///
    /// This method is called by the sync service after a successful upload to CloudKit
    ///
    /// **Only applies if cloud sync is enabled** for this organizer.
    ///
    /// - Note: Sets `syncStatus` to `.synced` and updates `lastSyncedAt` timestamp
    func markSynced() {
        guard cloudSyncEnabled else { return }
        syncStatusEnum = .synced
        lastSyncedAt = Date()
    }

    /// Marks the organizer as currently syncing to CloudKit
    ///
    /// This prevents duplicate sync operations for the same organizer
    func markSyncing() {
        guard cloudSyncEnabled else { return }
        syncStatusEnum = .syncing
    }

    /// Marks the organizer as having a sync error
    ///
    /// - Parameter errorMessage: Optional error description (for debugging)
    func markSyncError(_ errorMessage: String? = nil) {
        guard cloudSyncEnabled else { return }
        syncStatusEnum = .error

        if let errorMessage = errorMessage {
            print("❌ Sync error for organizer '\(name ?? "Unknown")': \(errorMessage)")
        }
    }

    /// Marks the organizer as having a sync conflict
    ///
    /// This occurs when the same organizer is edited on multiple devices while offline
    func markConflict() {
        guard cloudSyncEnabled else { return }
        syncStatusEnum = .conflict
        conflictVersion += 1
    }

    // MARK: - Computed Properties

    /// Checks if the organizer has unsynchronized local changes
    ///
    /// - Returns: `true` if local changes exist that haven't been synced, `false` otherwise
    ///
    /// **Logic**:
    /// - If cloud sync disabled → always returns `false`
    /// - If never synced → returns `true` (needs initial sync)
    /// - If `modifiedAt` > `lastSyncedAt` → returns `true` (edited since last sync)
    var hasUnsyncedChanges: Bool {
        guard cloudSyncEnabled else { return false }

        // Never synced before
        guard let lastSynced = lastSyncedAt else { return true }

        // Modified after last sync
        return modifiedAt! > lastSynced
    }

    /// Checks if the organizer is currently pending synchronization
    var isPendingSync: Bool {
        return syncStatusEnum == .pending && cloudSyncEnabled
    }

    /// Checks if the organizer is currently being synchronized
    var isSyncing: Bool {
        return syncStatusEnum == .syncing && cloudSyncEnabled
    }

    /// Checks if the organizer has a sync conflict
    var hasConflict: Bool {
        return syncStatusEnum == .conflict && cloudSyncEnabled
    }

    /// Checks if the organizer has a sync error
    var hasSyncError: Bool {
        return syncStatusEnum == .error && cloudSyncEnabled
    }

    // MARK: - User-Friendly Status Description

    /// Returns a human-readable status message for UI display
    ///
    /// **Examples**:
    /// - "Synced" (green checkmark)
    /// - "Syncing..." (spinner)
    /// - "Pending sync" (waiting)
    /// - "Conflict detected" (warning)
    /// - "Local only" (cloud disabled)
    var syncStatusDescription: String {
        guard cloudSyncEnabled else {
            return "Local only"
        }

        switch syncStatusEnum {
        case .local:
            return "Local only"
        case .synced:
            if let lastSynced = lastSyncedAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Synced \(formatter.localizedString(for: lastSynced, relativeTo: Date()))"
            }
            return "Synced"
        case .pending:
            return "Pending sync"
        case .syncing:
            return "Syncing..."
        case .error:
            return "Sync failed"
        case .conflict:
            return "Conflict detected"
        }
    }

    /// Returns an SF Symbol name for the current sync status
    ///
    /// **Icon mappings**:
    /// - `.local` → `"icloud.slash"` (no cloud)
    /// - `.synced` → `"checkmark.icloud"` (success)
    /// - `.pending` → `"icloud"` (waiting)
    /// - `.syncing` → `"icloud.and.arrow.up"` (uploading)
    /// - `.error` → `"exclamationmark.icloud"` (warning)
    /// - `.conflict` → `"exclamationmark.triangle"` (conflict)
    var syncStatusIcon: String {
        guard cloudSyncEnabled else {
            return "icloud.slash"
        }

        switch syncStatusEnum {
        case .local:
            return "icloud.slash"
        case .synced:
            return "checkmark.icloud"
        case .pending:
            return "icloud"
        case .syncing:
            return "icloud.and.arrow.up"
        case .error:
            return "exclamationmark.icloud"
        case .conflict:
            return "exclamationmark.triangle"
        }
    }
}

// MARK: - Compartments Array Helper

extension OrganizerDesign {
    /// Returns compartments as a sorted array (by createdAt)
    ///
    /// CoreData relationships return `NSSet`, which is unordered.
    /// This helper provides a consistent, sorted array for UI display.
    var compartmentsSortedArray: [Compartment] {
        let set = compartments as? Set<Compartment> ?? []
        return set.sorted { $0.createdAt! < $1.createdAt! }
    }
}
