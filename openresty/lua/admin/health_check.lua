local _M = {}

function _M.check()
    local dict = ngx.shared.keywords
    local version_dict = ngx.shared.keyword_version
    local config_dict = ngx.shared.api_config

    -- 获取基本状态信息
    local keyword_count = 0
    local keys = dict:get_keys(0)
    if keys then
        keyword_count = #keys
    end

    local version = version_dict:get("version") or 0
    local has_token = config_dict:get("api_token") ~= nil

    -- 统计路由数量
    local auth_route_enabled = config_dict:get("auth_route_enabled")
    local routes_count = 0

    if auth_route_enabled == "true" then
        local keys = config_dict:get_keys(0)
        for _, key in ipairs(keys) do
            if key:match("^route:") then
                routes_count = routes_count + 1
            end
        end
    end

    ngx.status = 200
    ngx.header["Content-Type"] = "application/json"
    ngx.say(string.format([[{
        "status": "healthy",
        "service": "claude-gateway",
        "timestamp": "%s",
        "keywords_loaded": %d,
        "keyword_version": %d,
        "auth_configured": %s,
        "routing_enabled": %s,
        "routes_loaded": %d,
        "upstream_url": "%s",
        "openai_upstream_url": "%s"
    }]], ngx.localtime(), keyword_count, version, has_token and "true" or "false",
    (auth_route_enabled == "true") and "true" or "false", routes_count,
    config_dict:get("upstream_url") or "dynamic",
    config_dict:get("openai_upstream_url") or "dynamic"))
end

return _M
