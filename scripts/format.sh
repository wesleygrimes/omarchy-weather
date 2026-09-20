#!/usr/bin/env bash
# Write QML and JS. Pass --check to fail if a file would change.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf '%s\n' "$@" >&2; exit 1; }

command -v qmlformat >/dev/null || die "qmlformat not found (qt6-declarative)"
command -v biome >/dev/null || die "biome not found (mise install)"
[[ $# -eq 0 || $1 == --check ]] || die "usage: format.sh [--check]"

shopt -s nullglob
qml_files=(./*.qml)
(( ${#qml_files[@]} > 0 )) || die "no QML files"

if [[ ${1:-} == --check ]]; then
  failed=0
  tmp=$(mktemp)
  trap 'rm -f "$tmp"' EXIT
  for f in "${qml_files[@]}"; do
    qmlformat "$f" >"$tmp"
    if ! diff -u --label "$f" --label "$f (formatted)" "$f" "$tmp" >&2; then
      failed=1
    fi
  done
  biome format >&2 || failed=1
  (( failed == 0 )) || die "run mise format"
  exit 0
fi

qmlformat -i "${qml_files[@]}"
printf 'formatted: %s\n' "${qml_files[@]}"
biome format --write
