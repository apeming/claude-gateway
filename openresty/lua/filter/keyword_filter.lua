local _M = {}

local function sanitize_for_text(value, max_len)
    if not value then
        return ""
    end

    value = tostring(value)
    value = value:gsub("[\r\n\t]", " ")

    if max_len and #value > max_len then
        value = value:sub(1, max_len) .. "..."
    end

    return value
end

function _M.check(data)
    ngx.ctx.blocked_keyword = nil

    if not data or data == "" then
        return true
    end

    local ahocorasick = require "ahocorasick"
    local dict = ngx.shared.keywords
    local version_dict = ngx.shared.keyword_version
    local current_version = version_dict:get("version") or 0

    -- 使用 package.loaded 存储 worker 级别的 AC 自动机缓存
    if not package.loaded.ac_cache then
        package.loaded.ac_cache = {
            dict = nil,
            version = 0
        }
    end
    local ac_cache = package.loaded.ac_cache

    -- 检查是否需要重建AC自动机
    if not ac_cache.dict or ac_cache.version ~= current_version then
        local keys = dict:get_keys(0)
        if #keys > 0 then
            ac_cache.dict = ahocorasick.create(keys)
            ac_cache.version = current_version
        else
            ac_cache.dict = nil
        end
    end

    -- 使用AC自动机进行匹配
    if ac_cache.dict then
        local b, e = ahocorasick.match(ac_cache.dict, data)
        if b and e then
            -- lua-aho-corasick returns 0-based inclusive offsets, while
            -- string.sub expects 1-based inclusive indexes.
            local matched = data:sub(b + 1, e + 1)
            ngx.ctx.blocked_keyword = matched
            ngx.log(ngx.WARN, "Keyword filter blocked request, matched keyword: ", sanitize_for_text(matched, 80),
                ", uri: ", ngx.var.request_uri or "")
            return false
        end
    end

    return true
end

function _M.send_blocked_response()
    local matched = sanitize_for_text(ngx.ctx.blocked_keyword, 200)

    ngx.status = 403
    ngx.header["Content-Type"] = "text/plain; charset=utf-8"

    local message = "\n\n检测到请求中包含敏感信息，已被安全策略拦截。" ..
        "\n\n请先执行 `/clear` 清理当前会话上下文，避免潜在的信息泄露，然后修改请求内容后重试。"

    if matched ~= "" then
        message = message .. "\n\n命中关键词：" .. matched
    end

    ngx.print(message)
end

return _M
