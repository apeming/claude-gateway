local cjson = require "cjson"

local _M = {}

local function send_text(status, message)
    ngx.status = status
    ngx.header["Content-Type"] = "text/plain; charset=utf-8"
    ngx.say(message)
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

local function add_keyword(keyword)
    local dict = ngx.shared.keywords
    if dict:get(keyword) then
        send_text(200, "Keyword already exists: " .. keyword)
        return
    end

    dict:set(keyword, true)

    local file = "/etc/openresty/keywords.txt"
    local handle = io.open(file, "a+")
    if not handle then
        send_text(500, "Failed to write file!")
        return
    end

    handle:write(keyword .. "\n")
    handle:close()

    local version_dict = ngx.shared.keyword_version
    local current_version = version_dict:get("version") or 0
    version_dict:set("version", current_version + 1)

    send_text(200, "Keyword added: " .. keyword)
end

local function delete_keyword(keyword)
    local dict = ngx.shared.keywords
    if not dict:get(keyword) then
        send_text(200, "Keyword not exists: " .. keyword)
        return
    end

    dict:delete(keyword)

    local file = "/etc/openresty/keywords.txt"
    local lines = {}
    local handle = io.open(file, "r")
    if handle then
        for line in handle:lines() do
            local line_kw = line:match("^%s*(.-)%s*$")
            if line_kw ~= keyword and line_kw ~= "" then
                table.insert(lines, line_kw)
            end
        end
        handle:close()
    end

    local writer = io.open(file, "w")
    if not writer then
        send_text(500, "Failed to write file!")
        return
    end

    for _, line in ipairs(lines) do
        writer:write(line .. "\n")
    end
    writer:close()

    local version_dict = ngx.shared.keyword_version
    local current_version = version_dict:get("version") or 0
    version_dict:set("version", current_version + 1)

    send_text(200, "Keyword deleted: " .. keyword)
end

local function list_keywords()
    local dict = ngx.shared.keywords
    local keys = dict:get_keys(0)
    send_text(200, "Keywords: " .. table.concat(keys, ", "))
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
