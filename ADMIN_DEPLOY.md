# Claude Gateway 管理后台部署文档

## 概述

本项目为 Claude Gateway 添加了完整的管理后台系统,支持:
- 飞书OAuth登录
- 用户角色管理(管理员/普通用户)
- 关键字管理(用户隔离)
- 路由管理(仅管理员)
- 用户管理(仅管理员)

## 架构说明

### 技术栈
- **前端**: React 18 + Ant Design 5 + TypeScript + Vite
- **后端**: Python FastAPI + SQLAlchemy + SQLite
- **网关**: OpenResty/Nginx + Lua
- **部署**: Docker + Supervisor(多进程管理)

### 服务架构
```
┌─────────────────────────────────────────┐
│         Docker Container                │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │      Supervisor                  │  │
│  │  ┌────────────┐  ┌────────────┐ │  │
│  │  │ OpenResty  │  │  FastAPI   │ │  │
│  │  │  (Nginx)   │  │  (Python)  │ │  │
│  │  │   :80      │  │   :8000    │ │  │
│  │  └────────────┘  └────────────┘ │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  Static Files (React Build)      │  │
│  │  /usr/local/openresty/nginx/html │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │  SQLite Database                 │  │
│  │  /app/data/gateway.db            │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

### 路由说明
- `/` - 管理后台前端(React SPA)
- `/api/*` - 管理后台API(FastAPI)
- `/gateway/*` - 原业务API(Claude API代理,关键字过滤)
- `/health` - 健康检查

## 部署步骤

### 1. 配置飞书应用

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 创建企业自建应用
3. 获取 `App ID` 和 `App Secret`
4. 配置重定向URL: `http://your-domain/login`
5. 开启"网页"能力,添加权限:
   - 获取用户基本信息
   - 获取用户邮箱

### 2. 配置环境变量

复制环境变量模板:
```bash
cp .env.example .env
```

编辑 `.env` 文件,配置以下关键参数:

```bash
# API Token(用于原有的关键字/路由管理API)
API_TOKEN=your-super-secret-token-32chars

# JWT密钥(用于管理后台认证)
SECRET_KEY=your-jwt-secret-key-32chars

# 飞书OAuth配置
FEISHU_APP_ID=cli_xxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxx
FEISHU_REDIRECT_URI=http://your-domain/login

# 数据库路径(默认即可)
DATABASE_URL=sqlite+aiosqlite:////app/data/gateway.db

# 其他配置保持默认或根据需要调整
ENABLE_DYNAMIC_ROUTING=false
UPSTREAM_URL=https://api.anthropic.com
HOST_PORT=80
```

### 3. 构建和启动

```bash
# 构建镜像
docker compose build

# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f
```

### 4. 首次登录

1. 访问 `http://your-domain`
2. 点击"飞书登录"
3. 完成飞书OAuth授权
4. **第一个登录的用户自动成为管理员**
5. 后续用户默认为普通用户,管理员可在用户管理页面修改角色

## 功能说明

### 用户角色

#### 管理员(admin)
- 查看和管理所有关键字
- 管理路由配置
- 管理用户(修改角色、启用/禁用)

#### 普通用户(user)
- 仅查看和管理自己添加的关键字
- 无法访问路由管理和用户管理

### 关键字管理

- 添加关键字后自动同步到 `/etc/openresty/keywords.txt`
- OpenResty实时加载,无需重启
- 普通用户只能看到自己添加的关键字
- 管理员可以看到所有关键字

### 路由管理(仅管理员)

- 添加/修改/删除路由后自动同步到 `/etc/openresty/routes.txt`
- 支持动态路由功能
- 需要设置 `ENABLE_DYNAMIC_ROUTING=true` 才生效

### 数据持久化

以下数据会持久化到宿主机:
- 数据库: `./data/gateway.db`
- 配置文件: `./openresty/keywords.txt`, `./openresty/routes.txt`

## API文档

启动服务后访问:
- Swagger UI: `http://your-domain/api/docs`
- ReDoc: `http://your-domain/api/redoc`

## 故障排查

### 1. 飞书登录失败

检查:
- `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET` 是否正确
- `FEISHU_REDIRECT_URI` 是否与飞书后台配置一致
- 飞书应用是否已发布并开启"网页"能力

### 2. 数据库错误

```bash
# 进入容器
docker exec -it claude-gateway sh

# 检查数据库文件
ls -la /app/data/

# 查看FastAPI日志
tail -f /var/log/supervisord.log
```

### 3. 前端无法访问

检查:
- Nginx配置是否正确
- 前端构建产物是否存在: `/usr/local/openresty/nginx/html/`

### 4. API请求失败

检查:
- FastAPI是否正常运行: `curl http://localhost:8000/health`
- Nginx代理配置是否正确

## 升级说明

### 从旧版本升级

1. 备份数据:
```bash
docker compose down
cp -r ./data ./data.backup
cp -r ./openresty ./openresty.backup
```

2. 更新代码:
```bash
git pull
```

3. 更新环境变量:
```bash
# 对比 .env.example 和 .env,添加新的配置项
```

4. 重新构建和启动:
```bash
docker compose build --no-cache
docker compose up -d
```

## 安全建议

1. **生产环境必须修改**:
   - `API_TOKEN`: 至少32字符随机字符串
   - `SECRET_KEY`: 至少32字符随机字符串

2. **使用HTTPS**:
   - 生产环境建议使用Nginx反向代理并配置SSL证书
   - 修改 `FEISHU_REDIRECT_URI` 为 `https://` 开头

3. **限制访问**:
   - 使用防火墙限制80端口访问
   - 配置 `HOST_IP=127.0.0.1` 仅允许本地访问

4. **定期备份**:
   - 定期备份 `./data/gateway.db`
   - 定期备份配置文件

## 开发说明

### 本地开发

#### 后端开发
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

#### 前端开发
```bash
cd frontend
npm install
npm run dev
```

### 目录结构
```
claude-gateway/
├── backend/              # Python后端
│   ├── app/
│   │   ├── models/      # 数据库模型
│   │   ├── routers/     # API路由
│   │   ├── services/    # 业务逻辑
│   │   ├── utils/       # 工具函数
│   │   ├── config.py    # 配置
│   │   ├── database.py  # 数据库连接
│   │   ├── schemas.py   # Pydantic模型
│   │   └── main.py      # 应用入口
│   └── requirements.txt
├── frontend/            # React前端
│   ├── src/
│   │   ├── api/        # API调用
│   │   ├── components/ # 组件
│   │   ├── pages/      # 页面
│   │   ├── types/      # TypeScript类型
│   │   ├── utils/      # 工具函数
│   │   ├── App.tsx
│   │   └── main.tsx
│   ├── package.json
│   └── vite.config.ts
├── openresty/          # OpenResty配置
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── supervisord.conf
│   ├── keywords.txt
│   └── routes.txt
├── docker-compose.yml
└── .env.example
```

## 常见问题

### Q: 如何添加新的管理员?
A: 管理员登录后,在"用户管理"页面将目标用户的角色改为"管理员"。

### Q: 普通用户能看到其他用户的关键字吗?
A: 不能。普通用户只能看到和管理自己添加的关键字。

### Q: 如何重置管理员密码?
A: 本系统使用飞书OAuth登录,无需密码。如需重置管理员,可直接修改数据库。

### Q: 数据库可以换成MySQL/PostgreSQL吗?
A: 可以。修改 `DATABASE_URL` 环境变量并安装对应的Python驱动即可。

### Q: 前端可以自定义主题吗?
A: 可以。修改 `frontend/src/App.tsx` 中的 `ConfigProvider` 配置。

## 联系支持

如有问题,请提交Issue到项目仓库。
