# Claude Gateway

基于 OpenResty/Nginx + Lua 的高性能 Claude API 网关，提供关键词过滤、请求代理和 API 管理功能。

## 🛡️ 关键词过滤功能

本网关的核心功能是**关键词过滤**，专门用于防止敏感信息泄露到第三方AI服务器：

- **前缀匹配**：取敏感信息（API密钥、令牌、密码等）的前N位作为关键词进行匹配
- **实时拦截保护**：当检测到请求包含配置的关键词时，立即阻止请求转发
- **安全响应机制**：返回安全提示并建议用户执行 `/clear` 指令清除上下文，避免信息污染
- **高性能算法**：使用 Aho-Corasick 算法，确保关键词匹配的高效性

**典型使用场景**：
```bash
# 配置敏感信息前缀作为关键词
sk-123456          # OpenAI API Key 前缀
ghp_1a2b3c         # GitHub Token 前缀
eyJhbGciOiJIUzI1   # JWT Token 前缀

# 当用户请求包含这些前缀时，系统会自动拦截并提示
```

## ✨ 特性

- 🚀 **高性能关键词过滤**: 使用 Aho-Corasick 算法，O(m) 时间复杂度，支持敏感信息前缀匹配保护
- 🔐 **API 鉴权保护**: 支持 API Token 认证，保护管理接口
- 🎯 **动态路由**: 基于 Authorization 头智能路由到不同上游服务，支持多租户和多后端管理
- 🔄 **请求代理**: 透明代理 Claude API 请求
- 🛠️ **命令行管理工具**: 提供便捷的CLI工具管理关键字
- 📊 **JSON 日志**: 结构化日志，便于分析和监控
- 🏥 **健康检查**: 内置健康检查端点，支持容器编排
- 🐳 **容器化部署**: 完整的 Docker/Docker Compose 支持

## 📁 项目结构

```
claude-gateway/
├── docker-compose.yml       # Docker Compose 配置
├── .env.example             # 环境变量模板
├── .gitignore               # Git 忽略规则
├── Makefile                 # 便捷命令工具
├── README.md                # 项目文档（本文件）
├── QUICKSTART.md            # 快速启动指南
├── tools/                   # 关键字管理工具
│   ├── keywords             # CLI工具执行脚本
│   ├── keywords.py          # Python CLI实现
│   ├── install.sh           # 安装脚本
│   ├── requirements.txt     # Python依赖
│   ├── sample-keywords.txt  # 示例关键字文件
│   └── README.md            # 工具使用说明
└── openresty/               # OpenResty 相关文件
    ├── Dockerfile           # Docker 镜像构建
    ├── nginx.conf           # Nginx 配置
    ├── keywords.txt         # 关键词配置文件
    └── routes.txt           # 路由配置文件
```

## 🚀 快速开始

### 1. 环境准备

```bash
# 克隆或进入项目目录
cd claude-gateway

# 复制环境变量配置文件
cp .env.example .env

# 编辑 .env 文件，设置你的 API Token
vim .env
```

### 2. 生成安全的 API Token

```bash
# 使用 openssl 生成随机 token
openssl rand -base64 32

# 或使用 make 命令
make token

# 将生成的 token 填入 .env 文件的 API_TOKEN 变量
```

### 3. 启动服务

```bash
# 方式1: 使用 docker compose
docker compose up -d

# 方式2: 使用 Makefile（推荐）
make deploy
```

### 4. 验证服务

```bash
# 健康检查
curl http://localhost/health

# 或使用 make 命令
make health
```

## 📖 配置说明

### 环境变量

在 `.env` 文件中配置以下变量：

| 变量名 | 说明 | 默认值 | 必须 |
|--------|------|--------|------|
| `API_TOKEN` | API 鉴权 Token | `default-secret-token...` | ✅ 是 |
| `ENABLE_DYNAMIC_ROUTING` | 是否启用动态路由 | `false` | ❌ 否 |
| `UPSTREAM_URL` | 上游服务地址（默认模式使用） | `https://api.anthropic.com` | ❌ 否 |
| `HOST_PORT` | 主机端口映射 | `80` | ❌ 否 |
| `CONFIG_DIR` | 配置目录（宿主机，包含配置文件） | `./openresty` | ❌ 否 |
| `DOCKER_NETWORK_NAME` | Docker 网络名称 | `claude-gateway-network` | ❌ 否 |
| `DOCKER_NETWORK_DRIVER` | Docker 网络驱动 | `bridge` | ❌ 否 |
| `DOCKER_NETWORK_EXTERNAL` | 是否使用外部网络 | `false` | ❌ 否 |

