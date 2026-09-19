#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

node tests/model.test.js
omarchy plugin validate .
