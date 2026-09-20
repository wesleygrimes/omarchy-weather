#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

command -v qmllint >/dev/null || { echo "qmllint not found (qt6-declarative)" >&2; exit 1; }
shell_path="${OMARCHY_PATH:-/usr/share/omarchy}/shell"
[[ -f $shell_path/Commons/qmldir && -f $shell_path/Ui/qmldir ]] || {
  echo "Omarchy QML modules not found under $shell_path; set OMARCHY_PATH" >&2
  exit 1
}

# Quickshell exposes the shell directory as the qs import namespace at runtime.
imports=$(mktemp -d)
trap 'rm -rf "$imports"' EXIT
ln -s "$(realpath "$shell_path")" "$imports/qs"
qmllint --ignore-settings --max-warnings 0 -I "$imports" ./*.qml
