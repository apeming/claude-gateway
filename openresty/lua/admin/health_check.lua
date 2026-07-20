local cjson = require "cjson"

local _M = {}

function _M.check()
    local config_dict = ngx.shared.api_config
    local keyword_loader = require "filter.keyword_loader"
    local metadata = keyword_loader.read_metadata()

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

    local status = "healthy"
    if metadata.keywords_status == "ready" then
        ngx.status = 200
    else
        ngx.status = 503
        status = "unhealthy"
    end
    ngx.header["Content-Type"] = "application/json"
    ngx.say(cjson.encode({
        status = status,
        service = "claude-gateway",
        timestamp = ngx.localtime(),
        keyword_backend = metadata.keyword_backend,
        keywords_loaded = metadata.keywords_loaded,
        keyword_matcher_chunks = metadata.keyword_matcher_chunks,
        keyword_chunk_size = metadata.keyword_chunk_size,
        keyword_version = metadata.keyword_version,
        keywords_status = metadata.keywords_status,
        keywords_last_loaded_at = metadata.keywords_last_loaded_at,
        keywords_load_error = metadata.keywords_load_error,
        regex_rules_loaded = metadata.regex_rules_loaded,
        regex_rules_version = metadata.regex_rules_version,
        regex_rules_status = metadata.regex_rules_status,
        regex_rules_last_loaded_at = metadata.regex_rules_last_loaded_at,
        regex_rules_load_error = metadata.regex_rules_load_error,
        regex_pattern_bytes = metadata.regex_pattern_bytes,
        auth_configured = has_token,
        routing_enabled = auth_route_enabled == "true",
        routes_loaded = routes_count,
        upstream_url = config_dict:get("upstream_url") or "dynamic",
        openai_upstream_url = config_dict:get("openai_upstream_url") or "dynamic"
    }))
end

return _M
