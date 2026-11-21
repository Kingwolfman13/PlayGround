#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
PROJECT_DIR="$(pwd -P)"
STATIC_DIR="$PROJECT_DIR/dist"
: "${OPENCODE_WEB_DIR:?OPENCODE_WEB_DIR must point to the worker metadata directory}"
PORT="${PORT:-3000}"
export PORT PROJECT_DIR STATIC_DIR

# This preview has no third-party dependencies. Keep this install step ready if
# a package manifest is added later, without installing anything into worker temp.
if [[ -f package.json ]]; then
  if [[ -f package-lock.json ]]; then
    /usr/bin/time -p npm ci --no-audit --no-fund
  else
    /usr/bin/time -p npm install --no-audit --no-fund
  fi
fi

/usr/bin/time -p mkdir -p "$STATIC_DIR" "$OPENCODE_WEB_DIR"
/usr/bin/time -p cp preview/index.html "$STATIC_DIR/index.html"
/usr/bin/time -p node --input-type=module -e '
  import { writeFileSync } from "node:fs";
  const output = { project: process.env.PROJECT_DIR, directory: process.env.STATIC_DIR };
  writeFileSync(`${process.env.OPENCODE_WEB_DIR}/deployment-output.json`, JSON.stringify(output));
'
exec /usr/bin/time -p node scripts/serve-preview.mjs "$STATIC_DIR"
