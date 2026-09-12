# Supabase migration plan

Status: planned on September 12, 2026. Nothing implemented.
Source project inspected: `nanodracula/dreamproject-old` at commit `effe870`
(`server/supabase/`, `scripts/supabase-*.sh`, `shared/`, `src/lib/supabase/`).

Move the Supabase project files and their deployment tooling from the old Expo
repository into this repository, adapted to a monorepo that has no Node and no
TypeScript application. The self-hosted instance itself is not migrated.

## 0. What is and is not being migrated

The Supabase instance is self-hosted on a Hostinger VPS under Dokploy. Nothing
in it is coupled to the Expo app: the database keeps its data, its
`supabase_migrations.schema_migrations` history, its storage buckets, and its
auth users regardless of which repository the SQL files live in.

This is a repository migration, not a project migration. No downtime, no data
movement, no re-push of existing migrations.

What moves:

| Source path | Destination | Change |
| --- | --- | --- |
| `server/supabase/config.toml` | same | none |
| `server/supabase/schemas/*.sql` | same | none |
| `server/supabase/migrations/*.sql` | same | **filenames unchanged** |
| `server/supabase/seed.sql` | same | none |
| `server/supabase/functions/` | same | import paths only (§2) |
| `server/supabase/.gitignore` | same | none |
| `shared/contracts/`, `shared/config/` | `server/supabase/functions/_shared/` | folded in (§2) |
| `scripts/supabase-tunnel.sh` | `tools/supabase/tunnel.sh` | env-driven identifiers (§3) |
| `scripts/supabase-db-deploy.sh` | `tools/supabase/db-deploy.sh` | type generation removed (§4) |
| `scripts/supabase-functions-deploy.sh` | `tools/supabase/functions-deploy.sh` | alias rewriting and gates removed (§2, §4) |
| `scripts/supabase-backup.sh` | `tools/supabase/backup.sh` | path fixes only |

What does not move:

- `src/lib/supabase/client.ts`, `session.ts`, `database.types.ts`. Replaced by
  `apps/ios/DreamApp/Infrastructure/Supabase/`.
- `drizzle.config.ts` and `src/lib/database/migrations/`. Replaced by the GRDB
  migrations already implemented (`v1_settings`, `v2_content`).
- The `supabase gen types typescript` step. No TypeScript consumer remains.
- The `npx tsc --noEmit` and `npm run lint` gates. No Node project remains.

History is not grafted. Copy the files and name the source commit in the commit
message. Every path changes, so `git subtree` or `git filter-repo` would buy
little beyond `git log --follow` and cost a tangled merge base.

## 1. Target layout

Credentials and environment files live under `server/`, next to the project
they configure. Repository helper scripts stay in `tools/`, per `01-init.md`.

```text
dreamproject/
├── server/
│   ├── README.md                  # deployment runbook
│   ├── .env.example               # committed; names only, no values
│   ├── .env.local                 # gitignored; operator secrets and infra identifiers
│   └── supabase/
│       ├── config.toml
│       ├── .gitignore
│       ├── seed.sql
│       ├── schemas/
│       ├── migrations/
│       └── functions/
│           ├── deno.json
│           ├── .env.example       # names of provider keys the edge runtime needs
│           ├── main/              # vendored router, optional (§4e)
│           ├── _shared/
│           │   ├── contracts/
│           │   ├── config/
│           │   ├── providers/
│           │   └── utils/
│           ├── generate-text/
│           ├── generate-image/
│           ├── generate-audio/
│           └── hello/
├── tools/
│   └── supabase/
│       ├── tunnel.sh
│       ├── db-deploy.sh
│       ├── functions-deploy.sh
│       └── backup.sh
└── mise.toml
```

`tools/db/` is an empty placeholder allocated by `01-init.md` for "database/CI
helpers". Replace it with `tools/supabase/`: one directory owning one service
beats splitting the database scripts from the functions-deploy script that
talks to the same host over the same SSH connection. Delete `tools/db/.gitkeep`
and amend `01-init.md` accordingly.

## 2. Fold `shared/` into the functions

In the old repository `shared/` was imported by both the Expo app and the Deno
functions, through the `@root/shared/` alias in `functions/deno.json`. The
deployed artifact has no import map, so `supabase-functions-deploy.sh` builds a
temporary artifact, copies `shared/` into `_shared/dreamproject/`, walks every
`.ts` file, computes relative `../` ascent, and rewrites `'@root/shared/` and
`from 'zod'` with `sed`, then verifies no alias import survived.

