import Foundation
import CoreData
import CloudKit

class DataPersistenceService {
    static let shared = DataPersistenceService()

    // MARK: - Preview Support

    static var preview: DataPersistenceService = {
        let service = DataPersistenceService(inMemory: true)

        // Create sample data for previews
        let context = service.viewContext
        let organizer = OrganizerDesign(context: context)
        organizer.id = UUID()
        organizer.name = "Sample Organizer"
        organizer.createdAt = Date()
        organizer.modifiedAt = Date()

        do {
            try context.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }

        return service
    }()

    // MARK: - Core Data Stack

    lazy var persistentContainer: NSPersistentCloudKitContainer = {
        // Use NSPersistentCloudKitContainer for CloudKit support (T014)
        let container = NSPersistentCloudKitContainer(name: "PeppermintDataModel")

        if inMemory {
            // Use in-memory store for previews/testing
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit container options based on user preference
            if UserDefaults.standard.bool(forKey: "cloudSyncEnabled") {
                configureCloudKitContainer(for: container)
            } else {
                disableCloudKitContainer(for: container)
            }

            // Configure encryption for production
            let storeDescription = container.persistentStoreDescriptions.first
            storeDescription?.setOption(FileProtectionType.complete as NSObject,
                                       forKey: NSPersistentStoreFileProtectionKey)

            // Enable automatic lightweight migration (T014)
            storeDescription?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            storeDescription?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            print("✅ CoreData loaded: \(description)")
        }

        // T015: Configure merge policies for conflict resolution
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Listen for remote changes from CloudKit
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )

        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    private let inMemory: Bool

