# Content seed plan

Status: planned, not implemented, September 13, 2026.
Source data: `dreamproject-old` `src/lib/database/seed.ts` at `917575a`.
Target now: `apps/ios/DreamApp/Resources/Seed/`.
Future target, with the Settings button:
`apps/ios/DreamApp/Infrastructure/Persistence/ContentSeed.swift`.

Ship the existing starter words and sentences with the app as four JSON files,
split by content type and language. Import them only when the user taps a
future Settings button. First launch leaves the content tables empty; the
existing settings initialization stays as it is. This plan covers the file
layout, the JSON shape, and the one-off conversion from the old TypeScript
seed, and records the future manual import behavior. Implement the loader
when the Settings button has a caller. It adds no migration: `v2_content`
already defines both tables.

## 1. What the seed contains

| File | Rows |
| --- | --- |
| `sentences.ja.json` | 82 |
| `sentences.ko.json` | 14 |
| `words.ja.json` | 42 |
| `words.ko.json` | 2 |

96 sentences and 44 words. The source stores them in two forms: 50 sentences
built through the `makeSeedSentence` and `breakdownWord` helpers, and the rest
written out as plain object literals. Both forms produce the same row shape.

Every row carries `photoId`, `audioId`, and `audioTranslationId` as `null`.
The only media in the source is a separate `seedSentenceAudioPaths` map of 35
sentence recordings (§4).

Every enum value in the source already sits inside the contracts fixed by
`03-content-storage.md`: `sentenceType` is `phrase`, `sentence`, or `question`;
breakdown parts of speech stay inside the universal tag set; and each
`frequencyRank` is one of `100`, `500`, `1000`, `2000`, `5000`. Nothing needs
remapping, and no unrecognized value may be coerced to a default during
conversion.

## 2. Where the files live

```text
apps/ios/DreamApp/Resources/Seed/
├── sentences.ja.json
├── sentences.ko.json
├── words.ja.json
└── words.ko.json
```

- The only consumer is the Swift app, through the future Settings import
  action. Anything outside the app target is unreadable at runtime without a
  build phase that copies it in.
- `DreamApp/` is a synchronized folder group, so a new `Resources/Seed/` folder
  needs no `project.pbxproj` edit; the files join Copy Bundle Resources
  automatically. They are flattened into the bundle root, so their names must
  be unique bundle-wide. `<type>.<lang>.json` guarantees that and reads
  directly as `Bundle.main.url(forResource:withExtension:)`.
- Type before language means adding a language is adding two files and one
  entry in the loader's language list.
- A few hundred kilobytes in total. Small enough that bundling beats any
  download path.

Not `server/supabase/seed.sql`: that is the repeatable seed for the remote
development database, in SQL, for a different consumer. If the same rows are
wanted upstream later, generate the SQL from these files with a script in
`tools/db/`, keeping the JSON as the single source.

Not a repository-root `data/` folder: it would need a copy phase into the
bundle for no present benefit.

One file per type per language is the whole split. Do not shard further by
deck, feature, or size.

## 3. JSON shape

Each file is a JSON array of rows matching the Core models exactly, so the
loader decodes straight into `[Word]` and `[Sentence]` with no payload type
and no mapper. Keys are camelCase, as the models declare them.

```json
[
  {
    "id": "b7441927-8153-52a5-9ed8-3e9d1e3ca95d",
    "lang": "ja",
    "title": "明日来る?",
    "sentenceType": "question",
    "source": null,
    "writingTransliterated": "Ashita kuru?",
    "writingPhonetic": "あした くる?",
    "difficultyLevel": null,
    "translations": "Will you come tomorrow?",
    "breakdown": {
      "schemaVersion": 1,
      "items": [
        {
          "type": "word",
          "partOfSpeech": "NOUN",
          "originalChunk": "明日",
          "baseForm": "明日",
          "frequencyRank": 1000,
          "details": "A noun used to indicate the next day after today.",
          "translationInContext": "tomorrow",
          "otherTranslations": ["the near future"],
          "writingPhonetic": "あした",
          "writingTransliterated": "ashita"
        }
      ]
    },
    "tags": [],
    "photo": {},
    "audio": {},
    "createdAt": "2026-02-17T00:23:46Z",
    "updatedAt": "2026-05-29T15:12:07Z"
  }
]
```

Rules the conversion must hold to:

