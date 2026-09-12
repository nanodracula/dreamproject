# Server: self-hosted Supabase

The Supabase project for DreamApp lives in `server/supabase/`. The instance
itself runs on a Hostinger VPS under Dokploy; this directory holds the SQL,
the edge functions, and the configuration those deploy from. Moved from
`nanodracula/dreamproject-old` at commit `effe870` on September 13, 2026
(see `docs/plans/04-supabase-migration.md`).

```text
server/
├── README.md                  # this runbook
├── .env.example               # operator configuration, names only
├── .env.local                 # gitignored; your copy with values
└── supabase/
    ├── config.toml            # project_id, db.major_version = 17, functions verify_jwt
    ├── seed.sql               # local `db reset` seed only; never runs against the tunnel
    ├── schemas/               # declarative schema files (source of `db diff`)
    ├── migrations/            # timestamped history matched against the remote
    └── functions/
        ├── deno.json          # the single `check` task and format settings
        ├── deno.lock          # committed; shared by all functions and the router
        ├── .env.example       # provider key names the edge runtime needs
        ├── main/              # checked-in Supabase router
        ├── _shared/           # contracts, providers, utils
        ├── generate-text/     # workflows own their schemas and prompts
        ├── generate-image/
        └── generate-audio/
```

Helper scripts live in `tools/supabase/` and are exposed as mise tasks.

## Setup

1. `bash tools/bootstrap.sh` installs mise, Deno 2, and the Supabase CLI
   (`2.117.0`, pinned in `mise.toml` to support the current `config.toml`).
2. SSH access to the VPS as configured in `~/.ssh/config`; the host alias goes
   into `SUPABASE_SSH_HOST`.
3. `cp server/.env.example server/.env.local` and fill in every value. The
   file is gitignored by the root `.gitignore` (`.env.*`). Quote values that
   contain spaces or shell characters; the file is sourced by the scripts.
   Set `SUPABASE_DB_USER` to `postgres.<POOLER_TENANT_ID>`, using the tenant
   ID configured for Supavisor in the Dokploy compose environment.

| Variable | Used by | Meaning |
| --- | --- | --- |
| `SUPABASE_DB_USER` | `db:deploy` | Supavisor login, `postgres.<POOLER_TENANT_ID>`; plain `postgres` only for a direct Postgres connection |
| `POSTGRES_PASSWORD` | `db:deploy` | Password of the `postgres` role on the remote database |
| `SUPABASE_SSH_HOST` | all | SSH alias or `user@host` of the VPS |
| `SUPABASE_REMOTE_CONTAINER` | `db:tunnel`, `db:deploy` | Supavisor container name; the tunnel targets its port 5432 |
| `SUPABASE_FUNCTIONS_CONTAINER` | `functions:deploy` | Edge functions container, restarted on deploy |
| `SUPABASE_FUNCTIONS_DIR` | `functions:deploy` | Absolute path of the functions volume on the VPS |
| `SUPABASE_TUNNEL_PORT` | `db:tunnel`, `db:deploy` | Local port for the tunnel, default `54330` |

Optional: `SUPABASE_FUNCTION_RELEASES_TO_KEEP` (5),
`SUPABASE_FAILED_FUNCTION_RELEASES_TO_KEEP` (1),
`SUPABASE_FUNCTION_HEALTH_RETRIES` (20).

Every script sources `tools/supabase/env.sh`, which loads `server/.env.local`
when present, then validates its own required values with `${VAR:?}` so a
missing value fails loudly. Exported environment variables work without the
file. Infrastructure names are deliberately not committed.

## Provider keys

`OPENROUTER_API_KEY` and `ELEVENLABS_API_KEY` are read with `Deno.env.get()`
inside the functions container. Self-hosted Supabase has no
`supabase secrets set`. The values live in the **Dokploy UI**, in the
environment of the Supabase compose stack's functions service; they are not
in this repository and the deploy scripts never need them locally.
`server/supabase/functions/.env.example` lists the names only.

## Database

```sh
mise run db:tunnel                          # SSH tunnel to 127.0.0.1:$SUPABASE_TUNNEL_PORT
bash tools/supabase/tunnel.sh status|stop
mise run db:deploy                          # tunnel + supabase db push --db-url …
```

`db:deploy` builds the connection URL with Deno so the username and password
are percent-encoded, opens the tunnel, and runs
`supabase --workdir server db push --db-url "$db_url"`. Every Supabase CLI
command uses `--workdir server` (or the absolute path in scripts) so it reads
`server/supabase/config.toml` and these migrations.

The URL uses `SUPABASE_DB_USER` and `sslmode=disable`: this Supavisor listener
requires a tenant-qualified username and does not provide PostgreSQL TLS.
Traffic between the operator's machine and the VPS remains encrypted by the
SSH tunnel, which listens only on `127.0.0.1` locally.

Rules:

- Migration filenames are the migration identity: the timestamp prefix is
  matched against `supabase_migrations.schema_migrations` on the remote. Never
  rename, renumber, or squash them.
- `config.toml` `db.major_version = 17` must match `SHOW server_version` on the
  remote, or the shadow database used by `db diff` reports false differences.
- Schema changes are separate work: edit `schemas/`, generate a migration with
  `supabase --workdir server db diff -f <name>` (needs Docker), review, deploy.
- **Never run `supabase db reset` against the tunnel.** It is a local-stack
  command; pointed at production it drops everything.

