# Local words and sentences storage plan

Status: schema and models implemented and verified on September 12, 2026
(GRDB 7.11.1, Xcode 26.6). Import, sync, and downloads are not implemented.
Code: `apps/ios/DreamApp/Database/AppDatabase.swift` (`v2_content` migration),
`apps/ios/DreamApp/Content/`.

Add local `words` and `sentences` tables with plain translation text and
embedded media metadata. Curated Supabase content keeps its own structure;
an import/sync adapter converts it into these local records.

Source project inspected:
`/Users/vlad/Documents/My/Projects/Sites/dreamproject`.
The recommendations are based on its schema and implementation, not an
inspection of a live database file.

## 1. Local table structure

Add a `v2_content` migration after the existing `v1_settings` migration.

- Preserve existing content fields, favorites, and creation/update/deletion
  timestamps.
- Store `translations` as non-null `TEXT`, represented by `String` in Swift.
  Each local row contains one selected translation, without language keys.
- Store `photo` and `audio` as non-null JSON text columns.
- Keep `tags`, word `sentence_ids`, and sentence `breakdown` as JSON text.
- Replace `photo_id`, `audio_id`, and `audio_translation_id` with the embedded
  media columns. Do not create separate local media tables.
- Keep the existing indexes on `(lang, created_at DESC)` for rows where
  `deleted_at IS NULL`.

Both tables retain `id`, `lang`, `title`, `writing_transliterated`,
`writing_phonetic`, `difficulty_level`, `translations`, `tags`,
`favorited_at`, `created_at`, `updated_at`, and `deleted_at`.

Words additionally retain `definition`, `base_form`, `part_of_speech`,
`frequency_rank`, and `sentence_ids`.

Sentences additionally retain `sentence_type`, `source`, and `breakdown`.

### Column types and nullability

Shared columns:

| SQL column | Swift type | SQL storage | Nullable |
| --- | --- | --- | --- |
| `id` | `UUID` | BLOB, primary key, non-null | No |
| `lang` | `String` | TEXT | No |
| `title` | `String` | TEXT | No |
| `writing_transliterated` | `String` | TEXT | No |
| `writing_phonetic` | `String?` | TEXT | Yes |
| `difficulty_level` | `Int?` | INTEGER | Yes |
| `translations` | `String` | TEXT, not JSON | No |
| `tags` | `[String]` | TEXT containing a JSON string array | No |
| `photo` | `ContentPhoto` | TEXT containing a JSON object | No |
| `audio` | `ContentAudio` | TEXT containing a JSON object | No |
| `favorited_at` | `Date?` | GRDB date text | Yes |
| `created_at` | `Date` | GRDB date text | No |
| `updated_at` | `Date` | GRDB date text | No |
| `deleted_at` | `Date?` | GRDB date text | Yes |

Word-only columns:

| SQL column | Swift type | SQL storage | Nullable |
| --- | --- | --- | --- |
| `definition` | `String` | TEXT | No |
| `base_form` | `String?` | TEXT | Yes |
| `part_of_speech` | `PartOfSpeech` | TEXT raw value | No |
| `frequency_rank` | `FrequencyRank?` | INTEGER raw value | Yes |
| `sentence_ids` | `[UUID]` | TEXT containing a JSON UUID-string array | No |

Sentence-only columns:

| SQL column | Swift type | SQL storage | Nullable |
| --- | --- | --- | --- |
| `sentence_type` | `SentenceType` | TEXT raw value | No |
| `source` | `String?` | TEXT | Yes |
| `breakdown` | `SentenceBreakdown` | TEXT containing a JSON object | No |

Initialize new records with `tags: []`, `sentence_ids: []` for words, absent
media as specified below, and nullable columns as `nil`. A new empty
breakdown is `{"schemaVersion":1,"items":[]}`. Supply IDs, required content,
and creation/update dates explicitly. Imports preserve supplied values.
SQL columns are non-null where marked; collection/media defaults may be
provided by record initializers rather than duplicated as SQL defaults.

`favorited_at` is the only favorite state: favoriting sets a timestamp,
unfavoriting clears it, and favoriting again records a new time.
`sentence_ids` preserves order; it is not a SQL foreign-key relationship.
Preserve the source schema's unrestricted nullable integer for
`difficulty_level`; do not invent difficulty ranges or an enum.