- **Emit every non-optional key.** Swift's synthesized `Decodable` ignores a
  property's default value: a missing key for a non-optional property throws
  `keyNotFound`, whatever the declaration says. So `tags`, `photo`, `audio`,
  `breakdown`, `schemaVersion`, and a breakdown word's `otherTranslations` are
  always written, even when empty. Only genuinely optional properties
  (`writingPhonetic`, `source`, `difficultyLevel`, `frequencyRank`,
  `baseForm` on words, `favoritedAt`, `deletedAt`) may be `null` or absent.
- **Empty media is `{}`.** `ContentPhoto.main`, `ContentAudio.title`, and
  `ContentAudio.translation` are optional, so an empty object decodes cleanly.
  Writing `{"main": null}` is equivalent; pick one and keep it uniform.
- **Timestamps are whole seconds with a `Z` suffix.** The source mixes
  `2026-02-17T00:23:46.000Z` with `2026-05-29T13:10:09.300Z`, and
  `JSONDecoder`'s `.iso8601` strategy rejects fractional seconds. Truncate
  during conversion rather than teaching the loader a custom strategy;
  millisecond precision means nothing for fixed seed rows.
- **UUIDs stay lowercase**, as in the source. `UUID` decodes either case.
- **Stable formatting**: two-space indent, LF, trailing newline, keys in the
  model's property order, rows sorted by `createdAt` then `id`. The files are
  read in diffs, so churn between regenerations is a real cost.

## 4. Sentence audio

The source's `seedSentenceAudioPaths` maps 35 sentence IDs to
`seed/sentences/<id>/audio_sentence_<suffix>.mp3`. The map is dead code in the
old app: it is exported and never imported, so those paths have never been
resolved by a client.

`AudioAsset.storagePath` is a full `bucket/path/filename.ext`. The self-hosted
project has curated `photos`, `audio`, and `videos` buckets alongside the
`ugc-*` ones, and seed recordings belong in `audio`, giving
`audio/seed/sentences/<id>/audio_sentence_<suffix>.mp3`.

Confirm the 35 objects actually exist at those paths before emitting any of
them, by listing the `audio` bucket in Studio or over the tunnel from
`04-supabase-migration.md`.

- If they exist, attach to each of those sentences:

  ```json
  "audio": {
    "title": {
      "storagePath": "audio/seed/sentences/3d886cdb-2352-5337-af70-24fe9de42a42/audio_sentence_x7p3ixkt7q.mp3",
      "lang": "ja",
      "pace": "normal",
      "origin": "curated"
    }
  }
  ```

  `voice`, `durationMs`, and `aiModel` stay absent; the source records none.
  Use `"origin": "ai"` with the generating `provider:model-id` only if that is
  actually known. Do not guess a model from the filename.

- If they do not exist, emit `"audio": {}` everywhere and treat seed audio as a
  later download task. The seed is useful without it.

The other 61 sentences and all 44 words have no audio either way, and no seed
row has a photo.

## 5. Conversion

A one-off, run from the old checkout. The JSON becomes the source of truth
afterwards and the TypeScript seed dies with that repository, so the converter
is not committed to the new repository: there would be nothing left to re-run
it against.

1. In `dreamproject-old` at `917575a`, write a throwaway script that imports
   `sentences`, `words`, and `seedSentenceAudioPaths` from
   `src/lib/database/seed.ts`.
2. Map each row per the table below.
3. Group by `lang` and write the four files.
4. Copy them into `apps/ios/DreamApp/Resources/Seed/` and commit the JSON only.

| Old field | New field | Rule |
| --- | --- | --- |
| `translations: { en: "…" }` | `translations: "…"` | Take `en`. Fail loudly if absent; never substitute an empty string. |
| `photoId` | `photo` | Always `{}`. |
| `audioId`, `audioTranslationId` | `audio` | `{}`, or `{"title": …}` for the 35 sentences in §4. |
| `createdAt`, `updatedAt` | same | Truncate to whole seconds. |
| — | `favoritedAt`, `deletedAt` | Omit. |
| `sentenceIds` (words) | same | Preserve order. |
| `breakdown` | same | Already `{"schemaVersion": 1, "items": [...]}`. |
| `source`, `difficultyLevel`, `writingPhonetic`, `frequencyRank` | same | Keep nulls. |

The 50 helper-built sentences must be materialized through `makeSeedSentence`
and `breakdownWord` first, so their defaults land in the output as literal
values: `lang: "ja"` where the call omits it, the empty `otherTranslations`,
and the punctuation `details` lookup. Nothing in the JSON may depend on a
helper existing.

