#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

PROJECT_DIR="$(pwd -P)"
PORT="${PORT:-3000}"
OPENCODE_WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
DIST_DIR="$PROJECT_DIR/dist"

run_timed() {
  /usr/bin/time -p "$@"
}

run_timed mkdir -p "$DIST_DIR" "$OPENCODE_WEB_DIR"
run_timed rm -rf "$DIST_DIR"/*
run_timed cp -a "$PROJECT_DIR/web/." "$DIST_DIR/"

if [[ ! -f "$DIST_DIR/index.html" ]]; then
  echo "Static build defect: dist/index.html was not created" >&2
  exit 1
fi

run_timed python3 - <<PY
import json
from pathlib import Path
metadata = {"project": "$PROJECT_DIR", "directory": "$DIST_DIR"}
Path("$OPENCODE_WEB_DIR/deployment-output.json").write_text(json.dumps(metadata), encoding="utf-8")
PY

echo "Serving static preview at http://127.0.0.1:$PORT (directory: $DIST_DIR)"
exec /usr/bin/time -p python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$DIST_DIR"
