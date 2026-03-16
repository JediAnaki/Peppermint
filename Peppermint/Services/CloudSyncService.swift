import Foundation
import CoreData
import CloudKit
import Combine

/// Cloud Sync Service - T071-T077
///
/// Manages conflict detection and resolution for multi-device synchronization.
/// Monitors persistent history to detect when the same organizer is modified on multiple devices offline.
@MainActor
class CloudSyncService: ObservableObject {
    // MARK: - Published Properties

    /// T071: Current sync status
    @Published var syncStatus: SyncStatus = .synced

    /// T072: Whether a conflict has been detected
    @Published var conflictDetected = false

    /// T075: The currently detected conflict (if any)
    @Published var currentConflict: SyncConflict?

    /// T075: The organizer involved in the conflict
    @Published var conflictedOrganizer: OrganizerDesign?

    // MARK: - Private Properties

    private let persistenceController = DataPersistenceService.shared

    /// T077: Last processed history token for incremental checking
    private var lastHistoryToken: NSPersistentHistoryToken?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Load last history token from UserDefaults if exists
        if let tokenData = UserDefaults.standard.data(forKey: "lastHistoryToken") {
            lastHistoryToken = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSPersistentHistoryToken.self,
                from: tokenData
            )
        }
    }

    // MARK: - Public Methods

    /// T072: Setup observer for persistent history changes
    func setupConflictObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePersistentHistoryChange),
            name: .NSPersistentStoreRemoteChange,
            object: persistenceController.persistentContainer.persistentStoreCoordinator
        )

        print("✅ CloudSyncService: Conflict observer setup complete")
    }

    /// T078-T083: Resolve conflict using selected strategy
    func resolveConflict(strategy: ResolutionStrategy) {
        guard let conflict = currentConflict else {
            print("⚠️ No conflict to resolve")
            return
        }

        let context = persistenceController.viewContext

        do {
            try conflict.resolve(strategy: strategy, in: context)

            // Clear conflict state
            self.conflictDetected = false
            self.currentConflict = nil
            self.conflictedOrganizer = nil
            self.syncStatus = .synced

            print("✅ Conflict resolved with strategy: \(strategy.rawValue)")

        } catch {
            print("❌ Failed to resolve conflict: \(error)")
            syncStatus = .error("Failed to resolve conflict")
        }
    }

    // MARK: - Private Methods

    /// T073: Handle persistent history changes from CloudKit
    @objc private func handlePersistentHistoryChange(_ notification: Notification) {
        persistenceController.viewContext.perform {
            Task { @MainActor in
                await self.processHistoryChanges()
            }
        }
    }

    /// T073-T076: Process persistent history to detect conflicts
    private func processHistoryChanges() async {
        let context = persistenceController.viewContext

        // T073: Fetch changes after last history token
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: lastHistoryToken)

        do {
            let result = try context.execute(request) as? NSPersistentHistoryResult
            guard let transactions = result?.result as? [NSPersistentHistoryTransaction] else {
                return
            }

            print("☁️ Processing \(transactions.count) history transactions")

            // T074: Check each transaction for conflicts
            for transaction in transactions {
                // Skip transactions made by this app instance
                if transaction.author == "app" { continue }

                for change in transaction.changes ?? [] {
                    // T074: Detect conflicts on update operations
                    if change.changeType == .update {
                        await detectConflict(for: change, in: context)
                    }
                }
            }

            // T077: Update last history token
            if let lastTransaction = transactions.last {
                saveHistoryToken(lastTransaction.token)
            }

        } catch {
            print("❌ Failed to process persistent history: \(error)")
        }
    }

    /// T074-T075: Detect if a change conflicts with local modifications
    private func detectConflict(for change: NSPersistentHistoryChange, in context: NSManagedObjectContext) async {
        guard let objectID = change.changedObjectID else { return }

        // Only check OrganizerDesign entities
        guard objectID.entity.name == "OrganizerDesign" else { return }

        // T074: Check if local version also has changes
        guard hasLocalChanges(for: objectID, in: context) else { return }

        // T075: Conflict detected - create SyncConflict entity
        do {
            guard let organizer = try context.existingObject(with: objectID) as? OrganizerDesign else {
                return
            }

            // Create conflict record
            let conflict = SyncConflict.create(
                for: organizer,
                localVersion: organizer,
                remoteVersion: organizer, // Remote version will be fetched from CloudKit
                in: context
            )

            try context.save()

            // Update published state
            self.conflictDetected = true
            self.currentConflict = conflict
            self.conflictedOrganizer = organizer
            self.syncStatus = .conflict

            print("⚠️ Conflict detected for organizer: \(organizer.name ?? "Untitled")")

        } catch {
            print("❌ Failed to create conflict record: \(error)")
        }
    }

    /// T076: Check if object has uncommitted local changes
    private func hasLocalChanges(for objectID: NSManagedObjectID, in context: NSManagedObjectContext) -> Bool {
        guard let object = try? context.existingObject(with: objectID) else {
            return false
        }

        // Check if object is in modified state
        return object.hasChanges
    }

    /// T077: Save history token for incremental processing
    private func saveHistoryToken(_ token: NSPersistentHistoryToken) {
        self.lastHistoryToken = token

        // Persist to UserDefaults
        if let tokenData = try? NSKeyedArchiver.archivedData(
            withRootObject: token,
            requiringSecureCoding: true
        ) {
            UserDefaults.standard.set(tokenData, forKey: "lastHistoryToken")
        }
    }
}

// MARK: - SyncStatus Enum

enum SyncStatus: Equatable {
    case synced
    case syncing
    case offline
    case error(String)
    case conflict

    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.synced, .synced),
             (.syncing, .syncing),
             (.offline, .offline),
             (.conflict, .conflict):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