### Enum contracts

Port these exact values from the source project's
`shared/contracts/database.ts`. Use `String` raw values except for
`FrequencyRank`, which uses `Int` raw values.

| Swift contract | Exact stored values |
| --- | --- |
| `PartOfSpeech` | `ADJ`, `ADP`, `ADV`, `AUX`, `CCONJ`, `DET`, `INTJ`, `NOUN`, `NUM`, `PART`, `PRON`, `PROPN`, `PUNCT`, `SCONJ`, `SYM`, `VERB`, `X` |
| `SentenceType` | `phrase`, `sentence`, `question` |
| `MediaOrigin` | `ai`, `user`, `curated` |
| `AudioPace` | `slow`, `normal`, `fast` |
| `FrequencyRank` | `100`, `200`, `500`, `1000`, `2000`, `5000`, `10000`, `20000` |

`FrequencyRank` represents the existing rank buckets, not an arbitrary
positive rank. `null` means unknown. A word row may use any `PartOfSpeech`
value; the exclusion of `PUNCT` applies specifically to breakdown word items.

Use typed enum decoding and import validation for these values. Do not
silently turn unrecognized content enum values into `X` or another default.
No additional SQL CHECK constraints or indexes are required in this phase.
Keep content and audio language codes as strings, as in the current local
content schema, rather than introducing a new language enum.

Reuse the existing settings types without redefining them:

- `KnowledgeLevel`: `beginner`, `intermediate`, `advanced`.
- `WritingDisplayMode`: `standardOnly`, `standardAndPhonetic`,
  `standardAndTransliterated`, `standardAndPhoneticAndTransliterated`.

The old `MediaOwnerType` (`word`, `sentence`) and `MediaAudioType`
(`original`, `translation`) are not stored in the embedded media objects.
The containing table and the `title`/`translation` keys supply those roles.
The new local media contract replaces the old metadata envelopes; do not
port their `speakerGender` enum, video metadata, or media-level
`schemaVersion` fields into these objects.

## 2. Shared media structure

- `photo.main`: an image object or `null`.
- `audio.title`: an original pronunciation object or `null`.
- `audio.translation`: a single selected translation recording or `null`,
  without language-keyed nesting.
- `storagePath`: full `bucket/path/filename.ext`, also used as asset identity.
  No separate media ID is needed.
- Replacing or regenerating media creates a new storage path.
- `origin`: `"ai"`, `"user"`, or `"curated"`.
- `aiModel`: `"provider:model-id"`, or `null` when not applicable or unknown.
  Do not add separate provider or model-name fields.
- `width`, `height`, `durationMs`, and `voice` are nullable when unknown.
- `voice` is a stable voice identifier, rather than a display label.
- Audio `lang` identifies the spoken language independently of the voice.
- Audio `pace` preserves the existing `slow`, `normal`, and `fast` values.
- `subtitleTracks` is reserved directly on each audio asset, without
  language-keyed nesting or a `lang` field inside it. Examples show `null`;
  local encoding may omit it. Leave it out of the Swift model until the
  non-null track structure is defined, then add an optional typed property.

### Media field contracts

`ContentPhoto` contains the optional property `main: PhotoAsset?`.
`ContentAudio` contains the optional properties `title: AudioAsset?` and
`translation: AudioAsset?`. Neither container is a language dictionary.

The table below describes value constraints to validate at the import
boundary. Nullable values become optional Swift properties: local decoding
accepts either a missing key or `null`, and encoding may omit `nil` values.
Nonoptional properties remain required when decoding local records.

| Asset | JSON key | Value contract |
| --- | --- | --- |
| Both | `storagePath` | Nonempty string containing bucket and object path, with a file extension; not a URL or local filesystem path |
| Both | `origin` | `MediaOrigin` raw string |
| Both | `aiModel` | Nonempty `provider:model-id` string, or `null`; both components must be nonempty |
| Photo | `width` | Positive integer, or `null` |
| Photo | `height` | Positive integer, or `null` |
| Audio | `lang` | Nonempty spoken-language code string |
| Audio | `voice` | Nonempty stable voice identifier, or `null` |
| Audio | `pace` | `AudioPace` raw string; initialize new recordings to `normal` unless specified |
| Audio | `durationMs` | Nonnegative integer milliseconds, or `null` |
| Audio | `subtitleTracks` | Reserved; `null` in examples, omitted by the Swift model in this phase |