### 配置文件

配置目录默认为 `./openresty`，包含以下配置文件：

- **keywords.txt** - 关键词过滤配置，每行一个关键词
- **routes.txt** - 路由配置（启用动态路由时使用），每行格式：`<token> <upstream_url>`

**关键词文件示例（keywords.txt）：**

```text
sensitive-word-1
sensitive-word-2
bad-content
```

**路由配置文件示例（routes.txt）：**

```text
cr_1 http://backend1.example.com/api
cr_2 http://backend2.example.com/claude-api
cr_3 http://backend3.example.com
```

**自定义配置目录：**

```bash
# 在 .env 文件中配置
CONFIG_DIR=/path/to/your/config

# 或直接在命令行指定
CONFIG_DIR=/path/to/your/config docker compose up -d
```

### 动态路由配置

网关支持基于 `Authorization` 头的动态路由，将不同的 token 路由到不同的上游服务。支持两种工作模式，通过 `ENABLE_DYNAMIC_ROUTING` 环境变量控制。

#### 工作模式

**模式 1：启用动态路由（严格模式）**

当 `ENABLE_DYNAMIC_ROUTING=true` 时：
- ✅ 必须提供 `Authorization` 头
- ✅ Token 必须在 `routes.txt` 中配置
- ✅ 从路由文件读取配置并路由到对应后端
- ❌ 未匹配的 token 返回 401 错误
- ℹ️ `UPSTREAM_URL` 配置被忽略

**模式 2：默认模式（无需认证）**

当 `ENABLE_DYNAMIC_ROUTING=false` 时（默认）：
- ✅ 无需 `Authorization` 认证
- ✅ 所有请求使用 `UPSTREAM_URL` 配置
- ℹ️ `routes.txt` 文件被忽略

#### 路由配置文件

**文件路径：** `openresty/routes.txt`（容器内：`/etc/openresty/routes.txt`）

**文件格式：** 每行一个路由规则，格式为 `<token> <upstream_url>`（空格分隔）

```text
cr_1 http://backend1.example.com/api
cr_2 http://backend2.example.com/claude-api
cr_3 http://backend3.example.com
```

**格式要求：**
- 严格两字段格式：token 和 URL，空格分隔
- 不支持注释
- 不允许多余字段
- 空行自动忽略

#### 路径替换规则

**重要约定：**
- 所有客户端请求必须使用 `/api/*` 路径格式
- 网关会将请求中的 `/api` 前缀替换为 upstream 配置的 base_path
- 查询参数会自动保留

**转换示例：**

| 用户请求 | Token | Upstream 配置 | 实际转发 |
|---------|-------|--------------|---------|
| `/api/v1/messages` | cr_1 | `http://1.1.1.1/api` | `http://1.1.1.1/api/v1/messages` |
| `/api/v1/messages` | cr_2 | `http://2.2.2.2/api/claude` | `http://2.2.2.2/api/claude/v1/messages` |
| `/api/v1/messages` | cr_3 | `http://3.3.3.3` | `http://3.3.3.3/v1/messages` |
| `/api/health?check=true` | cr_1 | `http://1.1.1.1/api` | `http://1.1.1.1/api/health?check=true` |

#### 配置示例

**1. 启用动态路由：**

```bash
# .env 文件配置
ENABLE_DYNAMIC_ROUTING=true
API_TOKEN=your-management-api-token

# routes.txt 文件配置
cr_1 http://backend1.example.com/api
cr_2 http://backend2.example.com/claude-api
cr_3 http://backend3.example.com
```

**2. 默认模式（无需认证）：**

```bash
# .env 文件配置
ENABLE_DYNAMIC_ROUTING=false
UPSTREAM_URL=https://api.anthropic.com
```

