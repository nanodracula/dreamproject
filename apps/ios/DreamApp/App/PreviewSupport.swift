#if DEBUG
import SwiftUI

extension View {
    /// Supplies in-memory dependencies and starts settings observation, as
    /// the app root does.
    func previewDependencies() -> some View {
        modifier(PreviewDependencies())
    }
}

/// Owns the dependencies so re-evaluation keeps the same database and the
/// observation task restarts on retry.
private struct PreviewDependencies: ViewModifier {
    @State private var dependencies = AppDependencies(database: try! AppDatabase.openInMemory())

    func body(content: Content) -> some View {
        content
            .environment(dependencies)
            .environment(dependencies.settings)
            .task(id: dependencies.settings.observationRun) {
                await dependencies.settings.observe()
            }
    }
}
#endif
