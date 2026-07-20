local cjson = require "cjson"
local keyword_loader = require "filter.keyword_loader"

local _M = {}
local RULES_FILE = "/etc/openresty/regex_rules.jsonl"

local function send(status, value)
    ngx.status = status
    ngx.header["Content-Type"] = "application/json; charset=utf-8"
    ngx.say(cjson.encode(value))
end

local function authorized()
    local token = ngx.var.http_x_api_key or ngx.var.http_authorization
    token = token and token:gsub("^Bearer%s+", "")
    return token and token == ngx.shared.api_config:get("api_token")
end

local function request_json()
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    if not body then return nil, "Invalid JSON body" end
    local ok, value = pcall(cjson.decode, body)
    if not ok or type(value) ~= "table" then return nil, "Invalid JSON body" end
    return value
end

local function read_lines()
    local file, err = io.open(RULES_FILE, "r")
    if not file then
        if err and err:find("No such file or directory", 1, true) then return {} end
        return nil, err
    end
    local lines = {}
    for line in file:lines() do if line:match("%S") then lines[#lines + 1] = line end end
    file:close()
    return lines
end

local function write_lines(lines)
    local tmp = RULES_FILE .. ".tmp"
    local file, err = io.open(tmp, "w")
    if not file then return nil, err end
    for _, line in ipairs(lines) do file:write(line, "\n") end
    file:close()
    local ok, rename_err = os.rename(tmp, RULES_FILE)
    if not ok then os.remove(tmp) end
    return ok, rename_err
end

local function persist(next_lines, previous_lines)
    local ok, err = write_lines(next_lines)
    if not ok then return nil, err end
    local metadata, reload_err = keyword_loader.reload()
    if metadata then return metadata end
    write_lines(previous_lines)
    keyword_loader.reload()
    return nil, reload_err
end

function _M.handle()
    if not authorized() then return send(401, { error = "Unauthorized" }) end
    local method = ngx.req.get_method()
    if method == "GET" then return send(200, keyword_loader.read_metadata()) end
    local payload, err = request_json()
    if not payload then return send(400, { error = err }) end
    local lines, read_err = read_lines()
    if not lines then return send(500, { error = read_err }) end
    if method == "POST" then
        if type(payload.id) ~= "string" or type(payload.anchor) ~= "string" or type(payload.expression) ~= "string" then
            return send(400, { error = "id, anchor, and expression are required" })
        end
        for _, line in ipairs(lines) do
            local ok, rule = pcall(cjson.decode, line)
            if ok and rule.id == payload.id then return send(409, { error = "Rule already exists" }) end
        end
        local previous_lines = {}
        for _, line in ipairs(lines) do previous_lines[#previous_lines + 1] = line end
        lines[#lines + 1] = cjson.encode({ id = payload.id, anchor = payload.anchor, expression = payload.expression, enabled = payload.enabled ~= false })
        local _, reload_err = persist(lines, previous_lines)
        if reload_err then return send(400, { error = reload_err }) end
        return send(200, { message = "Regex rule added", id = payload.id })
    end
    if method == "DELETE" then
        if type(payload.id) ~= "string" then return send(400, { error = "id is required" }) end
        local next_lines, found = {}, false
        for _, line in ipairs(lines) do
            local ok, rule = pcall(cjson.decode, line)
            if ok and rule.id == payload.id then found = true else next_lines[#next_lines + 1] = line end
        end
        if not found then return send(404, { error = "Rule not found" }) end
        local _, reload_err = persist(next_lines, lines)
        if reload_err then return send(400, { error = reload_err }) end
        return send(200, { message = "Regex rule deleted", id = payload.id })
    end
    return send(405, { error = "Method not allowed" })
end

return _M
