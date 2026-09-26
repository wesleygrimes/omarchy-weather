#!/usr/bin/env bash
# Install wesgrimes.weather-dev: dest manifest with a -dev id, source files linked.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf '%s\n' "$@" >&2; exit 1; }

command -v jq >/dev/null || die "jq not found"
command -v omarchy >/dev/null || die "omarchy not on PATH"

prod_id=$(jq -r .id manifest.json)
[[ $prod_id != *-dev ]] || die "checkout id is $prod_id; it should be wesgrimes.weather"
dev_id="${prod_id}-dev"

src=$(pwd -P)
dest=$HOME/.config/omarchy/plugins/$dev_id
plugins_root=$HOME/.config/omarchy/plugins
entry=$(jq -r '.entryPoints.barWidget // empty' "$src/manifest.json")

[[ $src != "$dest" ]] || die "run mise dev from ~/Work/omarchy-weather"
[[ $src != "$plugins_root/$prod_id" && $src != "$plugins_root/$dev_id" ]] ||
  die "run mise dev from ~/Work/omarchy-weather"
[[ -n $entry && -f $src/$entry ]] || die "missing entry point ${entry:-<none>}"

if [[ -e $dest ]]; then
  if [[ -L $dest ]]; then
    rm -f "$dest"
  else
    existing=$(jq -r '.id // empty' "$dest/manifest.json" 2>/dev/null || true)
    [[ $existing == "$dev_id" ]] || die "refusing to replace $dest (id ${existing:-unknown})"
  fi
fi

stage=$(mktemp -d "$plugins_root/.${dev_id}.XXXXXX")
trap 'rm -rf "$stage"' EXIT

jq --arg id "$dev_id" '
  .id = $id
  | .barWidget.displayName = ((.barWidget.displayName // .name) + " (dev)")
  | .barWidget.defaultSection = "left"
  | .name += " (dev)"
' "$src/manifest.json" >"$stage/manifest.json"

while IFS= read -r -d '' file; do
  rel=${file#"$src/"}
  mkdir -p "$stage/$(dirname -- "$rel")"
  ln -s "$file" "$stage/$rel"
done < <(find "$src" \( -name .git -o -name tmp -o -name scripts -o -name .github \) -prune -o \
  -type f \( -name '*.qml' -o -name '*.js' \) -print0)

omarchy plugin validate "$src"

same=0
if [[ -d $dest ]] && diff -rq "$stage" "$dest" >/dev/null 2>&1; then
  same=1
fi

if ((same == 0)); then
  rm -rf "$dest"
  mv "$stage" "$dest"
  trap - EXIT
fi

if ! omarchy-shell shell ping >/dev/null 2>&1; then
  printf 'linked %s — start the shell with: omarchy restart shell\n' "$dev_id"
  exit 0
fi

if ((same == 0)); then
  omarchy-shell shell rescanPlugins >/dev/null
fi

discovered=0
for ((attempt = 0; attempt < 40; attempt++)); do
  if omarchy plugin list --json | jq -e --arg id "$dev_id" 'any(.[]; .id == $id)' >/dev/null; then
    discovered=1
    break
  fi
  sleep 0.05
done
((discovered)) || die "plugin '$dev_id' is not known after rescan"

on_left=0
if jq -e --arg id "$dev_id" '[.bar.layout.left[]? | select(.id == $id)] | length > 0' \
  "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1; then
  on_left=1
fi

if ((on_left == 0)); then
  omarchy plugin enable "$dev_id" --section left
fi

if ((same == 0)); then
  printf 'loaded %s\n' "$dev_id"
fi
