# 测试套件

本目录包含 Claude Gateway 的测试代码。

## 目录结构

```
tests/
├── README.md                   # 本文件
├── TEST_APIKEY.md              # API Key 模式测试文档
├── TEST_API.md                 # 标准 API 模式测试文档
├── test_openai.js              # OpenAI 兼容接口测试脚本
├── test_apikey.js              # API Key 模式测试脚本
├── test_api.js                 # 标准 API 模式测试脚本
└── package.json                # Node.js 依赖配置
```

## 快速开始

### 1. 安装依赖

```bash
cd tests
npm install
```

### 2. 运行测试

#### API Key 模式测试

```bash
# 基础测试（不包含关键字过滤）
export ANTHROPIC_AUTH_TOKEN=your-api-key
npm run test:apikey

# 完整测试（包含关键字过滤）
# 方式 1: 使用环境变量
export ANTHROPIC_AUTH_TOKEN=your-api-key
export API_TOKEN=your-api-token
npm run test:apikey

# 方式 2: 使用配置文件（推荐）
# 先使用 keywords 工具配置，然后直接运行
export ANTHROPIC_AUTH_TOKEN=your-api-key
npm run test:apikey
```

#### 标准 API 模式测试

```bash
# 基础测试（不包含关键字过滤）
export ANTHROPIC_AUTH_TOKEN=your-auth-token
npm run test:api

# 完整测试（包含关键字过滤）
# 方式 1: 使用环境变量
export ANTHROPIC_AUTH_TOKEN=your-auth-token
export API_TOKEN=your-api-token
npm run test:api

# 方式 2: 使用配置文件（推荐）
# 先使用 keywords 工具配置，然后直接运行
export ANTHROPIC_AUTH_TOKEN=your-auth-token
npm run test:api
```

#### 运行所有测试

```bash
export ANTHROPIC_AUTH_TOKEN=your-token
export API_TOKEN=your-api-token
npm test
```

#### OpenAI 兼容接口测试

```bash
export OPENAI_AUTH_TOKEN=your-openai-token
export GATEWAY_URL=http://127.0.0.1:18888
npm run test:openai
```

#### 自定义网关地址

```bash
export GATEWAY_URL=http://localhost:8080
export ANTHROPIC_AUTH_TOKEN=your-token
npm run test:apikey
```

#### 自定义模型

```bash
# 使用不同的模型进行测试
export ANTHROPIC_MODEL=claude-opus-4-5-20251101
export ANTHROPIC_AUTH_TOKEN=your-token
npm run test:apikey
```

## 测试列表

### 1. API Key 模式测试 (`test_apikey.js`)

测试 `/apikey/v1/messages` 接口，包括：
- ✅ 非流式响应（正常请求）
- ✅ 流式响应（正常请求）
- ✅ 无效的 API Key（认证失败）
- ✅ 缺少 API Key（认证失败）
- ✅ 关键字过滤（添加→拦截→删除→通过）*需要 API_TOKEN*

**认证方式**: x-api-key 头
**详细文档**: [TEST_APIKEY.md](TEST_APIKEY.md)

### 2. 标准 API 模式测试 (`test_api.js`)

测试 `/api/v1/messages` 接口，包括：
- ✅ 非流式响应（正常请求）
- ✅ 流式响应（正常请求）
- ✅ 无效的 Authorization Token（认证失败）
- ✅ 缺少 Authorization Token（认证失败）
- ✅ 关键字过滤（添加→拦截→删除→通过）*需要 API_TOKEN*

**认证方式**: Authorization 头（Bearer token）
**动态路由**: 需要在 routes.txt 中配置
**详细文档**: [TEST_API.md](TEST_API.md)

### 3. OpenAI 兼容接口测试 (`test_openai.js`)

测试 `/openai/*` 和 `/openai/v1/*` 接口，包括：
- ✅ `/openai/v1/models` 模型列表
- ✅ `/openai/responses` 非流式响应
- ✅ `/openai/v1/responses` 非流式响应

**认证方式**: Authorization 头（Bearer token）
**详细用途**: 验证 OpenAI 路径改写和代理转发

## 测试覆盖

- ✅ 功能测试：验证正常请求流程
- ✅ 安全测试：验证认证机制
- ✅ 错误处理：验证错误响应
- ✅ 流式响应：验证流式传输
- ✅ 动态路由：验证路由机制
- ✅ 关键字过滤：验证敏感内容拦截

## 环境变量

| 变量 | 用途 | 必需 | 说明 |
|------|------|------|------|
| `ANTHROPIC_AUTH_TOKEN` | API Key 或 Auth Token | ✅ | 用于业务请求 |
| `OPENAI_AUTH_TOKEN` | OpenAI Bearer Token | OpenAI 测试必需 | 用于 `/openai*` 业务请求 |
| `ANTHROPIC_MODEL` | 模型名称 | ❌ | 默认: claude-sonnet-4-5-20250929 |
| `OPENAI_MODEL` | OpenAI 模型名称 | ❌ | 默认: gpt-5.4 |
| `API_TOKEN` | 管理接口 Token | ❌ | 用于测试关键字过滤，优先从环境变量读取，否则从配置文件读取 |
| `GATEWAY_URL` | 网关地址 | ❌ | 默认: http://127.0.0.1:18888 |

## 关键字过滤测试

关键字过滤测试已集成到两个主测试脚本中。`API_TOKEN` 的获取顺序：

1. **环境变量** - `export API_TOKEN=your-token`
2. **配置文件** - `~/.config/claude-gateway/config.json`

如果找到 `API_TOKEN`，测试将自动包含关键字过滤功能：

1. 添加测试关键字
2. 发送包含关键字的请求（验证被拦截）
3. 删除测试关键字
4. 发送包含已删除关键字的请求（验证通过）

**配置文件示例** (`~/.config/claude-gateway/config.json`):
```json
{
  "api_base_url": "http://localhost:18888",
  "api_token": "your-api-token-here"
}
```

**使用 tools 配置**:
```bash
# 使用 keywords 工具配置（会自动创建配置文件）
cd ../tools
./keywords config
```

## 环境要求

- Node.js >= 18.0.0
- npm 或 yarn
- 运行中的 Claude Gateway 服务

## 相关文档

- [主文档](../README.md)
- [快速启动](../QUICKSTART.md)
