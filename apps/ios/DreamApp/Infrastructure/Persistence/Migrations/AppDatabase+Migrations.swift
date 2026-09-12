import GRDB

nonisolated extension AppDatabase {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_settings") { db in
            try db.create(table: UserSettings.databaseTableName) { t in
                t.primaryKey("user_id", .blob)
                t.column("native_language", .text).notNull()
                t.column("active_learning_language", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            try db.create(table: UserLearningLanguageSettings.databaseTableName) { t in
                t.primaryKey("id", .blob)
                t.column("user_id", .blob).notNull()
                    .references(UserSettings.databaseTableName, onDelete: .cascade, onUpdate: .cascade)
                t.column("language_code", .text).notNull()
                t.column("knowledge_level", .text).notNull()
                t.column("writing_display_mode", .text).notNull()
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
                t.uniqueKey(["user_id", "language_code"])
            }
        }

        migrator.registerMigration("v2_content") { db in
            try db.create(table: Word.databaseTableName) { t in
                t.primaryKey("id", .blob)
                t.column("lang", .text).notNull()
                t.column("title", .text).notNull()
                t.column("definition", .text).notNull()
                t.column("base_form", .text)
                t.column("part_of_speech", .text).notNull()
                t.column("writing_transliterated", .text).notNull()
                t.column("writing_phonetic", .text)
                t.column("difficulty_level", .integer)
                t.column("frequency_rank", .integer)
                t.column("translations", .text).notNull()
                t.column("tags", .text).notNull()
                t.column("sentence_ids", .text).notNull()
                t.column("photo", .text).notNull()
                t.column("audio", .text).notNull()
                t.column("favorited_at", .datetime)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            try db.create(table: Sentence.databaseTableName) { t in
                t.primaryKey("id", .blob)
                t.column("lang", .text).notNull()
                t.column("title", .text).notNull()
                t.column("sentence_type", .text).notNull()
                t.column("source", .text)
                t.column("writing_transliterated", .text).notNull()
                t.column("writing_phonetic", .text)
                t.column("difficulty_level", .integer)
                t.column("translations", .text).notNull()
                t.column("breakdown", .text).notNull()
                t.column("tags", .text).notNull()
                t.column("photo", .text).notNull()
                t.column("audio", .text).notNull()
                t.column("favorited_at", .datetime)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
                t.column("deleted_at", .datetime)
            }

            // GRDB's index builder cannot express a DESC column, so use SQL.
            for table in [Word.databaseTableName, Sentence.databaseTableName] {
                try db.execute(sql: """
                    CREATE INDEX "index_\(table)_on_lang_created_at"
                    ON "\(table)"("lang", "created_at" DESC)
                    WHERE "deleted_at" IS NULL
                    """)
            }
        }

        return migrator
    }
}
