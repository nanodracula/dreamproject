import SwiftUI

@main
struct DreamApp: App {
    /// The persistent app database, opened and migrated at startup.
    let database: AppDatabase

    init() {
        do {
            database = try AppDatabase.openPersistent()
        } catch {
            fatalError("Could not open the app database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
