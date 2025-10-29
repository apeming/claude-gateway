# Claude Gateway

基于 OpenResty/Nginx + Lua 的高性能 Claude API 网关，提供关键词过滤、请求代理和 API 管理功能。

## ✨ 特性

- 🚀 **高性能关键词过滤**: 使用 Aho-Corasick 算法，O(m) 时间复杂度
- 🔐 **API 鉴权保护**: 支持 API Token 认证，保护管理接口
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
    └── nginx.conf           # Nginx 配置
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
| `UPSTREAM_URL` | 上游服务地址 | `https://api.anthropic.com` | ❌ 否 |
| `HOST_PORT` | 主机端口映射 | `80` | ❌ 否 |
| `KEYWORDS_FILE_DIR` | 关键词文件目录（宿主机） | `./openresty/keywords` | ❌ 否 |
| `DOCKER_NETWORK_NAME` | Docker 网络名称 | `claude-gateway-network` | ❌ 否 |
| `DOCKER_NETWORK_DRIVER` | Docker 网络驱动 | `bridge` | ❌ 否 |
| `DOCKER_NETWORK_EXTERNAL` | 是否使用外部网络 | `false` | ❌ 否 |

### 关键词文件

关键词文件包含需要过滤的关键词，每行一个。默认使用 `openresty/keywords` 目录下的 `keywords.txt` 文件，也可以通过 `KEYWORDS_FILE_DIR` 环境变量指定自定义目录：

```text
sensitive-word-1
sensitive-word-2
bad-content
```

**自定义关键词文件路径：**

```bash
# 在 .env 文件中配置
KEYWORDS_FILE_DIR=/path/to/your/custom

# 或直接在命令行指定
KEYWORDS_FILE_DIR=/path/to/your/custom docker compose up -d
```

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
POST /api/anthropic
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

### 持久化关键词文件

关键词文件路径支持通过 `KEYWORDS_FILE_DIR` 环境变量配置，默认挂载 `./openresty/keywords`：

```yaml
volumes:
  - ${KEYWORDS_FILE_DIR:-./openresty/keywords}:/etc/openresty
```

**使用自定义路径：**

```bash
# 方式1: 在 .env 文件中配置
KEYWORDS_FILE_DIR=/host/path/to

# 方式2: 命令行指定
KEYWORDS_FILE_DIR=/host/path/to docker compose up -d
```

修改宿主机上的关键词文件会自动同步到容器内。

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
