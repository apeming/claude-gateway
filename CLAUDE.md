# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Gateway is a high-performance API gateway built on OpenResty/Nginx + Lua, designed to proxy Claude API requests with keyword filtering, dynamic routing, and intelligent retry mechanisms. The project uses a modular Lua architecture that reduced the nginx.conf from 1041 lines to 269 lines (74% reduction).

**Core Purpose**: Protect sensitive information from being sent to third-party AI services by filtering keywords (especially prefixes of API keys, tokens, passwords) while providing flexible routing and retry capabilities.

## Build & Development Commands

### Docker Compose
```bash
# Start service
docker compose up -d

# Stop service
docker compose down

# View logs
docker compose logs -f

# Rebuild image
docker compose build --no-cache
```

### Makefile Commands (Recommended)
```bash
make help          # Show all available commands
make deploy        # Build + start + health check
make up            # Start service
make down          # Stop service
make restart       # Restart service
make logs          # View logs (follow mode)
make ps            # Show service status
make health        # Detailed health check
make health-quick  # Quick health check
make shell         # Enter container shell
make token         # Generate random API token
make clean         # Clean containers and images
make host-up       # Start with host network mode
```

### Testing
```bash
cd tests/
npm install

# Run API Key mode tests (x-api-key authentication)
export ANTHROPIC_AUTH_TOKEN=your-api-key
npm run test:apikey

# Run Authorization Token mode tests
export ANTHROPIC_AUTH_TOKEN=your-auth-token
npm run test:api

# Run all tests
npm test
```

### CLI Tools
```bash
cd tools/

# Install CLI tool
./install.sh

# Configure API connection
keywords config

# Manage keywords
keywords add "sensitive-prefix"
keywords del "old-prefix"
keywords list
keywords import sample-keywords.txt
keywords export backup.txt

# Manage routes
routes config
routes add cr_1 http://backend1.example.com/api
routes list
```

## Architecture

### Modular Lua Structure

The codebase follows a highly modular architecture with 9 independent Lua modules:

```
openresty/lua/
├── utils/
│   ├── body_reader.lua      # Request body reading (supports large files)
│   └── brotli.lua           # Brotli decompression for retry responses
├── filter/
│   └── keyword_filter.lua   # Keyword filtering using Aho-Corasick algorithm
├── router/
│   └── dynamic_router.lua   # Dynamic routing (Authorization & x-api-key)
├── proxy/
│   └── http_proxy.lua       # HTTP proxy (streaming & non-streaming)
├── handler/
│   ├── api_handler.lua      # API request handler (orchestrates modules)
│   └── retry_handler.lua    # Retry handler (400 errors with exponential backoff)
└── admin/
    ├── health_check.lua     # Health check endpoint
    ├── keyword_manager.lua  # Keyword management API
    └── route_manager.lua    # Route management API
```

### Request Flow

**Standard Flow** (`/api/v1/messages` with retry):
1. `retry_handler.lua` → Retry wrapper (up to 10 times for 400 errors)
2. `body_reader.lua` → Read request body (handles large files from temp storage)
3. `keyword_filter.lua` → Check for sensitive keywords using AC automaton
4. `dynamic_router.lua` → Route based on Authorization token
5. `http_proxy.lua` → Proxy to upstream (non-streaming)

**API Key Flow** (`/apikey/v1/messages`):
1. `api_handler.lua` → Entry point
2. `body_reader.lua` → Read request body
3. `keyword_filter.lua` → Keyword filtering
4. `dynamic_router.lua` → Route based on x-api-key header
5. `http_proxy.lua` → Proxy (streaming or non-streaming based on `stream` field)

**Generic Proxy** (`/api/*`):
- Uses nginx `proxy_pass` for better performance
- Still includes keyword filtering and dynamic routing in `access_by_lua_block`
- No retry mechanism

### Configuration Files

**Location**: `./openresty/` (mounted to `/etc/openresty/` in container)

- **keywords.txt**: One keyword per line, used for prefix matching of sensitive data
- **routes.txt**: Format `<token> <upstream_url>`, maps auth tokens to backend URLs
- **nginx.conf**: Main nginx configuration (269 lines)
- **conf.d/default.conf**: Server block with location definitions (135 lines)

### Environment Variables

Set in `.env` file:

- `API_TOKEN`: Management API authentication token (required, generate with `make token`)
- `ENABLE_DYNAMIC_ROUTING`: `true` or `false` (default: `false`)
- `UPSTREAM_URL`: Default upstream URL when dynamic routing is disabled (default: `https://api.anthropic.com`)
- `HOST_PORT`: Host port mapping (default: `80`)
- `CONFIG_DIR`: Config directory path (default: `./openresty`)

### Shared Memory Dictionaries

Defined in `nginx.conf`:

- `keywords` (1MB): Stores keyword list
- `keyword_version` (128KB): Version number to trigger AC automaton rebuild
- `api_config` (128KB): Stores API_TOKEN, UPSTREAM_URL, routing config

## Key Features & Implementation Details

### 1. Keyword Filtering (Aho-Corasick)

**Purpose**: Prevent sensitive information (API keys, tokens, passwords) from being sent to third-party services.

