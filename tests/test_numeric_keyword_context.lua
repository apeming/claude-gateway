local context = require "filter.numeric_keyword_context"

local keyword = "123456"
local cases = {
    { data = "phone123456", skip = false },
    { data = "+1123456", skip = false },
    { data = "+1 123456", skip = false },
    { data = "1234567", skip = false },
    { data = "12345678", skip = false },
    { data = "999 123456", skip = false },
    { data = "11 123456 22", skip = true },
    { data = "9999123456", skip = true },
    { data = "123456789", skip = true },
}

for _, case in ipairs(cases) do
    local begin_offset = assert(case.data:find(keyword, 1, true)) - 1
    local end_offset = begin_offset + #keyword - 1
    local actual = context.should_skip(case.data, begin_offset, end_offset)

    assert(actual == case.skip,
        string.format("expected should_skip(%q) to be %s, got %s", case.data, tostring(case.skip), tostring(actual)))
end

print("numeric keyword context rules are valid")
