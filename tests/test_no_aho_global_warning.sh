#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

docker compose up -d --build >/dev/null
sleep 2
curl -fsS http://127.0.0.1:18888/health >/dev/null

LOG_OUTPUT="$(docker compose logs --tail=200 claude-gateway 2>&1 || true)"

if grep -F "writing a global Lua variable ('aho-corasick')" <<<"$LOG_OUTPUT" >/dev/null; then
  echo "❌ 检测到 ahocorasick 模块写入全局变量告警"
  exit 1
fi

echo "✅ 未检测到 ahocorasick 模块全局变量写入告警"
