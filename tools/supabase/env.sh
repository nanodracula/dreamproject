# Loads operator configuration for the Supabase scripts. Source it before
# reading any SUPABASE_* or POSTGRES_* value; each script then validates its
# own required values with ${VAR:?}.
#
# server/.env.local is gitignored, shell-compatible, and trusted. When present,
# its assignments override inherited environment values; without it, exported
# variables still work. Never print secret values.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ -f "$repo_root/server/.env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$repo_root/server/.env.local"
  set +a
fi
