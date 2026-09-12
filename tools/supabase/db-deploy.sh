#!/usr/bin/env bash
# Pushes pending migrations from server/supabase/migrations to the remote
# database through the SSH tunnel. Configuration comes from server/.env.local
# through env.sh; see server/README.md.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tools/supabase/env.sh
source "$repo_root/tools/supabase/env.sh"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

for command_name in deno ssh supabase; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
done

: "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in server/.env.local or the environment.}"
export POSTGRES_PASSWORD
export SUPABASE_TUNNEL_PORT="${SUPABASE_TUNNEL_PORT:-54330}"

# The URL API percent-encodes the password; the value is read from the
# environment and never appears on a command line or in output.
db_url="$(deno eval --quiet '
const url = new URL(`postgresql://postgres@127.0.0.1:${Deno.env.get("SUPABASE_TUNNEL_PORT")}/postgres`)
url.password = Deno.env.get("POSTGRES_PASSWORD") ?? ""
Deno.stdout.writeSync(new TextEncoder().encode(url.href))
')"

bash "$repo_root/tools/supabase/tunnel.sh" start

supabase --workdir "$repo_root/server" db push --db-url "$db_url"
