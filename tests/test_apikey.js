#!/usr/bin/env node

/**
 * Claude Gateway API Key 模式测试脚本
 * 测试 /apikey/v1/messages 接口
 *
 * 环境变量:
 * - ANTHROPIC_AUTH_TOKEN: API Key
 * - ANTHROPIC_MODEL: 模型名称 (默认: claude-sonnet-4-5-20250929)
 * - GATEWAY_URL: 网关地址 (默认: http://127.0.0.1:18888)
 * - API_TOKEN: 管理接口 Token (用于测试关键字过滤)
 */

import Anthropic from '@anthropic-ai/sdk';
import { readFileSync, existsSync } from 'fs';
import { homedir, platform } from 'os';
import { join } from 'path';

/**
 * 获取配置目录
 */
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

/**
 * 从配置文件读取 API_TOKEN
 */
function loadApiTokenFromConfig() {
  try {
    const configDir = getConfigDir();
    const configFile = join(configDir, 'config.json');

    if (existsSync(configFile)) {
      const config = JSON.parse(readFileSync(configFile, 'utf-8'));
      return config.api_token;
    }
  } catch (error) {
    // 忽略错误，返回 null
  }
  return null;
}

// 从环境变量读取配置
const API_KEY = process.env.ANTHROPIC_AUTH_TOKEN;
const GATEWAY_URL = process.env.GATEWAY_URL || 'http://127.0.0.1:18888';
const MODEL = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5-20250929';

// API_TOKEN 优先从环境变量读取，如果没有则从配置文件读取
const API_TOKEN = process.env.API_TOKEN || loadApiTokenFromConfig();

// 检查必需的环境变量
if (!API_KEY) {
  console.error('❌ 错误: 未设置 ANTHROPIC_AUTH_TOKEN 环境变量');
  console.error('');
  console.error('使用方法:');
  console.error('  export ANTHROPIC_AUTH_TOKEN=your-api-key');
  console.error('  export API_TOKEN=your-api-token  # 可选，用于测试关键字过滤');
  console.error('  export GATEWAY_URL=http://127.0.0.1:18888  # 可选');
  console.error('  node test_apikey.js');
  console.error('');
  console.error('注意: API_TOKEN 也可以从配置文件读取 (~/.config/claude-gateway/config.json)');
  process.exit(1);
}

// 创建 Anthropic 客户端，指向 /apikey 端点
const client = new Anthropic({
  apiKey: API_KEY,
  baseURL: GATEWAY_URL + '/apikey',
});

const TEST_KEYWORD = 'test-sensitive-keyword-' + Date.now();

/**
 * 添加关键字
 */
