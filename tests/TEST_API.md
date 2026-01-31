# 标准 API 模式测试

## 概述

本测试套件用于验证 Claude Gateway 的标准 API 接口（使用 Authorization 头进行动态路由）。

## API 接口说明

Claude Gateway 提供了标准的 API 接口：

### `/api/v1/messages`

- **路径**: `/api/v1/messages`
- **认证方式**: 使用 `Authorization` 请求头（Bearer token）
- **动态路由**: 根据 Authorization token 在 routes.txt 中查找对应的 upstream
- **特性**:
  - 支持动态路由
  - 支持流式响应
  - 支持非流式响应
  - 支持重试机制

## 测试文件

### 1. `test_api.js`

Node.js 测试脚本，使用 Anthropic SDK 测试 `/api/v1/messages` 接口。

**功能**:
- 测试非流式响应（正常请求）
- 测试流式响应（正常请求）
- 测试无效的 Authorization Token（认证失败）
- 测试缺少 Authorization Token（认证失败）
- 测试关键字过滤（需要 API_TOKEN）
  - 添加关键字
  - 验证包含关键字的请求被拦截
  - 删除关键字
  - 验证删除后请求通过

**环境变量**:
- `ANTHROPIC_AUTH_TOKEN`: 你的 Authorization Token（必需，必须在 routes.txt 中配置）
- `API_TOKEN`: 管理接口 Token（可选，用于测试关键字过滤，从 .env 获取）
- `GATEWAY_URL`: 网关地址（可选，默认: http://127.0.0.1:18888）

**配置**:
- 网关地址: `http://127.0.0.1:18888`
- 测试端点: `/api/v1/messages`

### 2. `package.json`

Node.js 项目配置文件，包含依赖项。

**依赖**:
- `@anthropic-ai/sdk`: Anthropic 官方 Node.js SDK

## 使用方法

### 1. 进入测试目录

```bash
cd tests
```

### 2. 安装依赖

```bash
npm install
```

### 3. 配置路由

确保你的 Authorization Token 已在 `routes.txt` 中配置：

```bash
# 编辑 routes.txt（或通过 API 添加）
echo "your-auth-token https://api.anthropic.com" >> ~/.config/claude-code/routes.txt

# 或使用管理 API
curl -X POST http://127.0.0.1:18888/route/add \
  -H "X-API-Key: your-api-token" \
  -H "Content-Type: application/json" \
  -d '{"token": "your-auth-token", "url": "https://api.anthropic.com"}'
```

### 4. 设置环境变量

```bash
# 基础测试（不包含关键字过滤）
export ANTHROPIC_AUTH_TOKEN=your-auth-token

# 完整测试（包含关键字过滤）
export ANTHROPIC_AUTH_TOKEN=your-auth-token
export API_TOKEN=$(grep API_TOKEN ../.env | cut -d '=' -f2)
```

### 5. 运行测试

```bash
# 方式 1: 使用 npm
npm run test:api

# 方式 2: 直接运行
node test_api.js

# 方式 3: 一行命令
ANTHROPIC_AUTH_TOKEN=your-auth-token node test_api.js
```

## 测试输出示例

```
========================================
Claude Gateway /api/v1/messages 接口测试
========================================
网关地址: http://127.0.0.1:18888/api
Authorization Token: your-auth-token

========================================
测试 1: 非流式响应
========================================

发送测试消息...
✅ 请求成功！

响应内容:
---
Hello! Nice to meet you. How can I help you today?
---

========================================
测试 2: 流式响应
========================================

发送测试消息（流式）...
✅ 流式响应开始：
---
1, 2, 3, 4, 5
---
流式响应完成

========================================
测试 3: 无效的 Authorization Token（预期失败）
========================================

使用无效 Authorization Token 发送请求...
✅ 正确返回认证错误
   HTTP 状态码: 401
   错误信息: Unauthorized

========================================
测试 4: 缺少 Authorization Token（预期失败）
========================================

不提供 Authorization Token 发送请求...
✅ 正确返回认证错误
   HTTP 状态码: 401
   响应内容: {"error":"Unauthorized","message":"Missing authorization token"}...

========================================
✅ 所有测试通过 (4/4)
========================================
```

## 故障排查

### 错误: 未设置 ANTHROPIC_AUTH_TOKEN

```
❌ 错误: 未设置 ANTHROPIC_AUTH_TOKEN 环境变量
```

**解决方法**: 设置环境变量
```bash
export ANTHROPIC_AUTH_TOKEN=your-auth-token
```

### 错误: 401 Unauthorized（使用有效 token）

```
❌ 请求失败！
HTTP 状态码: 401
```

**可能原因**:
1. Token 未在 routes.txt 中配置
2. 动态路由未启用（检查 .env 中的 ENABLE_DYNAMIC_ROUTING）

**解决方法**:
```bash
# 检查路由配置
curl -H "X-API-Key: your-api-token" http://127.0.0.1:18888/route/list

# 添加路由
curl -X POST http://127.0.0.1:18888/route/add \
  -H "X-API-Key: your-api-token" \
  -H "Content-Type: application/json" \
  -d '{"token": "your-auth-token", "url": "https://api.anthropic.com"}'
```

### 错误: 连接失败

```
❌ 请求失败！
错误信息: connect ECONNREFUSED 127.0.0.1:18888
```

**解决方法**: 确保网关服务正在运行
```bash
# 检查服务状态
curl http://127.0.0.1:18888/health

# 如果服务未运行，启动服务
docker compose up -d
```

## 与 API Key 接口的区别

| 特性 | `/api/v1/messages` | `/apikey/v1/messages` |
|------|-------------------|---------------------|
| 认证方式 | Authorization 头（Bearer token） | x-api-key 头 |
| 路由方式 | routes.txt 动态路由 | routes.txt 动态路由 |
| 流式支持 | ✅ | ✅ |
| 重试机制 | ✅ | ✅ |
| 使用场景 | 标准 Claude API 调用 | API Key 直接认证 |

## 配置说明

### 动态路由配置

在 `routes.txt` 中配置 token 到 upstream 的映射：

```
your-auth-token https://api.anthropic.com
another-token https://another-backend.com
```

### 环境变量

确保 `.env` 文件中启用了动态路由：

```bash
ENABLE_DYNAMIC_ROUTING=true
```

## 相关文档

- [测试目录说明](README.md)
- [API Key 模式测试](TEST_APIKEY.md)
- [项目主文档](../README.md)
- [快速启动](../QUICKSTART.md)
