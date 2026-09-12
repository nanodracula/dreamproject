# iOS app architecture

Rules for `apps/ios/DreamApp/`. Folders exist only when they have content.

## Layers

- `App/`: entry point, `AppDependencies` (composition root), `RootView`, navigation. Only place that wires features together.
- `Features/<Name>/`: `UI/` always; `Logic/` and `Data/` only when needed (see below).
- `Core/`: shared models and contracts. Plain Swift, imports Foundation only. No GRDB, SwiftUI, or feature code.
- `Core/Contracts/` holds only shared protocols for process or hardware boundaries. Repositories over SQLite have no protocol.
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

- Column names are defined once, in `Columns` inside the record extension. Repositories and feature queries use `Model.Columns.x`; never `Column("x")` string literals. Migrations and raw SQL use schema names directly.
- Frequently reused predicates (active rows, favorites) are request builders on the record extension. One-off filters and sorts are composed inline.
- Shared repositories (used by 2+ features) are concrete structs in `Infrastructure/Repositories/`, hold `AppDatabase`, and expose one-shot fetches, `ValueObservation` streams, and writes.
- Feature-only queries live in `Features/<Name>/Data/` (for example `FeedQueries`). Move to Infrastructure when a second feature needs them.
- `Data/` also holds request/response payloads and mappers for endpoints only that feature calls. `Data/` may import GRDB and networking; `UI/` and `Logic/` may not.

## Protocols

- Introduce a protocol when a consumer needs a controllable substitute in tests or previews. Typical cases: Supabase/HTTP, audio, speech, keychain, notifications, clock. Decide up front for hardware and network; retrofitting is cheap but tedious.
- SQLite repositories stay concrete, injected with `AppDatabase`; the in-memory database is their substitute.
- Feature-specific contracts live with the feature. `Core/Contracts/` holds only shared ones.

## Live UI data

- Production opens a `DatabasePool`; tests use an in-memory `DatabaseQueue`.
- Screens observe via repository `ValueObservation` streams consumed in `.task` / `.task(id:)`. Writes go through the repository; no manual reloads.
- No in-memory stores mirroring the database, no event buses, no hand-rolled change listeners. Observation and `Task` cancellation cover these.
- Do not use the GRDBQuery package. `@Query` puts database access in views.

## Dependencies

- `AppDependencies` owns the database, shared repositories, and platform services. Features assemble their own view models and queries from those. `App/` owns navigation between features.
- No module-level singletons.
- Start with folders. Extract `Core`, `Infrastructure`, and `DesignSystem` into local packages only when compiler-enforced boundaries solve an actual problem. It is a separate refactor: public access control, explicit public initializers, `@retroactive` GRDB conformances, test target split. The cost grows with code size, so decide early if you want it at all.

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
