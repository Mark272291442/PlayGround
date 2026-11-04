#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_DIR
cd "$PROJECT_DIR"
: "${RUNTIME_DIR:?RUNTIME_DIR must point to the OpenCode runtime}"
: "${CAPTURE_URL:?Set CAPTURE_URL to the exact preview URL}"
: "${CAPTURE_DIR:?Set CAPTURE_DIR outside the project for screenshot evidence}"

CAPTURE_DIR="$(/usr/bin/time -p realpath -m -- "$CAPTURE_DIR")"
case "$CAPTURE_DIR/" in
  "$PROJECT_DIR/"*) echo "CAPTURE_DIR must be outside the project directory." >&2; exit 1 ;;
esac
/usr/bin/time -p test -f "$RUNTIME_DIR/scripts/default-capture.mjs"
/usr/bin/time -p node --input-type=module -e 'const u = new URL(process.env.CAPTURE_URL); if (!["http:", "https:"].includes(u.protocol)) process.exit(1)' \
  || { echo "CAPTURE_URL must be an absolute HTTP or HTTPS URL." >&2; exit 1; }

export CAPTURE_DIR
export CAPTURE_READY_SELECTOR="${CAPTURE_READY_SELECTOR:-#echo-app}"
export CAPTURE_STRICT="${CAPTURE_STRICT:-1}"
/usr/bin/time -p node "$RUNTIME_DIR/scripts/default-capture.mjs"
