local cjson = require "cjson"

local _M = {}
local RULES_FILE = "/etc/openresty/regex_rules.jsonl"
local DEFAULT_MAX_RULES = 32
local DEFAULT_MAX_EXPRESSION_BYTES = 1024
local DEFAULT_MAX_TOTAL_EXPRESSION_BYTES = 16384
local DEFAULT_MAX_PATTERN_BYTES = 32768

local function positive_limit(name, default)
    local raw = os.getenv(name)
    if not raw or raw == "" then
        return default
    end
    local value = tonumber(raw)
    if not value or value < 1 then
        return nil, name .. " 非法: " .. tostring(raw)
    end
    return math.floor(value)
end

local function escape_pcre_literal(value)
    return (value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$%{%}%|\\])", function(char)
        return "\\" .. char
    end))
end

local function validate_rule(rule, ids)
    if type(rule) ~= "table" or type(rule.id) ~= "string"
        or not rule.id:match("^[A-Za-z][A-Za-z0-9_-]*$") then
        return nil, "规则 id 非法"
    end
    if ids[rule.id] then
        return nil, "规则 id 重复: " .. rule.id
    end
    if type(rule.anchor) ~= "string" or #rule.anchor < 6 then
        return nil, "规则锚点至少 6 字节"
    end
    if type(rule.expression) ~= "string" or not rule.expression:find("{{anchor}}", 1, true) then
        return nil, "规则表达式必须包含 {{anchor}}"
    end
    if rule.expression:find("\\[1-9]") or rule.expression:find("(?R", 1, true)
        or rule.expression:find("(?0", 1, true) or rule.expression:find("(?&", 1, true)
        or rule.expression:find("(?<=", 1, true) or rule.expression:find("(?<!", 1, true) then
        return nil, "规则使用了不支持的正则特性"
    end

    ids[rule.id] = true
    rule.expression = rule.expression:gsub("{{anchor}}", function()
        return escape_pcre_literal(rule.anchor)
    end)
    rule.enabled = rule.enabled ~= false
    return rule
end

function _M.load()
    local max_rules, limit_err = positive_limit("REGEX_RULE_MAX_COUNT", DEFAULT_MAX_RULES)
    if not max_rules then return nil, limit_err end
    local max_expression_bytes
    max_expression_bytes, limit_err = positive_limit("REGEX_RULE_MAX_EXPRESSION_BYTES", DEFAULT_MAX_EXPRESSION_BYTES)
    if not max_expression_bytes then return nil, limit_err end
    local max_total_bytes
    max_total_bytes, limit_err = positive_limit("REGEX_RULE_MAX_TOTAL_EXPRESSION_BYTES", DEFAULT_MAX_TOTAL_EXPRESSION_BYTES)
    if not max_total_bytes then return nil, limit_err end
    local max_pattern_bytes
    max_pattern_bytes, limit_err = positive_limit("REGEX_RULE_MAX_PATTERN_BYTES", DEFAULT_MAX_PATTERN_BYTES)
    if not max_pattern_bytes then return nil, limit_err end
    local handle, err = io.open(RULES_FILE, "r")
    if not handle then
        if err and err:find("No such file or directory", 1, true) then
            return { rules = {}, anchors = {}, master_pattern = "", pattern_bytes = 0 }
        end
        return nil, "读取正则规则文件失败: " .. (err or "unknown error")
    end

    local rules, anchors, seen_anchors, ids, branches = {}, {}, {}, {}, {}
    local total_expression_bytes = 0
    local line_number = 0
    for line in handle:lines() do
        line_number = line_number + 1
        if line:match("%S") then
            local ok, decoded = pcall(cjson.decode, line)
            if not ok then
                handle:close()
                return nil, "正则规则第 " .. line_number .. " 行不是有效 JSON"
            end
            local rule, rule_err = validate_rule(decoded, ids)
            if not rule then
                handle:close()
                return nil, "正则规则第 " .. line_number .. " 行无效: " .. rule_err
            end
            if rule.enabled then
                if #rule.expression > max_expression_bytes then
                    handle:close()
                    return nil, "正则规则第 " .. line_number .. " 行超过单条表达式长度上限"
                end
                if #rules >= max_rules then
                    handle:close()
                    return nil, "正则规则数量超过上限"
                end
                total_expression_bytes = total_expression_bytes + #rule.expression
                if total_expression_bytes > max_total_bytes then
                    handle:close()
                    return nil, "正则规则表达式总长度超过上限"
                end
                rule.capture_name = "rule_" .. (#rules + 1)
                rules[#rules + 1] = rule
                branches[#branches + 1] = "(?<" .. rule.capture_name .. ">" .. rule.expression .. ")"
                if not seen_anchors[rule.anchor] then
                    seen_anchors[rule.anchor] = true
                    anchors[#anchors + 1] = rule.anchor
                end
            end
        end
    end
    handle:close()

    local master_pattern = #branches > 0 and "(?:" .. table.concat(branches, "|") .. ")" or ""
    if #master_pattern > max_pattern_bytes then
        return nil, "正则规则组合表达式长度超过上限"
    end
    if master_pattern ~= "" then
        local _, compile_err = ngx.re.match("", master_pattern, "ujo")
        if compile_err then
            return nil, "正则规则编译失败: " .. compile_err
        end
    end

    return { rules = rules, anchors = anchors, master_pattern = master_pattern, pattern_bytes = #master_pattern }
end

function _M.find_match(snapshot, data)
    if snapshot.master_pattern == "" then
        return nil
    end
    local captures, err = ngx.re.match(data, snapshot.master_pattern, "ujo")
    if err then
        return nil, nil, "正则规则匹配失败: " .. err
    end
    if not captures then
        return nil
    end
    for _, rule in ipairs(snapshot.rules) do
        if captures[rule.capture_name] then
            return rule.id, captures[rule.capture_name]
        end
    end
    return nil
end

return _M
