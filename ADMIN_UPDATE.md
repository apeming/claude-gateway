# Claude Gateway 管理后台更新说明

## 🎉 新增功能

本次更新为 Claude Gateway 添加了完整的 Web 管理后台系统!

### ✨ 主要特性

#### 1. 飞书 OAuth 登录
- 企业级身份认证
- 安全可靠的单点登录
- 自动获取用户信息

#### 2. 用户角色管理
- **管理员**: 全局管理权限
  - 查看和管理所有关键字
  - 管理路由配置
  - 管理用户角色
- **普通用户**: 个人数据管理
  - 仅查看和管理自己添加的关键字
  - 数据完全隔离

#### 3. 关键字管理
- 可视化界面添加/编辑/删除关键字
- 实时同步到 OpenResty
- 支持批量操作
- 普通用户数据隔离

#### 4. 路由管理(管理员专属)
- Web界面管理动态路由
- 实时生效,无需重启
- 支持路由描述和状态管理

#### 5. 用户管理(管理员专属)
- 查看所有用户列表
- 修改用户角色
- 启用/禁用用户

### 🏗️ 技术架构

```
┌─────────────────────────────────────────┐
│         Docker Container                │
│  ┌────────────┐  ┌────────────┐        │
│  │ OpenResty  │  │  FastAPI   │        │
│  │  (Nginx)   │  │  (Python)  │        │
│  │   :80      │  │   :8000    │        │
│  └────────────┘  └────────────┘        │
│       │                 │               │
│       ├─ React SPA      └─ SQLite DB    │
│       └─ Lua Gateway                    │
└─────────────────────────────────────────┘
```

- **前端**: React 18 + Ant Design 5 + TypeScript
- **后端**: FastAPI + SQLAlchemy + SQLite
- **网关**: OpenResty/Nginx + Lua
- **部署**: Docker + Supervisor

### 📍 路由变更

⚠️ **重要**: 为避免冲突,原业务API路径已调整

| 功能 | 旧路径 | 新路径 |
|------|--------|--------|
| 管理后台前端 | - | `/` |
| 管理后台API | - | `/api/*` |
| Claude API代理 | `/api/*` | `/gateway/*` |
| 健康检查 | `/health` | `/health` |

**迁移示例**:
```bash
# 旧的API调用
curl http://localhost/api/v1/messages

# 新的API调用
curl http://localhost/gateway/v1/messages
```

### 🚀 快速开始

#### 1. 配置飞书应用
```bash
# 访问飞书开放平台创建应用
https://open.feishu.cn/

# 获取 App ID 和 App Secret
# 配置重定向URL: http://localhost/login
```

#### 2. 配置环境变量
```bash
cp .env.example .env

# 编辑 .env 文件
vim .env

# 必须配置:
FEISHU_APP_ID=cli_xxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxx
API_TOKEN=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 32)
```

#### 3. 启动服务
```bash
docker compose build
docker compose up -d
```

#### 4. 访问管理后台
```
http://localhost
```

第一个登录的用户自动成为管理员!

### 📚 文档

- [快速启动指南](./ADMIN_QUICKSTART.md) - 5分钟快速部署
- [完整部署文档](./ADMIN_DEPLOY.md) - 详细配置和故障排查
- [原项目文档](./README.md) - OpenResty网关功能说明

### 🔒 安全建议

生产环境部署前请务必:
1. ✅ 修改 `API_TOKEN` 和 `SECRET_KEY` 为强随机字符串
2. ✅ 使用 HTTPS (配置 Nginx 反向代理 + SSL 证书)
3. ✅ 限制访问 IP (使用防火墙或修改 `HOST_IP`)
4. ✅ 定期备份数据库文件 (`./data/gateway.db`)

### 🎯 使用场景

#### 场景1: 团队协作管理敏感词
- 每个团队成员添加自己负责的敏感词
- 管理员统一审核和管理
- 数据隔离,互不干扰

#### 场景2: 多租户路由管理
- 管理员为不同客户配置独立路由
- 实时生效,无需重启服务
- Web界面可视化管理

#### 场景3: 企业内部部署
- 飞书OAuth企业级认证
- 角色权限精细控制
- 审计日志完整记录

### 🐛 已知问题

无

### 🔄 升级说明

从旧版本升级:
```bash
# 1. 备份数据
docker compose down
cp -r ./data ./data.backup
cp -r ./openresty ./openresty.backup

# 2. 更新代码
git pull

# 3. 更新环境变量(对比 .env.example)
vim .env

# 4. 重新构建
docker compose build --no-cache
docker compose up -d
```

### 📝 更新日志

#### v2.0.0 (2026-01-29)
- ✨ 新增 Web 管理后台
- ✨ 新增飞书 OAuth 登录
- ✨ 新增用户角色管理
- ✨ 新增关键字可视化管理
- ✨ 新增路由可视化管理
- ✨ 新增用户管理功能
- 🔧 API路径调整: `/api` → `/gateway`
- 🔧 集成 FastAPI 后端
- 🔧 集成 React 前端
- 🔧 使用 Supervisor 管理多进程

#### v1.0.0 (2025-10-29)
- ✅ 基于 Aho-Corasick 算法的高性能关键词过滤
- ✅ API Token 鉴权机制
- ✅ 健康检查端点
- ✅ Docker Compose 支持

### 🤝 贡献

欢迎提交 Issue 和 Pull Request!

### 📄 许可证

MIT License
