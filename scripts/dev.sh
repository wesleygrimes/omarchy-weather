#!/usr/bin/env bash
# Watch this plugin and hot-reload Quickshell via rescanPlugins.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf '%s\n' "$@" >&2; exit 1; }

command -v inotifywait >/dev/null || die "inotifywait not found (pacman -S inotify-tools)"
command -v omarchy-shell >/dev/null || die "omarchy-shell not on PATH"

id=$(jq -r .id manifest.json)

reload() {
  if ! omarchy-shell shell ping >/dev/null 2>&1; then
    printf 'shell down — waiting (omarchy restart shell)\n'
    return 0
  fi
  local out
  out=$(omarchy-shell shell rescanPlugins 2>&1 || true)
  printf 'reload %s\n' "$(date +%H:%M:%S)"
  [[ -z $out || $out == ok ]] || printf '%s\n' "$out"
}

printf 'Watching %s — edits hot-reload Quickshell\n' "$id"
printf 'Ctrl-C to stop\n'
reload

inotifywait -m -r -e close_write,create,delete,move \
  --exclude '(\.git/|.*\.(qmlc|jsc)$)' \
  . 2>/dev/null |
while read -r _dir _event file; do
  [[ -n ${file:-} ]] || continue
  while read -r -t 0.3 _; do :; done
  reload
done