#### 使用示例

**启用动态路由时的请求：**

```bash
# 使用 cr_1 token - 路由到 backend1
curl -X POST http://localhost/api/v1/messages \
  -H "Authorization: Bearer cr_1" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4-5-20250929", "messages": [{"role": "user", "content": "Hello"}]}'

# 使用 cr_2 token - 路由到 backend2
curl -X POST http://localhost/api/v1/messages \
  -H "Authorization: cr_2" \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4-5-20250929", "messages": [{"role": "user", "content": "Hello"}]}'

# 使用无效 token - 返回 401
curl -X POST http://localhost/api/v1/messages \
  -H "Authorization: invalid_token" \
  -H "Content-Type: application/json" \
  -d '{...}'
```

**默认模式下的请求（无需 Authorization）：**

```bash
curl -X POST http://localhost/api/v1/messages \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4-5-20250929", "messages": [{"role": "user", "content": "Hello"}]}'
```

**错误响应：**

```json
{
  "error": "Unauthorized",
  "message": "Invalid authorization token",
  "timestamp": "2025-11-12 10:30:45"
}
```

#### 动态路由管理 API

网关提供 RESTful API 接口管理路由配置，支持实时增删改查，无需重启服务。

**所有管理接口都需要 API Token 认证：**

```bash
# 使用 X-API-Key 头
curl -H "X-API-Key: your-token" http://localhost/route/list

# 或使用 Authorization 头
curl -H "Authorization: Bearer your-token" http://localhost/route/list
```

**1. 查看所有路由**

```bash
GET /route/list

# 请求示例
curl -H "X-API-Key: your-token" http://localhost/route/list

# 响应示例
{
  "routes": [
    {"token": "cr_1", "url": "http://backend1.example.com/api"},
    {"token": "cr_2", "url": "http://backend2.example.com/claude-api"}
  ],
  "count": 2,
  "timestamp": "2025-11-12 10:30:45"
}
```

**2. 添加路由**

```bash
POST /route/add
Content-Type: application/json

{
  "token": "cr_new",
  "url": "http://new-backend.example.com/api"
}

# 请求示例
curl -X POST http://localhost/route/add \
  -H "X-API-Key: your-token" \
  -H "Content-Type: application/json" \
  -d '{"token": "cr_new", "url": "http://new-backend.example.com/api"}'

# 响应示例
{
  "success": true,
  "message": "Route added successfully",
  "token": "cr_new",
  "url": "http://new-backend.example.com/api"
}
```

**3. 删除路由**

```bash
POST /route/del
Content-Type: application/json

{
  "token": "cr_old"
}

# 请求示例
curl -X POST http://localhost/route/del \
  -H "X-API-Key: your-token" \
  -H "Content-Type: application/json" \
  -d '{"token": "cr_old"}'

# 响应示例
{
  "success": true,
  "message": "Route deleted successfully",
  "token": "cr_old"
}
```

**4. 更新路由**

```bash
POST /route/update
Content-Type: application/json

{
  "token": "cr_1",
  "url": "http://updated-backend.example.com/api"
}

# 请求示例
curl -X POST http://localhost/route/update \
  -H "X-API-Key: your-token" \
  -H "Content-Type: application/json" \
  -d '{"token": "cr_1", "url": "http://updated-backend.example.com/api"}'

# 响应示例
{
  "success": true,
  "message": "Route updated successfully",
  "token": "cr_1",
  "url": "http://updated-backend.example.com/api"
}
```

**5. 重新加载路由配置**

```bash
POST /route/reload

# 请求示例
curl -X POST http://localhost/route/reload \
  -H "X-API-Key: your-token"

# 响应示例
{
  "success": true,
  "message": "Routes reloaded successfully",
  "loaded": 3,
  "errors": 0
}
```

#### 应用场景

- **多租户系统**：不同客户路由到不同的后端服务，每个租户使用独立的 base_path
- **路径隔离**：不同 token 访问后端服务的不同路径空间（如 `/api` vs `/api/claude`）
- **负载均衡**：手动分配不同用户到不同服务器实例
- **A/B 测试**：部分用户路由到新版本服务的测试路径
- **服务隔离**：VIP 用户和普通用户使用不同的服务实例或路径前缀
- **API 版本管理**：不同客户端版本路由到不同的 API 版本路径

