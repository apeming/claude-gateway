local http = require "resty.http"

local _M = {}

-- 准备请求头
local function prepare_headers(full_url)
    local headers = {}
    local req_headers = ngx.req.get_headers()

    for k, v in pairs(req_headers) do
        if k ~= "host" and k ~= "connection" and k ~= "content-length" then
            headers[k] = v
        end
    end

    local target_host = full_url:match("^https?://([^/]+)")
    if target_host then
        headers["Host"] = target_host
    end

    return headers
end

-- 转发响应
local function forward_response(res)
    ngx.status = res.status

    for k, v in pairs(res.headers) do
        local lower_k = k:lower()
        if lower_k ~= "connection" and lower_k ~= "transfer-encoding" then
            ngx.header[k] = v
        end
    end

    ngx.print(res.body)
end

-- 发送错误响应
local function send_error_response(err_msg)
    ngx.log(ngx.ERR, "HTTP request failed: ", err_msg)
    ngx.status = 500
    ngx.header["Content-Type"] = "application/json"
    ngx.say('{"error": {"type": "api_error", "message": "Failed to connect to upstream"}}')
end

-- 非流式代理
function _M.proxy(full_url, body)
    local headers = prepare_headers(full_url)

    local httpc = http.new()
    httpc:set_timeouts(10000, 120000, 120000)

    local res, err = httpc:request_uri(full_url, {
        method = ngx.var.request_method,
        body = body,
        headers = headers,
        ssl_verify = false
    })

    if not res then
        send_error_response(err)
        return false
    end

    forward_response(res)
    return true
end

-- 流式代理（目前与非流式相同，因为 request_uri 会等待完整响应）
-- 如果需要真正的流式代理，需要使用 httpc:connect + httpc:request + 循环读取
function _M.proxy_stream(full_url, body)
    return _M.proxy(full_url, body)
end

return _M