For `aiModel`, split on the first colon if parsing is needed; retain the rest
as the model identifier. It may be `null` even for AI-origin assets when the
original model is unknown. Do not derive or guess a model from the filename.

Keep `PhotoAsset` and `AudioAsset` as separate types. No `locale`, `status`,
owner fields, `isPrimary`, asset timestamps, tags, style, prompt, or general
metadata dictionary is included in the agreed local media shape. These
remain available in the old source or curated schema where applicable.

Logical defaults for absent media, shown with explicit nulls for clarity:

```json
{
  "photo": { "main": null },
  "audio": { "title": null, "translation": null }
}
```

Synthesized encoding may store `{}` for either empty media container. The
`photo` and `audio` SQL columns themselves remain non-null JSON objects.

## 3. Complete words row example

These examples represent database rows as JSON for readability. Nested
objects and arrays are decoded views of their respective SQLite JSON text
columns. UUIDs and dates are shown as readable strings; actual SQL encoding
follows the new project's UUID and date conventions. Paths, model names,
dimensions, and durations are illustrative. Explicit nulls in these examples
are explanatory, not a required byte-for-byte persistence format; optional
keys may be absent in stored JSON.

```json
{
  "id": "b7a76949-ecef-4256-b9be-496d06c01721",
  "lang": "ja",
  "title": "猫",
  "definition": "A small domesticated feline.",
  "base_form": "猫",
  "part_of_speech": "NOUN",
  "writing_transliterated": "neko",
  "writing_phonetic": "ねこ",
  "difficulty_level": null,
  "frequency_rank": null,
  "translations": "cat",
  "tags": ["animals"],
  "sentence_ids": [
    "3f478e44-5403-4d80-9102-5c89ddbc63aa"
  ],
  "photo": {
    "main": {
      "storagePath": "ugc-photos/user-id/cat-image.webp",
      "width": 1024,
      "height": 1024,
      "origin": "ai",
      "aiModel": "openai:model-name"
    }
  },
  "audio": {
    "title": {
      "storagePath": "ugc-audio/user-id/cat-ja.mp3",
      "lang": "ja",
      "voice": "japaneseFemaleMalo",
      "pace": "normal",
      "durationMs": 1250,
      "origin": "ai",
      "aiModel": "elevenlabs:model-name",
      "subtitleTracks": null
    },
    "translation": {
      "storagePath": "ugc-audio/user-id/cat-en.mp3",
      "lang": "en",
      "voice": "japaneseFemaleMalo",
      "pace": "normal",
      "durationMs": 980,
      "origin": "ai",
      "aiModel": "elevenlabs:model-name",
      "subtitleTracks": null
    }
  },
  "favorited_at": null,
  "created_at": "2026-09-12T10:00:00Z",
  "updated_at": "2026-09-12T10:00:00Z",
  "deleted_at": null
}
```

The translation recording can retain the existing learning-language voice
while speaking English; `voice` and `lang` describe different things.

## 4. Complete sentences row example

Sentences use the same media structure. This example includes original audio
with no image or translation recording yet.

