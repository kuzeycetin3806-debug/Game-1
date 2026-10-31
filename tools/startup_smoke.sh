#!/usr/bin/env bash
# Cold-start smoke test: run the real game once with an empty save dir, then
# inspect the save it wrote. Usage: tools/startup_smoke.sh [godot-binary-or-exported-game]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
GAME="${1:-}"
export SEHIR_SAVE_DIR="user://startup_smoke_$$"
if [ -n "$GAME" ]; then
	"$GAME" --headless --quit-after 120 >/dev/null 2>&1
else
	"$GODOT" --headless --path . --quit-after 120 >/dev/null 2>&1
fi
"$GODOT" --headless --path . -s tools/startup_smoke.gd
