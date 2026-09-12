# Supabase migration plan

Status: repository move, live baseline, first deployment, and real generation
calls verified on September 13, 2026. Migration IDs and application schema
definitions match; enum ownership and platform permission differences remain
documented in §8, so the raw schema diff is not empty. Live JWT verification
is disabled, and card-breakdown remains a stub. Phase 5 archival is pending.
The `hello` function was removed at the owner's request; per-function
`OPTIONS` probes are the activation gate.
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

This is a repository migration, not a project migration. No data movement or
re-push of existing migrations is needed. Copying files causes no downtime; the
verification deployment briefly interrupts functions because the existing
script stops and starts their container. Keep that deployment mechanism.

What moves:

| Source path | Destination | Change |
| --- | --- | --- |
| `server/supabase/config.toml` | same | none |
| `server/supabase/schemas/*.sql` | same | none |
| `server/supabase/migrations/*.sql` | same | **filenames unchanged** |
| `server/supabase/seed.sql` | same | none |
| `server/supabase/functions/` | same | explicit imports and contract ownership (§2) |
| `server/supabase/.gitignore` | same | none |
| Backend-used parts of `shared/contracts/database.ts` | `server/supabase/functions/_shared/contracts/database.ts` | preserve shared values and schemas (§2) |
| `shared/contracts/text-generation.ts` | `generate-text/index.ts` and `generate-text/workflows/card-title.ts` under functions | colocate contracts with their consumers (§2) |
| Live `main/index.ts` router | `server/supabase/functions/main/index.ts` | copy once, record runtime image version (§4e) |
| `scripts/supabase-tunnel.sh` | `tools/supabase/tunnel.sh` | env-driven identifiers (§3) |
| `scripts/supabase-db-deploy.sh` | `tools/supabase/db-deploy.sh` | type generation removed (§4) |
| `scripts/supabase-functions-deploy.sh` | `tools/supabase/functions-deploy.sh` | alias rewriting and gates removed (§2, §4) |

What does not move:

