local _M = {}

-- 验证 API Token
local function verify_token()
    local config_dict = ngx.shared.api_config
    local valid_token = config_dict:get("api_token")
    local client_token = ngx.var.http_x_api_key or ngx.var.http_authorization

    if client_token and client_token:match("^Bearer%s+") then
        client_token = client_token:gsub("^Bearer%s+", "")
    end

    if not client_token or client_token ~= valid_token then
        ngx.status = 401
        ngx.header["WWW-Authenticate"] = 'Bearer realm="API"'
        ngx.say('{"error": "Unauthorized", "message": "Invalid or missing API token"}')
        return false
    end

    return true
end

-- 添加关键字
function _M.add()
    if not verify_token() then
        return
    end

    local kw = ngx.var.arg_kw
    if not kw or kw == "" then
        ngx.say("Missing kw parameter")
        return
    end

    local dict = ngx.shared.keywords
    if dict:get(kw) then
        ngx.say("Keyword already exists: " .. kw)
        return
    end

    dict:set(kw, true)

    -- 写入文件
    local file = "/etc/openresty/keywords.txt"
    local f = io.open(file, "a+")
    if f then
        f:write(kw .. "\n")
        f:close()
    else
        ngx.say("Failed to write file!")
        return
    end

    -- 更新版本号，触发AC自动机重建
    local version_dict = ngx.shared.keyword_version
    local current_version = version_dict:get("version") or 0
    version_dict:set("version", current_version + 1)

    ngx.say("Keyword added: " .. kw)
end

-- 删除关键字
function _M.delete()
    if not verify_token() then
        return
    end

    local kw = ngx.var.arg_kw
    if not kw or kw == "" then
        ngx.say("Missing kw parameter")
        return
    end

    local dict = ngx.shared.keywords
    if not dict:get(kw) then
        ngx.say("Keyword not exists: " .. kw)
        return
    end

    dict:delete(kw)

    -- 从文件删除
    local file = "/etc/openresty/keywords.txt"
    local lines = {}
    local f = io.open(file, "r")
    if f then
        for line in f:lines() do
            local line_kw = line:match("^%s*(.-)%s*$")
            if line_kw ~= kw and line_kw ~= "" then
                table.insert(lines, line_kw)
            end
        end
        f:close()
    end

    -- 覆盖写回
    local fw = io.open(file, "w")
    if fw then
        for _, l in ipairs(lines) do
            fw:write(l .. "\n")
        end
        fw:close()
    else
        ngx.say("Failed to write file!")
        return
    end

    -- 更新版本号，触发AC自动机重建
    local version_dict = ngx.shared.keyword_version
    local current_version = version_dict:get("version") or 0
    version_dict:set("version", current_version + 1)

    ngx.say("Keyword deleted: " .. kw)
end

-- 列出所有关键字
function _M.list()
    if not verify_token() then
        return
    end

    local dict = ngx.shared.keywords
    local keys = dict:get_keys(0)
    ngx.say("Keywords: " .. table.concat(keys, ", "))
end

return _M