## 🔌 API 接口

### 1. 健康检查（无需鉴权）

```bash
GET /health
```

**响应示例：**
```json
{
  "status": "healthy",
  "service": "claude-gateway",
  "timestamp": "2025-10-29 11:30:45",
  "keywords_loaded": 2,
  "keyword_version": 1,
  "auth_configured": true
}
```

### 2. 业务接口（无需鉴权）

```bash
POST /
Content-Type: application/json

{
  "model": "claude-sonnet-4-5-20250929",
  "messages": [{"role": "user", "content": "Hello"}]
}
```

### 3. 查看关键词（需要鉴权）

```bash
GET /keyword/list
X-API-Key: your-token-here
```

**响应示例：**
```text
Keywords: word1, word2, word3
```

### 4. 添加关键词（需要鉴权）

```bash
GET /keyword/add?kw=badword
X-API-Key: your-token-here
```

**响应示例：**
```text
Keyword added: badword
```

### 5. 删除关键词（需要鉴权）

```bash
GET /keyword/del?kw=badword
X-API-Key: your-token-here
```

**响应示例：**
```text
Keyword deleted: badword
```

### 6. 查看所有路由（需要鉴权）

```bash
GET /route/list
X-API-Key: your-token-here
```

**响应示例：**
```json
{
  "routes": [
    {"token": "cr_1", "url": "http://backend1.example.com/api"},
    {"token": "cr_2", "url": "http://backend2.example.com/claude-api"}
  ],
  "count": 2,
  "timestamp": "2025-11-12 10:30:45"
}
```

### 7. 添加路由（需要鉴权）

```bash
POST /route/add
X-API-Key: your-token-here
Content-Type: application/json

{
  "token": "cr_new",
  "url": "http://new-backend.example.com/api"
}
```

**响应示例：**
```json
{
  "success": true,
  "message": "Route added successfully",
  "token": "cr_new",
  "url": "http://new-backend.example.com/api"
}
```

### 8. 删除路由（需要鉴权）

```bash
POST /route/del
X-API-Key: your-token-here
Content-Type: application/json

{
  "token": "cr_old"
}
```

**响应示例：**
```json
{
  "success": true,
  "message": "Route deleted successfully",
  "token": "cr_old"
}
```

### 9. 更新路由（需要鉴权）

```bash
POST /route/update
X-API-Key: your-token-here
Content-Type: application/json

{
  "token": "cr_1",
  "url": "http://updated-backend.example.com/api"
}
```

**响应示例：**
```json
{
  "success": true,
  "message": "Route updated successfully",
  "token": "cr_1",
  "url": "http://updated-backend.example.com/api"
}
```

### 10. 重新加载路由配置（需要鉴权）

```bash
POST /route/reload
X-API-Key: your-token-here
```

**响应示例：**
```json
{
  "success": true,
  "message": "Routes reloaded successfully",
  "loaded": 3,
  "errors": 0
}
```

## 🔐 鉴权方式

支持三种请求头格式：

```bash
# 方式1: X-API-Key 头
curl -H "X-API-Key: your-token" http://localhost/keyword/list

# 方式2: Authorization Bearer 头
curl -H "Authorization: Bearer your-token" http://localhost/keyword/list

# 方式3: Authorization 头（无 Bearer）
curl -H "Authorization: your-token" http://localhost/keyword/list
```

## 🛠️ 关键字管理CLI工具

为了方便管理关键字，项目提供了专用的命令行工具，支持批量操作和脚本自动化。

### 快速安装

```bash
# 进入工具目录
cd tools/

# 自动安装（推荐）
./install.sh

# 或手动安装依赖
pip3 install -r requirements.txt
```

### 基本使用

```bash
# 配置API连接（首次使用）
keywords config

# 检查服务状态
keywords status

# 添加关键字
keywords add "sensitive-word"

# 删除关键字
keywords del "sensitive-word"

# 列出所有关键字
keywords list

# 从文件批量导入
keywords import sample-keywords.txt

# 导出到文件
keywords export backup.txt
```

