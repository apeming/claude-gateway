# Keyword Scaling Design

## Context

Claude Gateway currently stores all keywords in `ngx.shared.keywords` and rebuilds
the Aho-Corasick automaton by calling `dict:get_keys(0)` when the keyword
version changes. This works for small keyword sets, but it does not scale well
to hundreds of thousands of keywords.

The target operating model is:

- Keywords are updated by editing `keywords.txt`
- OpenResty is reloaded after batch updates
- Security takes priority over availability
- If the keyword corpus cannot be loaded, requests must be blocked

## Goals

- Support hundreds of thousands of keywords without runtime full-dictionary scans
- Keep request-path matching fast and predictable
- Preserve the current keyword file format and request blocking behavior
- Fail closed when keyword loading is broken
- Expose lightweight operational status through health checks

## Non-Goals

- No external keyword store
- No paginated keyword browsing API
- No high-frequency online keyword mutation workflow
- No fallback to a stale automaton after load failure

## Recommended Approach

Treat `keywords.txt` as the only source of truth for the keyword corpus.
Workers build their local Aho-Corasick automaton directly from the file instead
of reconstructing it from `ngx.shared.keywords`.

`ngx.shared` remains useful, but only for lightweight metadata:

- `keyword_version`
- `keywords_loaded`
- `keywords_status`
- `keywords_last_loaded_at`
- `keywords_load_error`

This removes the main scalability bottleneck from the request path and aligns
with the intended operational model of batch file updates plus reload.

## Design

### 1. Keyword Load Model

`openresty/lua/filter/keyword_filter.lua` will own automaton lifecycle.

Each worker keeps a local cache in `package.loaded.ac_cache` with:

- compiled automaton
- loaded version
- loaded keyword count
- load status
- last load timestamp
- last load error

When a request arrives:

1. Read `keyword_version` from shared metadata
2. If the local cache is missing or the version changed, reload from
   `keywords.txt`
3. Parse the file line by line, trim surrounding whitespace, ignore empty lines
4. Build a new Aho-Corasick automaton from the parsed list
5. Publish metadata into shared dictionaries
6. Use the compiled automaton for matching

Workers never call `ngx.shared.keywords:get_keys(0)` during request filtering.

### 2. Failure Strategy

This system must fail closed.

If a worker cannot produce a valid automaton because the keyword file is
missing, unreadable, empty, or AC construction fails:

- the worker marks keyword status as failed
- the worker stores a Chinese error string in shared metadata
- request filtering returns a blocking response immediately
- the response status is `400`
- the response body is Chinese and explains that the keyword library failed to
  load and the administrator must check the file

External response content should remain safe and general. Detailed failure data
belongs in logs and health metadata, not in user-facing responses.

Example response:

`关键词库加载失败，请联系管理员检查关键词文件是否存在、可读且格式正确。`

### 3. Health Check Contract

`openresty/lua/admin/health_check.lua` should stop scanning the keyword corpus.

It will report lightweight metadata instead:

- `keywords_loaded`
- `keyword_version`
- `keywords_status`
- `keywords_last_loaded_at`
- `keywords_load_error`

This keeps health checks cheap even when the corpus contains hundreds of
thousands of keywords.

### 4. Keyword Management API

`/keywords` is no longer treated as the primary large-scale management path.

#### GET `/keywords`

Change the default response from full keyword enumeration to metadata output.

Recommended fields:

- `keywords_loaded`
- `keyword_version`
- `keywords_status`
- `keywords_last_loaded_at`
- `keywords_load_error`

This avoids building a huge response body for very large keyword sets.

#### POST `/keywords`

Keep this endpoint for small-scale maintenance.

Required updates:

- append to `keywords.txt`
- increment `keyword_version`
- update lightweight metadata explicitly

This endpoint is still valid for small changes, but not the recommended path for
large batches.

#### DELETE `/keywords`

Keep this endpoint for small-scale maintenance only.

Required updates:

- rewrite `keywords.txt`
- increment `keyword_version`
- update lightweight metadata explicitly

This remains operationally expensive for large files and is intentionally not
optimized as a bulk workflow.

### 5. Shared Metadata Initialization

Startup and reload logic in `openresty/nginx.conf` should initialize metadata,
not populate `ngx.shared.keywords` with the full corpus.

At startup:

- initialize `keyword_version` if absent
- initialize `keywords_status`
- initialize `keywords_loaded`
- initialize `keywords_last_loaded_at`
- initialize `keywords_load_error`

The actual keyword corpus is loaded by workers through the file-based loader.

### 6. Matching Semantics

Request blocking semantics stay the same:

- empty request bodies pass
- non-empty request bodies are scanned with the compiled automaton
- first detected match blocks the request
- response remains a human-readable Chinese security message

The only new behavior is that a broken keyword corpus also blocks requests.

## Error Handling

### File Missing or Unreadable

- mark status as failed
- record Chinese load error metadata
- log the concrete filesystem error
- block requests with status `400`

### Automaton Build Failure

- mark status as failed
- record Chinese load error metadata
- log the concrete build error
- block requests with status `400`

### Shared-Metadata Write Failure

Metadata write failures should be logged. They should not silently corrupt the
loader state. If core load state cannot be represented safely, request filtering
should treat the loader as failed and block requests.

### Admin API File Write Failure

If `/keywords` POST or DELETE cannot persist to file, return a clear error and
do not claim success.

## Testing Strategy

### Functional Tests

- Load a valid `keywords.txt` and confirm matching still blocks requests
- Change `keyword_version`, reload, and confirm new keywords take effect
- Verify empty request bodies still pass

### Failure Tests

- Missing keyword file causes `400` responses with Chinese error text
- Unreadable keyword file causes `400` responses with Chinese error text
- Invalid corpus or AC build failure causes `400` responses with Chinese error
  text
- Health check reports failed status and the last load error

### Admin API Tests

- `GET /keywords` returns metadata instead of full keyword list
- `POST /keywords` still supports small additions
- `DELETE /keywords` still supports small removals
- metadata write failure paths return errors instead of false success

## Migration Notes

- Existing `keywords.txt` format remains unchanged
- Existing request filtering behavior remains unchanged for healthy keyword
  corpora
- Operators should treat `/keywords` POST and DELETE as small-scale maintenance
  tools, not bulk loaders
- Bulk updates should continue to use file replacement plus OpenResty reload

## Implementation Outline

1. Refactor `keyword_filter.lua` to load from file and cache per worker
2. Add fail-closed response path for loader failure
3. Replace health-check keyword counting with metadata reads
4. Change `/keywords` GET to metadata output
5. Harden `/keywords` POST and DELETE error handling
6. Update tests to cover healthy and failed load states