Swift cannot import TypeScript, so the functions are now the only consumer.
Moving the contracts to `server/supabase/functions/_shared/contracts/` and
`_shared/config/` makes the artifact a plain `rsync` of the directory and
deletes all of that machinery: the rewrite loop, the `rewritten_alias_imports`
counter, the unresolved-import guard, and the `zod_specifier` pin check against
`deno.json`.

Imports become relative, matching the existing `_shared/providers/*` imports:

```ts
import { partsOfSpeech } from '../_shared/contracts/database.ts'
```

`deno.json` keeps only the zod specifier:

```jsonc
{
	"imports": { "zod": "npm:zod@4.5.4" },
	"compilerOptions": { "strict": true },
	"fmt": { "lineWidth": 100, "useTabs": true, "singleQuote": true, "semiColons": false }
}
```

Swift mirrors the contract enums by hand. `03-content-storage.md` already
specifies them value for value (`PartOfSpeech`, `SentenceType`, `MediaOrigin`,
`AudioPace`, `FrequencyRank`). Do not build code generation for five enums.

## 3. Credentials and environment

Three tiers that never mix.

### Operator secrets: `server/.env.local`

Gitignored, never leaves the operator's machine. The root `.gitignore` already
covers it (`.env`, `.env.*`, with `!.env.example` exceptions), so
`server/.env.local` is ignored and `server/.env.example` is tracked with no
rule changes.

```sh
# server/.env.example

# --- Remote Postgres (through the SSH tunnel, or direct for backups) ---
POSTGRES_PASSWORD=
POSTGRES_EXTERNAL_HOST=
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_DB=postgres

# --- Supabase API (backups read Storage over HTTP) ---
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=

# --- Infrastructure identifiers ---
SUPABASE_SSH_HOST=
SUPABASE_REMOTE_CONTAINER=
SUPABASE_FUNCTIONS_CONTAINER=
SUPABASE_FUNCTIONS_DIR=
SUPABASE_TUNNEL_PORT=54330
```

The last block matters. Today the Dokploy stack name, both container names, and
the compose volume path are shell defaults inside the scripts, and therefore
committed to GitHub. Read them as required values (`${VAR:?}` rather than
`${VAR:-default}`) so the scripts fail loudly when unset. This takes the
infrastructure topology out of git and makes a staging stack a one-file change.

### Provider secrets: never in the repository

`OPENROUTER_API_KEY` and `ELEVENLABS_API_KEY` are read with `Deno.env.get()`
inside the functions container. Self-hosted Supabase has no
`supabase secrets set`; the values come from the Dokploy compose environment.
Commit `server/supabase/functions/.env.example` listing only the names, and
record in `server/README.md` that the values live in the Dokploy UI. That is
the one piece of deployment knowledge currently written down nowhere.

### Client configuration: the one thing outside `server/`

The iOS app needs `SUPABASE_URL` and the anon key. The anon key is public by
design — row-level security is what protects the data, and the existing
policies are correct: `select` on `status = 'published'` for `anon` and
`authenticated`, all writes to `service_role`, and storage insert/select/delete
gated on `(storage.foldername(name))[1] = auth.uid()`. It ships inside the IPA
regardless. The goal is to keep it out of scattered Swift source, not to hide it.

The Xcode equivalent of `EXPO_PUBLIC_*` is an xcconfig feeding Info.plist:

```sh
# apps/ios/Config/Supabase.xcconfig            (gitignored)
# apps/ios/Config/Supabase.example.xcconfig    (committed)
# xcconfig treats // as a comment, so break the scheme separator:
SUPABASE_URL = https:$()//supabase.example.com
SUPABASE_ANON_KEY = your-anon-key
```

```swift
// apps/ios/DreamApp/Config/AppConfiguration.swift
import Foundation

nonisolated enum AppConfiguration {
    static let supabaseURL = url(for: "SUPABASE_URL")
    static let supabaseAnonKey = string(for: "SUPABASE_ANON_KEY")

    private static func string(for key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else { fatalError("Missing \(key). Copy apps/ios/Config/Supabase.example.xcconfig to Supabase.xcconfig.") }
        return value
    }

    private static func url(for key: String) -> URL {
        guard let url = URL(string: string(for: key)) else { fatalError("\(key) is not a URL") }
        return url
    }
}
```

