# API Key 模式测试

## 概述

本测试套件用于验证 Claude Gateway 的 API Key 模式接口功能和安全性。

## API 接口说明

Claude Gateway 提供了专门的 API Key 接口：

### `/apikey/v1/messages`

- **路径**: `/apikey/v1/messages`
- **认证方式**: 使用 `x-api-key` 请求头
- **特性**:
  - 支持 API Key 认证
  - 支持流式响应
  - 支持非流式响应

## 测试文件

### 1. `test_apikey.js`

Node.js 测试脚本，使用 Anthropic SDK 测试 `/apikey/v1/messages` 接口。

**功能**:
- 测试非流式响应（正常请求）
- 测试流式响应（正常请求）
- 测试无效的 API Key（认证失败）
- 测试缺少 API Key（认证失败）
- 测试关键字过滤（需要 API_TOKEN）
  - 添加关键字
  - 验证包含关键字的请求被拦截
  - 删除关键字
  - 验证删除后请求通过

**环境变量**:
- `ANTHROPIC_AUTH_TOKEN`: 你的 API Key（必需）
- `API_TOKEN`: 管理接口 Token（可选，用于测试关键字过滤，从 .env 获取）
- `GATEWAY_URL`: 网关地址（可选，默认: http://127.0.0.1:18888）

**配置**:
- 网关地址: `http://127.0.0.1:18888`
- 测试端点: `/apikey/v1/messages`

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

### 3. 设置环境变量

```bash
# 基础测试（不包含关键字过滤）
export ANTHROPIC_AUTH_TOKEN=your-api-key

# 完整测试（包含关键字过滤）
export ANTHROPIC_AUTH_TOKEN=your-api-key
export API_TOKEN=$(grep API_TOKEN ../.env | cut -d '=' -f2)
```

### 4. 运行测试

```bash
# 方式 1: 使用 npm
npm test

# 方式 2: 直接运行
node test_apikey.js

# 方式 3: 一行命令
ANTHROPIC_AUTH_TOKEN=your-api-key node test_apikey.js
```

## 测试输出示例

```
========================================
Claude Gateway /apikey/v1/messages 接口测试
========================================
网关地址: http://127.0.0.1:18888/apikey
API Key: sk-ant-xxxxx

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
测试 3: 无效的 API Key（预期失败）
========================================

使用无效 API Key 发送请求...
✅ 正确返回认证错误
   HTTP 状态码: 401
   错误信息: Unauthorized

========================================
测试 4: 缺少 API Key（预期失败）
========================================

不提供 API Key 发送请求...
✅ 正确返回认证错误
   HTTP 状态码: 401
   响应内容: {"error":"Unauthorized","message":"Missing API key"}...

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
export ANTHROPIC_AUTH_TOKEN=your-api-key
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

### 错误: 401 Unauthorized

```
❌ 请求失败！
HTTP 状态码: 401
```

**解决方法**: 检查 API Key 是否正确
- 确认 API Key 有效
- 检查网关配置是否正确

## 与标准接口的区别

| 特性 | `/api/v1/messages` | `/apikey/v1/messages` |
|------|-------------------|---------------------|
| 认证方式 | Authorization 头（routes.txt 路由） | x-api-key 头 |
| 流式支持 | ✅ | ✅ |
| 重试机制 | ✅ | ✅ |
| 使用场景 | 动态路由模式 | API Key 直接认证 |

## 配置说明

### 当前配置

- **服务地址**: `http://127.0.0.1:18888`
- **服务端口**: `18888`
- **绑定地址**: `127.0.0.1` (仅本地访问)
- **动态路由**: 已启用
- **配置目录**: `~/.config/claude-code`

### 修改配置

编辑 `.env` 文件:

```bash
# 修改端口
HOST_PORT=8080

# 修改绑定地址（允许外部访问）
HOST_IP=0.0.0.0

# 重启服务
docker compose restart
```

## 相关文档

- [测试目录说明](README.md)
- [项目主文档](../README.md)
- [快速启动](../QUICKSTART.md)
