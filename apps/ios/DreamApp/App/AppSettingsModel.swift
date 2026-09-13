import Foundation
import Observation

/// The current user's account settings, kept current by database
/// observation. Views read saved values here and edit through its methods;
/// the database stays the only writable state, so a save shows up only once
/// it is committed.
///
/// The user scope is fixed per instance. Account switching replaces the
/// model and its repository and restarts observation.
@MainActor @Observable
final class AppSettingsModel {
    /// The last committed snapshot; `nil` until the first load.
    private(set) var snapshot: SettingsSnapshot?
    private(set) var isSaving = false
    /// True after the current observation has delivered a snapshot.
    private(set) var isObservationReady = false
    /// Why observation stopped; `nil` while it is healthy.
    private(set) var loadError: (any Error)?
    /// Changes on retry. Key the `.task` that runs `observe()` on it.
    private(set) var observationRun = 0
    /// The last failed save. Cleared when its alert is dismissed.
    var saveError: String?

    private let repository: SettingsRepository

    init(repository: SettingsRepository) {
        self.repository = repository
    }

    // MARK: - Saved values

    var isLoaded: Bool { snapshot != nil }

    /// Editing waits for the first load and pauses during a save or a broken
    /// observation, which would hide the committed result.
    var canEdit: Bool { isObservationReady && loadError == nil && !isSaving }

    var nativeLanguageCode: String? { snapshot?.account.nativeLanguage }

    /// `nil` when the saved code is not a supported native language.
    var nativeLanguage: NativeLanguage? {
        nativeLanguageCode.flatMap { code in NativeLanguage.all.first { $0.code == code } }
    }

    var activeLanguageCode: String? { snapshot?.account.activeLearningLanguage }

    /// `nil` when the saved code is not a supported learning language.
    var activeLanguage: LearningLanguage? {
        activeLanguageCode.flatMap(LearningLanguage.with(code:))
    }

    /// Enrolled languages in enrollment order. Unsupported codes are skipped.
    var enrolledLanguages: [LearningLanguage] {
        snapshot?.enrollments.compactMap { LearningLanguage.with(code: $0.languageCode) } ?? []
    }

    func enrollment(for code: String) -> UserLearningLanguageSettings? {
        snapshot?.enrollments.first { $0.languageCode == code }
    }

    func isEnrolled(_ code: String) -> Bool {
        enrollment(for: code) != nil
    }

    // MARK: - Observation

    /// Loads the saved values and keeps them current until cancelled.
    func observe() async {
        isObservationReady = false
        defer { isObservationReady = false }
        loadError = nil
        do {
            for try await snapshot in repository.observeSnapshot() {
                self.snapshot = snapshot
                isObservationReady = true
            }
        } catch {
            guard !Task.isCancelled else { return }
            loadError = error
        }
    }

    func retryObservation() {
        observationRun += 1
    }

    // MARK: - Editing

    func setNativeLanguage(_ code: String) async {
        await save { try await repository.setNativeLanguage(code) }
    }

    func setActiveLanguage(_ code: String) async {
        await save { try await repository.setActiveLanguage(code) }
    }

    func setKnowledgeLevel(_ level: KnowledgeLevel, for code: String) async {
        await save { try await repository.setKnowledgeLevel(level, for: code) }
    }

    func setWritingDisplayMode(_ mode: WritingDisplayMode, for code: String) async {
        await save { try await repository.setWritingDisplayMode(mode, for: code) }
    }

    func enroll(_ code: String) async {
        await save { try await repository.enroll(code) }
    }

    func remove(_ code: String) async {
        await save { try await repository.remove(code) }
    }

    /// Runs one write at a time; a request during a save is dropped, since
    /// the controls are disabled and the committed value will show anyway.
    private func save(_ operation: () async throws -> Void) async {
        guard canEdit else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await operation()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