`Config/AppConfiguration.swift` is the slot already reserved in
`architecture.md`. The `service_role` key must never reach anything the app can
read; it belongs to `server/.env.local` and the Dokploy environment only.

## 4. Deployment

### What stays the same

SSH to the VPS, tunnel to the Supavisor container for the database, push
migrations with `supabase db push --db-url`, and deploy functions by rsyncing a
versioned release directory and swapping it atomically. The functions script
has a `flock` lock, a release marker, per-function `OPTIONS` health probes,
automatic restore of the previous release on failure, and release pruning. None
of it is repository-specific and none of it should be replaced.

The remote does not need preparation. The release id is
`<timestamp>-<git sha>`, so the first deploy from this repository simply writes
a new id beside the existing ones in the releases directory.

### a. Drop type generation from `db-deploy.sh`

Nothing consumes `database.types.ts`. The script becomes: start tunnel, then
`supabase db push --db-url`. When `apps/web/` arrives, reintroduce generation as
a separate `db:types` task writing into the web app, not as a side effect of
deploying.

### b. Replace the pre-deploy gates with Deno's own

`npx tsc --noEmit` and `expo lint` validated the application, not the artifact
being deployed. Use instead:

```sh
deno check server/supabase/functions/*/index.ts
deno lint server/supabase/functions
deno fmt --check server/supabase/functions
```

This typechecks the actual deployable and is the only gate that still has
meaning in a repository with no `package.json`.

### c. Pin the toolchain in `mise.toml`

The Supabase CLI and Deno are now real dependencies. `mise.toml` has no
`[tools]` yet, and `README.md` states "no mise-managed tools yet"; both change.

```toml
[tools]
deno = "2"
"aqua:supabase/cli" = "2.65.2"   # pin to the version in use

[tasks."db:tunnel"]
description = "Open the SSH tunnel to the remote Postgres"
run = "bash tools/supabase/tunnel.sh start"

[tasks."db:deploy"]
description = "Push pending migrations to the remote database"
run = "bash tools/supabase/db-deploy.sh"

[tasks."db:backup"]
description = "Back up the remote database and Storage to a local directory"
run = "bash tools/supabase/backup.sh"

[tasks."functions:check"]
description = "Typecheck, lint, and format-check the edge functions"
run = """
deno check server/supabase/functions/*/index.ts
deno lint server/supabase/functions
deno fmt --check server/supabase/functions
"""

[tasks."functions:deploy"]
description = "Deploy a versioned edge-functions release"
run = "bash tools/supabase/functions-deploy.sh"
```

### d. Do not touch the schema during the move

The local app flattens media into embedded `photo` and `audio` JSON while the
server keeps normalized `media_photos`, `media_audio`, and `media_videos`. That
divergence is deliberate per `03-content-storage.md`; the import/sync adapter is
where the two meet. Any server-side schema evolution is a separate phase with
its own `supabase db diff` migration. Mixing it into the repository move turns a
zero-risk file copy into a risky one.

### e. Optional: vendor the `main` router

`supabase-functions-deploy.sh` copies `main/` from the live server into each
release and then rewrites `importMapPath = '/home/deno/functions/deno.json'` to
`null`. The repository therefore does not contain the router, and the deployment
cannot be rebuilt from git if that volume is lost.

Committing `server/supabase/functions/main/index.ts` with `importMapPath = null`
already applied makes the repository self-sufficient and removes the remote
preparation block and its two validation greps. The router ships with the
edge-runtime image, so a vendored copy can drift; re-snapshot it when the image
is upgraded. Disaster recovery is worth that maintenance.

### f. CI: later

`tools/ci/Dockerfile` is an empty placeholder. A GitHub Actions job running
`deno check` and `supabase db lint` on pull requests is cheap and safe. Deploys
need an SSH key on the runner, so keep those manual until that is wanted.

## 5. Phases

### Phase 0 — safety net

1. From the old repository, run
   `bash scripts/supabase-backup.sh --output ~/backups/pre-migration`. Store it
   outside both repositories; it contains auth data and storage objects read
   with the service role.
2. Record the current state for later comparison:

   ```sh
   bash scripts/supabase-tunnel.sh start
   supabase migration list --db-url "postgresql://postgres:$POSTGRES_PASSWORD@127.0.0.1:54330/postgres"
   ssh "$SUPABASE_SSH_HOST" "cat $SUPABASE_FUNCTIONS_DIR/.dreamproject-release"
   ```

