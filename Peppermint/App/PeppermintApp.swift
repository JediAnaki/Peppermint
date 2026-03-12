import SwiftUI
import UserNotifications

@main
struct PeppermintApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceService = DataPersistenceService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceService.viewContext)
                .environmentObject(appDelegate.notificationHandler)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationHandler = NotificationHandler()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set up notification service
        UNUserNotificationCenter.current().delegate = NotificationService.shared

        return true
    }
}

// MARK: - Notification Handler

class NotificationHandler: ObservableObject {
    @Published var selectedCompartmentId: UUID?
    @Published var shouldNavigateToCompartment: Bool = false

    init() {
        // Listen for notification taps
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMedicationReminder(_:)),
            name: .didReceiveMedicationReminder,
            object: nil
        )
    }

    @objc private func handleMedicationReminder(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let compartmentIdString = userInfo["compartmentId"] as? String,
              let compartmentId = UUID(uuidString: compartmentIdString) else {
            return
        }

        // Update published properties to trigger navigation
        DispatchQueue.main.async {
            self.selectedCompartmentId = compartmentId
            self.shouldNavigateToCompartment = true
        }
    }

    func resetNavigation() {
        shouldNavigateToCompartment = false
    }
}
