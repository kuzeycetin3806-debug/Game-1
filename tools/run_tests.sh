#!/usr/bin/env bash
# Runs the GUT suite headless. Usage: tools/run_tests.sh [extra gut args]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
if [ ! -d .godot ]; then
	"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
