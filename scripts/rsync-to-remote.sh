#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "用法: $0 <user@host>" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "错误: 未找到 rsync" >&2
  exit 1
fi

REMOTE="$1"
REMOTE_DIR="/opt/claude-gateway"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "==> 同步到 ${REMOTE}:${REMOTE_DIR}"
rsync -az \
  --exclude "__pycache__/" \
  --exclude "*.pyc" \
  --exclude ".DS_Store" \
  "$PROJECT_ROOT/docker-compose.yml" \
  "$PROJECT_ROOT/openresty" \
  "$PROJECT_ROOT/tools" \
  "$REMOTE:$REMOTE_DIR/"

echo "==> 同步完成"
