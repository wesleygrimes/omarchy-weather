#!/usr/bin/env bash
# Write JS. Pass --check to fail if a file would change.
set -euo pipefail
cd "$(dirname "$0")/.."

die() { printf '%s\n' "$@" >&2; exit 1; }

command -v biome >/dev/null || die "biome not found (mise install)"
[[ $# -eq 0 || $1 == --check ]] || die "usage: format.sh [--check]"

if [[ ${1:-} == --check ]]; then
  biome format >&2 || die "run mise format"
  exit 0
fi

biome format --write
