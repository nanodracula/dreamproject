import Foundation
import GRDB
import Testing
@testable import DreamApp

struct AppDatabaseTests {
    private let guestID = AppDatabase.guestUserID
    // Whole seconds: GRDB's default Date encoding keeps millisecond precision.
    private let fixedDate = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func migrationsRunRepeatedlyOnTheSameConnection() throws {
        let queue = try DatabaseQueue()
        _ = try AppDatabase(queue)
        _ = try AppDatabase(queue)

        try queue.read { db in
            let hasSettings = try db.tableExists(UserSettings.databaseTableName)
            let hasEnrollments = try db.tableExists(UserLearningLanguageSettings.databaseTableName)
            let applied = try AppDatabase.migrator.appliedMigrations(db)
            let superseded = try AppDatabase.migrator.hasBeenSuperseded(db)
            #expect(hasSettings)
            #expect(hasEnrollments)
            #expect(applied == ["v1_settings"])
            #expect(!superseded)
        }
    }

    @Test func initialRecordsAreCreatedOnce() throws {
        let database = try AppDatabase.openInMemory()

        let (settings, enrollments) = try database.writer.read { db in
            (try UserSettings.fetchAll(db), try UserLearningLanguageSettings.fetchAll(db))
        }
        #expect(settings.count == 1)
        #expect(enrollments.count == 1)

        let guest = try #require(settings.first)
        #expect(guest.userId == guestID)
        #expect(guest.nativeLanguage == "en")
        #expect(guest.activeLearningLanguage == "ja")
        #expect(guest.deletedAt == nil)

        let japanese = try #require(enrollments.first)
        #expect(japanese.userId == guestID)
        #expect(japanese.languageCode == "ja")
        #expect(japanese.knowledgeLevel == .beginner)
        #expect(japanese.writingDisplayMode == .standardOnly)
        #expect(japanese.deletedAt == nil)

        // Re-running startup initialization on the same database adds nothing.
        _ = try AppDatabase(database.writer)
        let counts = try database.writer.read { db in
            (try UserSettings.fetchCount(db), try UserLearningLanguageSettings.fetchCount(db))
        }
        #expect(counts == (1, 1))
    }

    @Test func savedValuesSurviveReinitialization() throws {
        let queue = try DatabaseQueue()
        let database = try AppDatabase(queue)

        try database.writer.write { db in
            var guest = try #require(try UserSettings.fetchOne(db, key: guestID))
            guest.nativeLanguage = "de"
            guest.activeLearningLanguage = "fr"
            guest.updatedAt = fixedDate
            try guest.update(db)

            var japanese = try #require(try UserLearningLanguageSettings.fetchOne(db))
            japanese.knowledgeLevel = .advanced
            japanese.writingDisplayMode = .standardAndPhoneticAndTransliterated
            japanese.deletedAt = fixedDate
            try japanese.update(db)
        }

        _ = try AppDatabase(queue)

        try queue.read { db in
            let guest = try #require(try UserSettings.fetchOne(db, key: guestID))
            #expect(guest.nativeLanguage == "de")
            #expect(guest.activeLearningLanguage == "fr")
            #expect(guest.updatedAt == fixedDate)

            let japanese = try #require(try UserLearningLanguageSettings.fetchOne(db))
            #expect(japanese.knowledgeLevel == .advanced)
            #expect(japanese.writingDisplayMode == .standardAndPhoneticAndTransliterated)
            #expect(japanese.deletedAt == fixedDate)
            let enrollmentCount = try UserLearningLanguageSettings.fetchCount(db)
            #expect(enrollmentCount == 1)
        }
    }