**Implementation**: `openresty/lua/filter/keyword_filter.lua`
- Uses Aho-Corasick algorithm for O(m) time complexity
- AC automaton is cached at worker level in `package.loaded.ac_cache`
- Automatically rebuilds when `keyword_version` changes
- Recommended: Use 8-15 character prefixes of sensitive data

**When blocked**: Returns 403 with message suggesting user execute `/clear` to remove context pollution.

### 2. Dynamic Routing

**Two modes**:

**Mode 1: Dynamic Routing Enabled** (`ENABLE_DYNAMIC_ROUTING=true`)
- Requires Authorization header or x-api-key
- Token must exist in `routes.txt`
- Routes to corresponding backend URL
- Unmapped tokens return 401

**Mode 2: Default Mode** (`ENABLE_DYNAMIC_ROUTING=false`)
- No authentication required
- All requests use `UPSTREAM_URL`
- `routes.txt` is ignored

**Path Rewriting**:
- Client requests use `/api/*` or `/apikey/*` paths
- Gateway replaces prefix with upstream's base_path
- Example: `/api/v1/messages` + `http://backend.com/api` → `http://backend.com/api/v1/messages`

### 3. Intelligent Retry Mechanism

**Location**: `openresty/lua/handler/retry_handler.lua`

**Trigger**: HTTP 400 error with "unavailable" in response body
**Strategy**: Exponential backoff (2^n seconds, max 10 retries)
**Compression**: Automatically decompresses Brotli/Gzip responses before checking content

**Use case**: Claude API temporary unavailability, upstream overload, transient network issues.

### 4. Dual Authentication Modes

**Authorization Token Mode** (`/api/v1/messages`):
- Header: `Authorization: Bearer <token>` or `Authorization: <token>`
- Supports retry mechanism
- Routes based on token in `routes.txt`

**API Key Mode** (`/apikey/v1/messages`):
- Header: `x-api-key: <api-key>`
- Compatible with Anthropic official API
- Supports streaming responses
- Routes based on api-key in `routes.txt`

### 5. Management APIs

All management endpoints require authentication via `X-API-Key` or `Authorization` header.

**Keyword Management**:
- `GET /keywords` - List all keywords
- `POST /keywords` - Add keyword from JSON body
- `DELETE /keywords` - Delete keyword from JSON body

**Route Management**:
- `GET /route/list` - List all routes (JSON)
- `POST /route/add` - Add route (JSON body: `{token, url}`)
- `POST /route/del` - Delete route (JSON body: `{token}`)
- `POST /route/update` - Update route (JSON body: `{token, url}`)
- `POST /route/reload` - Reload from routes.txt file

## Common Development Patterns

### Adding a New Lua Module

1. Create module file in appropriate subdirectory under `openresty/lua/`
2. Follow the module pattern:
```lua
local _M = {}

function _M.your_function()
    -- implementation
end

return _M
```
3. Require in nginx location block or other modules:
```lua
local your_module = require "category.your_module"
your_module.your_function()
```

### Modifying Request Processing

The request processing pipeline is in `openresty/lua/handler/api_handler.lua`. To add a new processing step:

1. Create a new module in appropriate category
2. Import in `api_handler.lua`
3. Call in the appropriate handler function (`handle_auth_token_request` or `handle_api_key_request`)

### Adding a New API Endpoint

1. Add location block in `openresty/conf.d/default.conf`
2. Create handler in appropriate Lua module
3. Use `content_by_lua_block` to call handler

Example:
```nginx
location /your/endpoint {
    content_by_lua_block {
        local your_handler = require "category.your_handler"
        your_handler.handle()
    }
}
```

### Testing Changes

1. Modify code in `./openresty/` directory
2. Restart container: `make restart`
3. Check logs: `make logs`
4. Run health check: `make health`
5. Run test suite: `cd tests && npm test`

## Important Notes

- **Never commit `.env` file** - Contains sensitive API tokens
- **Keyword prefix length**: 8-15 characters recommended (balance between security and false positives)
- **Streaming responses**: Currently uses `request_uri` which waits for full response before forwarding
- **Worker-level caching**: AC automaton is cached per worker in `package.loaded.ac_cache`
- **Config hot reload**: Keywords and routes can be updated via API without restart
- **Large request bodies**: Automatically handled by reading from temp files when body exceeds buffer size
- **DNS resolver**: Configured in `default.conf` for dynamic proxy_pass (223.5.5.5, 114.114.114.114)

## Production Deployment

- Use HTTPS via reverse proxy (nginx/caddy)
- Generate strong API_TOKEN (32+ characters): `make token`
- Set resource limits in docker-compose.yml (default: 1 CPU, 512MB RAM)
- Enable structured logging for monitoring
- Use external Docker network for microservices integration
- Configure health checks for container orchestration (`/health` endpoint)
- Regularly rotate API tokens
- Monitor keyword filter effectiveness via logs

## Documentation

- `README.md` - Comprehensive project documentation (Chinese)
- `QUICKSTART.md` - 3-minute quick start guide
- `docs/ARCHITECTURE.md` - Detailed architecture explanation
- `tests/README.md` - Test suite documentation
- `tests/TEST_API.md` - Authorization Token mode tests
- `tests/TEST_APIKEY.md` - API Key mode tests
- `tools/README.md` - CLI tools usage guide
