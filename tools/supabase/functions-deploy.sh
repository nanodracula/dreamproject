#!/usr/bin/env bash

# Deploys a complete, versioned functions release to the self-hosted Supabase
# Edge Runtime. The release is the checked-in server/supabase/functions tree,
# including the main/ router and the committed deno.lock, copied unchanged.
# Configuration comes from server/.env.local through env.sh; see
# server/README.md.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tools/supabase/env.sh
source "$repo_root/tools/supabase/env.sh"

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

ssh_host="${SUPABASE_SSH_HOST:?Set SUPABASE_SSH_HOST in server/.env.local or the environment.}"
remote_container="${SUPABASE_FUNCTIONS_CONTAINER:?Set SUPABASE_FUNCTIONS_CONTAINER in server/.env.local or the environment.}"
remote_dir="${SUPABASE_FUNCTIONS_DIR:?Set SUPABASE_FUNCTIONS_DIR in server/.env.local or the environment.}"
releases_to_keep="${SUPABASE_FUNCTION_RELEASES_TO_KEEP:-5}"
failed_releases_to_keep="${SUPABASE_FAILED_FUNCTION_RELEASES_TO_KEEP:-1}"
health_retries="${SUPABASE_FUNCTION_HEALTH_RETRIES:-20}"

remote_dir="${remote_dir%/}"
functions_dir="$repo_root/server/supabase/functions"

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

for command_name in deno git rsync ssh; do
  require_command "$command_name"
done

[[ "$ssh_host" =~ ^[A-Za-z0-9_.@-]+$ ]] || fail 'SUPABASE_SSH_HOST contains unsupported characters.'
[[ "$remote_container" =~ ^[A-Za-z0-9_.-]+$ ]] || fail 'SUPABASE_FUNCTIONS_CONTAINER contains unsupported characters.'
[[ "$remote_dir" =~ ^/[A-Za-z0-9_./-]+$ ]] || fail 'SUPABASE_FUNCTIONS_DIR must be a simple absolute path.'
[[ "$remote_dir" != / ]] || fail 'Refusing to use the filesystem root as SUPABASE_FUNCTIONS_DIR.'
[[ "$releases_to_keep" =~ ^[1-9][0-9]*$ ]] || fail 'SUPABASE_FUNCTION_RELEASES_TO_KEEP must be positive.'
[[ "$failed_releases_to_keep" =~ ^[0-9]+$ ]] || fail 'SUPABASE_FAILED_FUNCTION_RELEASES_TO_KEEP must be zero or greater.'
[[ "$health_retries" =~ ^[1-9][0-9]*$ ]] || fail 'SUPABASE_FUNCTION_HEALTH_RETRIES must be positive.'

[[ -f "$functions_dir/deno.json" ]] || fail 'Functions deno.json is missing.'
[[ -f "$functions_dir/deno.lock" ]] || fail 'Functions deno.lock is missing; run the check task to generate it, then commit it.'
[[ -f "$functions_dir/main/index.ts" ]] || fail 'Functions main/index.ts (the router) is missing.'

release_sha="$(git -C "$repo_root" rev-parse --verify HEAD)"
release_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
release_suffix=''
if [[ -n "$(git -C "$repo_root" status --porcelain --untracked-files=normal)" ]]; then
  release_suffix='-dirty'
  printf 'Warning: deploying uncommitted changes.\n' >&2
fi
release_id="${release_timestamp}-${release_sha:0:12}${release_suffix}"
releases_dir="${remote_dir}.releases"
incoming_dir="$releases_dir/.incoming-$release_id"
release_dir="$releases_dir/$release_id"

# The frozen check fails on a missing or stale lockfile instead of updating it.
printf 'Checking edge functions (types, lint, formatting)...\n'
deno task --config "$functions_dir/deno.json" check

artifact_root="$(mktemp -d)"
trap 'rm -rf -- "$artifact_root"' EXIT
artifact_functions="$artifact_root/functions"

# Sources deploy with their explicit imports unchanged; the router runs with no
# import map. Local env files never leave the machine.
mkdir -p "$artifact_functions"
rsync -a \
  --exclude '.env*' \
  --exclude '.DS_Store' \
  "$functions_dir/" "$artifact_functions/"
printf '%s\n' "$release_id" > "$artifact_functions/.dreamproject-release"

printf 'Preparing remote release %s...\n' "$release_id"
ssh "$ssh_host" bash -s -- \
  "$remote_dir" "$releases_dir" "$incoming_dir" "$release_dir" <<'REMOTE_PREPARE'
set -euo pipefail

active_dir="$1"
releases_dir="$2"
incoming_dir="$3"
release_dir="$4"

[[ -d "$active_dir" ]] || {
  printf 'Active functions directory is missing: %s\n' "$active_dir" >&2
  exit 1
}
[[ ! -e "$incoming_dir" && ! -e "$release_dir" ]] || {
  printf 'Release path already exists.\n' >&2
  exit 1
}

mkdir -p "$releases_dir" "$incoming_dir"
REMOTE_PREPARE

rsync -az "$artifact_functions/" "$ssh_host:$incoming_dir/"

printf 'Activating release and checking every function...\n'
ssh "$ssh_host" bash -s -- \
  "$remote_container" "$remote_dir" "$releases_dir" "$incoming_dir" \
  "$release_dir" "$release_id" "$releases_to_keep" \
  "$failed_releases_to_keep" "$health_retries" <<'REMOTE_ACTIVATE'
