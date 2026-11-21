#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
: "${CAPTURE_URL:?Set CAPTURE_URL to the exact preview URL to capture}"
: "${CAPTURE_DIR:?Set CAPTURE_DIR to the evidence output directory}"
: "${RUNTIME_DIR:?RUNTIME_DIR must point to the preview runtime scripts}"
# The runtime capture helper classifies browser/navigation infrastructure errors
# as 75 and rendering/script defects as 1, and always closes its own browser.
exec /usr/bin/time -p node "$RUNTIME_DIR/scripts/default-capture.mjs"
