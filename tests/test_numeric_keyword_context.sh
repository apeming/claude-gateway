#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_CONFIG_DIR="$(mktemp -d)"
PROJECT_NAME="cg-numeric-context-$$"
NETWORK_NAME="${PROJECT_NAME}-net"
TEST_CONTAINER_NAME="${PROJECT_NAME}-gateway"
HOST_PORT="$(node -e 'const net = require("net"); const server = net.createServer(); server.listen(0, "127.0.0.1", () => { console.log(server.address().port); server.close(); });')"
GATEWAY_URL="http://127.0.0.1:${HOST_PORT}"
OUTPUT_FILE="$(mktemp)"
COMPOSE_FILES=(-f "$ROOT_DIR/docker-compose.yml" -f "$ROOT_DIR/tests/docker-compose.isolated.yml")

cleanup() {
  status=$?
  if [[ "$status" -ne 0 ]]; then
    env COMPOSE_PROJECT_NAME="$PROJECT_NAME" DOCKER_NETWORK_EXTERNAL=false \
      DOCKER_NETWORK_NAME="$NETWORK_NAME" HOST_IP=127.0.0.1 HOST_PORT="$HOST_PORT" \
      CONFIG_DIR="$TEST_CONFIG_DIR" API_TOKEN=default-secret-token-please-change-me \
      ENABLE_DYNAMIC_ROUTING=false WORKER_PROCESSES=1 TEST_CONTAINER_NAME="$TEST_CONTAINER_NAME" \
      docker compose "${COMPOSE_FILES[@]}" logs --no-color || true
  fi
  env COMPOSE_PROJECT_NAME="$PROJECT_NAME" DOCKER_NETWORK_EXTERNAL=false \
    DOCKER_NETWORK_NAME="$NETWORK_NAME" HOST_IP=127.0.0.1 HOST_PORT="$HOST_PORT" \
    CONFIG_DIR="$TEST_CONFIG_DIR" API_TOKEN=default-secret-token-please-change-me \
    ENABLE_DYNAMIC_ROUTING=false WORKER_PROCESSES=1 TEST_CONTAINER_NAME="$TEST_CONTAINER_NAME" \
    docker compose "${COMPOSE_FILES[@]}" down -v --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEST_CONFIG_DIR" "$OUTPUT_FILE"
}
trap cleanup EXIT

cat >"$TEST_CONFIG_DIR/keywords.txt" <<'EOF'
123
123456
literal-secret
EOF

: >"$TEST_CONFIG_DIR/routes.txt"

request() {
  curl -s -o "$OUTPUT_FILE" -w '%{http_code}' \
    -X POST "$GATEWAY_URL/openai/responses" \
    -H 'Authorization: Bearer dummy-token' \
    -H 'Content-Type: application/json' \
    -d "{\"input\":\"$1\"}" || true
}

assert_blocked() {
  local code
  code="$(request "$1")"
  [[ "$code" == "403" ]]
  grep -F '检测到请求中包含敏感信息' "$OUTPUT_FILE" >/dev/null
}

assert_not_blocked() {
  request "$1" >/dev/null
  ! grep -F '检测到请求中包含敏感信息' "$OUTPUT_FILE" >/dev/null
}

cd "$ROOT_DIR"
env COMPOSE_PROJECT_NAME="$PROJECT_NAME" DOCKER_NETWORK_EXTERNAL=false \
  DOCKER_NETWORK_NAME="$NETWORK_NAME" HOST_IP=127.0.0.1 HOST_PORT="$HOST_PORT" \
  CONFIG_DIR="$TEST_CONFIG_DIR" API_TOKEN=default-secret-token-please-change-me \
  ENABLE_DYNAMIC_ROUTING=false WORKER_PROCESSES=1 TEST_CONTAINER_NAME="$TEST_CONTAINER_NAME" \
  docker compose "${COMPOSE_FILES[@]}" up -d --build >/dev/null

for _ in $(seq 1 60); do
  code="$(curl -s -o "$OUTPUT_FILE" -w '%{http_code}' "$GATEWAY_URL/health" || true)"
  [[ "$code" == "200" ]] && break
  sleep 1
done

assert_blocked 'phone123456'
assert_blocked '+1123456'
assert_blocked '+1 123456'
assert_blocked '1234567'
assert_blocked '12345678'
assert_blocked '999 123456'
assert_blocked '9999123456 then phone123456'
assert_blocked 'literal-secret'

assert_not_blocked '11 123456 22'
assert_not_blocked '9999123456'
assert_not_blocked '123456789'

echo "numeric keyword context filtering works"
