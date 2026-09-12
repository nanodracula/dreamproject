# iOS app architecture

Rules for `apps/ios/DreamApp/`. Folders exist only when they have content.

## Layers

- `App/`: entry point, `AppDependencies` (composition root), `RootView`, navigation. Only place that wires features together.
- `Features/<Name>/`: `UI/` always; `Logic/` and `Data/` only when needed (see below).
- `Core/`: shared models and contracts. Plain Swift, imports Foundation only. No GRDB, SwiftUI, or feature code.
- `Core/Contracts/` holds only protocols for process or hardware boundaries. Repositories over SQLite have no protocol.
- `Infrastructure/`: GRDB record extensions, migrations, shared repositories, Supabase, sync, media cache, SDK wrappers (audio, speech, keychain, notifications).
- `SharedUI/`: reusable domain views. Depend on Core, receive services by injection.
- `DesignSystem/`: generic components and visual tokens. Per-feature theme files do not exist.
- Tests live in `apps/ios/DreamAppTests/`, mirroring `Features/`, `Core/`, `Infrastructure/`.

Dependency direction: `App` → `Features` → `Infrastructure` / `SharedUI` → `Core`.
Shared layers never depend on features. Features never depend on each other.

## UI

- Views render and forward actions. Views never touch a database, HTTP client, or SDK.
- View models are `@MainActor @Observable`, own presentation state, and call repositories directly.
- A `Logic/` service exists only when there are real business rules (review scheduling, feed composition). No pass-through services. Name it after the rule it owns (`FeedComposition`), not `XService`.
- Keep blocking I/O and heavy processing off the main actor. `async` alone does not move work off it.

## Models and GRDB (decision: option B)

- Core models are plain `Codable` structs: no `import GRDB`, no `CodingKeys` for column names, no `Columns`.
- GRDB conformance lives in `Infrastructure/Persistence/Records/<Model>+Record.swift`: `FetchableRecord`, `PersistableRecord`, `databaseTableName`, snake_case column strategies, `Columns`, and reusable request builders.
- No separate record types or mappers.
- Language codes are strings in the database. `LearningLanguage` in Core is a config value listing supported languages, never a column type.

```swift
extension Sentence: FetchableRecord, PersistableRecord {
    static let databaseTableName = "sentences"
    static let databaseColumnDecodingStrategy = DatabaseColumnDecodingStrategy.convertFromSnakeCase
    static let databaseColumnEncodingStrategy = DatabaseColumnEncodingStrategy.convertToSnakeCase
    enum Columns { static let lang = Column("lang") }
    static func active(lang: String) -> QueryInterfaceRequest<Sentence> { filter(Columns.lang == lang) }
}
```

## Queries and repositories

- Column names appear only in record extensions (request builders). Repositories and feature queries compose requests and never spell out a column.
- Shared repositories (used by 2+ features) are concrete structs in `Infrastructure/Repositories/`, hold `AppDatabase`, and expose one-shot fetches, `ValueObservation` streams, and writes.
- Feature-only queries live in `Features/<Name>/Data/` (for example `FeedQueries`). Move to Infrastructure when a second feature needs them.
- `Data/` also holds request/response payloads and mappers for endpoints only that feature calls. `Data/` may import GRDB and networking; `UI/` and `Logic/` may not.

## Protocols

Rule: a protocol exists only where a test or preview cannot run the real thing.

- Concrete, injected with `AppDatabase`: everything backed by SQLite. Tests use the in-memory database.
- Protocol, in `Core/Contracts/`: anything crossing a process or hardware boundary. Supabase/HTTP, audio playback, speech, TTS, keychain, notifications, clock.

## Live UI data

- Production opens a `DatabasePool`; tests use an in-memory `DatabaseQueue`.
- Screens observe via repository `ValueObservation` streams consumed in `.task` / `.task(id:)`. Writes go through the repository; no manual reloads.
- No in-memory stores mirroring the database, no event buses, no hand-rolled change listeners. Observation and `Task` cancellation cover these.
- Do not use the GRDBQuery package. `@Query` puts database access in views.

## Dependencies

- All dependencies are constructed in `AppDependencies` and injected into view models from `App/`. No module-level singletons.
- Start with folders, not Swift packages. Boundaries are conventions until they leak.
- If leaks appear or a second developer joins, promote `Core`, `Infrastructure`, and `DesignSystem` to local Swift packages so the compiler enforces the dependency direction. Budget one afternoon. When `Core` becomes a package, record extensions in Infrastructure need `@retroactive` on the GRDB conformances.

## Project root

```text
DreamProject/
├── apps/
│   └── ios/
├── server/
│   └── supabase/
├── docs/
├── tools/
└── README.md
```

## iOS app

Folders marked `(planned)` do not exist yet.

```text
apps/ios/DreamApp/
├── App/
│   ├── DreamApp.swift
│   ├── AppDependencies.swift
│   ├── RootView.swift
│   └── Navigation/
│       ├── AppRoute.swift
│       └── AppRouter.swift
│
├── Features/
│   ├── Feed/
│   │   ├── UI/
│   │   │   ├── FeedScreen.swift
│   │   │   ├── FeedViewModel.swift
│   │   │   └── Components/
│   │   ├── Logic/
│   │   │   └── FeedComposition.swift
│   │   └── Data/
│   │       └── FeedQueries.swift
│   ├── Dictionary/
│   ├── AddCard/
│   │   ├── UI/
│   │   └── Data/
│   │       └── CardTitleGeneration.swift   // edge-function payloads + mapper
│   ├── Settings/
│   │   └── UI/
│   └── Auth/                                (planned)
│
├── Core/
│   ├── Models/
│   │   ├── Word.swift
│   │   ├── Sentence.swift
│   │   ├── Deck.swift
│   │   ├── ReviewProgress.swift
│   │   ├── UserSettings.swift
│   │   └── LearningLanguage.swift          // supported languages config, not a column type
│   ├── Contracts/
│   │   ├── AudioPlaying.swift
│   │   ├── SpeechSynthesizing.swift
│   │   ├── SyncClient.swift
│   │   └── Clock.swift
│   └── Learning/
│       └── ReviewScheduler.swift           // shared pure rules only
│
├── SharedUI/
│   ├── SentencePreview.swift
│   ├── SentencePlayer.swift
│   └── WordPronunciation.swift
│
├── DesignSystem/
│   ├── Components/
│   └── Theme/
│       ├── Colors.swift
│       ├── Typography.swift
│       ├── Spacing.swift
│       └── Motion.swift
│
├── Infrastructure/
│   ├── Persistence/
│   │   ├── AppDatabase.swift
│   │   ├── Migrations/
│   │   └── Records/
│   │       ├── Word+Record.swift
│   │       └── Sentence+Record.swift
│   ├── Repositories/
│   │   ├── WordRepository.swift
│   │   ├── SentenceRepository.swift
│   │   └── SettingsRepository.swift
│   ├── Supabase/
│   ├── Sync/
│   ├── Media/
│   ├── Audio/
│   ├── Speech/
│   ├── Keychain/                            (planned)
│   └── Notifications/                       (planned)
│
├── Config/
│   └── AppConfiguration.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings

apps/ios/DreamAppTests/
├── Features/
├── Core/
└── Infrastructure/
```

## Feature folder

```text
Feed/
├── UI/
│   ├── FeedScreen.swift
│   ├── FeedViewModel.swift
│   └── Components/
│       ├── FeedCard.swift
│       ├── GrammarSection.swift
│       └── TranslationSection.swift
├── Logic/
│   └── FeedComposition.swift
└── Data/
    └── FeedQueries.swift
```
