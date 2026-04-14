#!/usr/bin/env node

/**
 * Claude Gateway OpenAI 兼容接口测试脚本
 *
 * 环境变量:
 * - OPENAI_AUTH_TOKEN: OpenAI Bearer Token
 * - OPENAI_MODEL: OpenAI 模型名称 (默认: gpt-5.4)
 * - GATEWAY_URL: 网关地址 (默认: http://127.0.0.1:18888)
 */

const OPENAI_AUTH_TOKEN = process.env.OPENAI_AUTH_TOKEN;
const GATEWAY_URL = process.env.GATEWAY_URL || 'http://127.0.0.1:18888';
const OPENAI_MODEL = process.env.OPENAI_MODEL || 'gpt-5.4';

if (!OPENAI_AUTH_TOKEN) {
  console.error('❌ 错误: 未设置 OPENAI_AUTH_TOKEN 环境变量');
  console.error('');
  console.error('使用方法:');
  console.error('  export OPENAI_AUTH_TOKEN=your-openai-token');
  console.error('  export GATEWAY_URL=http://127.0.0.1:18888  # 可选');
  console.error('  export OPENAI_MODEL=gpt-5.4  # 可选');
  console.error('  node test_openai.js');
  process.exit(1);
}

const OPENAI_URL = `${GATEWAY_URL}/openai`;
const OPENAI_V1_URL = `${GATEWAY_URL}/openai/v1`;

async function readJson(response) {
  const text = await response.text();
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function testListModels() {
  console.log('========================================');
  console.log('测试 1: /openai/v1/models 列表接口');
  console.log('========================================');
  console.log('');

  const response = await fetch(`${OPENAI_V1_URL}/models`, {
    headers: {
      'Authorization': `Bearer ${OPENAI_AUTH_TOKEN}`,
    },
  });

  const payload = await readJson(response);

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${typeof payload === 'string' ? payload : JSON.stringify(payload)}`);
  }

  if (!payload || !Array.isArray(payload.data)) {
    throw new Error('模型列表响应格式不正确');
  }

  console.log(`✅ 请求成功，返回 ${payload.data.length} 个模型`);
}

async function testResponsesPath(baseUrl, pathLabel) {
  console.log('');
  console.log('========================================');
  console.log(`测试 2: ${pathLabel} 非流式响应`);
  console.log('========================================');
  console.log('');

  const response = await fetch(`${baseUrl}/responses`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_AUTH_TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      input: 'Please reply with exactly: gateway-ok',
      stream: false,
    }),
  });

  const payload = await readJson(response);

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${typeof payload === 'string' ? payload : JSON.stringify(payload)}`);
  }

  console.log('✅ 请求成功');
  if (typeof payload === 'object' && payload && typeof payload.output_text === 'string') {
    console.log(`   output_text: ${payload.output_text.substring(0, 80)}`);
  }
}

async function main() {
  console.log('========================================');
  console.log('Claude Gateway OpenAI 兼容接口测试');
  console.log('========================================');
  console.log(`网关地址: ${GATEWAY_URL}`);
  console.log(`OpenAI 端点: ${OPENAI_URL}`);
  console.log(`OpenAI v1 端点: ${OPENAI_V1_URL}`);
  console.log(`模型: ${OPENAI_MODEL}`);
  console.log('');

  const failedTests = [];

  try {
    await testListModels();
  } catch (error) {
    failedTests.push({ test: '测试 1: /openai/v1/models', error: error.message });
  }

  try {
    await testResponsesPath(OPENAI_URL, '/openai/responses');
  } catch (error) {
    failedTests.push({ test: '测试 2: /openai/responses', error: error.message });
  }

  try {
    await testResponsesPath(OPENAI_V1_URL, '/openai/v1/responses');
  } catch (error) {
    failedTests.push({ test: '测试 3: /openai/v1/responses', error: error.message });
  }

  console.log('');
  console.log('========================================');
  if (failedTests.length === 0) {
    console.log('✅ 所有 OpenAI 兼容测试通过 (3/3)');
  } else {
    console.log(`❌ 部分 OpenAI 兼容测试失败 (${3 - failedTests.length}/3 通过)`);
    console.log('');
    console.log('失败的测试:');
    for (const { test, error } of failedTests) {
      console.log(`  ❌ ${test}`);
      console.log(`     ${error}`);
    }
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('❌ 测试执行失败:', error);
  process.exit(1);
});