    @Test func enrollmentRequiresExistingUser() throws {
        let database = try AppDatabase.openInMemory()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try makeEnrollment(userId: UUID(), languageCode: "ko").insert(db)
            }
        }
    }

    @Test func enrollmentIsUniquePerUserAndLanguage() throws {
        let database = try AppDatabase.openInMemory()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try makeEnrollment(userId: guestID, languageCode: "ja").insert(db)
            }
        }
        // A different language for the same user is fine.
        try database.writer.write { db in
            try makeEnrollment(userId: guestID, languageCode: "ko").insert(db)
        }
        let enrollmentCount = try database.writer.read { db in
            try UserLearningLanguageSettings.fetchCount(db)
        }
        #expect(enrollmentCount == 2)
    }

    @Test func updatingUserIDCascadesToEnrollments() throws {
        let database = try AppDatabase.openInMemory()
        let newID = UUID()

        try database.writer.write { db in
            try makeEnrollment(userId: guestID, languageCode: "ko").insert(db)
            try db.execute(
                sql: "UPDATE user_settings SET user_id = ? WHERE user_id = ?",
                arguments: [newID, guestID]
            )
        }

        try database.writer.read { db in
            let newExists = try UserSettings.exists(db, key: newID)
            let guestExists = try UserSettings.exists(db, key: guestID)
            #expect(newExists)
            #expect(!guestExists)
            let enrollments = try UserLearningLanguageSettings.fetchAll(db)
            #expect(enrollments.count == 2)
            #expect(enrollments.allSatisfy { $0.userId == newID })
        }
    }

    @Test func deletingUserCascadesToEnrollments() throws {
        let database = try AppDatabase.openInMemory()
        try database.writer.write { db in
            _ = try UserSettings.deleteOne(db, key: guestID)
        }
        let enrollmentCount = try database.writer.read { db in
            try UserLearningLanguageSettings.fetchCount(db)
        }
        #expect(enrollmentCount == 0)
    }

    @Test func deletionTimestampsRoundTrip() throws {
        let database = try AppDatabase.openInMemory()

        try database.writer.write { db in
            var guest = try #require(try UserSettings.fetchOne(db, key: guestID))
            guest.deletedAt = fixedDate
            try guest.update(db)
        }
        try database.writer.read { db in
            let guest = try #require(try UserSettings.fetchOne(db, key: guestID))
            #expect(guest.deletedAt == fixedDate)
        }

        try database.writer.write { db in
            var guest = try #require(try UserSettings.fetchOne(db, key: guestID))
            guest.deletedAt = nil
            try guest.update(db)
        }
        try database.writer.read { db in
            let guest = try #require(try UserSettings.fetchOne(db, key: guestID))
            #expect(guest.deletedAt == nil)
            let raw = try DatabaseValue.fetchOne(
                db, sql: "SELECT deleted_at FROM user_settings WHERE user_id = ?", arguments: [guestID])
            #expect(raw == .null)
        }
    }

    @Test func settingsSurviveClosingAndReopeningTheFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DreamAppTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appending(path: "test.sqlite")

        do {
            let database = try AppDatabase.openPersistent(at: fileURL)
            try database.writer.write { db in
                var guest = try #require(try UserSettings.fetchOne(db, key: guestID))
                guest.nativeLanguage = "uk"
                guest.deletedAt = fixedDate
                try guest.update(db)

                var japanese = try #require(try UserLearningLanguageSettings.fetchOne(db))
                japanese.knowledgeLevel = .intermediate
                try japanese.update(db)
            }
            try database.writer.close()
        }

        do {
            // Reopening reruns migrations and initialization without overwriting.
            let database = try AppDatabase.openPersistent(at: fileURL)
            try database.writer.read { db in
                let settingsCount = try UserSettings.fetchCount(db)
                #expect(settingsCount == 1)
                let guest = try #require(try UserSettings.fetchOne(db, key: guestID))
                #expect(guest.nativeLanguage == "uk")
                #expect(guest.deletedAt == fixedDate)

                let enrollmentCount = try UserLearningLanguageSettings.fetchCount(db)
                #expect(enrollmentCount == 1)
                let japanese = try #require(try UserLearningLanguageSettings.fetchOne(db))
                #expect(japanese.knowledgeLevel == .intermediate)
            }
            try database.writer.close()
        }
    }

    // MARK: - Helpers

    private func makeEnrollment(userId: UUID, languageCode: String) -> UserLearningLanguageSettings {
        UserLearningLanguageSettings(
            id: UUID(),
            userId: userId,
            languageCode: languageCode,
            knowledgeLevel: .beginner,
            writingDisplayMode: .standardOnly,
            createdAt: fixedDate,
            updatedAt: fixedDate,
            deletedAt: nil
        )
    }
}
