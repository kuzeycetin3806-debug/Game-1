#!/usr/bin/env bash
# Builds the browser version for the claude.ai page host: no-threads web export,
# gzipped engine and game data renamed to .wasm (the host serves only common web
# types), plus our loader page (platform/web/index.html). Output: build/site/
# Needs the web_nothreads_release.zip export template.
set -euo pipefail
cd "$(dirname "$0")/.."
G="${GODOT:-godot}"
rm -rf build/web build/site && mkdir -p build/web build/site
"$G" --headless --path . --export-release "Web" build/web/index.html
gzip -9 -c build/web/index.wasm > build/site/engine.gz.wasm
cp build/web/index.pck build/site/game.pck.wasm
cp build/web/index.js build/web/index.audio.worklet.js build/web/index.audio.position.worklet.js build/site/
# Keep the loader's progress sizes in step with this export.
python3 - <<'PY'
import os, re
pck = os.path.getsize("build/web/index.pck"); wasm = os.path.getsize("build/web/index.wasm")
s = open("platform/web/index.html").read()
s = re.sub(r'"fileSizes":\{[^}]*\}', '"fileSizes":{"index.pck":%d,"index.wasm":%d}' % (pck, wasm), s)
open("build/site/index.html", "w").write(s)
PY
ls -la build/site
