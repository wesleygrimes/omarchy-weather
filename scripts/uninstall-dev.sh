#!/usr/bin/env bash
# Remove the wesgrimes.weather-dev drop-in. Does not touch this checkout.
set -euo pipefail
trap '' INT TERM HUP
cd "$(dirname "$0")/.."

die() { printf '%s\n' "$@" >&2; exit 1; }

command -v jq >/dev/null || die "jq not found"

prod_id=$(jq -r .id manifest.json)
[[ $prod_id != *-dev ]] || prod_id=${prod_id%-dev}
dev_id="${prod_id}-dev"
src=$(pwd -P)
dest=$HOME/.config/omarchy/plugins/$dev_id

if [[ -e $dest ]]; then
  if omarchy-shell shell ping >/dev/null 2>&1; then
    omarchy-shell shell setPluginEnabled "$dev_id" false >/dev/null || true
  fi

  if [[ -L $dest ]]; then
    [[ $(readlink -f "$dest") == "$src" ]] || die "refusing to remove $dest (not this checkout)"
    rm -f "$dest"
  else
    existing=$(jq -r '.id // empty' "$dest/manifest.json" 2>/dev/null || true)
    [[ $existing == "$dev_id" ]] || die "refusing to remove $dest (id ${existing:-unknown})"
    rm -rf "$dest"
  fi
fi

rm -rf "$HOME/.config/omarchy/plugins/.${dev_id}."*
rm -f "$src/tmp/dev.lock" "$src/tmp/dev.events"

if omarchy-shell shell ping >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null
fi

printf 'removed %s\n' "$dev_id"
