local _M = {}

local ahocorasick = require "ahocorasick"

local KEYWORDS_FILE = "/etc/openresty/keywords.txt"
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

local function write_metadata(status, loaded, load_error)
    local version_dict = ngx.shared.keyword_version
    local now = ngx.localtime()

    local ok1 = version_dict:set("keywords_status", status)
    local ok2 = version_dict:set("keywords_loaded", loaded)
    local ok3 = version_dict:set("keywords_last_loaded_at", now)
    local ok4 = version_dict:set("keywords_load_error", load_error or "")

    return ok1 and ok2 and ok3 and ok4, now
end

local function load_keywords_from_file()
    local file, open_err = io.open(KEYWORDS_FILE, "r")
    if not file then
        ngx.log(ngx.ERR, "Failed to open keyword file: ", open_err or "unknown error")
        return nil, "关键词文件不存在或不可读"
    end

    local keywords = {}
    for line in file:lines() do
        local kw = line:match("^%s*(.-)%s*$")
        if kw ~= "" then
            table.insert(keywords, kw)
        end
    end
    file:close()

    if #keywords == 0 then
        ngx.log(ngx.ERR, "Keyword file is empty: ", KEYWORDS_FILE)
        return nil, "关键词文件为空"
    end

    local ok, matcher = pcall(ahocorasick.create, keywords)
    if not ok or not matcher then
        ngx.log(ngx.ERR, "Failed to build keyword automaton: ", matcher or "unknown error")
        return nil, "关键词自动机构建失败"
    end

    return matcher, nil, #keywords
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
    local version_dict = ngx.shared.keyword_version
    local version = version_dict:get(VERSION_KEY) or 1

    if current.matcher and current.version == version and current.status == "ready" then
        return true
    end

    local matcher, public_err, loaded = load_keywords_from_file()
    if not matcher then
        current.matcher = nil
        current.version = version
        current.loaded = 0
        current.status = "failed"
        current.load_error = public_err

        local metadata_ok, loaded_at = write_metadata("failed", 0, public_err)
        current.last_loaded_at = loaded_at or ngx.localtime()
        if not metadata_ok then
            current.load_error = "关键词元数据写入失败"
            current.last_loaded_at = ngx.localtime()
            ngx.log(ngx.ERR, "Failed to persist keyword failure metadata")
            return false, current.load_error
        end

        return false, public_err
    end

    local metadata_ok, loaded_at = write_metadata("ready", loaded, "")
    if not metadata_ok then
        current.matcher = nil
        current.version = version
        current.loaded = 0
        current.status = "failed"
        current.last_loaded_at = ngx.localtime()
        current.load_error = "关键词元数据写入失败"
        ngx.log(ngx.ERR, "Failed to persist keyword success metadata")
        return false, current.load_error
    end

    current.matcher = matcher
    current.version = version
    current.loaded = loaded
    current.status = "ready"
    current.last_loaded_at = loaded_at
    current.load_error = ""

    return true
end

function _M.find_match(data)
    local ok, err = _M.ensure_ready()
    if not ok then
        return nil, err
    end

    local current = cache()
    local b, e = ahocorasick.match(current.matcher, data)
    if not b or not e then
        return nil, nil
    end

    return data:sub(b + 1, e + 1), nil
end

return _M
