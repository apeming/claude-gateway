local _M = {}
local keyword_loader = require "filter.keyword_loader"

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
    ngx.ctx.blocked_regex_rule_id = nil
    ngx.ctx.blocked_regex_value = nil
    ngx.ctx.keyword_load_error = nil

    if not data or data == "" then
        return true
    end

    local matched, err = keyword_loader.find_match(data)
    if err then
        ngx.ctx.keyword_load_error = err
        ngx.log(ngx.ERR, "Keyword loader unavailable: ", sanitize_for_text(err, 120),
            ", uri: ", ngx.var.request_uri or "")
        return false
    end

    if matched then
        if matched.kind == "literal" then
            ngx.ctx.blocked_keyword = matched.value
            ngx.log(ngx.WARN, "Keyword filter blocked request, matched keyword: ", sanitize_for_text(matched.value, 80),
                ", uri: ", ngx.var.request_uri or "")
        else
            ngx.ctx.blocked_regex_rule_id = matched.id
            ngx.ctx.blocked_regex_value = matched.value
            ngx.log(ngx.WARN, "Keyword filter blocked request, matched regex rule: ", sanitize_for_text(matched.id, 80),
                ", uri: ", ngx.var.request_uri or "")
        end
        return false
    end

    return true
end

function _M.send_blocked_response()
    local load_error = sanitize_for_text(ngx.ctx.keyword_load_error, 200)
    local matched = sanitize_for_text(ngx.ctx.blocked_keyword, 200)
    local regex_rule_id = sanitize_for_text(ngx.ctx.blocked_regex_rule_id, 200)
    local regex_value = sanitize_for_text(ngx.ctx.blocked_regex_value, 200)

    ngx.header["Content-Type"] = "text/plain; charset=utf-8"

    if load_error ~= "" then
        ngx.status = 400
        ngx.print("关键词库加载失败，请联系管理员检查关键词文件。")
        return
    end

    ngx.status = 403

    local message = "检测到请求中包含敏感信息，已被安全策略拦截。" ..
        "请先执行 /clear 清理当前会话上下文，避免潜在的信息泄露，然后修改请求内容后重试。"

    if matched ~= "" then
        message = message .. "命中关键词：" .. matched
    elseif regex_value ~= "" then
        message = message .. "命中内容：" .. regex_value
    elseif regex_rule_id ~= "" then
        message = message .. "命中规则：" .. regex_rule_id
    end

    ngx.print(message)
end

return _M
