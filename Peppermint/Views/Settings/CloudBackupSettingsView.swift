import SwiftUI
import CloudKit

/// Cloud Backup Settings View - T059-T067
///
/// Allows users to enable/disable iCloud backup for organizer designs.
/// Implements optional cloud sync (User Story 2 - P2).
struct CloudBackupSettingsView: View {
    // T060: AppStorage for cloud sync toggle
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false

    // UI state
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var iCloudStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingStatus = false

    var body: some View {
        Form {
            // T060-T065: Cloud sync toggle section
            Section {
                Toggle("iCloud Backup", isOn: $cloudSyncEnabled)
                    .onChange(of: cloudSyncEnabled) { newValue in
                        if newValue {
                            // T061: Check iCloud availability before enabling
                            checkiCloudAvailability()
                        } else {
                            // T064: Disable cloud sync without deleting cloud data
                            disableCloudSync()
                        }
                    }

                // T065: Sync status display
                if cloudSyncEnabled {
                    HStack {
                        Text("Status")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Enabled")
                            .foregroundColor(.green)
                    }
                }

                if isCheckingStatus {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("Checking iCloud status...")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Cloud Storage")
            } footer: {
                Text("Automatically backs up your organizer designs to iCloud. You can access them from any device signed in with your Apple ID.")
            }

            // T066-T067: Sync controls section
            if cloudSyncEnabled {
                Section {
                    // T066: Manual sync trigger
                    Button("Sync Now") {
                        forceSyncAll()
                    }
                } footer: {
                    // T067: Last sync date display
                    Text("Last synced: \(lastSyncDate)")
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Cloud Backup")
        .navigationBarTitleDisplayMode(.inline)
        // T062: Handle iCloud status error cases
        .alert("iCloud Unavailable", isPresented: $showingError) {
            Button("OK") {
                cloudSyncEnabled = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Check initial iCloud status
            if cloudSyncEnabled {
                checkiCloudAvailability()
            }
        }
    }

    // MARK: - iCloud Availability Check (T061)

    /// T061: Check if iCloud is available and handle error cases
    private func checkiCloudAvailability() {
        isCheckingStatus = true

        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                self.iCloudStatus = status
                self.isCheckingStatus = false

                // T062: Handle different iCloud status cases
                switch status {
                case .available:
                    // iCloud available - enable sync
                    enableCloudSync()

                case .noAccount:
                    // User not signed in to iCloud
                    errorMessage = "Please sign in to iCloud in Settings to enable cloud backup."
                    showingError = true
                    cloudSyncEnabled = false

                case .restricted:
                    // iCloud restricted (parental controls, etc.)
                    errorMessage = "iCloud is restricted on this device. Check Settings → Screen Time."
                    showingError = true
                    cloudSyncEnabled = false

                case .couldNotDetermine:
                    // Unable to determine iCloud status
                    errorMessage = "Could not determine iCloud status. Please try again."
                    showingError = true
                    cloudSyncEnabled = false

                case .temporarilyUnavailable:
                    // iCloud temporarily unavailable
                    errorMessage = "iCloud is temporarily unavailable. Please try again later."
                    showingError = true
                    cloudSyncEnabled = false

                @unknown default:
                    errorMessage = "Unknown iCloud status."
                    showingError = true
                    cloudSyncEnabled = false
                }
            }
        }
    }

    // MARK: - Cloud Sync Control (T063-T064)

    /// T063: Enable cloud sync for all existing organizers
    private func enableCloudSync() {
        // Call DataPersistenceService to enable CloudKit
        DataPersistenceService.shared.enableCloudKit()

        print("✅ Cloud backup enabled")
    }

    /// T064: Disable cloud sync without deleting cloud data
    private func disableCloudSync() {
        // Call DataPersistenceService to disable CloudKit
        DataPersistenceService.shared.disableCloudKit()

        print("📍 Cloud backup disabled (data remains local)")
    }

    // MARK: - Manual Sync (T066)

    /// T066: Force manual sync by posting notification
    private func forceSyncAll() {
        NotificationCenter.default.post(name: .forceCloudSync, object: nil)
        print("🔄 Manual sync triggered")
    }

    // MARK: - Last Sync Date (T067)

    /// T067: Compute last sync date from most recent organizer
    private var lastSyncDate: String {
        let context = DataPersistenceService.shared.viewContext
        let request = OrganizerDesign.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lastSyncedAt", ascending: false)]
        request.fetchLimit = 1

        guard let mostRecent = try? context.fetch(request).first,
              let lastSynced = mostRecent.lastSyncedAt else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: lastSynced, relativeTo: Date())
    }
}

// MARK: - Previews

#Preview {
    NavigationView {
        CloudBackupSettingsView()
    }
}
