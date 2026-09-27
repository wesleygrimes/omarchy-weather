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
qml_files=(./*.qml)
extra_imports=()
if [[ -f /usr/lib/qt6/qml/MapLibre/qmldir ]]; then
  :
elif [[ -n ${QML_IMPORT_PATH:-} && -f ${QML_IMPORT_PATH}/MapLibre/qmldir ]]; then
  extra_imports=(-I "$QML_IMPORT_PATH")
else
  qml_files=()
  for file in ./*.qml; do
    [[ $file == ./RadarMap.qml ]] || qml_files+=("$file")
  done
  printf 'MapLibre Qt is not installed; skipping RadarMap.qml import lint\n' >&2
fi
qmllint --ignore-settings --max-warnings 0 -I "$imports" "${extra_imports[@]}" "${qml_files[@]}"
