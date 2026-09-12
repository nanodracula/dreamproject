# Settings storage plan

Status: implemented and verified on September 12, 2026 (GRDB 7.11.1, Xcode 26.6).
Code: `apps/ios/DreamApp/Infrastructure/Persistence/`,
`apps/ios/DreamApp/Core/Models/`, `apps/ios/DreamApp/Infrastructure/Preferences/`, tests in `apps/ios/DreamAppTests/Infrastructure/`.

Use GRDB for account and learning settings, and `UserDefaults` for device
preferences. This phase implements settings persistence only.

## 1. Database setup

- Add the [GRDB](https://github.com/groue/GRDB.swift) Swift package to the iOS target.
- Store one persistent, file-backed app database in Application Support and
  reopen the same file across app launches.
- Open the database with `DatabaseQueue` and use `DatabaseMigrator` for migrations.
- Expose the open database to the rest of the app as `any DatabaseWriter`, not
  as `DatabaseQueue`. Switching to `DatabasePool` when words, sentences, and
  background sync arrive then becomes a one-line change, and tests can inject
  an isolated in-memory `DatabaseQueue`.
- Open the database and run migrations at app startup.
- Create the two settings tables below in the initial migration.

## 2. Tables and Swift models

### `user_settings`

One row per user.

| Column | Logical type / constraint | Initial value |
| --- | --- | --- |
| `user_id` | UUID, primary key | Local guest ID |
| `native_language` | String | `"en"` |
| `active_learning_language` | String | `"ja"` |
| `created_at` | Date | Creation time |
| `updated_at` | Date | Creation time |
| `deleted_at` | Optional Date | `nil` |

### `user_learning_languages_settings`

Each row represents an enrolled language and its settings. The table name
matches the existing Expo app and is the name to use for the future Supabase
table as well.

| Column | Logical type / constraint | Initial value |
| --- | --- | --- |
| `id` | UUID, primary key | Generated UUID |
| `user_id` | UUID, foreign key to `user_settings.user_id`, `ON DELETE CASCADE`, `ON UPDATE CASCADE` | Owner |
| `language_code` | String | Enrolled language |
| `knowledge_level` | String-backed enum | `"beginner"` |
| `writing_display_mode` | String-backed enum | `"standardOnly"` |
| `created_at` | Date | Creation time |
| `updated_at` | Date | Creation time |
| `deleted_at` | Optional Date | `nil` |

Add a unique constraint on `(user_id, language_code)`. Retain nullable
`deleted_at` in both tables, defaulting to SQL `NULL`. For language enrollment,
this allows future deactivation to preserve preferences for reactivation.

The cascading foreign key means that re-keying the guest row to an
authenticated user ID later updates all enrollments with a single update of
the parent row.

Use GRDB's default encodings for the column types above: `UUID` stored as a
16-byte BLOB, `Date` stored in GRDB's default UTC text format, and enums stored
by their raw `String` value. Do not add custom coding strategies.

Represent rows with plain Swift structs conforming to `Codable`,
`FetchableRecord`, and `PersistableRecord`. Explicitly map Swift property names
to the SQL column names. Keep enum definitions with the relevant model.

Preserve the existing enum values:

- Knowledge level: `beginner`, `intermediate`, `advanced`.
- Writing display mode: `standardOnly`, `standardAndPhonetic`,
  `standardAndTransliterated`, `standardAndPhoneticAndTransliterated`.

## 3. Initial records

- Use the existing local guest ID, `00000000-0000-0000-0000-000000000000`, until
  authentication is implemented.
- When the guest settings row is absent, create it and the Japanese enrollment
  together in one transaction.
- Subsequent launches preserve existing values and deletion timestamps.
- Treat creation defaults as initialization values, not values to rewrite at
  every launch.

## 4. Device preferences

Add a small `DeviceSettings` wrapper backed by `UserDefaults`, exposing three
typed Boolean properties:

| Property | Default |
| --- | --- |
| `autoplayPronunciation` | `false` |
| `offlineAudio` | `false` |
| `offlinePhotos` | `false` |

Accept a `UserDefaults` instance in the initializer so verification can use an
isolated store. Register defaults without overwriting saved choices. The
wrapper does not depend on SwiftUI.

These preferences belong to the device and are not stored in either SQLite
table or included in future account synchronization. Downloaded audio and
images themselves belong on disk; downloading is outside this phase.

## 5. Verification

This phase adds the previously deferred `DreamAppTests` target, as described in
`docs/plans/01-init.md` step 4: a separate synchronized folder at
`apps/ios/DreamAppTests/`, included in the shared scheme's test action. The
settings code is pure records against a database, so the checks below are
unit tests running against an isolated in-memory `DatabaseQueue` and an
isolated `UserDefaults` suite. Only the close/reopen persistence test uses a
database file in its own temporary directory, cleaned up after closing the
database. The app itself always uses its persistent file in Application Support.

- Build the iOS app.
- Verify database initialization and migrations can run repeatedly.
- Verify foreign-key and uniqueness constraints, including that updating
  `user_settings.user_id` cascades to the enrollment rows.
- Verify initial records are created once and saved values are preserved.
- Verify database settings survive closing the database connection and opening
  a new connection to the same file, including rerunning startup migrations
  and initialization without overwriting saved values.
- Verify device preferences survive recreating the `DeviceSettings` wrapper
  with the same `UserDefaults` suite.
- Verify nullable deletion timestamps round-trip correctly.
- Run the tests through `mise run ios:test` and update the README note that
  describes the test task as deferred.

## Scope

Included: GRDB dependency, database setup, models, enums, initial schema
migration, initial records, the `UserDefaults` wrapper, and the
`DreamAppTests` target with tests for the above.

Deferred: UI, observable stores, settings operations such as language switching
and deactivation, downloads, authentication, Supabase tables and synchronization,
and migration of data from the existing Expo app.

The source app's existing settings were inspected at
`/Users/vlad/Documents/My/Projects/Sites/dreamproject`. Its two-table learning
structure informs this plan; device preferences are separated as agreed.