Checks (tunnel open, `$db_url` built as in `db-deploy.sh`):

```sh
supabase --workdir server migration list --db-url "$db_url"   # local == remote, nothing pending
supabase --workdir server db diff --db-url "$db_url" --schema public   # needs Docker; expect no diff
```

## Edge functions

```sh
mise run functions:check     # deno check --frozen */index.ts && deno lint . && deno fmt --check .
mise run functions:deploy    # check, then rsync a versioned release and activate it
```

The check task is defined once, in `server/supabase/functions/deno.json`;
mise and the deploy script both invoke it. Sources use explicit specifiers
(`npm:zod@4.5.4`, `jsr:@std/encoding@1/base64`) with no import map, so they
run unchanged under the router's `importMapPath = null`. The lint rule
`no-import-prefix` is disabled for that reason.

### Lockfile

`deno.lock` (format version 5, generated by Deno 2.9.6) is committed beside
`deno.json` and covers all three functions and the router. `--frozen` makes
checks and deploys fail on a missing or stale lockfile instead of updating
it. To update dependencies intentionally, change the specifier in source, run
`deno check */index.ts` from the functions directory, and review the lockfile
diff together with the source change.

The release artifact carries `deno.json` and `deno.lock` unchanged. Verified
September 13, 2026 in a throwaway `supabase/edge-runtime:v1.74.0` container
(bundled Deno 2.1.4) on the VPS: with this lockfile present, every function
passes its `OPTIONS` probe, and `POST` with an invalid body
returns 400 from Zod, so the full module graph (npm, jsr, and remote
specifiers) resolves. The runtime logged no lockfile error. Whether it
enforces the lockfile's integrity hashes at resolution time is still unknown;
treat the lockfile as a repository guarantee, not a runtime one.

### Router (`main/index.ts`)

The router is Supabase's self-hosted entrypoint: it verifies the JWT when
`VERIFY_JWT=true`, then dispatches `/<function>` to a user worker. It is a
byte-for-byte copy of the live router taken on September 13, 2026 (release
`20260911T124727Z-54169b6026ae`), with a seven-line provenance header and
`// @ts-nocheck` prepended (the `EdgeRuntime` global has no local types). It
uses `https://deno.land/x/jose@v4.14.4`, verifies HS256 tokens with
`JWT_SECRET` and ES256/RS256 tokens against the JWKS at `SUPABASE_URL`, and
runs workers with `importMapPath = null`. It is excluded from lint and fmt so
it stays diffable.

Edge Runtime image in use: `supabase/edge-runtime:v1.74.0`
(`sha256:2781daf92394db91f7e94129cc3d04ec474ad16a8fe64b3fbeef6e7d557ab120`),
started with `start --main-service /home/deno/functions/main` and the
functions volume mounted at `/home/deno/functions`. When upgrading the image,
review the upstream router
(`docker/volumes/functions/main/index.ts` in `supabase/supabase`) and update
this copy; newer upstream versions read `SUPABASE_JWKS` and use an import
map, which this deployment does not provide.

To confirm the copy still matches the server:

```sh
ssh "$SUPABASE_SSH_HOST" cat "$SUPABASE_FUNCTIONS_DIR/main/index.ts" | diff - <(tail -n +8 server/supabase/functions/main/index.ts)
```

### Release layout and deploy

A release id is `<UTC timestamp>-<12-char git sha>` (`-dirty` appended when
the tree has uncommitted changes). `functions:deploy`:

1. Runs the check task; a stale lockfile or lint/format problem aborts.
2. Builds the artifact: the whole `functions/` tree minus `.env*`, plus a
   `.dreamproject-release` marker.
3. On the VPS, creates `${SUPABASE_FUNCTIONS_DIR}.releases/.incoming-<id>`
   and rsyncs the artifact into it.
4. Under a `flock`, stops the functions container, moves the active
   directory aside as the previous release, moves the new release into
   place, and starts the container.
5. Probes `OPTIONS /<function>` for every function (with the container's
   anon key). Any failure restores the previous release and keeps the failed
   one as `failed-<id>`.
6. Prunes old releases, keeping the newest 5 healthy and 1 failed.

The first deploy from this repository writes a new id beside the ones the old
repository produced; nothing on the server needs to change. The former
`hello` function was removed on September 13, 2026; the `OPTIONS` probes are
the health gate.

### Function contracts

Request and response fields are unchanged from the old repository. Card-title
input requires `learningLanguageCode` in `ja`, `zh-Hant`, `ko`, `pl`, `uk`
(declared in `generate-text/workflows/card-title.ts`; adding a language edits
that list and the Swift catalog) and uses `nativeWritingSystem` as the
language description in the prompt, e.g. `Japanese (Kanji and kana)`.

## Client-facing contract

Clients receive `SUPABASE_URL` and the public **anon** key only, and use an
anonymous user session for authenticated calls (`enable_anonymous_sign_ins`
is on). The service-role key stays in the Dokploy environment; the anon and
service-role keys look alike, so check which one you are pasting. Storage
policies on the `ugc-*` buckets require the `{auth.uid()}/filename` object
prefix. The Swift integration is plan 07.

## Not migrated

Backup tooling (`scripts/supabase-backup.sh` in the old repository), the
TypeScript type generation, the Node lint/tsc gates, and the Expo client code.
