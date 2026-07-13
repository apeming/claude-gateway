#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KEYWORDS_FILE="/etc/openresty/keywords.txt"
BACKUP_FILE="/etc/openresty/keywords.txt.bak"
OUTPUT_FILE="$(mktemp)"
GATEWAY_URL="${GATEWAY_URL:-http://127.0.0.1:18888}"
CONTAINER_NAME="${CONTAINER_NAME:-claude-gateway}"

wait_for_gateway() {
  local attempt
  for attempt in $(seq 1 30); do
    if curl -sS "$GATEWAY_URL/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

cleanup() {
  rm -f "$OUTPUT_FILE"

  if docker exec "$CONTAINER_NAME" test -f "$BACKUP_FILE"; then
    docker exec "$CONTAINER_NAME" mv "$BACKUP_FILE" "$KEYWORDS_FILE"
    docker compose restart claude-gateway >/dev/null
    wait_for_gateway
  fi
}

trap cleanup EXIT

docker exec "$CONTAINER_NAME" mv "$KEYWORDS_FILE" "$BACKUP_FILE"
docker compose restart claude-gateway >/dev/null
wait_for_gateway

HTTP_CODE="$(curl -sS -o "$OUTPUT_FILE" -w "%{http_code}" \
  -X POST "$GATEWAY_URL/openai/responses" \
  -H 'Authorization: Bearer dummy-token' \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4.1-mini","input":"hello"}')"

BODY="$(cat "$OUTPUT_FILE")"

[[ "$HTTP_CODE" == "400" ]]
grep -F "关键词库加载失败" <<<"$BODY" >/dev/null

echo "fail-closed path returns 400 with Chinese error"
