#!/usr/bin/env bash
set -euo pipefail

GATEWAY_URL="${GATEWAY_URL:-http://127.0.0.1:18888}"
AUTH_TOKEN="${AUTH_TOKEN:-cr_0df7284d9b131a044514b5f2ba2b743b6cd1bde840888de5c32f4a29020b9b0f}"
OUTPUT_FILE="$(mktemp)"

cleanup() {
  rm -f "$OUTPUT_FILE"
}

trap cleanup EXIT

HTTP_CODE="$(curl -sS -o "$OUTPUT_FILE" -w "%{http_code}" \
  -X POST "$GATEWAY_URL/openai/responses" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4.1-mini","input":"hello"}')"

BODY="$(cat "$OUTPUT_FILE")"
FIRST_TWO_BYTES="$(head -c 2 "$OUTPUT_FILE" || true)"

[[ "$HTTP_CODE" == "403" ]]

if [[ "$FIRST_TWO_BYTES" == $'\n\n' ]]; then
  echo "❌ 响应体仍以空行开头"
  exit 1
fi

EXPECTED="检测到请求中包含敏感信息，已被安全策略拦截。请先执行 /clear 清理当前会话上下文，避免潜在的信息泄露，然后修改请求内容后重试。命中关键词：hello"
if ! grep -F "$EXPECTED" <<<"$BODY" >/dev/null; then
  echo "❌ 响应体主文案格式不符合预期"
  echo "$BODY"
  exit 1
fi

echo "✅ 403 拦截响应格式正确"
