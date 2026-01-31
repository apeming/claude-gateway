local _M = {}

function _M.read_body()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()

    if not data then
        local body_file = ngx.req.get_body_file()
        if body_file then
            local f = io.open(body_file, "rb")
            if f then
                data = f:read("*all")
                f:close()
            end
        end
    end

    return data
end

return _M
