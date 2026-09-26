#!/usr/bin/env bash
# Install wesgrimes.weather-dev, reload on save, remove it on exit.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf '%s\n' "$@" >&2; exit 1; }

command -v inotifywait >/dev/null || die "inotifywait not found (pacman -S inotify-tools)"
command -v flock >/dev/null || die "flock not found"
command -v jq >/dev/null || die "jq not found"

id=$(jq -r .id manifest.json)
dev_id=${id%-dev}-dev

mkdir -p tmp
exec 9>tmp/dev.lock
if ! flock -n 9; then
  printf 'mise dev already running\n'
  exit 0
fi

cleaned=0
watch_pid=
fifo=tmp/dev.events

cleanup() {
  ((cleaned)) && return 0
  cleaned=1
  trap '' INT TERM HUP EXIT
  if [[ -n $watch_pid ]]; then
    kill "$watch_pid" 2>/dev/null || true
    wait "$watch_pid" 2>/dev/null || true
  fi
  setsid --wait bash scripts/uninstall-dev.sh </dev/null ||
    bash scripts/uninstall-dev.sh </dev/null || true
}

trap cleanup INT TERM HUP EXIT

bash scripts/install-dev.sh
printf 'Watching %s — saves reload the bar\n' "$dev_id"
printf 'Ctrl-C removes %s\n' "$dev_id"

rm -f "$fifo"
mkfifo "$fifo"
inotifywait -m -r -e close_write,create,delete,move \
  --exclude '(\.git/|tmp/|.*\.(qmlc|jsc)$)' \
  --format '%f' \
  . >"$fifo" 2>/dev/null &
watch_pid=$!

while read -r file; do
  [[ -n $file ]] || continue
  case $file in
  *.qml | *.js | manifest.json) ;;
  *) continue ;;
  esac
  while read -r -t 0.3 _; do :; done
  bash scripts/install-dev.sh
done <"$fifo"
