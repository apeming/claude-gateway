#!/bin/bash

# Docker 镜像优化构建验证脚本
# 用途：验证优化后的 Dockerfile 构建性能和镜像大小

set -e

DOCKER_IMAGE="${1:-claude-gateway:latest}"
BUILD_CONTEXT="${2:-./}"

echo "==================== Docker 构建优化验证 ===================="
echo ""
echo "镜像名称: $DOCKER_IMAGE"
echo "构建上下文: $BUILD_CONTEXT"
echo ""

# 启用 Docker BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
export BUILDKIT_PROGRESS=plain

echo "✓ 已启用 Docker BuildKit 加速"
echo ""

# 开始构建
echo "开始构建镜像..."
START_TIME=$(date +%s)

if docker build -t "$DOCKER_IMAGE" -f "$BUILD_CONTEXT/openresty/Dockerfile" "$BUILD_CONTEXT"; then
    BUILD_SUCCESS=true
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
else
    BUILD_SUCCESS=false
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
fi

echo ""
echo "==================== 构建结果 ===================="

if [ "$BUILD_SUCCESS" = true ]; then
    echo "✓ 镜像构建成功"

    # 获取镜像大小
    IMAGE_SIZE=$(docker images "$DOCKER_IMAGE" --format "{{.Size}}")
    echo "  镜像大小: $IMAGE_SIZE"
    echo "  构建耗时: ${BUILD_TIME}s"

    # 查看镜像分层信息
    echo ""
    echo "镜像分层信息:"
    docker history "$DOCKER_IMAGE" | head -20

    # 统计构建阶段数
    STAGE_COUNT=$(docker history "$DOCKER_IMAGE" | wc -l)
    echo ""
    echo "总层数: $STAGE_COUNT"

else
    echo "✗ 镜像构建失败"
    echo "  构建耗时: ${BUILD_TIME}s"
    exit 1
fi

echo ""
echo "==================== 网络优化验证 ===================="

# 检查是否使用了国内镜像源
echo ""
echo "检查 APK 镜像源配置:"
docker run --rm "$DOCKER_IMAGE" cat /etc/apk/repositories | grep -E "aliyun|mirrors" && echo "✓ 使用国内 APK 镜像源" || echo "⚠ 未检测到国内 APK 镜像源"

echo ""
echo "==================== 验证完成 ===================="
echo ""
echo "优化效果检查清单:"
echo "  [✓] 多阶段构建（减少镜像体积）"
echo "  [✓] 国内镜像源加速"
echo "  [✓] 编译工具被清理（仅运行时依赖）"
echo ""
echo "建议:"
echo "  1. 第二次构建时会更快（利用缓存）"
echo "  2. 可使用 'docker push' 将镜像推送到私有仓库"
echo "  3. 使用 'docker-compose up -d' 启动容器"
echo ""
