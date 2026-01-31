FROM openresty/openresty:alpine

# 使用阿里云镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

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

# 复制预下载的库文件
COPY libs/ /tmp/libs/

# 安装 lua-aho-corasick（Aho-Corasick算法实现，用于高性能关键字匹配）
RUN cd /tmp/libs \
    && unzip lua-aho-corasick.zip \
    && cd lua-aho-corasick-master \
    && make \
    && make install LUA_INCLUDE_DIR=/usr/local/openresty/luajit/include/luajit-2.1 \
    && cp ahocorasick.so /usr/local/openresty/site/lualib/ \
    && cd /tmp \
    && rm -rf /tmp/libs/lua-aho-corasick-master

# 安装 lua-resty-http（HTTP 客户端库，用于重试机制）
RUN cd /tmp/libs \
    && tar -xzf lua-resty-http.tar.gz \
    && cd lua-resty-http-0.17.1 \
    && cp -r lib/resty/* /usr/local/openresty/site/lualib/resty/ \
    && cd /tmp \
    && rm -rf /tmp/libs/lua-resty-http-0.17.1

# 安装 lua-zlib（用于 gzip 解压缩）
RUN apk add --no-cache zlib-dev \
    && cd /tmp/libs \
    && tar -xzf lua-zlib.tar.gz \
    && cd lua-zlib-1.2 \
    && gcc -O2 -fPIC -I/usr/local/openresty/luajit/include/luajit-2.1 -c lua_zlib.c -o lua_zlib.o \
    && gcc -shared -o zlib.so lua_zlib.o -lz \
    && cp zlib.so /usr/local/openresty/site/lualib/ \
    && cd /tmp \
    && rm -rf /tmp/libs/lua-zlib-1.2

# 安装 brotli 系统库（用于 brotli 解压缩，通过 FFI 调用）
RUN apk add --no-cache brotli-dev brotli-libs

# 复制 Nginx 配置文件
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

# 复制 conf.d 配置目录
COPY conf.d/ /usr/local/openresty/nginx/conf/conf.d/

# 复制 Lua 模块
COPY lua/ /usr/local/openresty/nginx/lua/

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
