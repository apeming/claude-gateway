local body_reader = require "utils.body_reader"
local keyword_filter = require "filter.keyword_filter"
local dynamic_router = require "router.dynamic_router"
local http_proxy = require "proxy.http_proxy"

local _M = {}

-- 处理 API 请求（基于 Authorization token）
function _M.handle_auth_token_request(path_prefix)
    -- 读取请求体
    local body = body_reader.read_body()

    -- 关键词过滤
    if not keyword_filter.check(body) then
        keyword_filter.send_blocked_response()
        return
    end

    -- 动态路由
    local full_url = dynamic_router.route_by_auth_token(path_prefix)
    if not full_url then
        return
    end

    -- 代理请求
    http_proxy.proxy(full_url, body)
end

-- 处理 API 请求（基于 x-api-key）
function _M.handle_api_key_request(path_prefix)
    -- 读取请求体
    local body = body_reader.read_body()

    -- 关键词过滤
    if not keyword_filter.check(body) then
        keyword_filter.send_blocked_response()
        return
    end

    -- 动态路由
    local full_url = dynamic_router.route_by_api_key(path_prefix)
    if not full_url then
        return
    end

    -- 检查是否为流式请求
    local is_stream = false
    if body then
        local cjson = require "cjson"
        local ok, body_json = pcall(cjson.decode, body)
        if ok and body_json.stream == true then
            is_stream = true
        end
    end

    -- 代理请求
    if is_stream then
        http_proxy.proxy_stream(full_url, body)
    else
        http_proxy.proxy(full_url, body)
    end
end

return _M
