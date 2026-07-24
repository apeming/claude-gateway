local _M = {}
local regex_rules = require "filter.regex_rules"
local numeric_keyword_context = require "filter.numeric_keyword_context"

local KEYWORDS_FILE = "/etc/openresty/keywords.txt"
local VERSION_KEY = "version"
local STATUS_INIT = "init"
local STATUS_LOADING = "loading"
local STATUS_READY = "ready"
local STATUS_FAILED = "failed"
local DEFAULT_KEYWORD_CHUNK_SIZE = 50000

local function cache()
    if not package.loaded.keyword_loader_cache then
        package.loaded.keyword_loader_cache = {
            matchers = nil,
            numeric_keywords = nil,
            numeric_keyword_lengths = nil,
            regex_snapshot = nil,
            anchor_matcher = nil,
            regex_version = 0,
            version = 0,
            loaded = 0,
            chunks = 0,
            status = STATUS_INIT,
            last_loaded_at = "",
            load_error = "",
            loading = false
        }
    end

    return package.loaded.keyword_loader_cache
end

local function version_dict()
    return ngx.shared.keyword_version
end

local function current_version()
    return version_dict():get(VERSION_KEY) or 1
end

local function update_metadata(version, loaded, status, last_loaded_at, load_error)
    local dict = version_dict()

    dict:set(VERSION_KEY, version)
    dict:set("keyword_backend", "lua")
    dict:set("keywords_loaded", loaded or 0)
    dict:set("keywords_status", status or STATUS_INIT)
    dict:set("keywords_last_loaded_at", last_loaded_at or "")
    dict:set("keywords_load_error", load_error or "")
end

local function keyword_chunk_size()
    local raw = os.getenv("KEYWORD_CHUNK_SIZE")
    if not raw or raw == "" then
        return DEFAULT_KEYWORD_CHUNK_SIZE
    end

    local size = tonumber(raw)
    if not size or size < 1 then
        return nil, "KEYWORD_CHUNK_SIZE 非法: " .. tostring(raw)
    end

    return math.floor(size)
end

local function build_chunk_matcher(ahocorasick, keywords)
    local ok, matcher_or_err = pcall(ahocorasick.create, keywords)
    if not ok or not matcher_or_err then
        local detail = ok and "unknown error" or tostring(matcher_or_err)
        return nil, "构建关键词自动机失败: " .. detail
    end

    return matcher_or_err
end

local function is_numeric_keyword(keyword)
    return keyword:match("^%d+$") ~= nil
end

local function is_ascii_digit(byte)
    return byte and byte >= 48 and byte <= 57
end

