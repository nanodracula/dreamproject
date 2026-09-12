#!/usr/bin/env bash
# Opens, checks, or closes an SSH tunnel from 127.0.0.1:$SUPABASE_TUNNEL_PORT to
# the remote Supavisor container's Postgres port. Configuration comes from
# server/.env.local through env.sh; see server/README.md.

set -euo pipefail

# shellcheck source=tools/supabase/env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

ssh_host="${SUPABASE_SSH_HOST:?Set SUPABASE_SSH_HOST in server/.env.local or the environment.}"
remote_container="${SUPABASE_REMOTE_CONTAINER:?Set SUPABASE_REMOTE_CONTAINER in server/.env.local or the environment.}"
local_port="${SUPABASE_TUNNEL_PORT:-54330}"
remote_port="5432"
control_path="/tmp/dreamproject-supabase-tunnel.sock"

is_running() {
  ssh -S "$control_path" -O check "$ssh_host" >/dev/null 2>&1
}

start_tunnel() {
  if is_running; then
    printf 'Supabase tunnel is already running on 127.0.0.1:%s\n' "$local_port"
    return
  fi

  if lsof -nP -iTCP:"$local_port" -sTCP:LISTEN >/dev/null 2>&1; then
    printf 'Cannot start: local port %s is already in use.\n' "$local_port" >&2
    exit 1
  fi

  container_ip="$(
    ssh "$ssh_host" \
      "docker inspect '$remote_container' --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"
  )"

  if [[ ! "$container_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Could not resolve the Supavisor container IP.\n' >&2
    exit 1
  fi

  ssh -fN -M \
    -S "$control_path" \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -L "127.0.0.1:${local_port}:${container_ip}:${remote_port}" \
    "$ssh_host"

  printf 'Supabase tunnel started on 127.0.0.1:%s\n' "$local_port"
}

show_status() {
  if is_running; then
    printf 'Supabase tunnel is running on 127.0.0.1:%s\n' "$local_port"
  else
    printf 'Supabase tunnel is not running.\n'
    exit 1
  fi
}

stop_tunnel() {
  if is_running; then
    ssh -S "$control_path" -O exit "$ssh_host" >/dev/null
    printf 'Supabase tunnel stopped.\n'
  else
    printf 'Supabase tunnel is not running.\n'
  fi
}

case "${1:-start}" in
  start)
    start_tunnel
    ;;
  status)
    show_status
    ;;
  stop)
    stop_tunnel
    ;;
  *)
    printf 'Usage: %s {start|status|stop}\n' "$0" >&2
    exit 2
    ;;
esac
