import SwiftUI

/// Main Settings View
///
/// Provides access to app configuration and cloud backup settings (T068)
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                // Cloud Backup Section
                Section {
                    NavigationLink(destination: CloudBackupSettingsView()) {
                        Label("Cloud Backup", systemImage: "icloud")
                    }
                } header: {
                    Text("Data")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("002")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview {
    SettingsView()
}
