.PHONY: help build up down restart logs ps clean token host-up network-create

help:
	@echo "Claude Gateway - Makefile Commands"
	@echo ""
	@echo "Basic commands:"
	@echo "  make build     - 构建 Docker 镜像"
	@echo "  make up        - 启动服务（默认网络模式）"
	@echo "  make down      - 停止服务"
	@echo "  make restart   - 重启服务"
	@echo "  make logs      - 查看日志"
	@echo "  make ps        - 查看服务状态"
	@echo "  make health    - 检查服务健康状态"
	@echo "  make shell     - 进入容器 shell"
	@echo ""
	@echo "Network commands:"
	@echo "  make host-up   - 使用 host 网络模式启动"
	@echo "  make network-create NETWORK=name - 创建自定义网络"
	@echo ""
	@echo "Utility commands:"
	@echo "  make token     - 生成随机 API Token"
	@echo "  make clean     - 清理容器和镜像"
	@echo "  make deploy    - 快速部署（构建+启动+健康检查）"
	@echo ""

build:
	docker compose build --no-cache

up:
	docker compose up -d

# Host 网络模式启动
host-up:
	@echo "Starting with host network mode..."
	docker compose -f docker-compose.yml -f docker-compose.host.yml up -d

down:
	docker compose down

restart:
	docker compose restart

logs:
	docker compose logs -f

ps:
	docker compose ps

health:
	@echo "Checking service health..."
	@curl -s http://localhost/health | jq '.' || echo "Service not responding or jq not installed"

token:
	@echo "Generated API Token:"
	@openssl rand -base64 32 || uuidgen

# 创建自定义网络
network-create:
	@if [ -z "$(NETWORK)" ]; then \
		echo "Usage: make network-create NETWORK=network-name"; \
		exit 1; \
	fi
	@echo "Creating network: $(NETWORK)"
	@docker network create $(NETWORK) || echo "Network $(NETWORK) already exists"

clean:
	docker compose down -v
	docker rmi claude-gateway:latest 2>/dev/null || true

shell:
	docker exec -it claude-gateway sh

# 快速部署
deploy: build up
	@echo "Deployment complete. Waiting for service to be ready..."
	@sleep 5
	@make health
