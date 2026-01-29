# Claude Gateway 管理后台 - 快速启动

## 5分钟快速部署

### 1. 配置飞书应用(2分钟)

1. 访问 https://open.feishu.cn/ 创建企业自建应用
2. 记录 `App ID` 和 `App Secret`
3. 配置重定向URL: `http://localhost/login`
4. 开启"网页"能力,添加权限: 获取用户基本信息、获取用户邮箱

### 2. 配置环境变量(1分钟)

```bash
cp .env.example .env
vim .env
```

修改以下配置:
```bash
# 生成随机token
API_TOKEN=$(openssl rand -base64 32)
SECRET_KEY=$(openssl rand -base64 32)

# 填入飞书配置
FEISHU_APP_ID=cli_xxxxxxxxxx
FEISHU_APP_SECRET=xxxxxxxxxxxxxx
FEISHU_REDIRECT_URI=http://localhost/login
```

### 3. 启动服务(2分钟)

```bash
# 构建并启动
docker compose up -d

# 查看日志
docker compose logs -f
```

### 4. 访问管理后台

1. 打开浏览器访问: http://localhost
2. 点击"飞书登录"
3. 完成授权后,第一个登录的用户自动成为管理员

## 功能概览

### 管理员功能
- ✅ 查看和管理所有关键字
- ✅ 管理路由配置
- ✅ 管理用户(修改角色、启用/禁用)

### 普通用户功能
- ✅ 添加和管理自己的关键字
- ✅ 查看自己添加的关键字列表

## API路径变更

⚠️ **重要**: 原业务API路径已从 `/api` 改为 `/gateway`

```bash
# 旧路径(不再使用)
curl http://localhost/api/v1/messages

# 新路径
curl http://localhost/gateway/v1/messages
```

## 路由说明

- `/` - 管理后台前端
- `/api/*` - 管理后台API
- `/gateway/*` - Claude API代理(关键字过滤)
- `/health` - 健康检查

## 常用命令

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 重新构建
docker compose build --no-cache
docker compose up -d
```

## 故障排查

### 飞书登录失败
- 检查 `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET`
- 确认重定向URL配置正确
- 确认飞书应用已发布

### 无法访问管理后台
- 检查容器是否正常运行: `docker compose ps`
- 查看日志: `docker compose logs`
- 确认端口80未被占用

### 数据库错误
```bash
# 进入容器检查
docker exec -it claude-gateway sh
ls -la /app/data/
```

## 详细文档

完整部署文档请参考: [ADMIN_DEPLOY.md](./ADMIN_DEPLOY.md)

## 下一步

1. 添加更多管理员: 在"用户管理"页面修改用户角色
2. 配置关键字: 在"关键字管理"页面添加敏感词
3. 配置路由: 在"路由管理"页面添加动态路由(需要管理员权限)

## 安全提示

⚠️ 生产环境部署前请务必:
1. 修改 `API_TOKEN` 和 `SECRET_KEY` 为强随机字符串
2. 使用HTTPS(配置Nginx反向代理+SSL证书)
3. 限制访问IP(使用防火墙或修改 `HOST_IP`)
4. 定期备份数据库文件