### 批量管理示例

```bash
# 备份现有关键字
keywords export backup-$(date +%Y%m%d).txt

# 批量添加关键字
for word in "spam" "malware" "phishing"; do
    keywords add "$word"
done

# 从文件导入新的关键字列表
keywords import new-keywords.txt
```

> 📚 详细使用说明请参考：[tools/README.md](tools/README.md)

## 🛠️ 常用命令

### Docker Compose 命令

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 重启服务
docker compose restart

# 查看日志
docker compose logs -f

# 查看服务状态
docker compose ps

# 重新构建镜像
docker compose build --no-cache

# 更新并重启服务
docker compose up -d --build
```

### Makefile 命令（推荐）

```bash
# 查看所有命令
make help

# 一键部署
make deploy

# 查看服务状态
make ps

# 查看实时日志
make logs

# 检查健康状态
make health

# 生成随机 token
make token

# 进入容器 shell
make shell

# 重启服务
make restart

# 停止服务
make down

# 完全清理
make clean
```

## 🔧 高级配置

### 持久化配置目录

配置目录通过 `CONFIG_DIR` 环境变量配置，默认挂载 `./openresty` 目录到容器的 `/etc/openresty`：

```yaml
volumes:
  - ${CONFIG_DIR:-./openresty}:/etc/openresty
```

**配置目录包含：**
- `keywords.txt` - 关键词过滤配置
- `routes.txt` - 路由配置（启用动态路由时使用）

**使用自定义配置目录：**

```bash
# 方式1: 在 .env 文件中配置
CONFIG_DIR=/path/to/your/config

# 方式2: 命令行指定
CONFIG_DIR=/path/to/your/config docker compose up -d
```

**配置文件格式：**

`keywords.txt`：
```text
sensitive-word-1
sensitive-word-2
api-key-prefix
```

`routes.txt`：
```text
cr_1 http://backend1.example.com/api
cr_2 http://backend2.example.com/claude-api
cr_3 http://backend3.example.com
```

**配置热加载：**
- **关键词**：通过 `/keyword/add`、`/keyword/del` API 动态管理，修改立即生效
- **路由**：通过 `/route/add`、`/route/update`、`/route/del` API 动态管理，或通过 `/route/reload` API 重新加载文件
- 修改宿主机上的配置文件会自动同步到容器内

## 🔍 关键词过滤功能详解

### 核心功能

本系统提供强大的关键词过滤机制，可有效防止敏感信息被意外发送到第三方服务器。当检测到请求内容包含配置的关键词时，系统会立即拦截请求并返回错误响应。

### 敏感信息前缀保护

针对敏感信息（如 API 密钥、令牌、密码等），推荐使用**前缀匹配**策略：

#### 配置示例

```bash
# 获取敏感信息的前 8-12 位作为关键词
# 原始 API Key: sk-1234567890abcdef...
# 关键词配置: sk-123456

# 示例关键词文件 (keywords.txt)
sk-123456          # API Key 前缀
ghp_1a2b3c         # GitHub Token 前缀
AIza4f7h9k         # Google API Key 前缀
xoxb-123456        # Slack Bot Token 前缀
```

#### 使用建议

| 敏感信息类型 | 推荐前缀长度 | 示例关键词 | 说明 |
|-------------|-------------|-----------|------|
| API Keys | 8-10 位 | `sk-123456` | OpenAI API Key 前缀 |
| GitHub Tokens | 10-12 位 | `ghp_1a2b3c` | GitHub Personal Token |
| 数据库连接串 | 10-15 位 | `mongodb://user:pass@` | 包含协议和认证信息 |
| JWT Tokens | 15-20 位 | `eyJhbGciOiJIUzI1NiI` | JWT Header 部分 |
| 私钥文件 | 10-15 位 | `-----BEGIN RSA` | PEM 格式开头 |

### 工作原理

1. **请求拦截**: 所有发往上游服务的请求都会经过关键词检查
2. **内容扫描**: 使用 Aho-Corasick 算法快速匹配请求体中的关键词
3. **即时拦截**: 发现匹配关键词时立即阻止请求转发
4. **安全响应**: 返回通用错误信息，不暴露具体的敏感内容