local function add_numeric_keyword(numeric_keywords, numeric_keyword_lengths, keyword)
    local length = #keyword
    if not numeric_keywords[length] then
        numeric_keywords[length] = {}
        numeric_keyword_lengths[#numeric_keyword_lengths + 1] = length
    end
    numeric_keywords[length][keyword] = true
end

local function has_loaded_keywords(state)
    return (state.matchers and #state.matchers > 0)
        or (state.numeric_keyword_lengths and #state.numeric_keyword_lengths > 0)
end

local function find_numeric_match(data, numeric_keywords, numeric_keyword_lengths)
    if not numeric_keyword_lengths or #numeric_keyword_lengths == 0 then
        return nil
    end

    local position = 1
    while position <= #data do
        if is_ascii_digit(data:byte(position)) then
            local run_start = position
            repeat
                position = position + 1
            until position > #data or not is_ascii_digit(data:byte(position))

            local run_end = position - 1
            local run_length = run_end - run_start + 1
            for _, keyword_length in ipairs(numeric_keyword_lengths) do
                if keyword_length <= run_length then
                    -- A valid candidate must have fewer than four preceding digits and
                    -- fewer than three trailing digits in its contiguous digit run.
                    local first_offset = math.max(0, run_length - keyword_length - 2)
                    local last_offset = math.min(3, run_length - keyword_length)
                    local keywords = numeric_keywords[keyword_length]

                    for offset = first_offset, last_offset do
                        local begin_index = run_start + offset
                        local end_index = begin_index + keyword_length - 1
                        local candidate = data:sub(begin_index, end_index)
                        if keywords[candidate]
                            and not numeric_keyword_context.should_skip(data, begin_index - 1, end_index - 1) then
                            return candidate
                        end
                    end
                end
            end
        else
            position = position + 1
        end
    end

    return nil
end

local function build_anchor_matcher(ahocorasick, anchors)
    if #anchors == 0 then
        return nil
    end
    return build_chunk_matcher(ahocorasick, anchors)
end

local function load_ahocorasick()
    local ok, module_or_err = pcall(require, "ahocorasick")
    if not ok then
        return nil, "加载 ahocorasick 模块失败: " .. tostring(module_or_err)
    end

    return module_or_err
end

local function apply_failed_state(target_version, err)
    local state = cache()
    local chunk_size = keyword_chunk_size() or DEFAULT_KEYWORD_CHUNK_SIZE

    state.matchers = nil
    state.numeric_keywords = nil
    state.numeric_keyword_lengths = nil
    state.version = target_version
    state.loaded = 0
    state.chunks = 0
    state.status = STATUS_FAILED
    state.load_error = err
    state.loading = false

    update_metadata(target_version, 0, STATUS_FAILED, state.last_loaded_at, err)
    version_dict():set("keyword_matcher_chunks", 0)
    version_dict():set("keyword_chunk_size", chunk_size)
    ngx.log(ngx.ERR, "Keyword load failed: ", err)

    return nil, err
end

local function build_for_version(target_version)
    local ahocorasick, module_err = load_ahocorasick()
    if not ahocorasick then
        return apply_failed_state(target_version, module_err)
    end

    local regex_snapshot, regex_err = regex_rules.load()
    if not regex_snapshot then
        version_dict():set("regex_rules_status", STATUS_FAILED)
        version_dict():set("regex_rules_load_error", regex_err)
        return apply_failed_state(target_version, regex_err)
    end

    local chunk_size, chunk_err = keyword_chunk_size()
    if not chunk_size then
        return apply_failed_state(target_version, chunk_err)
    end

    local handle, err = io.open(KEYWORDS_FILE, "r")
    if not handle then
        return apply_failed_state(target_version, "关键词文件不存在或不可读: " .. (err or "unknown error"))
    end

    local matchers = {}
    local numeric_keywords = {}
    local numeric_keyword_lengths = {}
    local keywords = {}
    local loaded = 0
    local chunks = 0
    local saw_keyword = false

    local function flush_chunk()
        if #keywords == 0 then
            return true
        end

        local literal_keywords = {}
        for _, keyword in ipairs(keywords) do
            if is_numeric_keyword(keyword) then
                add_numeric_keyword(numeric_keywords, numeric_keyword_lengths, keyword)
            else
                literal_keywords[#literal_keywords + 1] = keyword
            end
        end

        chunks = chunks + 1
        if #literal_keywords > 0 then
            local matcher, build_err = build_chunk_matcher(ahocorasick, literal_keywords)
            if not matcher then
                return nil, build_err
            end
            matchers[#matchers + 1] = matcher
        end
        keywords = {}

        -- 构建下一块前主动回收上一块的临时字符串表，降低启动峰值内存。
        collectgarbage("collect")
        return true
    end

    for line in handle:lines() do
        local keyword = line:match("^%s*(.-)%s*$")
        if keyword ~= "" then
            saw_keyword = true
            loaded = loaded + 1
            keywords[#keywords + 1] = keyword

            if #keywords >= chunk_size then
                local ok, flush_err = flush_chunk()
                if not ok then
                    handle:close()
                    return apply_failed_state(target_version, flush_err)
                end
            end
        end
    end

    handle:close()

    if not saw_keyword then
        return apply_failed_state(target_version, "关键词文件为空")
    end

    local ok, flush_err = flush_chunk()
    if not ok then
        return apply_failed_state(target_version, flush_err)
    end

    local anchor_matcher, anchor_err = build_anchor_matcher(ahocorasick, regex_snapshot.anchors)
    if #regex_snapshot.anchors > 0 then
        if not anchor_matcher then
            return apply_failed_state(target_version, anchor_err)
        end
    end

    local loaded_at = ngx.localtime()
    local state = cache()

    table.sort(numeric_keyword_lengths, function(left, right)
        return left > right
    end)

    state.matchers = matchers
    state.numeric_keywords = numeric_keywords
    state.numeric_keyword_lengths = numeric_keyword_lengths
    state.regex_snapshot = regex_snapshot
    state.anchor_matcher = anchor_matcher
    state.regex_version = target_version
    state.version = target_version
    state.loaded = loaded
    state.chunks = chunks
    state.status = STATUS_READY
    state.last_loaded_at = loaded_at
    state.load_error = ""
    state.loading = false

    update_metadata(target_version, loaded, STATUS_READY, loaded_at, "")
    version_dict():set("keyword_matcher_chunks", chunks)
    version_dict():set("keyword_chunk_size", chunk_size)
    version_dict():set("regex_rules_loaded", #regex_snapshot.rules)
    version_dict():set("regex_rules_status", STATUS_READY)
    version_dict():set("regex_rules_last_loaded_at", loaded_at)
    version_dict():set("regex_rules_load_error", "")
    version_dict():set("regex_rules_version", target_version)
    version_dict():set("regex_pattern_bytes", regex_snapshot.pattern_bytes)

    return {
        keyword_backend = "lua",
        keyword_version = target_version,
        keywords_loaded = loaded,
        keyword_matcher_chunks = chunks,
        keyword_chunk_size = chunk_size,
        keywords_status = STATUS_READY,
        keywords_last_loaded_at = loaded_at,
        keywords_load_error = ""
    }
end

local function schedule_reload(target_version)
    local state = cache()

    if state.loading and state.version == target_version then
        return true
    end

    state.matchers = nil
    state.numeric_keywords = nil
    state.numeric_keyword_lengths = nil
    state.regex_snapshot = nil
    state.anchor_matcher = nil
    state.version = target_version
    state.loaded = 0
    state.chunks = 0
    state.status = STATUS_LOADING
    state.load_error = ""
    state.loading = true

    update_metadata(target_version, 0, STATUS_LOADING, state.last_loaded_at, "")
    version_dict():set("keyword_matcher_chunks", 0)
    version_dict():set("keyword_chunk_size", keyword_chunk_size() or DEFAULT_KEYWORD_CHUNK_SIZE)

    local ok, err = ngx.timer.at(0, function(premature, version)
        if premature then
            return
        end

        build_for_version(version)
    end, target_version)

    if not ok then
        return apply_failed_state(target_version, "调度关键词加载失败: " .. (err or "unknown error"))
    end

    return true
end

function _M.init_worker()
    local dict = version_dict()

    if dict:get(VERSION_KEY) == nil then
        update_metadata(1, 0, STATUS_INIT, "", "")
        dict:set("regex_rules_status", STATUS_INIT)
        dict:set("regex_rules_loaded", 0)
        dict:set("regex_rules_version", 1)
        dict:set("regex_rules_last_loaded_at", "")
        dict:set("regex_rules_load_error", "")
        dict:set("regex_pattern_bytes", 0)
    else
        if dict:get("keyword_backend") == nil then
            dict:set("keyword_backend", "lua")
        end
        if dict:get("keywords_loaded") == nil then
            dict:set("keywords_loaded", 0)
        end
        if dict:get("keywords_status") == nil then
            dict:set("keywords_status", STATUS_INIT)
        end
        if dict:get("keyword_matcher_chunks") == nil then
            dict:set("keyword_matcher_chunks", 0)
        end
        if dict:get("keyword_chunk_size") == nil then
            dict:set("keyword_chunk_size", keyword_chunk_size() or DEFAULT_KEYWORD_CHUNK_SIZE)
        end
        if dict:get("keywords_last_loaded_at") == nil then
            dict:set("keywords_last_loaded_at", "")
        end
        if dict:get("keywords_load_error") == nil then
            dict:set("keywords_load_error", "")
        end
    end

    schedule_reload(current_version())
end

function _M.read_metadata()
    local dict = version_dict()

    return {
        keyword_backend = dict:get("keyword_backend") or "lua",
        keyword_version = dict:get(VERSION_KEY) or 1,
        keywords_loaded = dict:get("keywords_loaded") or 0,
        keyword_matcher_chunks = dict:get("keyword_matcher_chunks") or 0,
        keyword_chunk_size = dict:get("keyword_chunk_size") or (keyword_chunk_size() or DEFAULT_KEYWORD_CHUNK_SIZE),
        keywords_status = dict:get("keywords_status") or STATUS_INIT,
        keywords_last_loaded_at = dict:get("keywords_last_loaded_at") or "",
        keywords_load_error = dict:get("keywords_load_error") or ""
        ,regex_rules_loaded = dict:get("regex_rules_loaded") or 0
        ,regex_rules_version = dict:get("regex_rules_version") or 1
        ,regex_rules_status = dict:get("regex_rules_status") or STATUS_INIT
        ,regex_rules_last_loaded_at = dict:get("regex_rules_last_loaded_at") or ""
        ,regex_rules_load_error = dict:get("regex_rules_load_error") or ""
        ,regex_pattern_bytes = dict:get("regex_pattern_bytes") or 0
    }
end

function _M.ensure_ready()
    local state = cache()
    local version = current_version()
    local regex_version = version_dict():get("regex_rules_version") or 1

    if state.version ~= version then
        local ok, err = schedule_reload(version)
        if not ok then
            return false, err
        end
        return false, "关键词库加载中"
    end

    if state.status == STATUS_READY and has_loaded_keywords(state) then
        if state.regex_version ~= regex_version then
            local _, regex_err = _M.reload_regex(regex_version)
            if regex_err then
                return false, regex_err
            end
        end
        return true
    end

    if state.status == STATUS_FAILED then
        return false, state.load_error ~= "" and state.load_error or "关键词库加载失败"
    end

    if state.status == STATUS_LOADING then
        return false, "关键词库加载中"
    end

    local ok, err = schedule_reload(version)
    if not ok then
        return false, err
    end

    return false, "关键词库加载中"
end

function _M.reload()
    return build_for_version(current_version() + 1)
end

function _M.reload_regex(version)
    local state = cache()
    if state.status ~= STATUS_READY or not has_loaded_keywords(state) then
        return nil, "关键词库未就绪"
    end
    local ahocorasick, module_err = load_ahocorasick()
    if not ahocorasick then
        return nil, module_err
    end
    local snapshot, load_err = regex_rules.load()
    if not snapshot then
        return nil, load_err
    end
    local matcher, matcher_err = build_anchor_matcher(ahocorasick, snapshot.anchors)
    if #snapshot.anchors > 0 and not matcher then
        return nil, matcher_err
    end
    state.regex_snapshot = snapshot
    state.anchor_matcher = matcher
    version = version or ((version_dict():get("regex_rules_version") or 0) + 1)
    state.regex_version = version
    local loaded_at = ngx.localtime()
    local dict = version_dict()
    dict:set("regex_rules_loaded", #snapshot.rules)
    dict:set("regex_rules_status", STATUS_READY)
    dict:set("regex_rules_last_loaded_at", loaded_at)
    dict:set("regex_rules_load_error", "")
    dict:set("regex_rules_version", version)
    dict:set("regex_pattern_bytes", snapshot.pattern_bytes)
    return _M.read_metadata()
end

function _M.find_match(data)
    if not data or data == "" then
        return nil, nil
    end

    local ready, err = _M.ensure_ready()
    if not ready then
        return nil, err
    end

    local ahocorasick, module_err = load_ahocorasick()
    if not ahocorasick then
        return nil, module_err
    end

    local state = cache()
    for _, matcher in ipairs(state.matchers or {}) do
        local begin_offset, end_offset = ahocorasick.match(matcher, data)
        if begin_offset and end_offset then
            return { kind = "literal", value = data:sub(begin_offset + 1, end_offset + 1) }, nil
        end
    end

    local numeric_match = find_numeric_match(data, state.numeric_keywords, state.numeric_keyword_lengths)
    if numeric_match then
        return { kind = "literal", value = numeric_match }, nil
    end

    if state.anchor_matcher then
        local anchor_begin = ahocorasick.match(state.anchor_matcher, data)
        if anchor_begin then
            local rule_id, matched_value, regex_err = regex_rules.find_match(state.regex_snapshot, data)
            if regex_err then
                return nil, regex_err
            end
            if rule_id then
                return { kind = "anchored_regex", id = rule_id, value = matched_value }, nil
            end
        end
    end

    return nil, nil
end

return _M
