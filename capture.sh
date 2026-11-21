#!/usr/bin/env bash
set -euo pipefail

cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

: "${CAPTURE_URL:?Set CAPTURE_URL}"
: "${CAPTURE_DIR:?Set CAPTURE_DIR}"

run_timed() {
  echo "+ $*"
  /usr/bin/time -p "$@"
}

run_timed mkdir -p "$CAPTURE_DIR"
export CAPTURE_URL CAPTURE_DIR
export CAPTURE_AUTO_START=false
export CAPTURE_STRICT=1

set +e
run_timed node "${RUNTIME_DIR:?}/scripts/default-capture.mjs"
status=$?
set -e

exit "$status"
