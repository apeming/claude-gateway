# 快速启动指南

## 🚀 3 分钟快速部署

### 1️⃣ 准备环境变量

```bash
# 进入项目根目录
cd claude-gateway

# 复制环境变量模板
cp .env.example .env

# 生成安全的 API Token
openssl rand -base64 32

# 编辑 .env 文件，填入生成的 token
vim .env
```

### 2️⃣ 启动服务

```bash
# 方式1: 使用 docker compose
docker compose up -d

# 方式2: 使用 Makefile（推荐）
make deploy
```

### 3️⃣ 验证服务

```bash
# 检查健康状态
curl http://localhost/health

# 或使用 make 命令
make health
```

## 📝 常用命令速查

```bash
# 查看服务状态
make ps

# 查看实时日志
make logs

# 重启服务
make restart

# 进入容器
make shell

# 生成新 token
make token

# 停止服务
make down

# 完全清理
make clean
```

## 🔐 API 使用示例

```bash
# 替换 YOUR_TOKEN 为你的实际 token
export API_TOKEN="YOUR_TOKEN"

# 查看关键词元数据
curl -H "X-API-Key: $API_TOKEN" http://localhost/keywords

# 添加关键词
curl -X POST \
  -H "X-API-Key: $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"keyword":"badword"}' \
  http://localhost/keywords

# 删除关键词
curl -X DELETE \
  -H "X-API-Key: $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"keyword":"badword"}' \
  http://localhost/keywords
```

## ❓ 常见问题

### 端口被占用？

```bash
# 检查哪个程序占用了 80 端口
lsof -i :80

# 方式1: 停止占用 80 端口的程序
# 方式2: 修改 docker-compose.yml 中的端口映射
# 将 "80:80" 改为 "8080:80"（宿主机8080端口映射到容器80端口）
```

### 忘记 token？

```bash
# 查看容器环境变量
docker exec claude-gateway env | grep API_TOKEN
```

### 服务无法访问？

```bash
# 检查容器状态
docker ps

# 查看日志
make logs

# 检查健康状态
curl -v http://localhost/health
```

## 📚 更多信息

详细文档请查看 [README.md](README.md)
