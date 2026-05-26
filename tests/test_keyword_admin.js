#!/usr/bin/env node

import { readFileSync, existsSync } from 'fs';
import { homedir, platform } from 'os';
import { join } from 'path';

function getConfigDir() {
  const home = homedir();
  const sys = platform();

  if (sys === 'darwin') {
    return join(home, 'Library', 'Application Support', 'claude-gateway');
  } else if (sys === 'win32') {
    return join(process.env.APPDATA || join(home, 'AppData', 'Roaming'), 'claude-gateway');
  } else {
    return join(home, '.config', 'claude-gateway');
  }
}

function loadApiTokenFromConfig() {
  try {
    const configDir = getConfigDir();
    const configFile = join(configDir, 'config.json');

    if (existsSync(configFile)) {
      const config = JSON.parse(readFileSync(configFile, 'utf-8'));
      return config.api_token;
    }
  } catch (error) {
    // Ignore config parsing errors and fall back to env vars.
  }

  return null;
}

const API_TOKEN = process.env.API_TOKEN || loadApiTokenFromConfig();
const GATEWAY_URL = process.env.GATEWAY_URL || 'http://127.0.0.1:18888';
const TEST_KEYWORD = `keyword with spaces ${Date.now()}`;
const TEST_KEYWORD_PLUS = `asd+23sd-${Date.now()}`;
const MISSING_KEYWORD_ERROR = 'Missing keyword in request body';
const INVALID_JSON_ERROR = 'Invalid JSON body';

if (!API_TOKEN) {
  console.error('❌ 错误: 未设置 API_TOKEN 环境变量');
  console.error('');
  console.error('使用方法:');
  console.error('  export API_TOKEN=your-api-token');
  console.error('  export GATEWAY_URL=http://127.0.0.1:18888  # 可选');
  console.error('  node test_keyword_admin.js');
  console.error('');
  console.error('注意: API_TOKEN 也可以从配置文件读取 (~/.config/claude-gateway/config.json)');
  process.exit(1);
}

async function keywordRequest(path, options = {}) {
  const response = await fetch(`${GATEWAY_URL}${path}`, {
    method: options.method || 'GET',
    headers: {
      'X-API-Key': API_TOKEN,
      ...(options.headers || {}),
    },
    body: options.body,
  });

  const text = await response.text();
  return {
    status: response.status,
    text: text.trimEnd(),
  };
}

async function addKeyword(keyword) {
  const response = await keywordRequest('/keywords', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ keyword }),
  });

  if (response.status !== 200) {
    throw new Error(`HTTP ${response.status}: ${response.text}`);
  }

  return response.text;
}

async function deleteKeyword(keyword) {
  const response = await keywordRequest('/keywords', {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ keyword }),
  });

  if (response.status !== 200) {
    throw new Error(`HTTP ${response.status}: ${response.text}`);
  }

  return response.text;
}

async function listKeywords() {
  const response = await keywordRequest('/keywords');

  if (response.status !== 200) {
    throw new Error(`HTTP ${response.status}: ${response.text}`);
  }

  return response.text;
}