```json
{
  "id": "3f478e44-5403-4d80-9102-5c89ddbc63aa",
  "lang": "ja",
  "title": "猫です。",
  "sentence_type": "sentence",
  "source": null,
  "writing_transliterated": "neko desu.",
  "writing_phonetic": "ねこです。",
  "difficulty_level": null,
  "translations": "It is a cat.",
  "breakdown": {
    "schemaVersion": 1,
    "items": [
      {
        "type": "word",
        "partOfSpeech": "NOUN",
        "originalChunk": "猫",
        "baseForm": "猫",
        "frequencyRank": null,
        "details": "The noun identifying the animal.",
        "translationInContext": "cat",
        "otherTranslations": [],
        "writingPhonetic": "ねこ",
        "writingTransliterated": "neko"
      },
      {
        "type": "word",
        "partOfSpeech": "AUX",
        "originalChunk": "です",
        "baseForm": "だ",
        "frequencyRank": null,
        "details": "The polite copula, expressing identification.",
        "translationInContext": "is",
        "otherTranslations": [],
        "writingPhonetic": null,
        "writingTransliterated": "desu"
      },
      {
        "type": "punctuation",
        "partOfSpeech": "PUNCT",
        "originalChunk": "。",
        "details": "A full stop marking the end of the sentence."
      }
    ]
  },
  "tags": ["animals"],
  "photo": {
    "main": null
  },
  "audio": {
    "title": {
      "storagePath": "ugc-audio/user-id/cat-sentence-ja.mp3",
      "lang": "ja",
      "voice": "japaneseFemaleMalo",
      "pace": "normal",
      "durationMs": 1800,
      "origin": "ai",
      "aiModel": "elevenlabs:model-name",
      "subtitleTracks": null
    },
    "translation": null
  },
  "favorited_at": null,
  "created_at": "2026-09-12T10:00:00Z",
  "updated_at": "2026-09-12T10:00:00Z",
  "deleted_at": null
}
```

Preserve the existing breakdown format and enum values. Explanatory text
within the local breakdown is not keyed by native language.

### Complete sentence breakdown contract

Apply the import-boundary validation rules from `sentenceBreakdownSchema`,
`sentenceBreakdownWordSchema`, and `sentenceBreakdownPunctuationSchema` in
the source contract. Keep JSON keys in camelCase exactly as shown. These
source-schema rules do not require strict object validation when reading
already-persisted local JSON.

The imported root object has exactly two required fields:

| Key | Value contract |
| --- | --- |
| `schemaVersion` | Integer literal `1` |
| `items` | Ordered array of word or punctuation items; an empty array is valid |

An imported word item has these required fields (nullable values become
optional properties in the local Swift model):

| Key | Value contract |
| --- | --- |
| `type` | String literal `word` |
| `partOfSpeech` | Any `PartOfSpeech` value except `PUNCT` |
| `originalChunk` | String with at least one character |
| `baseForm` | String with at least one character |
| `frequencyRank` | `FrequencyRank` integer raw value, or `null` |
| `details` | String with at least one character |
| `translationInContext` | String with at least one character |
| `otherTranslations` | Array of strings, each with at least one character; an empty array is valid |
| `writingPhonetic` | String with at least one character, or `null` |
| `writingTransliterated` | String with at least one character |

An imported punctuation item has exactly these required fields:

| Key | Value contract |
| --- | --- |
| `type` | String literal `punctuation` |
| `partOfSpeech` | String literal `PUNCT` |
| `originalChunk` | String with at least one character |
| `details` | String with at least one character |

Represent items with a Swift enum holding either a breakdown word or
punctuation struct, with custom coding that reads/writes the flat `type`
discriminator shown in the example. Do not use synthesized associated-value
enum JSON, which would introduce a different nesting structure.

At the import boundary, preserve the source's strict object contract:
unexpected keys, missing required keys, invalid discriminators, and invalid
values fail validation. Source nullable fields are required keys whose value
may be `null`.

For local persistence, ignore unknown keys and accept missing or `null`
optional fields such as `frequencyRank` and `writingPhonetic`. Keep the
custom `type` discriminator handling; unknown item types and missing
nonoptional fields still fail decoding. Validate string lengths and other
content constraints in the import adapter, not in persistence decoders.
Preserve item order and original chunk text. Do not add a native-language
dictionary to `details`, `translationInContext`, or `otherTranslations`.

## 5. Swift models and import

Create `Word` and `Sentence` GRDB records with shared typed `Codable` photo
and audio structures. Map Swift property names to snake_case SQL columns.

Use `Codable`, `Equatable`, and `Sendable` on the value types and
`FetchableRecord`/`PersistableRecord` on the row records, following the
existing settings implementation. Raw enums used directly as SQL values
also conform to `DatabaseValueConvertible`; add `CaseIterable` to the
finite raw enums. Keep shared content enums with the content models, and
keep the breakdown and media contracts with their respective model types.

### Import validation and local decoding

