local _M = {}

-- 基于 Authorization token 的路由
function _M.route_by_auth_token(path_prefix)
    local config_dict = ngx.shared.api_config
    local auth_route_enabled = config_dict:get("auth_route_enabled")

    if auth_route_enabled ~= "true" then
        local upstream_url = config_dict:get("upstream_url") or "https://api.anthropic.com"
        return _M.build_full_url(upstream_url, path_prefix, ngx.var.request_uri)
    end

    local auth_header = ngx.var.http_authorization
    local auth_token = nil

    if auth_header then
        if auth_header:match("^Bearer%s+") then
            auth_token = auth_header:gsub("^Bearer%s+", "")
        else
            auth_token = auth_header
        end
    end

    if not auth_token or auth_token == "" then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.header["WWW-Authenticate"] = 'Bearer realm="API"'
        ngx.say('{"error": "Unauthorized", "message": "Missing authorization token", "timestamp": "' .. ngx.localtime() .. '"}')
        return nil
    end

    local route_key = "route:" .. auth_token
    local upstream_url = config_dict:get(route_key)

    if not upstream_url then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say('{"error": "Unauthorized", "message": "Invalid authorization token", "timestamp": "' .. ngx.localtime() .. '"}')
        return nil
    end

    ngx.log(ngx.INFO, "Authorization matched, routing to: " .. upstream_url)
    return _M.build_full_url(upstream_url, path_prefix, ngx.var.request_uri)
end

-- 基于 x-api-key 的路由
function _M.route_by_api_key(path_prefix)
    local config_dict = ngx.shared.api_config
    local auth_route_enabled = config_dict:get("auth_route_enabled")

    if auth_route_enabled ~= "true" then
        local upstream_url = config_dict:get("upstream_url") or "https://api.anthropic.com"
        return _M.build_full_url(upstream_url, path_prefix, ngx.var.request_uri)
    end

    local api_key = ngx.var.http_x_api_key

    if not api_key or api_key == "" then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say('{"error": {"type": "authentication_error", "message": "Missing x-api-key header"}}')
        return nil
    end

    local route_key = "route:" .. api_key
    local upstream_url = config_dict:get(route_key)

    if not upstream_url then
        ngx.status = 401
        ngx.header["Content-Type"] = "application/json"
        ngx.say('{"error": {"type": "authentication_error", "message": "Invalid x-api-key"}}')
        return nil
    end

    ngx.log(ngx.INFO, "API Key matched, routing to: " .. upstream_url)
    return _M.build_full_url(upstream_url, path_prefix, ngx.var.request_uri)
end

-- 构建完整 URL
function _M.build_full_url(upstream_url, path_prefix, request_uri)
    local path_suffix = string.gsub(request_uri, "^" .. path_prefix, "")
    upstream_url = string.gsub(upstream_url, "/$", "")
    local full_url = upstream_url .. path_suffix

    ngx.log(ngx.INFO, "Path rewrite: " .. request_uri .. " -> " .. full_url)
    return full_url
end

return _M
