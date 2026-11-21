#!/usr/bin/env bash
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

run_timed() {
  echo "+ $*"
  /usr/bin/time -p "$@"
}

PROJECT_DIR="$PWD"
PORT="${PORT:-3000}"
DIST_DIR="$PROJECT_DIR/dist"
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"

mkdir -p "$DIST_DIR" "$WEB_DIR"
run_timed rm -rf "$DIST_DIR"
run_timed mkdir -p "$DIST_DIR"
run_timed cp "$PROJECT_DIR/build/preview.html" "$DIST_DIR/index.html"

mkdir -p /home/runner/work/_temp
cat > "$WEB_DIR/deployment-output.json" <<JSON
{"project":"$PROJECT_DIR","directory":"$DIST_DIR"}
JSON

echo "Serving $DIST_DIR on http://127.0.0.1:$PORT"
exec /usr/bin/time -p python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$DIST_DIR"