set -euo pipefail

container="$1"
active_dir="$2"
releases_dir="$3"
incoming_dir="$4"
release_dir="$5"
release_id="$6"
releases_to_keep="$7"
failed_releases_to_keep="$8"
health_retries="$9"
lock_file="${active_dir}.deploy.lock"
failed_dir="$releases_dir/failed-$release_id"

for command_name in curl docker flock; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Required remote command not found: %s\n' "$command_name" >&2
    exit 1
  }
done

exec 9>"$lock_file"
flock -n 9 || {
  printf 'Another functions deployment is already active.\n' >&2
  exit 1
}

[[ -f "$incoming_dir/.dreamproject-release" ]] || {
  printf 'Incoming release marker is missing.\n' >&2
  exit 1
}
[[ "$(<"$incoming_dir/.dreamproject-release")" == "$release_id" ]] || {
  printf 'Incoming release marker does not match the requested release.\n' >&2
  exit 1
}
[[ -f "$incoming_dir/main/index.ts" ]] || {
  printf 'Incoming release is missing main/index.ts.\n' >&2
  exit 1
}

mv "$incoming_dir" "$release_dir"

if [[ ! -f "$active_dir/.dreamproject-release" ]]; then
  printf 'legacy-%s\n' "$release_id" > "$active_dir/.dreamproject-release"
fi
previous_release_id="$(<"$active_dir/.dreamproject-release")"
[[ "$previous_release_id" =~ ^[A-Za-z0-9_.-]+$ ]] || {
  printf 'Active release marker contains an invalid identifier.\n' >&2
  exit 1
}
previous_dir="$releases_dir/$previous_release_id"
[[ ! -e "$previous_dir" ]] || {
  printf 'Previous release path already exists: %s\n' "$previous_dir" >&2
  exit 1
}

needs_rollback=false
rollback_on_exit() {
  status="$?"
  if [[ "$status" -eq 0 || "$needs_rollback" != true ]]; then
    return
  fi

  set +e
  printf 'Activation failed; restoring the previous release.\n' >&2
  docker stop "$container" >/dev/null 2>&1
  if [[ -d "$active_dir" && -d "$previous_dir" ]]; then
    mv "$active_dir" "$failed_dir"
  fi
  if [[ ! -d "$active_dir" && -d "$previous_dir" ]]; then
    mv "$previous_dir" "$active_dir"
  fi
  docker start "$container" >/dev/null
  return "$status"
}
trap rollback_on_exit EXIT

printf 'Stopping %s...\n' "$container"
needs_rollback=true
docker stop "$container" >/dev/null
mv "$active_dir" "$previous_dir"
mv "$release_dir" "$active_dir"
docker start "$container" >/dev/null

container_ip=''
for ((attempt = 1; attempt <= health_retries; attempt += 1)); do
  container_ip="$(
    docker inspect "$container" \
      --format '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' |
      sed -n '1p'
  )"
  [[ -n "$container_ip" ]] && break
  sleep 1
done

if [[ -z "$container_ip" ]]; then
  exit 1
fi

anon_key="$(
  docker inspect "$container" --format '{{range .Config.Env}}{{println .}}{{end}}' |
    sed -n 's/^SUPABASE_ANON_KEY=//p' |
    sed -n '1p'
)"
headers=()
if [[ -n "$anon_key" ]]; then
  headers+=(--header "apikey: $anon_key")
  headers+=(--header "Authorization: Bearer $anon_key")
fi

request_with_retry() {
  local method="$1"
  local url="$2"
  local attempt

  for ((attempt = 1; attempt <= health_retries; attempt += 1)); do
    if curl --fail --silent --show-error --max-time 5 \
      --request "$method" "${headers[@]}" "$url" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Every function answers OPTIONS without provider calls, so a passing probe
# means the router dispatched and the worker booted with its module graph.
for entrypoint in "$active_dir"/*/index.ts; do
  function_name="$(basename "$(dirname "$entrypoint")")"
  [[ "$function_name" == main ]] && continue

  if ! request_with_retry OPTIONS "http://$container_ip:9000/$function_name"; then
    printf 'Function health check failed: %s\n' "$function_name" >&2
    exit 1
  fi
done

printf 'Release %s is healthy.\n' "$release_id"
needs_rollback=false

prune_releases() {
  local release_kind="$1"
  local keep="$2"
  local kept=0
  local marker candidate candidate_name
  local markers=("$releases_dir"/*/.dreamproject-release)

  [[ -e "${markers[0]}" ]] || return

  while IFS= read -r marker; do
    candidate="$(dirname "$marker")"
    candidate_name="$(basename "$candidate")"

    [[ "$candidate_name" == .incoming-* ]] && continue
    if [[ "$release_kind" == failed && "$candidate_name" != failed-* ]]; then
      continue
    fi
    if [[ "$release_kind" == healthy && "$candidate_name" == failed-* ]]; then
      continue
    fi

    kept=$((kept + 1))
    if ((kept > keep)); then
      rm -rf -- "$candidate"
    fi
  done < <(ls -1t -- "${markers[@]}")
}

prune_releases healthy "$releases_to_keep"
prune_releases failed "$failed_releases_to_keep"
REMOTE_ACTIVATE

printf 'Deployed release %s.\n' "$release_id"
