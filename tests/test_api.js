#!/usr/bin/env node

/**
 * Claude Gateway 标准 API 模式测试脚本
 * 测试 /api/v1/messages 接口（使用 Authorization 头进行动态路由）
 *
 * 环境变量:
 * - ANTHROPIC_AUTH_TOKEN: Authorization Token (routes.txt 中配置的 token)
 * - ANTHROPIC_MODEL: 模型名称 (默认: claude-sonnet-4-5-20250929)
 * - GATEWAY_URL: 网关地址 (默认: http://127.0.0.1:18888)
 * - API_TOKEN: 管理接口 Token (用于测试关键字过滤)
 */

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
const AUTH_TOKEN = process.env.ANTHROPIC_AUTH_TOKEN;
const GATEWAY_URL = process.env.GATEWAY_URL || 'http://127.0.0.1:18888';
const MODEL = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5-20250929';

// API_TOKEN 优先从环境变量读取，如果没有则从配置文件读取
const API_TOKEN = process.env.API_TOKEN || loadApiTokenFromConfig();

// 检查必需的环境变量
if (!AUTH_TOKEN) {
  console.error('❌ 错误: 未设置 ANTHROPIC_AUTH_TOKEN 环境变量');
  console.error('');
  console.error('使用方法:');
  console.error('  export ANTHROPIC_AUTH_TOKEN=your-auth-token');
  console.error('  export API_TOKEN=your-api-token  # 可选，用于测试关键字过滤');
  console.error('  export GATEWAY_URL=http://127.0.0.1:18888  # 可选');
  console.error('  node test_api.js');
  console.error('');
  console.error('注意: AUTH_TOKEN 必须在 routes.txt 中配置');
  console.error('注意: API_TOKEN 也可以从配置文件读取 (~/.config/claude-gateway/config.json)');
  process.exit(1);
}

const API_URL = `${GATEWAY_URL}/api/v1/messages`;
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

/**
 * 发送 API 请求
 */
async function sendRequest(body, headers = {}) {
  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      'Authorization': `Bearer ${AUTH_TOKEN}`,
      'x-api-key': AUTH_TOKEN,
      ...headers,
    },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const error = new Error(`HTTP ${response.status}`);
    error.status = response.status;
    error.response = await response.text();
    throw error;
  }

  return response.json();
}

async function testNonStreaming() {
  console.log('========================================');
  console.log('测试 1: 非流式响应');
  console.log('========================================');
  console.log('');

  try {
    console.log('发送测试消息...');

    const message = await sendRequest({
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
    if (error.response) {
      console.error('响应内容:', error.response.substring(0, 200));
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

    const response = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'Authorization': `Bearer ${AUTH_TOKEN}`,
        'x-api-key': AUTH_TOKEN,
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 200,
        stream: true,
        messages: [
          {
            role: 'user',
            content: 'Count from 1 to 5.',
          },
        ],
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    }

    console.log('✅ 流式响应开始：');
    console.log('---');

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() || '';

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6);
          if (data === '[DONE]') continue;

          try {
            const event = JSON.parse(data);
            if (event.type === 'content_block_delta' && event.delta?.type === 'text_delta') {
              process.stdout.write(event.delta.text);
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
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

async function testInvalidAuthToken() {
  console.log('');
  console.log('========================================');
  console.log('测试 3: 无效的 Authorization Token（预期失败）');
  console.log('========================================');
  console.log('');

  try {
    console.log('使用无效 Authorization Token 发送请求...');

    const response = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'Authorization': 'Bearer invalid-auth-token-12345',
        'x-api-key': 'invalid-auth-token-12345',
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

    if (response.status === 401 || response.status === 403) {
      console.log('✅ 正确返回认证错误');
      console.log(`   HTTP 状态码: ${response.status}`);
      const text = await response.text();
      console.log(`   错误信息: ${text.substring(0, 100)}`);
    } else {
      console.error('❌ 测试失败：应该返回认证错误，但请求成功了');
      throw new Error('Expected authentication error but request succeeded');
    }
  } catch (error) {
    if (error.message.includes('Expected authentication error')) {
      throw error;
    }
    console.error('❌ 返回了非预期的错误');
    console.error(`   错误信息: ${error.message}`);
    throw error;
  }
}

async function testMissingAuthToken() {
  console.log('');
  console.log('========================================');
  console.log('测试 4: 缺少 Authorization Token（预期失败）');
  console.log('========================================');
  console.log('');

  try {
    console.log('不提供 Authorization Token 发送请求...');

    const response = await fetch(API_URL, {
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
    const response = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
        'Authorization': `Bearer ${AUTH_TOKEN}`,
        'x-api-key': AUTH_TOKEN,
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 100,
        messages: [
          {
            role: 'user',
            content: `This message contains the keyword: ${TEST_KEYWORD}`,
          },
        ],
      }),
    });

    if (response.status === 403) {
      console.log('✅ 包含关键字的请求被正确拦截');
      console.log(`   HTTP 状态码: ${response.status}`);
    } else {
      console.error('❌ 测试失败：包含关键字的请求应该被拦截');
      console.error(`   HTTP 状态码: ${response.status}`);
      throw new Error('Request with keyword should be blocked');
    }
  } catch (error) {
    if (error.message.includes('should be blocked')) {
      throw error;
    }
    console.error('❌ 返回了非预期的错误');
    console.error(`   错误信息: ${error.message}`);
    throw error;
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
    const message = await sendRequest({
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

async function main() {
  console.log('========================================');
  console.log('Claude Gateway /api/v1/messages 接口测试');
  console.log('========================================');
  console.log(`网关地址: ${API_URL}`);
  console.log(`Authorization Token: ${AUTH_TOKEN}`);
  console.log('');

  let passedTests = 0;
  let totalTests = API_TOKEN ? 6 : 4;

  try {
    // 测试 1: 非流式响应
    await testNonStreaming();
    passedTests++;

    // 测试 2: 流式响应
    await testStreaming();
    passedTests++;

    // 测试 3: 无效的 Authorization Token
    await testInvalidAuthToken();
    passedTests++;

    // 测试 4: 缺少 Authorization Token
    await testMissingAuthToken();
    passedTests++;

    // 如果提供了 API_TOKEN，测试关键字过滤
    if (API_TOKEN) {
      // 测试 5: 关键字过滤（添加关键字并验证拦截）
      await testKeywordFilter();
      passedTests++;

      // 测试 6: 删除关键字后验证通过
      await testKeywordFilterAfterDelete();
      passedTests++;
    } else {
      console.log('');
      console.log('⚠️  跳过关键字过滤测试（未设置 API_TOKEN）');
    }

    console.log('');
    console.log('========================================');
    console.log(`✅ 所有测试通过 (${passedTests}/${totalTests})`);
    console.log('========================================');
  } catch (error) {
    console.log('');
    console.log('========================================');
    console.log(`❌ 测试失败 (${passedTests}/${totalTests} 通过)`);
    console.log('========================================');

    // 尝试清理测试关键字
    if (API_TOKEN) {
      try {
        await deleteKeyword(TEST_KEYWORD);
        console.log('✅ 已清理测试关键字');
      } catch (e) {
        // 忽略清理错误
      }
    }

    process.exit(1);
  }
}

// 运行测试
main();
