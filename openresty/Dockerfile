# ==================== 构建阶段：编译依赖 ====================
FROM openresty/openresty:alpine as builder

# 配置 APK 镜像源（阿里云）
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装编译工具和依赖（仅在此阶段保留）
RUN apk add --no-cache \
    wget \
    curl \
    gcc \
    g++ \
    make \
    git \
    lua-dev

# 创建编译所需目录
RUN mkdir -p /usr/local/openresty/site/lualib/resty

# 编译 lua-aho-corasick（使用备选镜像和重试机制）
RUN cd /tmp && \
    (git clone --depth=1 https://github.com/cloudflare/lua-aho-corasick.git || \
     git clone --depth=1 https://gitee.com/mirrors/lua-aho-corasick.git lua-aho-corasick) && \
    cd lua-aho-corasick && \
    make && \
    make install LUA_INCLUDE_DIR=/usr/local/openresty/luajit/include/luajit-2.1 && \
    cp ahocorasick.so /usr/local/openresty/site/lualib/ && \
    cd /tmp && \
    rm -rf lua-aho-corasick

# 安装 lua-resty-http（HTTP 客户端库）
RUN cd /tmp && \
    (wget --timeout=30 https://github.com/ledgetech/lua-resty-http/archive/refs/tags/v0.17.1.tar.gz || \
     curl -L -o v0.17.1.tar.gz https://github.com/ledgetech/lua-resty-http/archive/refs/tags/v0.17.1.tar.gz) && \
    tar -xzf v0.17.1.tar.gz && \
    cd lua-resty-http-0.17.1 && \
    cp -r lib/resty/* /usr/local/openresty/site/lualib/resty/ && \
    cd /tmp && \
    rm -rf lua-resty-http-0.17.1 v0.17.1.tar.gz

# 构建前端
FROM node:18-alpine as frontend-builder

# 配置 NPM 镜像源（淘宝/阿里）
RUN npm config set registry https://registry.npmmirror.com

COPY ./frontend /app/frontend
WORKDIR /app/frontend
RUN npm install --legacy-peer-deps && npm run build

# 构建 Python 依赖（预编译）
FROM python:3.11-alpine as python-builder

# 配置 PyPI 镜像源（阿里云）
RUN pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/

COPY ./backend/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --user -r /tmp/requirements.txt

# ==================== 运行时阶段：精简镜像 ====================
FROM openresty/openresty:alpine

# 配置 APK 镜像源（阿里云）
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 仅安装运行时必需的工具（删除编译工具）
RUN apk add --no-cache \
    wget \
    curl \
    python3 \
    py3-pip \
    supervisor \
    ca-certificates

# 从 builder 阶段复制编译好的 Lua 库
COPY --from=builder /usr/local/openresty/site/lualib/resty /usr/local/openresty/site/lualib/resty
COPY --from=builder /usr/local/openresty/site/lualib/ahocorasick.so /usr/local/openresty/site/lualib/

# 创建应用目录结构
RUN mkdir -p /usr/local/openresty/nginx/logs \
    && mkdir -p /usr/local/openresty/nginx/lua \
    && mkdir -p /etc/openresty \
    && mkdir -p /app/backend /app/frontend /app/data

# 将日志链接到 stdout 和 stderr（Docker 最佳实践）
RUN ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

# 复制 Nginx 配置文件
COPY ./openresty/nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# 从 python-builder 阶段复制 Python 依赖（而非重新安装）
COPY --from=python-builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

# 复制后端代码
COPY ./backend /app/backend

# 从 frontend-builder 复制前端构建产物
COPY --from=frontend-builder /app/frontend/dist /usr/local/openresty/nginx/html

# 复制 supervisor 配置
COPY ./openresty/supervisord.conf /etc/supervisord.conf

# 设置默认环境变量
ENV API_TOKEN=default-secret-token-please-change-me
ENV UPSTREAM_URL=https://api.anthropic.com
ENV DATABASE_URL=sqlite+aiosqlite:///./data/gateway.db
ENV SECRET_KEY=your-secret-key-change-me-in-production
ENV FEISHU_APP_ID=
ENV FEISHU_APP_SECRET=
ENV FEISHU_REDIRECT_URI=http://localhost/admin/auth/callback
ENV PYTHONUNBUFFERED=1

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/health || exit 1

# 使用 supervisor 启动多个服务
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