### 配置最佳实践

#### 1. 敏感信息梳理
```bash
# 定期审查系统中的敏感信息
- API 密钥和令牌
- 数据库连接字符串
- 私钥和证书
- 用户密码和认证信息
- 内部系统地址和端口
```

#### 2. 关键词策略
```bash
# 平衡安全性和可用性
- 前缀长度：8-15 字符（过短误报，过长失效）
- 覆盖范围：包含所有可能的敏感信息类型
- 更新频率：敏感信息变更时及时更新关键词
```

#### 3. 动态管理
```bash
# 使用 CLI 工具快速管理
keywords add "new-sensitive-prefix"
keywords del "old-prefix"
keywords list | grep "pattern"
```

### 安全响应机制

当检测到敏感关键词时，系统会：

1. **阻止请求转发** - 请求不会到达上游服务器
2. **记录安全事件** - 在日志中记录拦截事件（不记录敏感内容）
3. **返回通用错误** - 返回标准错误响应，不泄露被拦截的具体原因

#### 关于上下文污染和清除

当系统检测到敏感信息并拦截请求时，强烈建议用户执行 `/clear` 指令清除对话上下文，原因如下：

1. **防止上下文泄露**: 敏感信息可能已经出现在当前对话上下文中
2. **避免后续风险**: 后续的对话可能无意中引用或重复敏感内容
3. **重新开始**: 清除上下文后重新组织请求，确保不包含敏感信息
4. **安全最佳实践**: 这是处理敏感信息意外暴露的标准安全做法

**操作步骤:**
```bash
# 1. 收到拦截提示后，立即执行清除指令
/clear

# 2. 重新组织你的请求，确保移除所有敏感信息
# 3. 重新发送清理后的请求
```

### Docker 网络配置

#### 1. 默认网络模式（Bridge）

```bash
# 使用默认配置
docker compose up -d
```

#### 2. 自定义网络名称

```bash
# 修改 .env 文件
DOCKER_NETWORK_NAME=my-custom-network

# 或直接指定
DOCKER_NETWORK_NAME=my-custom-network docker compose up -d
```

#### 3. 使用现有外部网络

```bash
# 首先创建外部网络（如果不存在）
docker network create my-external-network

# 配置使用外部网络
DOCKER_NETWORK_NAME=my-external-network
DOCKER_NETWORK_EXTERNAL=true
docker compose up -d
```

#### 4. Host 网络模式

```bash
# 使用 host 网络模式（性能最佳，但失去网络隔离）
docker compose -f docker-compose.yml -f docker-compose.host.yml up -d
```

#### 5. 不同网络驱动

```bash
# 使用 overlay 网络（适用于 Docker Swarm）
DOCKER_NETWORK_DRIVER=overlay docker compose up -d

# 使用 macvlan 网络（直接分配 MAC 地址）
DOCKER_NETWORK_DRIVER=macvlan docker compose up -d
```

#### 6. 自定义端口

```bash
# 修改主机端口
HOST_PORT=8080 docker compose up -d

# 服务将在 http://localhost:8080 可用
```

#### 网络配置示例

**连接到现有的微服务网络：**
```bash
# .env 配置
DOCKER_NETWORK_NAME=microservices-network
DOCKER_NETWORK_EXTERNAL=true
HOST_PORT=80
```

**Docker Swarm 集群部署：**
```bash
# .env 配置
DOCKER_NETWORK_NAME=swarm-overlay
DOCKER_NETWORK_DRIVER=overlay
DOCKER_NETWORK_EXTERNAL=true
```

**开发环境隔离：**
```bash
# .env 配置
DOCKER_NETWORK_NAME=claude-gateway-dev
DOCKER_NETWORK_DRIVER=bridge
HOST_PORT=8080
```

### 查看容器内日志

```bash
# 进入容器
docker exec -it claude-gateway sh

# 查看 Nginx 访问日志
tail -f /usr/local/openresty/nginx/logs/access.log

# 查看 Nginx 错误日志
tail -f /usr/local/openresty/nginx/logs/error.log
```

### 资源限制

