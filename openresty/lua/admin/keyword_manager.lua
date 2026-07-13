local cjson = require "cjson"
local keyword_loader = require "filter.keyword_loader"

local _M = {}
local KEYWORDS_FILE = "/etc/openresty/keywords.txt"

local function send_text(status, message)
    ngx.status = status
    ngx.header["Content-Type"] = "text/plain; charset=utf-8"
    ngx.say(message)
end

local function send_json(status, payload)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say(cjson.encode(payload))
end

local function read_request_body()
    ngx.req.read_body()

    local body = ngx.req.get_body_data()
    if body then
        return body
    end

    local body_file = ngx.req.get_body_file()
    if not body_file then
        return nil
    end

    local file = io.open(body_file, "r")
    if not file then
        return nil
    end

    local file_body = file:read("*a")
    file:close()

    return file_body
end

local function read_keyword_from_body()
    local body = read_request_body()
    if not body or body == "" then
        return nil, "Missing keyword in request body"
    end

    local ok, payload = pcall(cjson.decode, body)
    if not ok then
        return nil, "Invalid JSON body"
    end

    if type(payload) ~= "table" or payload.keyword == nil then
        return nil, "Missing keyword in request body"
    end

    local keyword = payload.keyword
    if type(keyword) ~= "string" or keyword == "" then
        return nil, "Missing keyword in request body"
    end

    return keyword
end

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

local function read_keywords_from_file()
    local handle, err = io.open(KEYWORDS_FILE, "r")
    if not handle then
        return nil, "读取关键词文件失败", err
    end

    local lines = {}
    local exists = {}

    for line in handle:lines() do
        local keyword = line:match("^%s*(.-)%s*$")
        if keyword ~= "" then
            table.insert(lines, keyword)
            exists[keyword] = true
        end
    end

    handle:close()
    return lines, exists
end

local function bump_keyword_version()
    local version_dict = ngx.shared.keyword_version
    local current_version = version_dict:get("version") or 1
    local next_version = current_version + 1
    local ok, err = version_dict:set("version", next_version)
    if not ok then
        return nil, err or "set failed"
    end
    return next_version
end

local function sync_keyword_metadata(loaded)
    local version_dict = ngx.shared.keyword_version
    local ok1 = version_dict:set("keywords_loaded", loaded)
    local ok2 = version_dict:set("keywords_load_error", "")
    local ok3 = version_dict:set("keywords_status", "ready")

    if not ok1 or not ok2 or not ok3 then
        return false
    end

    return true
end

local function add_keyword(keyword)
    local lines, exists, err = read_keywords_from_file()
    if not lines then
        ngx.log(ngx.ERR, "Failed to read keyword file for add: ", err or "unknown error")
        send_text(500, "读取关键词文件失败")
        return
    end

    if exists[keyword] then
        send_text(200, "Keyword already exists: " .. keyword)
        return
    end

    local handle = io.open(KEYWORDS_FILE, "a+")
    if not handle then
        send_text(500, "写入关键词文件失败")
        return
    end

    handle:write(keyword .. "\n")
    handle:close()

    local next_version, version_err = bump_keyword_version()
    if not next_version then
        ngx.log(ngx.ERR, "Failed to bump keyword version after add: ", version_err or "unknown error")
        send_text(500, "更新关键词版本失败")
        return
    end

    if not sync_keyword_metadata(#lines + 1) then
        ngx.log(ngx.ERR, "Failed to sync keyword metadata after add")
        send_text(500, "同步关键词元数据失败")
        return
    end

    send_text(200, "Keyword added: " .. keyword)
end

local function delete_keyword(keyword)
    local lines, exists, err = read_keywords_from_file()
    if not lines then
        ngx.log(ngx.ERR, "Failed to read keyword file for delete: ", err or "unknown error")
        send_text(500, "读取关键词文件失败")
        return
    end

    if not exists[keyword] then
        send_text(200, "Keyword not exists: " .. keyword)
        return
    end

    local filtered = {}
    for _, line in ipairs(lines) do
        if line ~= keyword then
            table.insert(filtered, line)
        end
    end

    local writer = io.open(KEYWORDS_FILE, "w")
    if not writer then
        send_text(500, "写入关键词文件失败")
        return
    end

    for _, line in ipairs(filtered) do
        writer:write(line .. "\n")
    end
    writer:close()

    local next_version, version_err = bump_keyword_version()
    if not next_version then
        ngx.log(ngx.ERR, "Failed to bump keyword version after delete: ", version_err or "unknown error")
        send_text(500, "更新关键词版本失败")
        return
    end

    if not sync_keyword_metadata(#filtered) then
        ngx.log(ngx.ERR, "Failed to sync keyword metadata after delete")
        send_text(500, "同步关键词元数据失败")
        return
    end

    send_text(200, "Keyword deleted: " .. keyword)
end

local function list_keywords()
    send_json(200, keyword_loader.read_metadata())
end

function _M.handle()
    if not verify_token() then
        return
    end

    local method = ngx.req.get_method()

    if method == "GET" then
        list_keywords()
        return
    end

    if method == "POST" then
        local keyword, err = read_keyword_from_body()
        if not keyword then
            send_text(400, err)
            return
        end
        add_keyword(keyword)
        return
    end

    if method == "DELETE" then
        local keyword, err = read_keyword_from_body()
        if not keyword then
            send_text(400, err)
            return
        end
        delete_keyword(keyword)
        return
    end

    send_text(405, "Method not allowed")
end

return _M
