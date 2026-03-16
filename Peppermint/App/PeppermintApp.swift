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

    // T083: App launch performance tracking
    private var launchStartTime: CFAbsoluteTime = 0

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // T083: Record launch start time
        launchStartTime = CFAbsoluteTimeGetCurrent()

        // Set up notification service
        UNUserNotificationCenter.current().delegate = NotificationService.shared

        // T083: Schedule first frame tracking
        DispatchQueue.main.async { [weak self] in
            self?.trackFirstFrame()
        }

        return true
    }

    // T083: Track time from launch to first frame render
    private func trackFirstFrame() {
        let launchDuration = CFAbsoluteTimeGetCurrent() - launchStartTime

        #if DEBUG
        print("⏱️ App launch performance: \(String(format: "%.3f", launchDuration))s")

        if launchDuration > 2.0 {
            print("⚠️ WARNING: App launch took longer than 2 seconds (target)")
        } else {
            print("✅ App launch performance is within target (<2s)")
        }
        #endif

        // In production, this could be sent to analytics
        // Analytics.track("app_launch_duration", duration: launchDuration)
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
