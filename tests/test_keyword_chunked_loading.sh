#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_CONFIG_DIR="$(mktemp -d)"
PROJECT_NAME="cg-chunked-$$"
NETWORK_NAME="${PROJECT_NAME}-net"
GATEWAY_URL="http://127.0.0.1:18888"
OUTPUT_FILE="$(mktemp)"

cleanup() {
  env \
    COMPOSE_PROJECT_NAME="$PROJECT_NAME" \
    DOCKER_NETWORK_EXTERNAL=false \
    DOCKER_NETWORK_NAME="$NETWORK_NAME" \
    HOST_IP=127.0.0.1 \
    HOST_PORT=18888 \
    CONFIG_DIR="$TEST_CONFIG_DIR" \
    API_TOKEN=default-secret-token-please-change-me \
    ENABLE_DYNAMIC_ROUTING=false \
    KEYWORD_CHUNK_SIZE=1 \
    WORKER_PROCESSES=1 \
    docker compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEST_CONFIG_DIR" "$OUTPUT_FILE"
}

trap cleanup EXIT

cat >"$TEST_CONFIG_DIR/keywords.txt" <<'EOF'
hello
world
EOF

: >"$TEST_CONFIG_DIR/routes.txt"

cd "$ROOT_DIR"

docker rm -f claude-gateway >/dev/null 2>&1 || true

env \
  COMPOSE_PROJECT_NAME="$PROJECT_NAME" \
  DOCKER_NETWORK_EXTERNAL=false \
  DOCKER_NETWORK_NAME="$NETWORK_NAME" \
  HOST_IP=127.0.0.1 \
  HOST_PORT=18888 \
  CONFIG_DIR="$TEST_CONFIG_DIR" \
  API_TOKEN=default-secret-token-please-change-me \
  ENABLE_DYNAMIC_ROUTING=false \
  KEYWORD_CHUNK_SIZE=1 \
  WORKER_PROCESSES=1 \
  docker compose up -d --build >/dev/null

for _ in $(seq 1 60); do
  HTTP_CODE="$(curl -sS -o "$OUTPUT_FILE" -w "%{http_code}" "$GATEWAY_URL/health" || true)"
  if [[ "$HTTP_CODE" == "200" ]]; then
    break
  fi
  sleep 1
done

BODY="$(cat "$OUTPUT_FILE")"
grep -F '"keywords_loaded":2' <<<"$BODY" >/dev/null
grep -F '"keyword_matcher_chunks":2' <<<"$BODY" >/dev/null

HTTP_CODE="$(curl -sS -o "$OUTPUT_FILE" -w "%{http_code}" \
  -X POST "$GATEWAY_URL/openai/responses" \
  -H 'Authorization: Bearer dummy-token' \
  -H 'Content-Type: application/json' \
  -d '{"model":"gpt-4.1-mini","input":"world"}')"

BODY="$(cat "$OUTPUT_FILE")"

[[ "$HTTP_CODE" == "403" ]]
grep -F "命中关键词：world" <<<"$BODY" >/dev/null

echo "chunked keyword loading matches across chunks"
