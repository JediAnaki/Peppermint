import SwiftUI

@main
struct PeppermintApp: App {
    let persistenceService = DataPersistenceService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceService.viewContext)
        }
    }
}
