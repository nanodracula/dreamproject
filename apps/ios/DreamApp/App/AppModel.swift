import Foundation
import Observation

enum AppPhase {
    case loading
    case ready(AppDependencies)
    case failed(any Error)
}

/// Owns local startup and the lifetime of the current user's dependencies.
/// Readiness is derived from the first saved settings snapshot, so there is
/// no separate copy of settings or independent ready flag to keep in sync.
@MainActor @Observable
final class AppModel {
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
