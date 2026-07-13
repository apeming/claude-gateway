local _M = {}

local VERSION_KEY = "version"

local function cache()
    if not package.loaded.keyword_loader_cache then
        package.loaded.keyword_loader_cache = {
            matcher = nil,
            version = 0,
            loaded = 0,
            status = "init",
            last_loaded_at = "",
            load_error = ""
        }
    end

    return package.loaded.keyword_loader_cache
end

function _M.read_metadata()
    local version_dict = ngx.shared.keyword_version

    return {
        keyword_version = version_dict:get(VERSION_KEY) or 1,
        keywords_loaded = version_dict:get("keywords_loaded") or 0,
        keywords_status = version_dict:get("keywords_status") or "init",
        keywords_last_loaded_at = version_dict:get("keywords_last_loaded_at") or "",
        keywords_load_error = version_dict:get("keywords_load_error") or ""
    }
end

function _M.ensure_ready()
    local current = cache()
    return false, current.load_error ~= "" and current.load_error or "关键词加载器尚未初始化"
end

function _M.find_match(_data)
    local current = cache()
    return nil, current.load_error ~= "" and current.load_error or "关键词加载器尚未初始化"
end

return _M
