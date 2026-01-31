# Anthropic API 兼容实现 - 模块化架构

## 重构成果

### 代码精简对比
- **原 nginx.conf**: 1041 行
- **新 nginx.conf**: 269 行（减少 **74%**）
- **Lua 模块**: 922 行（9 个模块）

### 架构优势
✅ **高度模块化** - 每个功能独立成模块
✅ **零代码重复** - 公共逻辑完全复用
✅ **易于维护** - 修改只需改对应模块
✅ **易于测试** - 每个模块可独立测试
✅ **易于扩展** - 新增功能只需添加模块

## 模块结构

```
openresty/lua/
├── utils/
│   └── body_reader.lua          # 请求体读取（支持大文件）
├── filter/
│   └── keyword_filter.lua       # 关键词过滤（AC自动机）
├── router/
│   └── dynamic_router.lua       # 动态路由（支持 Authorization 和 x-api-key）
├── proxy/
│   └── http_proxy.lua           # HTTP 代理（支持流式响应）
├── handler/
│   ├── api_handler.lua          # API 请求处理器
│   └── retry_handler.lua        # 重试处理器
└── admin/
    ├── health_check.lua         # 健康检查
    ├── keyword_manager.lua      # 关键词管理
    └── route_manager.lua        # 路由管理
```

## 核心模块说明

### 1. utils/body_reader.lua
- 读取请求体
- 自动处理大文件（从临时文件读取）

### 2. filter/keyword_filter.lua
- 使用 Aho-Corasick 算法进行关键词匹配
- 自动重建 AC 自动机（当关键词更新时）
- 提供统一的拦截响应

### 3. router/dynamic_router.lua
- `route_by_auth_token()`: 基于 Authorization token 的路由
- `route_by_api_key()`: 基于 x-api-key 的路由
- `build_full_url()`: 路径重写逻辑

### 4. proxy/http_proxy.lua
- `proxy()`: 非流式代理
- `proxy_stream()`: 流式代理
- 统一的错误处理和响应转发

### 5. handler/api_handler.lua
- `handle_auth_token_request()`: 处理 Authorization token 认证的请求
- `handle_api_key_request()`: 处理 x-api-key 认证的请求
- 整合所有模块，提供统一的请求处理流程

### 6. handler/retry_handler.lua
- `handle_with_retry()`: 处理带重试机制的请求
- 支持 400 错误重试（当响应包含 "unavailable" 时）
- 指数退避策略

### 7. admin/health_check.lua
- 健康检查接口实现
- 返回系统状态信息

### 8. admin/keyword_manager.lua
- `add()`: 添加关键词
- `delete()`: 删除关键词
- `list()`: 列出所有关键词
- 统一的 API Token 验证

### 9. admin/route_manager.lua
- `list()`: 列出所有路由
- `add()`: 添加路由
- `delete()`: 删除路由
- `update()`: 更新路由
- `reload()`: 重新加载配置文件

## API 接口

### 1. `/api/v1/messages` - Claude API（AUTH_TOKEN + 重试）
- **认证方式**: Authorization token（Bearer token）
- **动态路由**: 基于 Authorization token 查找对应的 upstream
- **功能**: 关键词过滤、动态路由、重试机制（400 错误）

### 2. `/apikey/v1/messages` - Anthropic API（API_KEY）
- **认证方式**: x-api-key
- **动态路由**: 基于 x-api-key 查找对应的 upstream
- **功能**: 关键词过滤、动态路由、流式响应支持

### 3. `/api/*` - 其他 API（proxy_pass）
- **认证方式**: Authorization token
- **动态路由**: 基于 Authorization token
- **功能**: 关键词过滤、动态路由、高性能代理

## nginx.conf 精简示例

**原来的 location 块（180+ 行）：**
```lua
location ~ ^/api/v1/messages {
    client_max_body_size 100m;
    content_by_lua_block {
        -- 180+ 行重复代码
    }
}
```

**现在的 location 块（3 行）：**
```lua
location ~ ^/apikey/v1/messages {
    client_max_body_size 100m;
    content_by_lua_block {
        local api_handler = require "handler.api_handler"
        api_handler.handle_api_key_request("/apikey")
    }
}
```

## 使用示例

### 非流式请求
```bash
curl -X POST http://localhost/apikey/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### 流式请求
```bash
curl -X POST http://localhost/apikey/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: your-api-key" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-opus-4-5-20251101",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": true
  }'
```

## 配置说明

### 动态路由配置
在 `routes.txt` 中配置 token/api-key 到 upstream 的映射：

```
your-auth-token https://upstream1.example.com
your-api-key https://upstream2.example.com
```

### 环境变量
- `ENABLE_DYNAMIC_ROUTING=true`: 启用动态路由
- `UPSTREAM_URL`: 默认 upstream URL（未启用动态路由时使用）
- `API_TOKEN`: 管理接口的认证 token

## 注意事项

1. 流式响应目前使用 `request_uri` 实现，会等待完整响应后再转发
2. 如需真正的流式代理，需要使用 `httpc:connect` + `httpc:request` + 循环读取
3. 关键词过滤对所有请求生效
4. 动态路由需要在 `routes.txt` 中配置映射关系
5. 原 nginx.conf 已备份为 `nginx.conf.backup`