在 `docker-compose.yml` 中已配置资源限制：

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
```

根据实际需求调整。

## 🌐 生产部署建议

### 1. 使用反向代理（HTTPS）

```nginx
# Nginx 反向代理配置
server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2. Kubernetes 部署

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: claude-gateway-secret
type: Opaque
stringData:
  api-token: your-secret-token

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: claude-gateway
spec:
  replicas: 3
  selector:
    matchLabels:
      app: claude-gateway
  template:
    metadata:
      labels:
        app: claude-gateway
    spec:
      containers:
      - name: claude-gateway
        image: claude-gateway:latest
        ports:
        - containerPort: 80
        env:
        - name: API_TOKEN
          valueFrom:
            secretKeyRef:
              name: claude-gateway-secret
              key: api-token
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 10
        resources:
          limits:
            cpu: 1000m
            memory: 512Mi
          requests:
            cpu: 500m
            memory: 256Mi

---
apiVersion: v1
kind: Service
metadata:
  name: claude-gateway
spec:
  selector:
    app: claude-gateway
  ports:
  - port: 80
    targetPort: 80
  type: ClusterIP
```

### 3. 监控集成

#### Prometheus

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'claude-gateway'
    metrics_path: '/health'
    static_configs:
      - targets: ['localhost:80']
```

#### 日志分析

```bash
# 使用 jq 解析 JSON 日志
docker compose logs -f | jq '.remote_addr, .status, .request'

# 统计状态码分布
docker compose logs --no-color | jq -r '.status' | sort | uniq -c
```

## 🐛 故障排查

### 服务无法启动

```bash
# 查看详细日志
docker compose logs

# 检查端口占用
lsof -i :80

# 验证配置文件
docker compose config

# 检查 Docker 版本
docker --version
docker compose version
```

### 关键词过滤不生效

```bash
# 检查关键词是否加载
curl http://localhost/health | jq '.keywords_loaded'

# 查看关键词列表
curl -H "X-API-Key: token" http://localhost/keyword/list

# 检查容器内文件
docker exec claude-gateway cat /etc/openresty/keywords.txt
```

### 鉴权失败

```bash
# 确认 token 配置
docker exec claude-gateway env | grep API_TOKEN

# 测试不同的请求头格式
curl -v -H "X-API-Key: token" http://localhost/keyword/list

# 查看 Nginx 错误日志
docker exec claude-gateway tail /usr/local/openresty/nginx/logs/error.log
```

### 容器健康检查失败

```bash
# 查看健康检查状态
docker inspect claude-gateway | jq '.[0].State.Health'

# 手动测试健康检查
docker exec claude-gateway wget -O- http://localhost/health

# 查看详细日志
docker compose logs --tail=50
```

## 📊 性能优化

### 1. 增加 Worker 进程

编辑 `openresty/nginx.conf`:

```nginx
worker_processes auto;  # 改为自动（基于CPU核心数）
```

### 2. 调整连接数

```nginx
events {
    worker_connections 2048;  # 增加连接数
}
```

### 3. 启用 Gzip 压缩

```nginx
http {
    gzip on;
    gzip_types application/json text/plain;
    gzip_min_length 1000;
}
```

## 🔒 安全建议

1. ✅ **必须设置强密码 API_TOKEN**（至少 32 字符）
2. ✅ **生产环境使用 HTTPS**（通过反向代理）
3. ✅ **定期轮换 API Token**
4. ✅ **使用防火墙限制访问**
5. ✅ **启用日志审计**
6. ✅ **定期更新镜像和依赖**
7. ✅ **不要将 .env 文件提交到版本控制**

## 📚 相关文档

- [快速启动指南](QUICKSTART.md) - 3 分钟快速上手
- [Nginx 配置](openresty/nginx.conf) - 详细的配置文件
- [Dockerfile](openresty/Dockerfile) - 镜像构建说明

## 📝 更新日志

### v1.0.0 (2025-10-29)

- ✅ 基于 Aho-Corasick 算法的高性能关键词过滤
- ✅ API Token 鉴权机制
- ✅ 健康检查端点
- ✅ Docker Compose 支持
- ✅ 完整的文档和示例

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

## 📧 联系方式

如有问题或建议，请提交 Issue。
