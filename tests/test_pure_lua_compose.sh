#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if rg -n "keyword-engine|KEYWORD_ENGINE_URL" docker-compose.yml openresty/nginx.conf scripts/rsync-to-remote.sh README.md docs/ARCHITECTURE.md tools/README.md >/dev/null; then
  echo "expected pure Lua rollback to remove keyword-engine wiring"
  exit 1
fi

echo "pure Lua rollback removed keyword-engine wiring"
