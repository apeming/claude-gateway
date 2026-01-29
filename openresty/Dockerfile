FROM openresty/openresty:alpine

# 安装必要的工具（包括编译工具用于lua-aho-corasick）
RUN apk add --no-cache \
    wget \
    unzip \
    gcc \
    g++ \
    make \
    git \
    lua-dev

# 创建必要的目录
RUN mkdir -p /usr/local/openresty/nginx/logs \
    && mkdir -p /usr/local/openresty/nginx/lua \
    && mkdir -p /usr/local/openresty/site/lualib/resty \
    && mkdir -p /etc/openresty

# 将日志链接到 stdout 和 stderr（Docker 最佳实践）
RUN ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

# 安装 lua-aho-corasick（Aho-Corasick算法实现，用于高性能关键字匹配）
RUN cd /tmp \
    && git clone --depth=1 https://github.com/cloudflare/lua-aho-corasick.git \
    && cd lua-aho-corasick \
    && make \
    && make install LUA_INCLUDE_DIR=/usr/local/openresty/luajit/include/luajit-2.1 \
    && cp ahocorasick.so /usr/local/openresty/site/lualib/ \
    && cd /tmp \
    && rm -rf lua-aho-corasick

# 安装 lua-resty-http（HTTP 客户端库，用于重试机制）
RUN cd /tmp \
    && wget https://github.com/ledgetech/lua-resty-http/archive/refs/tags/v0.17.1.tar.gz \
    && tar -xzf v0.17.1.tar.gz \
    && cd lua-resty-http-0.17.1 \
    && cp -r lib/resty/* /usr/local/openresty/site/lualib/resty/ \
    && cd /tmp \
    && rm -rf lua-resty-http-0.17.1 v0.17.1.tar.gz

# 复制 Nginx 配置文件
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# 设置默认环境变量
ENV API_TOKEN=default-secret-token-please-change-me
ENV UPSTREAM_URL=https://api.anthropic.com

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/health || exit 1

# 启动 OpenResty
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