Validate incoming content against its source schema in the import adapter,
then map it into local models. This is where nonempty-string, numeric-range,
part-of-speech combination, and other content rules belong. Local and
curated Supabase schemas are deliberately different.

Use synthesized `Codable` for photo and audio structs and other ordinary
value structs. On local reads, ignore unknown keys and accept missing or
`null` optional properties through normal `decodeIfPresent` behavior. On
writes, allow synthesized encoding to omit `nil` properties. Do not add
custom coding just to enforce key presence, reject unknown keys, or emit
explicit nulls. Retain custom coding only where the format requires it,
such as the flat breakdown item discriminator.

Missing required properties, malformed property types, and unknown enum
values still fail decoding. Adding optional properties later does not
require rewriting existing JSON. Adding required properties needs a
deliberate decoding default or migration; changing a stored representation
may also need a migration. Ignored unknown keys are not retained if an older
model reads and re-encodes a row.

Leave `subtitleTracks` out of `AudioAsset` for now. Existing JSON containing
`"subtitleTracks": null` decodes because the key is ignored. When subtitles
are implemented, add an optional typed property so older rows with an
absent or null key keep decoding. Do not introduce a `JSONNull` type.

There is no byte-for-byte parity requirement between local JSON and server
payloads. If an external API later requires explicit nulls, handle that in
its export adapter, without changing local persistence encoding. Retain the
existing GRDB UUID and date strategies for row columns.

Follow the new project's UUID and date storage conventions: UUIDs in SQL
columns use 16-byte BLOBs and dates use GRDB's default UTC text encoding.
IDs inside JSON, such as `sentence_ids`, remain UUID strings. Preserve
identity and timestamp values when converting old records.

Keep schema creation separate from importing existing content. Convert
existing records using this mapping:

| Existing data | Local destination |
| --- | --- |
| Selected native-language translation | `translations` string |
| Attached photo via `photo_id` | `photo.main` |
| Attached original audio via `audio_id` | `audio.title` |
| Attached audio matching the selected translation language via `audio_translation_id` | `audio.translation` |
| `object_path` | `storagePath` |
| Photo metadata dimensions | `width`, `height` |
| Known generation provider and model | `aiModel` |
| Audio subtitle tracks | Not imported in this phase; reserved key omitted by local encoding |

Follow each content row's explicit attachment IDs, not `is_primary`; the
existing generation code attaches media with `isPrimary: false`.

Preserve content IDs, sentence links, favorites, and timestamps. Import
attached, nondeleted media, with missing or deleted attachments represented
as `null`. This imports current attachments, not historical replaced media.
Review populated legacy metadata before intentionally omitting fields not
included here, such as prompts or styles.

Select translation text for the user's native language at the import/sync
boundary. If using the old English fallback, select audio for the actual
fallback language; clear translation audio if no matching recording exists.
The local `translations` column remains a string in either case.

## 6. Native-language changes, settings, and downloads

Local translated content represents the selected native language. Changing
it requires refreshing translation text, translation audio, and any localized
definitions or breakdown explanations. Replace a row's translation text and
matching audio together; clear translation audio when there is no matching
recording.

Keep the settings arrangement already implemented:

- Account and learning-language settings remain in SQLite.
- `autoplayPronunciation`, `offlineAudio`, and `offlinePhotos` remain in
  `UserDefaults` through `DeviceSettings`.

Media files stay on disk or in object storage. SQLite holds references and
metadata. Derive local cache filenames from a stable hash of the full
`storagePath`, preserving the file extension. Do not store absolute local
paths or download status inside these media objects.

## 7. Verification

- Build the app after implementation.
- Inspect representative imported rows, including absent media and flat
  translations.
- Verify content IDs, sentence links, favorites, and timestamps survive
  conversion.
- Verify that translation recordings match the selected translation text's
  language and that replacement media resolves through its new storage path.
- Inspect local decoding with absent optional keys and extra unknown keys;
  confirm missing required fields still fail. Validate source content at the
  import boundary rather than adding strict local JSON decoders.
- Do not add tests without the user's approval. Do not commit or push without
  approval.

Writing this plan does not implement schema migrations, imports, downloads,
or synchronization.
