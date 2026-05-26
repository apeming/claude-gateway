local http = require "resty.http"
local body_reader = require "utils.body_reader"
local keyword_filter = require "filter.keyword_filter"
local dynamic_router = require "router.dynamic_router"

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

-- 处理带重试机制的请求
function _M.handle_with_retry(path_prefix, max_retries)
    max_retries = max_retries or 10

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

    -- 准备请求头
    local headers = prepare_headers(full_url)

    -- 重试循环
    local retry_count = 0
    while retry_count <= max_retries do
        local httpc = http.new()
        httpc:set_timeouts(10000, 600000, 600000)

        local res, err = httpc:request_uri(full_url, {
            method = ngx.var.request_method,
            body = body,
            headers = headers,
            ssl_verify = false
        })

        if not res then
            ngx.log(ngx.ERR, "HTTP request failed: ", err)
            return
        end

        -- 保留原始响应体
        local response_body = res.body
        local check_body = response_body

        -- 如果是压缩格式，解压一份副本用于检查
        if response_body and res.headers["Content-Encoding"] then
            local encoding = res.headers["Content-Encoding"]:lower()
            ngx.log(ngx.WARN, "[DEBUG] Response has Content-Encoding: ", encoding)

            if encoding == "gzip" then
                local zlib = require "zlib"
                local stream = zlib.inflate()
                local decompressed, eof, bytes_in, bytes_out = stream(response_body)
                if decompressed then
                    check_body = decompressed
                    ngx.log(ngx.WARN, "[DEBUG] Gzip decompressed successfully, body length: ", #check_body)
                else
                    ngx.log(ngx.WARN, "[DEBUG] Failed to decompress gzip response")
                end
            elseif encoding == "br" then
                -- 使用 FFI 调用 brotli 解压
                local ok, brotli = pcall(require, "utils.brotli")
                if ok then
                    local decompressed, err = brotli.decompress(response_body)
                    if decompressed then
                        check_body = decompressed
                        ngx.log(ngx.WARN, "[DEBUG] Brotli decompressed successfully, body length: ", #check_body)
                    else
                        ngx.log(ngx.WARN, "[DEBUG] Failed to decompress brotli response: ", err or "unknown error")
                    end
                else
                    ngx.log(ngx.WARN, "[DEBUG] Brotli module not available: ", brotli)
                end
            end
        end

        -- 检查是否为 400 错误且响应体包含 "unavailable"
        if res.status == 400 then
            ngx.log(ngx.WARN, "[DEBUG] Received 400 response, body is nil: ", (check_body == nil), ", body length: ", check_body and #check_body or 0)
            if check_body and #check_body > 0 then
                local body_preview = check_body:sub(1, 200)  -- 前200个字符
                ngx.log(ngx.WARN, "[DEBUG] Response body preview: ", body_preview)
            end
            if check_body and check_body:lower():find("unavailable") then
                ngx.log(ngx.WARN, "[DEBUG] Found 'unavailable' in response body")
                if retry_count < max_retries then
                    local delay = math.pow(2, retry_count)
                    ngx.log(ngx.WARN, "Received 400 with 'unavailable', retrying in ", delay, "s (attempt ", retry_count + 1, "/", max_retries, ")")
                    ngx.sleep(delay)
                    retry_count = retry_count + 1
                else
                    -- 重试耗尽，返回原始响应
                    ngx.status = res.status
                    for k, v in pairs(res.headers) do
                        local lower_k = k:lower()
                        if lower_k ~= "connection" and lower_k ~= "transfer-encoding" then
                            ngx.header[k] = v
                        end
                    end
                    ngx.print(response_body)
                    return
                end
            else
                -- 400 但不包含 unavailable，返回原始响应
                ngx.log(ngx.WARN, "[DEBUG] 400 response but 'unavailable' not found in body")
                ngx.status = res.status
                for k, v in pairs(res.headers) do
                    local lower_k = k:lower()
                    if lower_k ~= "connection" and lower_k ~= "transfer-encoding" then
                        ngx.header[k] = v
                    end
                end
                ngx.print(response_body)
                return
            end
        else
            -- 其他响应，返回原始响应
            ngx.status = res.status
            for k, v in pairs(res.headers) do
                local lower_k = k:lower()
                if lower_k ~= "connection" and lower_k ~= "transfer-encoding" then
                    ngx.header[k] = v
                end
            end
            ngx.print(response_body)

            if retry_count > 0 then
                ngx.log(ngx.INFO, "Request completed after ", retry_count, " retries, status: ", res.status)
            end
            return
        end
    end
end

return _M
