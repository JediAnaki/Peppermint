import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            OrganizerLibraryView()
                .tabItem {
                    Label("Library", systemImage: "square.grid.2x2.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, DataPersistenceService.shared.viewContext)
}
