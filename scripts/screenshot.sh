#!/usr/bin/env bash
# Open the weather popup on an empty workspace and capture that output.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf '%s\n' "$@" >&2; exit 1; }

command -v grim >/dev/null || die "grim not found"
command -v omarchy-shell >/dev/null || die "omarchy-shell not on PATH"
command -v jq >/dev/null || die "jq not found"

id=$(jq -r .id manifest.json)

omarchy-shell shell ping >/dev/null 2>&1 || die "omarchy-shell is not running"

prev=$(hyprctl activeworkspace -j | jq -r .id)
[[ -n $prev ]] || die "could not read the current workspace"

focus_ws() {
  hyprctl dispatch "hl.dsp.focus({ workspace = \"$1\" })" >/dev/null
}

restore() {
  omarchy-shell shell hide "$id" >/dev/null || true
  focus_ws "$prev" || true
}
trap restore EXIT

focus_ws emptynm
sleep 0.35

omarchy-shell shell summon "$id" '{}' >/dev/null || true
omarchy-shell omarchy.weather open >/dev/null || true
sleep 2

output=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
[[ -n $output ]] || die "no focused monitor"

mkdir -p tmp
out=$(mktemp --suffix=.png "$PWD/tmp/weather.XXXXXX")
grim -t png -l 9 -o "$output" "$out" || die "grim failed"

if command -v wl-copy >/dev/null; then
  wl-copy --type image/png <"$out"
fi

printf '%s\n' "$out"
