local _M = {}

function _M.check(data)
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
