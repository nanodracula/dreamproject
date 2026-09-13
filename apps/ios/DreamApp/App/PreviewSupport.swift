#if DEBUG
import SwiftUI

extension View {
    /// Supplies in-memory dependencies and starts settings observation, as
    /// the app root does.
    func previewDependencies() -> some View {
        let dependencies = AppDependencies(database: try! AppDatabase.openInMemory())
        return environment(dependencies)
            .environment(dependencies.settings)
            .task { await dependencies.settings.observe() }
    }
}
#endif
