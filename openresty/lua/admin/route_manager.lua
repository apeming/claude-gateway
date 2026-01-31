local cjson = require "cjson"

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
        ngx.say('{"error": "Unauthorized"}')
        return false
    end

    return true
end

-- 列出所有路由
function _M.list()
    if not verify_token() then
        return
    end

    local config_dict = ngx.shared.api_config
    local routes = {}
    local keys = config_dict:get_keys(0)

    for _, key in ipairs(keys) do
        if key:match("^route:") then
            local token = key:gsub("^route:", "")
            local url = config_dict:get(key)
            table.insert(routes, {token = token, url = url})
        end
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        routes = routes,
        count = #routes,
        timestamp = ngx.localtime()
    }))
end

-- 添加路由
function _M.add()
    if not verify_token() then
        return
    end

    ngx.req.read_body()
    local body_data = ngx.req.get_body_data()

    if not body_data then
        ngx.status = 400
        ngx.say('{"error": "Missing request body"}')
        return
    end

    local ok, data = pcall(cjson.decode, body_data)
    if not ok then
        ngx.status = 400
        ngx.say('{"error": "Invalid JSON"}')
        return
    end

    local token = data.token
    local upstream = data.url

    if not token or not upstream then
        ngx.status = 400
        ngx.say('{"error": "Missing token or url"}')
        return
    end

    local config_dict = ngx.shared.api_config
    local route_key = "route:" .. token

    if config_dict:get(route_key) then
        ngx.status = 409
        ngx.say('{"error": "Route already exists"}')
        return
    end

    config_dict:set(route_key, upstream)

    local f = io.open("/etc/openresty/routes.txt", "a+")
    if f then
        f:write(token .. " " .. upstream .. "\n")
        f:close()
    else
        ngx.say('{"error": "Failed to write file"}')
        return
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        success = true,
        message = "Route added successfully",
        token = token,
        url = upstream
    }))
end

-- 删除路由
function _M.delete()
    if not verify_token() then
        return
    end

    ngx.req.read_body()
    local body_data = ngx.req.get_body_data()

    if not body_data then
        ngx.status = 400
        ngx.say('{"error": "Missing request body"}')
        return
    end

    local ok, data = pcall(cjson.decode, body_data)
    if not ok then
        ngx.status = 400
        ngx.say('{"error": "Invalid JSON"}')
        return
    end

    local token = data.token

    if not token then
        ngx.status = 400
        ngx.say('{"error": "Missing token"}')
        return
    end

    local config_dict = ngx.shared.api_config
    local route_key = "route:" .. token

    if not config_dict:get(route_key) then
        ngx.status = 404
        ngx.say('{"error": "Route not found"}')
        return
    end

    config_dict:delete(route_key)

    local route_file = "/etc/openresty/routes.txt"
    local f = io.open(route_file, "r")
    if f then
        local content = {}
        for line in f:lines() do
            local clean_line = line:match("^%s*(.-)%s*$")
            if clean_line ~= "" then
                local file_token = clean_line:match("^(%S+)%s+")
                if file_token ~= token then
                    table.insert(content, line)
                end
            end
        end
        f:close()

        f = io.open(route_file, "w")
        if f then
            for _, line in ipairs(content) do
                f:write(line .. "\n")
            end
            f:close()
        end
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        success = true,
        message = "Route deleted successfully",
        token = token
    }))
end

-- 更新路由
function _M.update()
    if not verify_token() then
        return
    end

    ngx.req.read_body()
    local body_data = ngx.req.get_body_data()

    if not body_data then
        ngx.status = 400
        ngx.say('{"error": "Missing request body"}')
        return
    end

    local ok, data = pcall(cjson.decode, body_data)
    if not ok then
        ngx.status = 400
        ngx.say('{"error": "Invalid JSON"}')
        return
    end

    local token = data.token
    local upstream = data.url

    if not token or not upstream then
        ngx.status = 400
        ngx.say('{"error": "Missing token or url"}')
        return
    end

    local config_dict = ngx.shared.api_config
    local route_key = "route:" .. token

    if not config_dict:get(route_key) then
        ngx.status = 404
        ngx.say('{"error": "Route not found"}')
        return
    end

    config_dict:set(route_key, upstream)

    local route_file = "/etc/openresty/routes.txt"
    local f = io.open(route_file, "r")
    if f then
        local content = {}
        for line in f:lines() do
            local clean_line = line:match("^%s*(.-)%s*$")
            if clean_line ~= "" then
                local file_token = clean_line:match("^(%S+)%s+")
                if file_token == token then
                    table.insert(content, token .. " " .. upstream)
                else
                    table.insert(content, line)
                end
            end
        end
        f:close()

        f = io.open(route_file, "w")
        if f then
            for _, line in ipairs(content) do
                f:write(line .. "\n")
            end
            f:close()
        end
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        success = true,
        message = "Route updated successfully",
        token = token,
        url = upstream
    }))
end

-- 重新加载配置文件
function _M.reload()
    if not verify_token() then
        return
    end

    local config_dict = ngx.shared.api_config
    local route_file = "/etc/openresty/routes.txt"
    local f = io.open(route_file, "r")
    local route_count = 0
    local error_count = 0
    local line_number = 0

    -- 清空现有路由
    local keys = config_dict:get_keys(0)
    for _, key in ipairs(keys) do
        if key:match("^route:") then
            config_dict:delete(key)
        end
    end

    if f then
        for line in f:lines() do
            line_number = line_number + 1
            local clean_line = line:match("^%s*(.-)%s*$")

            if clean_line ~= "" and not clean_line:match("^#") then
                local token, url = clean_line:match("^(%S+)%s+(%S+)$")

                if token and url then
                    local extra = clean_line:match("^%S+%s+%S+%s+(%S)")

                    if extra then
                        error_count = error_count + 1
                    else
                        config_dict:set("route:" .. token, url)
                        route_count = route_count + 1
                    end
                else
                    error_count = error_count + 1
                end
            end
        end
        f:close()
    else
        ngx.status = 500
        ngx.say('{"error": "Failed to read route file"}')
        return
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        success = true,
        message = "Routes reloaded successfully",
        loaded = route_count,
        errors = error_count
    }))
end

return _M
