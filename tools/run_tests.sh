#!/usr/bin/env bash
# Runs the GUT suite headless. Usage: tools/run_tests.sh [extra gut args]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Always refresh the import/class cache so newly added class_name scripts resolve.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
# Never let tests touch the real save.
export SEHIR_SAVE_DIR="user://test_saves"
export SEHIR_TEST=1
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