    private init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }

    // MARK: - Core Data Saving Support

    func saveContext() {
        let context = viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }

    // MARK: - CRUD Operations for OrganizerDesign

    func createOrganizer(name: String) -> OrganizerDesign {
        let organizer = OrganizerDesign(context: viewContext)
        organizer.id = UUID()
        organizer.name = name
        organizer.createdAt = Date()
        organizer.modifiedAt = Date()
        saveContext()
        return organizer
    }

    func fetchAllOrganizers() -> [OrganizerDesign] {
        let request: NSFetchRequest<OrganizerDesign> = OrganizerDesign.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching organizers: \(error)")
            return []
        }
    }

    func deleteOrganizer(_ organizer: OrganizerDesign) {
        viewContext.delete(organizer)
        saveContext()
    }

    // MARK: - CRUD Operations for Compartment

    func createCompartment(in organizer: OrganizerDesign,
                          width: Float,
                          height: Float,
                          depth: Float,
                          position: (x: Float, y: Float, z: Float),
                          colorHex: String = "#CCCCCC",
                          connectorMetadata: Data) -> Compartment {
        let compartment = Compartment(context: viewContext)
        compartment.id = UUID()
        compartment.width = width
        compartment.height = height
        compartment.depth = depth
        compartment.positionX = position.x
        compartment.positionY = position.y
        compartment.positionZ = position.z
        compartment.colorHex = colorHex
        compartment.connectorMetadata = connectorMetadata
        compartment.createdAt = Date()
        compartment.organizer = organizer

        organizer.modifiedAt = Date()
        saveContext()
        return compartment
    }

    func deleteCompartment(_ compartment: Compartment) {
        compartment.organizer?.modifiedAt = Date()
        viewContext.delete(compartment)
        saveContext()
    }

    // MARK: - CRUD Operations for Medication

    func createMedication(for compartment: Compartment,
                         name: String,
                         expirationDate: Date? = nil,
                         category: String? = nil,
                         notes: String? = nil) -> Medication {
        let medication = Medication(context: viewContext)
        medication.id = UUID()
        medication.name = name
        medication.expirationDate = expirationDate
        medication.category = category
        medication.notes = notes
        medication.createdAt = Date()
        medication.modifiedAt = Date()
        medication.compartment = compartment

        compartment.organizer?.modifiedAt = Date()
        saveContext()
        return medication
    }

    func updateMedication(_ medication: Medication,
                         name: String? = nil,
                         expirationDate: Date? = nil,
                         category: String? = nil,
                         notes: String? = nil) {
        if let name = name {
            medication.name = name
        }
        if let expirationDate = expirationDate {
            medication.expirationDate = expirationDate
        }
        if let category = category {
            medication.category = category
        }
        if let notes = notes {
            medication.notes = notes
        }

        medication.modifiedAt = Date()
        medication.compartment?.organizer?.modifiedAt = Date()
        saveContext()
    }

    func deleteMedication(_ medication: Medication) {
        medication.compartment?.organizer?.modifiedAt = Date()
        viewContext.delete(medication)
        saveContext()
    }

    // MARK: - CRUD Operations for ReminderSchedule

    func createReminderSchedule(for medication: Medication,
                               frequency: String,
                               timesOfDay: Data,
                               daysOfWeek: Data? = nil,
                               customDates: Data? = nil,
                               soundName: String? = nil) -> ReminderSchedule {
        let schedule = ReminderSchedule(context: viewContext)
        schedule.id = UUID()
        schedule.enabled = true
        schedule.frequency = frequency
        schedule.timesOfDay = timesOfDay
        schedule.daysOfWeek = daysOfWeek
        schedule.customDates = customDates
        schedule.soundName = soundName
        schedule.createdAt = Date()
        schedule.modifiedAt = Date()
        schedule.medication = medication

        medication.modifiedAt = Date()
        saveContext()
        return schedule
    }

    func deleteReminderSchedule(_ schedule: ReminderSchedule) {
        schedule.medication?.modifiedAt = Date()
        viewContext.delete(schedule)
        saveContext()
    }

    // MARK: - CRUD Operations for ExportHistory

    func createExportHistory(for organizer: OrganizerDesign,
                            fileName: String,
                            fileSize: Int64,
                            compartmentCount: Int16,
                            exportDuration: TimeInterval) -> ExportHistory {
        let history = ExportHistory(context: viewContext)
        history.id = UUID()
        history.exportedAt = Date()
        history.fileName = fileName
        history.fileSize = fileSize
        history.compartmentCount = compartmentCount
        history.exportDuration = exportDuration
        history.organizer = organizer

        saveContext()
        return history
    }

    // MARK: - CloudKit Configuration (T014)

    /// Configures CloudKit container options for cloud sync
    ///
    /// This enables automatic synchronization with iCloud for organizer designs
    private func configureCloudKitContainer(for container: NSPersistentCloudKitContainer) {
        guard let description = container.persistentStoreDescriptions.first else { return }

        // Set CloudKit container identifier from entitlements
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.peppermint.organizer"
        )

        // Enable persistent history tracking for conflict detection (T015)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

        // Enable remote change notifications
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        print("✅ CloudKit container enabled for cloud sync")
    }

    /// Disables CloudKit container for local-only mode
    ///
    /// This ensures no data is synced to iCloud when cloud backup is disabled
    private func disableCloudKitContainer(for container: NSPersistentCloudKitContainer) {
        guard let description = container.persistentStoreDescriptions.first else { return }

        // Disable CloudKit sync
        description.cloudKitContainerOptions = nil

        print("📍 CloudKit container disabled (local-only mode)")
    }

    /// Handles remote changes from CloudKit
    ///
    /// This is called automatically when another device pushes changes to iCloud
    @objc private func handleRemoteChange(_ notification: Notification) {
        print("☁️ Remote change detected from CloudKit")

        // Notify UI to refresh (e.g., organizer library)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cloudSyncCompleted, object: nil)
        }
    }

    // MARK: - Cloud Sync Control

    /// Enables cloud backup for all existing organizers
    ///
    /// Called when user enables cloud sync in Settings
    func enableCloudKit() {
        UserDefaults.standard.set(true, forKey: "cloudSyncEnabled")

        // Mark all existing organizers for cloud sync
        let organizers = fetchAllOrganizers()
        for organizer in organizers {
            organizer.cloudSyncEnabled = true
            organizer.markForSync()
        }

        saveContext()
        print("✅ Enabled cloud sync for \(organizers.count) organizers")

        // Reload persistent container with CloudKit enabled
        // Note: In production, this requires app restart or manual container reload
    }

    /// Disables cloud backup for all organizers
    ///
    /// Called when user disables cloud sync in Settings
    /// Note: Does not delete data from iCloud, just stops future syncing
    func disableCloudKit() {
        UserDefaults.standard.set(false, forKey: "cloudSyncEnabled")

        // Update all organizers to local-only mode
        let organizers = fetchAllOrganizers()
        for organizer in organizers {
            organizer.cloudSyncEnabled = false
        }

        saveContext()
        print("📍 Disabled cloud sync (data remains local)")
    }

    /// Checks if cloud sync is currently enabled
    var isCloudSyncEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "cloudSyncEnabled")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when CloudKit sync completes successfully
    static let cloudSyncCompleted = Notification.Name("cloudSyncCompleted")

    /// Posted when user manually triggers sync
    static let forceCloudSync = Notification.Name("forceCloudSync")
}