async function main() {
  console.log('========================================');
  console.log('Claude Gateway 关键字管理接口测试');
  console.log('========================================');
  console.log(`网关地址: ${GATEWAY_URL}`);
  console.log(`测试关键字: ${TEST_KEYWORD}`);
  console.log('');

  try {
    console.log('1. 添加包含空格的关键字...');
    const addResponse = await addKeyword(TEST_KEYWORD);
    const expectedAddResponse = `Keyword added: ${TEST_KEYWORD}`;
    if (addResponse !== expectedAddResponse) {
      throw new Error(`添加响应异常: expected "${expectedAddResponse}", got "${addResponse}"`);
    }
    console.log('✅ 添加响应正确');

    console.log('2. 查看关键字列表...');
    const listResponse = await listKeywords();
    if (!listResponse.includes(TEST_KEYWORD)) {
      throw new Error(`关键字列表未包含原始空格关键字: ${listResponse}`);
    }
    console.log('✅ 列表包含原始空格关键字');

    console.log('3. 重复添加同一个关键字...');
    const duplicateAddResponse = await addKeyword(TEST_KEYWORD);
    const expectedDuplicateAddResponse = `Keyword already exists: ${TEST_KEYWORD}`;
    if (duplicateAddResponse !== expectedDuplicateAddResponse) {
      throw new Error(`重复添加响应异常: expected "${expectedDuplicateAddResponse}", got "${duplicateAddResponse}"`);
    }
    console.log('✅ 重复添加响应正确');

    console.log('4. 添加包含字面 + 的关键字...');
    const addPlusResponse = await addKeyword(TEST_KEYWORD_PLUS);
    const expectedAddPlusResponse = `Keyword added: ${TEST_KEYWORD_PLUS}`;
    if (addPlusResponse !== expectedAddPlusResponse) {
      throw new Error(`字面 + 添加响应异常: expected "${expectedAddPlusResponse}", got "${addPlusResponse}"`);
    }
    console.log('✅ 字面 + 添加响应正确');

    const listWithPlusResponse = await listKeywords();
    if (!listWithPlusResponse.includes(TEST_KEYWORD_PLUS)) {
      throw new Error(`关键字列表未包含字面 + 关键字: ${listWithPlusResponse}`);
    }
    console.log('✅ 列表包含字面 + 关键字');

    console.log('5. 非法 JSON 请求体...');
    const invalidJsonResponse = await keywordRequest('/keywords', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: '{"keyword":',
    });
    if (invalidJsonResponse.status !== 400 || invalidJsonResponse.text !== INVALID_JSON_ERROR) {
      throw new Error(`非法 JSON 响应异常: expected "400 ${INVALID_JSON_ERROR}", got "${invalidJsonResponse.status} ${invalidJsonResponse.text}"`);
    }
    console.log('✅ 非法 JSON 返回正确错误');

    console.log('6. 缺少 keyword 字段...');
    const missingKeywordResponse = await keywordRequest('/keywords', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}),
    });
    if (missingKeywordResponse.status !== 400 || missingKeywordResponse.text !== MISSING_KEYWORD_ERROR) {
      throw new Error(`缺少 keyword 响应异常: expected "400 ${MISSING_KEYWORD_ERROR}", got "${missingKeywordResponse.status} ${missingKeywordResponse.text}"`);
    }
    console.log('✅ 缺少 keyword 返回正确错误');

    console.log('7. 删除包含空格的关键字...');
    const deleteResponse = await deleteKeyword(TEST_KEYWORD);
    const expectedDeleteResponse = `Keyword deleted: ${TEST_KEYWORD}`;
    if (deleteResponse !== expectedDeleteResponse) {
      throw new Error(`删除响应异常: expected "${expectedDeleteResponse}", got "${deleteResponse}"`);
    }
    console.log('✅ 删除响应正确');

    const listAfterDeleteResponse = await listKeywords();
    if (listAfterDeleteResponse.includes(TEST_KEYWORD)) {
      throw new Error(`删除后列表仍包含关键字: ${listAfterDeleteResponse}`);
    }
    console.log('✅ 删除后列表已移除原始空格关键字');

    console.log('8. 删除包含字面 + 的关键字...');
    const deletePlusResponse = await deleteKeyword(TEST_KEYWORD_PLUS);
    const expectedDeletePlusResponse = `Keyword deleted: ${TEST_KEYWORD_PLUS}`;
    if (deletePlusResponse !== expectedDeletePlusResponse) {
      throw new Error(`字面 + 删除响应异常: expected "${expectedDeletePlusResponse}", got "${deletePlusResponse}"`);
    }
    console.log('✅ 字面 + 删除响应正确');

    const listAfterDeletePlusResponse = await listKeywords();
    if (listAfterDeletePlusResponse.includes(TEST_KEYWORD_PLUS)) {
      throw new Error(`删除字面 + 关键字后列表仍包含该关键字: ${listAfterDeletePlusResponse}`);
    }
    console.log('✅ 删除后列表已移除字面 + 关键字');

    console.log('9. 删除不存在的关键字...');
    const deleteMissingResponse = await deleteKeyword(TEST_KEYWORD_PLUS);
    const expectedDeleteMissingResponse = `Keyword not exists: ${TEST_KEYWORD_PLUS}`;
    if (deleteMissingResponse !== expectedDeleteMissingResponse) {
      throw new Error(`删除不存在关键字响应异常: expected "${expectedDeleteMissingResponse}", got "${deleteMissingResponse}"`);
    }
    console.log('✅ 删除不存在的关键字响应正确');

    console.log('');
    console.log('========================================');
    console.log('✅ 关键字管理接口测试通过');
    console.log('========================================');
  } finally {
    try {
      await deleteKeyword(TEST_KEYWORD);
    } catch (error) {
      // Ignore cleanup failures.
    }

    try {
      await deleteKeyword(TEST_KEYWORD_PLUS);
    } catch (error) {
      // Ignore cleanup failures.
    }
  }
}

main().catch((error) => {
  console.error('');
  console.error('❌ 测试失败');
  console.error(error.message);
  process.exit(1);
});
