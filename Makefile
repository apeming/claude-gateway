.PHONY: help build up down restart logs ps clean token health health-quick host-up network-create fix-permissions deploy-safe deploy-with-init

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
	@echo "  make health    - 检查服务健康状态（详细）"
	@echo "  make health-quick - 快速健康检查"
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
	@echo "🏥 Checking service health..."
	@echo ""
	@# 方法1: 通过容器IP直接访问
	@CONTAINER_IP=$$(docker inspect claude-gateway --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | head -1) && \
	if [ -n "$$CONTAINER_IP" ] && [ "$$CONTAINER_IP" != "<no value>" ]; then \
		echo "📍 Container IP: $$CONTAINER_IP"; \
		if curl -s --connect-timeout 3 "http://$$CONTAINER_IP/health" >/tmp/health_response 2>/dev/null; then \
			echo "✅ Health check successful via container IP:"; \
			if command -v jq >/dev/null 2>&1; then \
				cat /tmp/health_response | jq '.'; \
			else \
				cat /tmp/health_response; \
			fi; \
			rm -f /tmp/health_response; \
		else \
			echo "❌ Failed to connect via container IP"; \
		fi; \
	else \
		echo "⚠️  Container IP not available"; \
	fi; \
	echo ""; \
	@# 方法2: 通过端口映射访问
	@HOST_PORT=$$(docker port claude-gateway 80 2>/dev/null | cut -d: -f2 | head -1) && \
	if [ -n "$$HOST_PORT" ]; then \
		echo "🔗 Host port mapping: localhost:$$HOST_PORT"; \
		if curl -s --connect-timeout 3 "http://localhost:$$HOST_PORT/health" >/tmp/health_response 2>/dev/null; then \
			echo "✅ Health check successful via port mapping:"; \
			if command -v jq >/dev/null 2>&1; then \
				cat /tmp/health_response | jq '.'; \
			else \
				cat /tmp/health_response; \
			fi; \
			rm -f /tmp/health_response; \
		else \
			echo "❌ Failed to connect via port mapping"; \
		fi; \
	else \
		echo "⚠️  No port mapping found, trying default port..."; \
		if curl -s --connect-timeout 3 "http://localhost/health" >/tmp/health_response 2>/dev/null; then \
			echo "✅ Health check successful via localhost:80:"; \
			if command -v jq >/dev/null 2>&1; then \
				cat /tmp/health_response | jq '.'; \
			else \
				cat /tmp/health_response; \
			fi; \
			rm -f /tmp/health_response; \
		else \
			echo "❌ Service not accessible on localhost:80"; \
		fi; \
	fi; \
	@echo ""; \
	@echo "📊 Container status:"; \
	@docker ps --filter name=claude-gateway --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "❌ Container not found"

# 快速健康检查（简化版）
health-quick:
	@echo "🚀 Quick health check..."
	@CONTAINER_IP=$$(docker inspect claude-gateway --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | head -1) && \
	if [ -n "$$CONTAINER_IP" ] && [ "$$CONTAINER_IP" != "<no value>" ]; then \
		curl -s --connect-timeout 3 "http://$$CONTAINER_IP/health" | jq -r '.status // "unknown"' 2>/dev/null || echo "❌ Failed"; \
	else \
		HOST_PORT=$$(docker port claude-gateway 80 2>/dev/null | cut -d: -f2 | head -1) && \
		if [ -n "$$HOST_PORT" ]; then \
			curl -s --connect-timeout 3 "http://localhost:$$HOST_PORT/health" | jq -r '.status // "unknown"' 2>/dev/null || echo "❌ Failed"; \
		else \
			curl -s --connect-timeout 3 "http://localhost/health" | jq -r '.status // "unknown"' 2>/dev/null || echo "❌ Failed"; \
		fi; \
	fi

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
	@echo "Running health check..."
	@make health-quick
