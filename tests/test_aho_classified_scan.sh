#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

docker compose build claude-gateway >/dev/null

docker run --rm claude-gateway:latest /usr/local/openresty/luajit/bin/luajit -e '
    package.cpath = "/usr/local/openresty/site/lualib/?.so;" .. package.cpath
    local ac = require "ahocorasick"
    local matcher = assert(ac.create({ "literal-secret", "contract-price" }))

    local literal, anchor = ac.scan(matcher, "prefix contract-price suffix", 1)
    assert(literal == nil and anchor == true)

    literal, anchor = ac.scan(matcher, "prefix literal-secret suffix", 1)
    assert(literal == 0 and anchor == nil)

    literal, anchor = ac.scan(matcher, "ordinary text", 1)
    assert(literal == nil and anchor == nil)
'

echo "classified aho-corasick scan works"
