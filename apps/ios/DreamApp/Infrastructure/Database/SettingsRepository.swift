import Foundation
import GRDB

/// One user's account settings and current enrollments, read in a single
/// transaction so the two never disagree.
nonisolated struct SettingsSnapshot: Equatable, Sendable {
    var account: UserSettings
    /// Non-removed enrollments in enrollment order.
    var enrollments: [UserLearningLanguageSettings]
}

nonisolated enum SettingsError: Error, Equatable {
    case accountMissing
    case notEnrolled(languageCode: String)
    case activeLanguageRemoval(languageCode: String)
}

nonisolated extension SettingsError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accountMissing:
            "The account settings are missing."
        case .notEnrolled(let code):
            "\(code) is not an enrolled language."
        case .activeLanguageRemoval(let code):
            "\(code) is the active language and cannot be removed."
        }
    }
}

/// Reads and writes one user's account settings and language enrollments.
///
/// Every write runs in its own transaction: it fetches the current row,
/// validates the change, and updates only the columns that differ, stamping
/// `updatedAt` only when something changed.
nonisolated struct SettingsRepository: Sendable {
    let writer: any DatabaseWriter
    let userID: UUID

    // MARK: - Reading

    /// Emits the current snapshot, then a fresh one after every change to
    /// either settings table. Consecutive equal snapshots are dropped.
    func observeSnapshot() -> AsyncValueObservation<SettingsSnapshot> {
        ValueObservation
            .tracking { db in try fetchSnapshot(db) }
            .removeDuplicates()
            .values(in: writer)
    }

    // MARK: - Account settings

    func setNativeLanguage(_ code: String) async throws {
        try await writer.write { db in
            try updateAccount(db) { $0.nativeLanguage = code }
        }
    }

    /// The language must be enrolled.
    func setActiveLanguage(_ code: String) async throws {
        try await writer.write { db in
            _ = try requireEnrollment(db, code: code)
            try updateAccount(db) { $0.activeLearningLanguage = code }
        }
    }

    // MARK: - Enrollment settings

    func setKnowledgeLevel(_ level: KnowledgeLevel, for code: String) async throws {
        try await writer.write { db in
            try updateEnrollment(db, code: code) { $0.knowledgeLevel = level }
        }
    }

    func setWritingDisplayMode(_ mode: WritingDisplayMode, for code: String) async throws {
        try await writer.write { db in
            try updateEnrollment(db, code: code) { $0.writingDisplayMode = mode }
        }
    }

    /// Enrolls the language and makes it active in one transaction. A removed
    /// enrollment is restored with the preferences it had.
    func enroll(_ code: String) async throws {
        try await writer.write { db in
            if let enrollment = try fetchEnrollment(db, code: code, includingRemoved: true) {
                try update(db, enrollment) { $0.deletedAt = nil }
            } else {
                let now = Date()
                try UserLearningLanguageSettings(
                    id: UUID(),
                    userId: userID,
                    languageCode: code,
                    knowledgeLevel: .beginner,
                    writingDisplayMode: .standardOnly,
                    createdAt: now,
                    updatedAt: now,
                    deletedAt: nil
                ).insert(db)
            }
            try updateAccount(db) { $0.activeLearningLanguage = code }
        }
    }

    /// Soft-deletes the enrollment. The active language cannot be removed.
    func remove(_ code: String) async throws {
        try await writer.write { db in
            let account = try requireAccount(db)
            guard account.activeLearningLanguage != code else {
                throw SettingsError.activeLanguageRemoval(languageCode: code)
            }
            try updateEnrollment(db, code: code) { $0.deletedAt = Date() }
        }
    }

    // MARK: - Fetching

    private typealias EnrollmentColumns = UserLearningLanguageSettings.Columns

    private func fetchSnapshot(_ db: Database) throws -> SettingsSnapshot {
        let enrollments = try UserLearningLanguageSettings
            .filter(EnrollmentColumns.userId == userID && EnrollmentColumns.deletedAt == nil)
            .order(EnrollmentColumns.createdAt)
            .fetchAll(db)
        return SettingsSnapshot(account: try requireAccount(db), enrollments: enrollments)
    }

    private func requireAccount(_ db: Database) throws -> UserSettings {
        guard let account = try UserSettings.fetchOne(db, key: userID) else {
            throw SettingsError.accountMissing
        }
        return account
    }

    private func fetchEnrollment(
        _ db: Database, code: String, includingRemoved: Bool = false
    ) throws -> UserLearningLanguageSettings? {
        var request = UserLearningLanguageSettings
            .filter(EnrollmentColumns.userId == userID && EnrollmentColumns.languageCode == code)
        if !includingRemoved {
            request = request.filter(EnrollmentColumns.deletedAt == nil)
        }
        return try request.fetchOne(db)
    }

    private func requireEnrollment(_ db: Database, code: String) throws -> UserLearningLanguageSettings {
        guard let enrollment = try fetchEnrollment(db, code: code) else {
            throw SettingsError.notEnrolled(languageCode: code)
        }
        return enrollment
    }

    // MARK: - Updating

    private func updateAccount(_ db: Database, _ mutate: (inout UserSettings) -> Void) throws {
        try update(db, try requireAccount(db), mutate)
    }

    private func updateEnrollment(
        _ db: Database, code: String, _ mutate: (inout UserLearningLanguageSettings) -> Void
    ) throws {
        try update(db, try requireEnrollment(db, code: code), mutate)
    }

    /// Writes the columns `mutate` changed, stamping `updatedAt`. A mutation
    /// that changes nothing writes nothing.
    private func update<Record: TimestampedRecord>(
        _ db: Database, _ record: Record, _ mutate: (inout Record) -> Void
    ) throws {
        var changed = record
        mutate(&changed)
        guard changed != record else { return }
        changed.updatedAt = Date()
        try changed.updateChanges(db, from: record)
    }
}

nonisolated private protocol TimestampedRecord: PersistableRecord, Equatable {
    var updatedAt: Date { get set }
}

nonisolated extension UserSettings: TimestampedRecord {}
nonisolated extension UserLearningLanguageSettings: TimestampedRecord {}
