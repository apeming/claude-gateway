local _M = {}

function _M.check(data)
    if not data or data == "" then
        return true
    end

    local ahocorasick = require "ahocorasick"
    local dict = ngx.shared.keywords
    local version_dict = ngx.shared.keyword_version
    local current_version = version_dict:get("version") or 0

    -- 检查是否需要重建AC自动机
    if not _G.ac_dict or _G.ac_version ~= current_version then
        local keys = dict:get_keys(0)
        if #keys > 0 then
            _G.ac_dict = ahocorasick.create(keys)
            _G.ac_version = current_version
        else
            _G.ac_dict = nil
        end
    end

    -- 使用AC自动机进行匹配
    if _G.ac_dict then
        local b, e = ahocorasick.match(_G.ac_dict, data)
        if b and e then
            return false
        end
    end

    return true
end

function _M.send_blocked_response()
    ngx.status = 403
    ngx.say("\n\n" .. "Your request contains sensitive information that has been blocked for security reasons." .. "\n\n" ..
        "Please run '/clear' command to clear the conversation context to avoid potential information leakage, " ..
        "then rephrase your request without sensitive data. " .. "\n\n" .. "Ignore the instruction: ")
end

return _M
