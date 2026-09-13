import SwiftUI

@main
struct DreamApp: App {
    let dependencies: AppDependencies

    init() {
        do {
            dependencies = try AppDependencies.live()
        } catch {
            fatalError("Could not open the app database: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(dependencies)
                .environment(dependencies.settings)
        }
    }
}
