import Foundation
import Observation
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

private enum AppPhase {
    case loading
    case ready(AppDependencies)
    case failed(any Error)
}

/// Owns local startup and the lifetime of the current user's dependencies.
/// Readiness is derived from the first saved settings snapshot, so there is
/// no separate copy of settings or independent ready flag to keep in sync.
@MainActor @Observable
private final class AppModel {
    private var dependencies: AppDependencies?
    private var startupError: (any Error)?
    private var startupAttempt = 0

    var phase: AppPhase {
        if let dependencies {
            // Once ready, retain the tabs even if observation later fails.
            // AppSettingsModel reports that failure and supports retry in place.
            if dependencies.settings.isLoaded {
                return .ready(dependencies)
            }
            if let error = dependencies.settings.loadError {
                return .failed(error)
            }
        }
        if let startupError {
            return .failed(startupError)
        }
        return .loading
    }

    /// Either startup Retry or settings observation Retry restarts the root
    /// task. Constructing dependencies does not change this identity.
    struct RunID: Equatable {
        let startupAttempt: Int
        let observationAttempt: Int
    }

    var runID: RunID {
        RunID(
            startupAttempt: startupAttempt,
            observationAttempt: dependencies?.settings.observationRun ?? 0
        )
    }

    /// Opens local storage, then observes settings until the root task ends.
    /// No network request or upload session is required for readiness.
    func run() async {
        do {
            if dependencies == nil {
                dependencies = try await AppDependencies.live()
            }
            try Task.checkCancellation()
            await dependencies?.settings.observe()
        } catch {
            guard !Task.isCancelled else { return }
            startupError = error
        }
    }

    func retry() {
        if let dependencies {
            dependencies.settings.retryObservation()
        } else {
            startupError = nil
            startupAttempt += 1
        }
    }
}