After the split, verify that every `sentenceIds` entry on a word resolves to a
sentence in that same language's file. A dangling reference is a conversion
bug to fix at the source, not something the loader is expected to tolerate.

## 6. Future loader (deferred)

When the Settings action is implemented, add
`Infrastructure/Persistence/ContentSeed.swift`, one file holding the decoder,
the seed language list, and the import. Not in `Core/` (Foundation-only
models, no `Bundle`, no GRDB), and not a new folder, since a single file does
not need one. Do not add this file before it has a caller.

The intended import shape is:

```swift
import Foundation
import GRDB

/// Bundled starter content, imported explicitly from Settings.
///
/// The JSON files in `Resources/Seed/` are the source of truth for this
/// content and decode directly into `Word` and `Sentence`.
nonisolated enum ContentSeed {
    /// Only languages with bundled seed files, not every supported language.
    static let seededLanguageCodes = ["ja", "ko"]

    /// Adds missing seed IDs while preserving every existing row.
    static func importContent(into database: AppDatabase, from bundle: Bundle = .main) throws {
        try database.writer.write { db in
            for lang in seededLanguageCodes {
                for sentence in try decode([Sentence].self, "sentences.\(lang)", from: bundle) {
                    if try !Sentence.exists(db, key: sentence.id) {
                        try sentence.insert(db)
                    }
                }
                for word in try decode([Word].self, "words.\(lang)", from: bundle) {
                    if try !Word.exists(db, key: word.id) {
                        try word.insert(db)
                    }
                }
            }
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ name: String, from bundle: Bundle) throws -> T {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw SeedError.missingFile(name)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: try Data(contentsOf: url))
    }

    enum SeedError: Error {
        case missingFile(String)
    }
}
```

- Call it only from the future Settings action. Do not wire it into
  `AppDependencies.live()`, `AppDatabase.init`, or any launch path.
- Import into empty or populated content tables in one transaction. Stable
  IDs make repeated imports safe: skip IDs already present, preserving user
  edits, favorites, and soft-deleted rows. Do not delete, replace, or upsert
  existing rows. A physically removed seed row can be added again by another
  explicit import; launching the app never restores it.
- Keep the seed language subset explicit. Plan 06 supports languages that
  have no bundled seed files.
- A missing or malformed seed file is a build mistake. Let the loader throw
  and roll back the entire import; the Settings action reports the failure.
  Seed decoding is not part of app startup.

## 7. Settings button (deferred)

Later, add an "Import starter content" button in Settings that calls the
loader in §6. It imports the bundled Japanese and Korean content into the
existing library and leaves the active learning language unchanged. Show
completion or failure and prevent overlapping imports while it runs.

This is an additive import action. The old app's destructive
`resetDatabaseFromSeed()` is not carried over. Implement the button and its
loader together when the Settings screen arrives.

## 8. Verification

For the bundled files now:

- Build and confirm all four JSON files are included in the app bundle.
- Verify the files contain 96 sentences and 44 words with the per-language
  counts in §1, and that word-to-sentence references resolve.
- Spot-check one helper-built Korean sentence and one object-form Japanese
  sentence: breakdown items, punctuation details, transliteration, phonetic
  writing, and the flat translation all survive conversion.
- Verify timestamps follow §3 and `favoritedAt` and `deletedAt` are absent
  or null in every seed row.
- If §4 audio is included, confirm one storage path resolves in the `audio`
  bucket.
- On a clean installation, launch and relaunch: both content tables stay
  empty, with Japanese active through the existing settings initialization.

When the Settings button and loader are implemented:

- Import into an empty library: it contains 96 sentences and 44 words.
  Confirm timestamps and all four files decode with the current models.
- Import again and relaunch: counts stay unchanged, with no duplicate rows.
- Import into a populated library: user-created rows, edits, favorites, and
  soft-deleted seed rows remain unchanged; only missing seed IDs are added.
- Confirm importing leaves the active learning language unchanged.
- Confirm an import failure rolls back all inserts and is reported in
  Settings.

Do not add tests without approval. Ask before opening the iPhone simulator.
Do not commit or push without approval.

## 9. Out of scope

The Settings screen, its import button, and the loader implementation are
deferred as described above. Automatic seeding, destructive reset, curated
content sync from Supabase, updates to already imported rows, media downloads,
additional languages, and per-deck seeds are out of scope.
