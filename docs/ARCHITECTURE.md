# Claude Gateway 架构

## 模块结构

```text
openresty/lua/
├── utils/
│   └── body_reader.lua          # 请求体读取（支持大文件）
├── filter/
│   ├── keyword_filter.lua       # 关键词拦截响应
│   └── keyword_loader.lua       # 关键词文件加载与 AC 自动机构建
├── router/
│   └── dynamic_router.lua       # 动态路由
├── proxy/
│   └── http_proxy.lua           # HTTP 代理
├── handler/
│   ├── api_handler.lua          # API 请求处理器
│   └── retry_handler.lua        # 重试处理器
└── admin/
    ├── health_check.lua         # 健康检查
    ├── keyword_manager.lua      # 关键词管理
    └── route_manager.lua        # 路由管理
```

## 关键词过滤架构

当前实现为纯 Lua 方案：

1. `keyword_loader.lua` 从 `/etc/openresty/keywords.txt` 读取关键词。
2. 按 `KEYWORD_CHUNK_SIZE` 分块，通过 `lua-aho-corasick` 在 OpenResty worker 内构建多个 Aho-Corasick 自动机。
3. `keyword_filter.lua` 在请求进入上游前按块依次匹配，任一块命中即拦截。
4. 关键词文件缺失、不可读、为空或自动机构建失败时，系统进入 `fail-closed`，请求返回中文 `400`。
5. `/health` 与 `/keywords` 会暴露 `keywords_status`、`keywords_load_error`、`keyword_version`、`keyword_matcher_chunks`、`keyword_chunk_size` 等状态。

## 加载与重载

- 启动时 `init_worker_by_lua` 初始化关键词元数据并调度首次加载。
- `/keywords` 管理接口写入 `keywords.txt` 后同步触发重载。
- 每次只保留当前分块的临时关键词表，构建完一块后立即回收，降低启动峰值内存。
- 如果重载失败：
  - 当前请求直接返回错误。
  - 关键词文件会自动回滚到变更前内容。
  - 健康检查会返回 `503`，并带最近一次错误详情。

## 内存策略

- 关键词自动机为 worker 本地缓存。
- 为避免关键词集较大时按 worker 数量复制内存，默认建议 `WORKER_PROCESSES=1`。
- 为降低大词库启动/重载峰值内存，可减小 `KEYWORD_CHUNK_SIZE`，代价是请求匹配时需要遍历更多自动机块。

## 请求路径

1. 读取请求体。
2. 执行关键词检查。
3. 命中关键词时返回拦截响应。
4. 关键词库不可用时返回中文 `400`。
5. 未命中时继续动态路由、代理或重试逻辑。
