#!/usr/bin/env node

import assert from 'node:assert/strict';

const GATEWAY_URL = process.env.GATEWAY_URL || 'http://127.0.0.1:18888';

async function main() {
  const response = await fetch(`${GATEWAY_URL}/health`);
  assert.equal(response.status, 200, 'health should return 200');

  const body = await response.json();
  assert.equal(body.status, 'healthy');
  assert.equal(typeof body.keyword_version, 'number');
  assert.equal(typeof body.keywords_loaded, 'number');
  assert.equal(typeof body.keywords_status, 'string');
  assert.equal(typeof body.keywords_last_loaded_at, 'string');
  assert.equal(typeof body.keywords_load_error, 'string');

  console.log('health metadata contract is valid');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
