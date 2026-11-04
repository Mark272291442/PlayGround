#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PROJECT_DIR
cd "$PROJECT_DIR"
PORT="${PORT:-3000}"
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "PORT must be an integer from 1 to 65535." >&2
  exit 1
fi

# This Godot project has no package manifest or web dependencies; build the
# lightweight browser preview directly, with all generated assets in dist/.
/usr/bin/time -p node scripts/build-preview.mjs
/usr/bin/time -p test -s "$PROJECT_DIR/dist/index.html"
echo "Serving ECHO preview on 0.0.0.0:$PORT"
exec /usr/bin/time -p python3 -m http.server "$PORT" --bind 0.0.0.0 --directory "$PROJECT_DIR/dist"
