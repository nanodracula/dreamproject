import SwiftUI

@main
struct DreamApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}

/// Displays startup until essential local state is available. The task is
/// attached outside the phase switch so it survives creating the tabs.
private struct AppRootView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.launchBackground.ignoresSafeArea())

            case .ready(let dependencies):
                RootView()
                    .environment(dependencies)
                    .environment(dependencies.settings)

            case .failed(let error):
                ContentUnavailableView {
                    Label {
                        Text("startupErrorTitle", tableName: "App")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } description: {
                    Text(error.localizedDescription)
                } actions: {
                    Button {
                        model.retry()
                    } label: {
                        Text("startupRetry", tableName: "App")
                    }
                }
                .background(AppColors.background.ignoresSafeArea())
            }
        }
        .preferredColorScheme(.dark)
        .task(id: model.runID) { await model.run() }
    }
}
