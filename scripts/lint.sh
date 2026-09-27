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
  native_imports=/usr/lib/qt6/qml
elif [[ -n ${QML_IMPORT_PATH:-} && -f ${QML_IMPORT_PATH}/MapLibre/qmldir ]]; then
  native_imports=$QML_IMPORT_PATH
else
  qml_files=()
  for file in ./*.qml; do
    [[ $file == ./RadarMap.qml ]] || qml_files+=("$file")
  done
  printf 'MapLibre Qt is not installed; skipping RadarMap.qml import lint\n' >&2
fi
if [[ -n ${native_imports:-} ]]; then
  # MapLibre 3.0 omits the QtQuick dependency needed to resolve Style's QQuickItem base.
  mkdir "$imports/MapLibre"
  cp "$native_imports/MapLibre/qmldir" "$imports/MapLibre/"
  cp "$native_imports/MapLibre/"*.qmltypes "$imports/MapLibre/"
  printf '\ndepends QtQuick 6.0\n' >> "$imports/MapLibre/qmldir"
  extra_imports=(-I "$native_imports")
fi
qmllint --bare --ignore-settings --max-warnings 0 -I "$imports" "${extra_imports[@]}" -I /usr/lib/qt6/qml "${qml_files[@]}"