async function addKeyword(keyword) {
  const response = await fetch(`${GATEWAY_URL}/keyword/add?kw=${encodeURIComponent(keyword)}`, {
    method: 'GET',
    headers: {
      'X-API-Key': API_TOKEN,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to add keyword: HTTP ${response.status}`);
  }

  return response.text();
}

/**
 * 删除关键字
 */
async function deleteKeyword(keyword) {
  const response = await fetch(`${GATEWAY_URL}/keyword/del?kw=${encodeURIComponent(keyword)}`, {
    method: 'GET',
    headers: {
      'X-API-Key': API_TOKEN,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to delete keyword: HTTP ${response.status}`);
  }

  return response.text();
}

async function testNonStreaming() {
  console.log('========================================');
  console.log('测试 1: 非流式响应');
  console.log('========================================');
  console.log('');

  try {
    console.log('发送测试消息...');

    const message = await client.messages.create({
      model: MODEL,
      max_tokens: 200,
      messages: [
        {
          role: 'user',
          content: 'Hello! Please respond with a short greeting.',
        },
      ],
    });

    console.log('✅ 请求成功！');
    console.log('');
    console.log('响应内容:');
    console.log('---');
    console.log(message.content[0].text);
    console.log('---');
  } catch (error) {
    console.error('❌ 请求失败！');
    console.error('错误信息:', error.message);
    if (error.status) {
      console.error('HTTP 状态码:', error.status);
    }
    throw error;
  }
}

async function testStreaming() {
  console.log('');
  console.log('========================================');
  console.log('测试 2: 流式响应');
  console.log('========================================');
  console.log('');

  try {
    console.log('发送测试消息（流式）...');

    const stream = await client.messages.create({
      model: MODEL,
      max_tokens: 200,
      stream: true,
      messages: [
        {
          role: 'user',
          content: 'Count from 1 to 5.',
        },
      ],
    });

    console.log('✅ 流式响应开始：');
    console.log('---');

    for await (const event of stream) {
      if (event.type === 'content_block_delta' && event.delta.type === 'text_delta') {
        process.stdout.write(event.delta.text);
      }
    }

    console.log('');
    console.log('---');
    console.log('流式响应完成');
  } catch (error) {
    console.error('❌ 请求失败！');
    console.error('错误信息:', error.message);
    if (error.status) {
      console.error('HTTP 状态码:', error.status);
    }
    throw error;
  }
}

async function testInvalidApiKey() {
  console.log('');
  console.log('========================================');
  console.log('测试 3: 无效的 API Key（预期失败）');
  console.log('========================================');
  console.log('');

  const invalidClient = new Anthropic({
    apiKey: 'invalid-api-key-12345',
    baseURL: GATEWAY_URL + '/apikey',
  });

  try {
    console.log('使用无效 API Key 发送请求...');

    await invalidClient.messages.create({
      model: MODEL,
      max_tokens: 100,
      messages: [
        {
          role: 'user',
          content: 'This should fail.',
        },
      ],
    });

    console.error('❌ 测试失败：应���返回认证错误，但请求成功了');
    throw new Error('Expected authentication error but request succeeded');
  } catch (error) {
    if (error.status === 401 || error.status === 403) {
      console.log('✅ 正确返回认证错误');
      console.log(`   HTTP 状态码: ${error.status}`);
      console.log(`   错误信息: ${error.message}`);
    } else {
      console.error('❌ 返回了非预期的错误');
      console.error(`   HTTP 状态码: ${error.status}`);
      console.error(`   错误信息: ${error.message}`);
      throw error;
    }
  }
}

async function testMissingApiKey() {
  console.log('');
  console.log('========================================');
  console.log('测试 4: 缺少 API Key（预期失败）');
  console.log('========================================');
  console.log('');

  try {
    console.log('不提供 API Key 发送请求...');

    const response = await fetch(`${GATEWAY_URL}/apikey/v1/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 100,
        messages: [
          {
            role: 'user',
            content: 'This should fail.',
          },
        ],
      }),
    });

    if (response.status === 401 || response.status === 403 || response.status === 400) {
      console.log('✅ 正确返回认证错误');
      console.log(`   HTTP 状态码: ${response.status}`);
      const text = await response.text();
      console.log(`   响应内容: ${text.substring(0, 100)}...`);
    } else {
      console.error('❌ 测试失败：应该返回认证错误');
      console.error(`   HTTP 状态码: ${response.status}`);
      throw new Error('Expected authentication error but got: ' + response.status);
    }
  } catch (error) {
    if (error.message.includes('Expected authentication error')) {
      throw error;
    }
    console.error('❌ 请求失败（非预期错误）:', error.message);
    throw error;
  }
}

async function testKeywordFilter() {
  console.log('');
  console.log('========================================');
  console.log('测试 5: 关键字过滤（添加关键字并验证拦截）');
  console.log('========================================');
  console.log('');

  try {
    // 添加关键字
    console.log(`添加测试关键字: ${TEST_KEYWORD}`);
    await addKeyword(TEST_KEYWORD);
    console.log('✅ 关键字添加成功');

    // 等待一小段时间确保关键字生效
    await new Promise(resolve => setTimeout(resolve, 100));

    // 发送包含关键字的请求
    console.log('发送包含关键字的请求...');
    const message = await client.messages.create({
      model: MODEL,
      max_tokens: 100,
      messages: [
        {
          role: 'user',
          content: `This message contains the keyword: ${TEST_KEYWORD}`,
        },
      ],
    });

    // 如果请求成功，说明过滤失败
    console.error('❌ 测试失败：包含关键字的请求应该被拦截');
    throw new Error('Request with keyword should be blocked');
  } catch (error) {
    if (error.status === 403) {
      console.log('✅ 包含关键字的请求被正确拦截');
      console.log(`   HTTP 状态码: ${error.status}`);
    } else if (error.message.includes('should be blocked')) {
      throw error;
    } else {
      console.error('❌ 返回了非预期的错误');
      console.error(`   错误信息: ${error.message}`);
      throw error;
    }
  }
}

async function testKeywordFilterAfterDelete() {
  console.log('');
  console.log('========================================');
  console.log('测试 6: 删除关键字后验证请求通过');
  console.log('========================================');
  console.log('');

  try {
    // 删除关键字
    console.log(`删除测试关键字: ${TEST_KEYWORD}`);
    await deleteKeyword(TEST_KEYWORD);
    console.log('✅ 关键字删除成功');

    // 等待一小段时间确保删除生效
    await new Promise(resolve => setTimeout(resolve, 100));

    // 发送包含已删除关键字的请求
    console.log('发送包含已删除关键字的请求...');
    const message = await client.messages.create({
      model: MODEL,
      max_tokens: 100,
      messages: [
        {
          role: 'user',
          content: `This message contains the deleted keyword: ${TEST_KEYWORD}`,
        },
      ],
    });

    console.log('✅ 请求通过（关键字已删除）');
    console.log(`   响应内容: ${message.content[0].text.substring(0, 50)}...`);
  } catch (error) {
    console.error('❌ 测试失败：删除关键字后请求应该通过');
    console.error('错误信息:', error.message);
    if (error.status) {
      console.error('HTTP 状态码:', error.status);
    }
    throw error;
  }
}

async function testWithUserAgent() {
  console.log('');
  console.log('========================================');
  console.log('测试 7: 使用 Anthropic/JS 0.32.1 User-Agent 头部');
  console.log('========================================');
  console.log('');

  try {
    console.log('发送带有 User-Agent 头部的请求...');

    const response = await fetch(`${GATEWAY_URL}/apikey/v1/messages`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'x-api-key': API_KEY,
        'User-Agent': 'Anthropic/JS 0.32.1',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 200,
        messages: [
          {
            role: 'user',
            content: 'Hello! Please respond with a short greeting.',
          },
        ],
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    }

    const message = await response.json();
    console.log('✅ 请求成功！');
    console.log('');
    console.log('响应内容:');
    console.log('---');
    console.log(message.content[0].text);
    console.log('---');
  } catch (error) {
    console.error('❌ 请求失败！');
    console.error('错误信息:', error.message);
    throw error;
  }
}

async function main() {
  console.log('========================================');
  console.log('Claude Gateway /apikey/v1/messages 接口测试');
  console.log('========================================');
  console.log(`网关地址: ${GATEWAY_URL}/apikey`);
  console.log(`API Key: ${API_KEY}`);
  console.log('');

  let passedTests = 0;
  let totalTests = API_TOKEN ? 7 : 5;
  const failedTests = [];

  // 测试 1: 非流式响应
  try {
    await testNonStreaming();
    passedTests++;
  } catch (error) {
    failedTests.push({ test: '测试 1: 非流式响应', error: error.message });
  }

  // 测试 2: 流式响应
  try {
    await testStreaming();
    passedTests++;
  } catch (error) {
    failedTests.push({ test: '测试 2: 流式响应', error: error.message });
  }

  // 测试 3: 无效的 API Key
  try {
    await testInvalidApiKey();
    passedTests++;
  } catch (error) {
    failedTests.push({ test: '测试 3: 无效的 API Key', error: error.message });
  }

  // 测试 4: 缺少 API Key
  try {
    await testMissingApiKey();
    passedTests++;
  } catch (error) {
    failedTests.push({ test: '测试 4: 缺少 API Key', error: error.message });
  }

  // 测试 5: 使用 Anthropic/JS 0.32.1 User-Agent 头部
  try {
    await testWithUserAgent();
    passedTests++;
  } catch (error) {
    failedTests.push({ test: '测试 5: 使用 Anthropic/JS 0.32.1 User-Agent 头部', error: error.message });
  }

  // 如果提供了 API_TOKEN，测试关键字过滤
  if (API_TOKEN) {
    // 测试 6: 关键字过滤（添加关键字并验证拦截）
    try {
      await testKeywordFilter();
      passedTests++;
    } catch (error) {
      failedTests.push({ test: '测试 6: 关键字过滤', error: error.message });
    }

    // 测试 7: 删除关键字后验证通过
    try {
      await testKeywordFilterAfterDelete();
      passedTests++;
    } catch (error) {
      failedTests.push({ test: '测试 7: 删除关键字后验证请求通过', error: error.message });
    }
  } else {
    console.log('');
    console.log('⚠️  跳过关键字过滤测试（未设置 API_TOKEN）');
  }

  // 尝试清理测试关键字
  if (API_TOKEN) {
    try {
      await deleteKeyword(TEST_KEYWORD);
      console.log('✅ 已清理测试关键字');
    } catch (e) {
      // 忽略清理错误
    }
  }

  console.log('');
  console.log('========================================');
  if (failedTests.length === 0) {
    console.log(`✅ 所有测试通过 (${passedTests}/${totalTests})`);
    console.log('========================================');
  } else {
    console.log(`❌ 部分测试失败 (${passedTests}/${totalTests} 通过)`);
    console.log('========================================');
    console.log('');
    console.log('失败的测试:');
    for (const { test, error } of failedTests) {
      console.log(`  ❌ ${test}`);
      console.log(`     ${error}`);
    }
    console.log('');
    process.exit(1);
  }
}

// 运行测试
main();