### Phase 1 — copy the project (one commit, no behaviour change)

3. Copy `server/supabase/` verbatim, replacing `server/supabase/.gitkeep`.
   Do not rename, renumber, or squash any migration file.
4. Move `shared/contracts/` and `shared/config/` into
   `server/supabase/functions/_shared/`, rewrite the `@root/shared/` imports to
   relative paths, and trim `deno.json` to the zod-only import map.
5. Copy the four scripts into `tools/supabase/`, fixing the `scripts/` to
   `tools/supabase/` repository-root path resolution and replacing hard-coded
   infrastructure defaults with required environment reads.

### Phase 2 — adapt tooling

6. `db-deploy.sh`: remove the type-generation half.
7. `functions-deploy.sh`: remove the artifact alias rewriting; replace the
   npm/tsc gates with `deno check`, `deno lint`, and `deno fmt --check`;
   optionally vendor `main/` and drop the remote rewrite block.
8. Add `[tools]` and the tasks to `mise.toml`; delete `tools/db/.gitkeep`;
   update `01-init.md` and `README.md`.

### Phase 3 — environment and documentation

9. Create `server/.env.example`, `server/supabase/functions/.env.example`, and
   `server/README.md` (how to tunnel, how to deploy the database, how to deploy
   functions, where the provider keys actually live, how to restore a backup).
10. Recreate `server/.env.local` from the old repository's copy.

### Phase 4 — verify against the live stack

See §6. Do not proceed past a failing check.

### Phase 5 — iOS client (separate work)

11. Add `supabase-community/supabase-swift` via SPM beside GRDB. Build
    `Infrastructure/Supabase/` (client plus anonymous sign-in, mirroring the old
    `ensureSession()`), `Infrastructure/Media/` (uploads keeping the
    `{auth.uid()}/filename` prefix the storage policies require), and the import
    adapter from `03-content-storage.md` §5.
12. Add `Config/AppConfiguration.swift` and the xcconfig pair.

### Phase 6 — retire the old repository

13. Once a deploy from this repository has succeeded, archive
    `dreamproject-old` read-only so migrations cannot be pushed from two places.

## 6. Verification

- `supabase migration list --db-url …` from this repository shows every
  migration applied on both sides and nothing pending. This single check proves
  the move was clean.
- `supabase db diff --db-url … --schema public` returns empty: the declarative
  `schemas/` still matches the live database.
- `mise run functions:check` passes.
- `mise run functions:deploy` produces a new release id, `/hello` answers, every
  function passes its `OPTIONS` probe, and the previous release is retained.
- One real call per function from a client using the anon key and an anonymous
  session.
- `mise run db:backup` produces a complete backup from this repository's copy of
  the script.
- `git grep -iE 'aphe0c|hostinger|/etc/dokploy'` returns nothing.

## 7. Risks

1. **Migration filenames are the migration identity.** `supabase db push`
   matches the timestamp prefixes against `supabase_migrations.schema_migrations`
   on the remote. Identical names mean nothing is pending; renamed or squashed
   names mean the remote treats all six as new and re-runs them. This is the one
   mistake that turns the move into an incident.
2. **`config.toml` `db.major_version = 17` must keep matching the remote**
   (`SHOW server_version`), or the shadow database used by `db diff` reports
   false differences.
3. **The anon key and the service-role key look alike.** Only the anon key may
   reach the app.
4. **Storage policies depend on the upload path prefix.** The iOS uploader must
   write `{uid}/filename.ext` into the `ugc-*` buckets or every insert is denied.
5. **`hello` is the deployment health probe**, not dead code. Activation is
   gated on it. Do not delete it.
6. **Never run `supabase db reset` against the tunnel.** It is a local-stack
   command; pointed at production it drops everything.
7. **Two repositories able to deploy to one stack** is the real risk window.
   Keep it short by completing Phase 6 promptly.

## Scope

Included: moving the Supabase project files and deployment tooling, folding the
shared contracts into the functions, the environment and credential layout, the
mise tasks, and the verification procedure.

Deferred: any server-side schema change, the Supabase Swift client and import
adapter (Phase 5, planned separately), continuous integration, and the web app's
type generation.

Writing this plan does not move any file, change any script, or deploy anything.
