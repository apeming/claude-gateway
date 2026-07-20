#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_CONFIG_DIR="$(mktemp -d)"
PROJECT_NAME="cg-anchored-regex-$$"
NETWORK_NAME="${PROJECT_NAME}-net"
GATEWAY_URL="http://127.0.0.1:18888"
OUTPUT_FILE="$(mktemp)"

cleanup() {
  status=$?
  if [[ "$status" -ne 0 ]]; then
    env COMPOSE_PROJECT_NAME="$PROJECT_NAME" DOCKER_NETWORK_EXTERNAL=false \
      DOCKER_NETWORK_NAME="$NETWORK_NAME" HOST_IP=127.0.0.1 HOST_PORT=18888 \
      CONFIG_DIR="$TEST_CONFIG_DIR" API_TOKEN=default-secret-token-please-change-me \
      ENABLE_DYNAMIC_ROUTING=false WORKER_PROCESSES=1 \
      docker compose logs --no-color || true
  fi
  env COMPOSE_PROJECT_NAME="$PROJECT_NAME" DOCKER_NETWORK_EXTERNAL=false \
    DOCKER_NETWORK_NAME="$NETWORK_NAME" HOST_IP=127.0.0.1 HOST_PORT=18888 \
    CONFIG_DIR="$TEST_CONFIG_DIR" API_TOKEN=default-secret-token-please-change-me \
    ENABLE_DYNAMIC_ROUTING=false WORKER_PROCESSES=1 \
    docker compose down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEST_CONFIG_DIR" "$OUTPUT_FILE"
}
trap cleanup EXIT

cat >"$TEST_CONFIG_DIR/keywords.txt" <<'EOF'
literal-secret
EOF
cat >"$TEST_CONFIG_DIR/regex_rules.jsonl" <<'EOF'
{"id":"contract-total-price","anchor":"服务总价","expression":"{{anchor}}[[:space:]]*[（(]?[[:space:]]*含税[[:space:]]*[)）]?[[:space:]]*[:：][[:space:]]*[￥¥][[:space:]]*[0-9]{1,3}(?:,[0-9]{3})*(?:[.][0-9]{1,2})?","enabled":true}
EOF
: >"$TEST_CONFIG_DIR/routes.txt"

cd "$ROOT_DIR"
docker rm -f claude-gateway >/dev/null 2>&1 || true
env COMPOSE_PROJECT_NAME="$PROJECT_NAME" DOCKER_NETWORK_EXTERNAL=false \
  DOCKER_NETWORK_NAME="$NETWORK_NAME" HOST_IP=127.0.0.1 HOST_PORT=18888 \
  CONFIG_DIR="$TEST_CONFIG_DIR" API_TOKEN=default-secret-token-please-change-me \
  ENABLE_DYNAMIC_ROUTING=false WORKER_PROCESSES=1 \
  docker compose up -d --build >/dev/null

for _ in $(seq 1 60); do
  code="$(curl -sS -o "$OUTPUT_FILE" -w '%{http_code}' "$GATEWAY_URL/health" || true)"
  [[ "$code" == "200" ]] && break
  sleep 1
done

literal_code="$(curl -sS -o "$OUTPUT_FILE" -w '%{http_code}' -X POST "$GATEWAY_URL/openai/responses" -H 'Authorization: Bearer dummy-token' -H 'Content-Type: application/json' -d '{"input":"literal-secret"}')"
[[ "$literal_code" == "403" ]]
grep -F '命中关键词：literal-secret' "$OUTPUT_FILE" >/dev/null

regex_code="$(curl -sS -o "$OUTPUT_FILE" -w '%{http_code}' -X POST "$GATEWAY_URL/openai/responses" -H 'Authorization: Bearer dummy-token' -H 'Content-Type: application/json' -d '{"input":"5.1 本协议服务总价（含税）：￥ 100,000.00"}')"
[[ "$regex_code" == "403" ]]
grep -F '命中内容：服务总价（含税）：￥ 100,000.00' "$OUTPUT_FILE" >/dev/null

plain_code="$(curl -sS -o "$OUTPUT_FILE" -w '%{http_code}' -X POST "$GATEWAY_URL/openai/responses" -H 'Authorization: Bearer dummy-token' -H 'Content-Type: application/json' -d '{"input":"普通讨论：100,000.00 元"}')"
! grep -F '检测到请求中包含敏感信息' "$OUTPUT_FILE" >/dev/null

invalid_code="$(curl -sS -o "$OUTPUT_FILE" -w '%{http_code}' -X POST "$GATEWAY_URL/regex-rules" -H 'X-API-Key: default-secret-token-please-change-me' -H 'Content-Type: application/json' -d '{"id":"invalid-backreference","anchor":"服务总价","expression":"{{anchor}}\\1"}')"
[[ "$invalid_code" == "400" ]]
grep -F '不支持的正则特性' "$OUTPUT_FILE" >/dev/null

echo "anchored regex filtering works"