- `shared/contracts/user-settings.ts` and `shared/config/`. These contain
  client configuration; remove the functions’ language-config dependency as
  described in §2 and [plan 06](06-language-config.md#6-server-changes).
- `scripts/supabase-backup.sh`. Backup tooling is deferred; it is not required
  for this repository move.
- `src/lib/supabase/client.ts`, `session.ts`, `database.types.ts`. Replaced by
  `apps/ios/DreamApp/Infrastructure/Supabase/`.
- `drizzle.config.ts` and `src/lib/database/migrations/`. Replaced by the GRDB
  migrations already implemented (`v1_settings`, `v2_content`).
- The `supabase gen types typescript` step. No TypeScript database-types
  consumer remains.
- The `npx tsc --noEmit` and `npm run lint` gates. No Node project remains.

History is not grafted. Copy the files and name the source commit in the commit
message. A filtered history import is unnecessary for this move; preserve the
source commit reference for tracing the original implementation.

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
│           ├── deno.lock          # committed; shared by all edge functions
│           ├── .env.example       # names of provider keys the edge runtime needs
│           ├── main/              # checked-in Supabase router (§4e)
│           ├── _shared/
│           │   ├── contracts/
│           │   ├── providers/
│           │   └── utils/
│           ├── generate-text/
│           │   ├── index.ts       # HTTP envelope, routing, responses
│           │   └── workflows/     # each workflow owns its schemas and prompt
│           ├── generate-image/
│           └── generate-audio/
├── tools/
│   └── supabase/
│       ├── env.sh                # shared operator configuration loader
│       ├── tunnel.sh
│       ├── db-deploy.sh
│       └── functions-deploy.sh
└── mise.toml
```

`tools/db/` is an empty placeholder allocated by `01-init.md` for "database/CI
helpers". Replace it with `tools/supabase/`: one directory owning one service
beats splitting the database scripts from the functions-deploy script that
talks to the same host over the same SSH connection. Delete `tools/db/.gitkeep`
and amend `01-init.md` accordingly.

## 2. Keep only backend dependencies

The old `shared/` directory served both Expo and Deno. There is no longer a
TypeScript client to share with, so migrate only code reached by the functions.

- Keep cross-function contracts, including the database enums and breakdown
  schemas needed by generation, in `_shared/contracts/database.ts`. Preserve
  their values and validation. Leave unused client-only exports behind.
- Put HTTP request/response envelope schemas in `generate-text/index.ts` when
  only the handler uses them. Move the card-title input/output schemas, tones,
  and inferred types into `generate-text/workflows/card-title.ts`, alongside
  its prompt. The other workflows already own their schemas.
- Workflows must not import `index.ts`: it imports the workflows and starts
  `Deno.serve`. Export workflow schemas to the handler when needed. Do not add
  a separate `contracts.ts` merely because Expo previously shared one.
- Do not copy `user-settings.ts` or `writing-display-mode.ts`; functions do not
  use them. Do not copy the language table with fonts, emoji, and on-device
  speech settings.
- Remove the card-title workflow's language-table lookup. Use the existing
  request's `nativeWritingSystem` as its language/writing-system description;
  keep language-specific prompt guidance keyed by code inside the workflow.
  Declare the supported-code list beside its input schema. This is the server
  work described in [plan 06 §6](06-language-config.md#6-server-changes), done
  during this migration so `_shared/config/` is unnecessary. Keep request and
  response fields unchanged; do not require a new language-name field.

As a one-time source edit in the new repository, change `@root/shared/` imports
to relative paths and every bare `zod` import to `npm:zod@4.5.4`:

```ts
import { audioPaces } from '../_shared/contracts/database.ts'
import { z } from 'npm:zod@4.5.4'
```

The sources then run with the router's `importMapPath = null`. Remove the
artifact rewrite loop, `rewritten_alias_imports` counter, unresolved-alias
check, and `zod_specifier` check against `deno.json`. Keep the release marker,
activation checks, and rollback machinery. Deployment copies the sources
without changing their imports.

`deno.json` owns the single check task and has no import map. Keep lockfile
generation enabled by omitting `"lock": false`:

```jsonc
{
    "tasks": {
        "check": "deno check --frozen */index.ts && deno lint . && deno fmt --check ."
    },
    "compilerOptions": { "strict": true },
    "fmt": { "lineWidth": 100, "useTabs": true, "singleQuote": true, "semiColons": false }
}
```

Commit one `server/supabase/functions/deno.lock` beside `deno.json`, shared by
all functions and the router. Keep explicit dependency specifiers in source;
the lockfile additionally records resolved dependencies and integrity hashes.
Generate it after relocating imports by running `deno check */index.ts` from
the functions directory. For intentional dependency updates, run that command
again and review the lockfile diff alongside the source changes. Normal checks
and deployments use `--frozen` so they fail rather than silently update it.

Include the lockfile unchanged in the release artifact. During implementation,
verify its format and how it is loaded by the deployed Edge Runtime image
recorded in §4e. Document any runtime limitation in `server/README.md`; copying
the file alone does not establish that runtime resolution enforces it.

Swift payload types are maintained independently; existing enum values are
recorded in [plan 03](03-content-storage.md). No shared package or code
generation is needed.

## 3. Credentials and environment

Operator configuration and provider secrets stay server-side. Clients receive
only the public API configuration described at the end of this section.

### Operator secrets: `server/.env.local`

Gitignored, never leaves the operator's machine. The root `.gitignore` already
covers it (`.env`, `.env.*`, with `!.env.example` exceptions), so
`server/.env.local` is ignored and `server/.env.example` is tracked with no
rule changes.

```sh
# server/.env.example

# --- Remote Postgres (through the SSH tunnel) ---
# Supavisor: postgres.<POOLER_TENANT_ID>; direct Postgres: postgres.
SUPABASE_DB_USER=
POSTGRES_PASSWORD=

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

### Load operator configuration once

Add `tools/supabase/env.sh`, sourced by all three scripts before they read any
configuration:

```sh
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -f "$repo_root/server/.env.local" ]]; then
  set -a
  source "$repo_root/server/.env.local"
  set +a
fi
```

The file is trusted, shell-compatible configuration with quoted secret values.
When present, its assignments override inherited environment values; without
it, exported variables still work. Each script validates only its own required
values with `${VAR:?}` after sourcing the loader. The tunnel does not require
the database password or functions directory. Database deployment exports the
password for Deno's URL construction and passes the same configuration to its
tunnel subprocess. Never print secret values.

### Provider secrets: never in the repository

`OPENROUTER_API_KEY` and `ELEVENLABS_API_KEY` are read with `Deno.env.get()`
inside the functions container. Self-hosted Supabase has no
`supabase secrets set`; the values come from the Dokploy compose environment.
Commit `server/supabase/functions/.env.example` listing only the names, and
record in `server/README.md` that the values live in the Dokploy UI. That is
the one piece of deployment knowledge currently written down nowhere.

### Client-facing contract

Clients receive `SUPABASE_URL` and the public anon key, and use an anonymous
user session for authenticated operations. The service-role key stays in the
Dokploy environment; these deployment scripts do not need it locally.
Preserve existing RLS policies and the `{auth.uid()}/filename` storage prefix.
Preserve the function request/response fields while relocating their schemas.

Swift configuration, session handling, uploads, and the import adapter are
separate work in [plan 07](07-supabase-ios-integration.md). Completing this
repository migration does not depend on implementing the iOS client.

## 4. Deployment

### What stays the same

SSH to the VPS, tunnel to the Supavisor container for the database, push
migrations with `supabase db push --db-url`, and deploy functions by rsyncing a
versioned release directory, stopping the functions container, swapping
directories, and starting the container again. The functions script
has a `flock` lock, a release marker, per-function `OPTIONS` health probes,
automatic restore of the previous release on failure, and release pruning. None
of it is repository-specific and none of it should be replaced.

The existing remote release layout does not need to change. The release id is
`<timestamp>-<git sha>`, so the first deploy from this repository simply writes
a new id beside the existing ones in the releases directory.

### a. Drop type generation from `db-deploy.sh`

Nothing consumes `database.types.ts`. The script becomes: load configuration,
build the connection URL, start the tunnel, then run
`supabase --workdir "$repo_root/server" db push --db-url "$db_url"`.
Replace the existing Node-based URL construction with Deno, preserving password
encoding through the URL API. No Node or npm dependency remains in the tooling.
When `apps/web/` arrives, reintroduce generation as a separate `db:types` task
writing into the web app, not as a side effect of deploying.

### b. Run the same check task everywhere

Replace the npm/tsc gates with the `check` task defined in §2. Both mise and
`functions-deploy.sh` invoke it; neither duplicates the underlying commands:

```sh
# From the repository root:
deno task --config server/supabase/functions/deno.json check

# Inside functions-deploy.sh:
deno task --config "$repo_root/server/supabase/functions/deno.json" check
```

Deno runs the task from the configuration directory, so imports and formatting
settings resolve consistently. The frozen check must pass against the committed
lockfile before uploading a release; deployment must not regenerate it.

Every Supabase CLI command uses `--workdir server` from the repository root,
or the absolute equivalent in scripts, to select `server/supabase/config.toml`
and the correct migrations.

### c. Pin the toolchain in `mise.toml`

The Supabase CLI and Deno are now real dependencies. `mise.toml` has no
`[tools]` yet, and `README.md` states "no mise-managed tools yet"; both change.

```toml
[tools]
deno = "2"
"aqua:supabase/cli" = "2.117.0"   # compatible with the committed config.toml

[tasks."db:tunnel"]
description = "Open the SSH tunnel to the remote Postgres"
run = "bash tools/supabase/tunnel.sh start"

[tasks."db:deploy"]
description = "Push pending migrations to the remote database"
run = "bash tools/supabase/db-deploy.sh"

[tasks."functions:check"]
description = "Typecheck, lint, and format-check the edge functions"
run = "deno task --config server/supabase/functions/deno.json check"

[tasks."functions:deploy"]
description = "Deploy a versioned edge-functions release"
run = "bash tools/supabase/functions-deploy.sh"
```

### d. Do not touch the schema during the move

The local app flattens media into embedded `photo` and `audio` JSON while the
server keeps normalized `media_photos`, `media_audio`, and `media_videos`. That
divergence is deliberate per `03-content-storage.md`; the import/sync adapter is
where the two meet. Any server-side schema evolution is a separate phase with
its own `supabase db diff` migration. Keep database changes separate from the
repository move.

### e. Check in the `main` router

`main/index.ts` is Supabase's entrypoint router: it handles incoming function
requests, performs its configured authentication checks, and dispatches to the
requested function. "Vendoring" means keeping a copy in this repository.

Copy the currently deployed router once to
`server/supabase/functions/main/index.ts`, with `importMapPath = null` applied.
Preserve its routing and authentication behavior. Record the corresponding
Edge Runtime image tag or digest and the local import-map adjustment in
`server/README.md`.

Remove the deployment steps that copy `main/` from the live server and patch
its import-map setting, along with the two associated text-match checks.
Include the checked-in router in the release artifact and retain the check
that its entrypoint exists. Keep remote release-directory preparation, locking,
health probes, rollback, and pruning.

Future deploys use the repository's router. When upgrading the Edge Runtime
image, review the upstream router changes and update this copy as needed.

### f. CI: later

`tools/ci/Dockerfile` is an empty placeholder. A GitHub Actions job running
the shared Deno check task and `supabase db lint` on pull requests can be added
later, with the local database setup required for SQL linting. Deploys
need an SSH key on the runner, so keep those manual until that is wanted.

## 5. Phases

### Phase 0 — record the baseline

1. From the old repository root, load `server/.env.local` into the shell and
   record the current state for later comparison. Use a connection URL with
   its password percent-encoded as in the deployment script:

   ```sh
   bash scripts/supabase-tunnel.sh start
   supabase --workdir server migration list --db-url "$db_url"
   ssh "$SUPABASE_SSH_HOST" "cat $SUPABASE_FUNCTIONS_DIR/.dreamproject-release"
   ```

### Phase 1 — copy the project and decouple the functions

2. Copy `server/supabase/` verbatim, replacing `server/supabase/.gitkeep`.
   Do not rename, renumber, or squash any migration file.
3. Bring over only the backend-used contracts and colocate them as in §2.
   Remove the language-config dependency, preserve the wire format, change
   aliases to relative imports, and use explicit Zod specifiers.
4. Copy the three deployment/tunnel scripts into `tools/supabase/`, fixing
   paths and sourcing the new `env.sh` before reading configuration. Replace
   hard-coded infrastructure defaults with required environment reads.

### Phase 2 — adapt tooling

5. `db-deploy.sh`: remove type generation, replace Node-based URL construction
   with Deno, and use the explicit Supabase working directory from §4a.
6. `functions-deploy.sh`: remove artifact import rewriting, check in `main/`
   as in §4e, and remove the remote router-copy and patch steps. Run the shared
   Deno check task before uploading.
7. Add the `deno.json` task, generate and commit the shared `deno.lock`, and
   verify compatibility with the deployed Edge Runtime as described in §2.
   Include the lockfile in releases. Add `[tools]` and tasks to `mise.toml`;
   delete `tools/db/.gitkeep`; update `01-init.md` and `README.md`. Keep check
   commands defined only in `deno.json`.

### Phase 3 — environment and documentation

8. Create `server/.env.example`, `server/supabase/functions/.env.example`, and
   `server/README.md` (how to tunnel, how to deploy the database, how to deploy
   functions, and where the provider keys actually live).
9. Recreate `server/.env.local` from the old repository's copy, retaining only
   the values needed by the deployment and tunnel scripts.

### Phase 4 — verify against the live stack

See §6. Do not proceed past a failing check.

### Phase 5 — retire the old repository

10. Once a deploy from this repository has succeeded, archive
    `dreamproject-old` read-only so this repository is the documented source
    for subsequent deployments. The separate iOS integration is not a
    prerequisite. Archiving does not disable deployment scripts in existing
    local checkouts; stop using those scripts.

## 6. Verification

- Compare copied migration filenames and contents with the source commit.
  `supabase --workdir server migration list --db-url …` must show matching
  local and remote versions with nothing pending; it does not compare SQL
  contents.
- With Docker available for the shadow database,
  `supabase --workdir server db diff --db-url … --schema public` should show no
  difference between replayed migrations and the live public schema. This
  does not establish that declarative `schemas/` matches production; compare
  those copied files with the source separately.
- `server/supabase/functions/deno.lock` is tracked and covers all function
  entrypoints, including the router. `mise run functions:check` passes without
  changing it; a missing or stale lockfile fails the frozen check.
- The release contains the committed lockfile unchanged. Verify that functions
  load with it under the recorded Edge Runtime image, and document whether
  runtime dependency resolution enforces it as described in §2.
- Function sources contain no bare `zod` or `@root/shared/` imports, no
  `_shared/config/`, and no copied user-settings or writing-display helpers.
- `mise run functions:deploy` produces a new release id, every
  function passes its `OPTIONS` probe, and the previous release is retained.
- One real call per function from a client using the anon key and an anonymous
  session.
- Inspect tracked deployment scripts and configuration for old hard-coded
  infrastructure identifiers. Exclude historical documentation from this
  check; operator-specific values belong in `server/.env.local`.

## 7. Risks

1. **Migration timestamp prefixes are the migration identity.** `supabase db push`
   matches the timestamp prefixes against `supabase_migrations.schema_migrations`
   on the remote. Preserve both filenames and contents. Changing timestamps
   or squashing history creates mismatched migration history; do not repair
   that mismatch or push replacement migrations as part of the move.
2. **`config.toml` `db.major_version = 17` must keep matching the remote**
   (`SHOW server_version`), or the shadow database used by `db diff` reports
   false differences.
3. **The anon key and the service-role key look alike.** Only the anon key may
   reach the app.
4. **Storage policies depend on the upload path prefix.** The iOS uploader must
   write `{uid}/filename.ext` into the `ugc-*` buckets or every insert is denied.
5. **Every function's `OPTIONS` probe gates activation.** These probes establish
   worker startup, not provider success or JWT enforcement; verify those separately.
6. **Never run `supabase db reset` against the tunnel.** It is a local-stack
   command; pointed at production it drops everything.
7. **Two repositories able to deploy to one stack** is the real risk window.
   Keep it short by completing Phase 5 promptly.

## 8. Live verification — September 13, 2026

- Recorded baseline release `20260911T124727Z-54169b6026ae` and PostgreSQL
  17.6. All six local migration versions match the live migration history.
  The corrected `mise run db:deploy` completed with `upToDate: true` and no
  migrations, seeds, or roles to apply. No schema or content-data changes were applied.
- Fixed two repository tooling defects exposed by real connections: CLI
  2.65.2 rejected the committed config, so mise now pins 2.117.0; the Supavisor
  connection needs `SUPABASE_DB_USER=postgres.<POOLER_TENANT_ID>` and
  `sslmode=disable` inside the encrypted SSH tunnel. The operator configuration
  and runbook now include these settings.
- Replayed all six migrations through the CLI on a disposable PostgreSQL 17
  shadow. pg-delta emitted platform schema/default-privilege changes and a
  misleading `DROP TYPE public.media_origin`. The `--use-migra` cross-check
  failed inside the CLI's diff worker with `ECONNREFUSED 127.0.0.1:54320`.
  Neither diff output was applied.
- Independently replayed the five public-schema migrations on the exact live
  image, `supabase/postgres:17.6.1.136`, in a disposable container without
  networking. Deterministic catalog comparisons matched all 5 tables, 82
  columns, 14 indexes, 20 constraints, 5 RLS policies, and 90 table grants,
  including comments, defaults, nullability, and RLS settings. All 7 enum
  definitions match. The sole application-object difference is the owner of
  `media_origin`: `supabase_admin` live versus `postgres` on replay. Ownership
  was not changed. The storage-only migration was checked separately: all six
  bucket configurations and all three ownership policies match.
- Deployed release `20260912T184222Z-3dff214a29cc-dirty` on the existing Edge
  Runtime `v1.76.2`. Every `OPTIONS` probe passed. All 15 deployed source/config
  files, including `deno.lock`, match the repository by SHA-256; the baseline
  release remains available for rollback. The `dirty` suffix records local
  uncommitted work; no commit or push was made by this verification.
- A temporary anonymous session made five real public-API calls, all HTTP 200:
  Japanese and Polish card titles, a Japanese example sentence, a tea image,
  and Japanese speech. Text response shapes and content were checked; the image
  decoded to a 1200×896 PNG, and the audio was recognized as a 44.1 kHz MP3,
  about 1.23 s. Invalid payloads and unsupported language codes returned HTTP
  400. The temporary anonymous account and its local session credentials were
  removed after verification.
- Authentication enforcement did **not** pass: the live functions container
  has `VERIFY_JWT=false`. Missing credentials, an invalid API key, and an invalid
  bearer token all reached handler validation and returned HTTP 400. The
  repository's `config.toml` `verify_jwt=true` does not set this self-hosted
  runtime environment variable. The deployment preserved the existing setting;
  enforcing JWTs requires a separate persistent Dokploy configuration change.
- `card-breakdown` was found to ignore its input and send the literal `TODO`
  as its prompt. It was not treated as a working generation workflow. Implementing
  that feature, resolving ownership/permission drift, and archiving the old
  repository remain separate work.

## Scope

Included: moving the Supabase project files and deployment tooling, folding the
backend-used contracts into their function owners, checking in the router,
the environment and credential layout, the committed Deno lockfile, the shared
frozen check task, mise tasks, and the verification procedure.

Deferred: backup tooling, server-side schema changes, the
[Supabase Swift integration](07-supabase-ios-integration.md), continuous
integration, and the web app's type generation.

The implementation and live verification record above supersede the original
planning-only status. No migration history was rewritten.
