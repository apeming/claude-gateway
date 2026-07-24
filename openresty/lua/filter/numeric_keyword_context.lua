local _M = {}

local RELAXED_LEFT_DIGITS = 2
local RELAXED_RIGHT_DIGITS = 2
local CONTIGUOUS_LEFT_DIGITS = 4
local CONTIGUOUS_RIGHT_DIGITS = 3

local function is_ascii_digit(byte)
    return byte and byte >= 48 and byte <= 57
end

local function count_digits(data, position, step, allow_one_space)
    local count = 0
    local skipped_space = false

    while position >= 1 and position <= #data do
        local byte = data:byte(position)
        if is_ascii_digit(byte) then
            count = count + 1
        elseif allow_one_space and not skipped_space and byte == 32 then
            skipped_space = true
        else
            break
        end

        position = position + step
    end

    return count
end

function _M.should_skip(data, begin_offset, end_offset)
    if type(data) ~= "string" or type(begin_offset) ~= "number" or type(end_offset) ~= "number" then
        return false
    end

    local left_position = begin_offset
    local right_position = end_offset + 2
    local relaxed_left = count_digits(data, left_position, -1, true)
    local relaxed_right = count_digits(data, right_position, 1, true)

    if relaxed_left >= RELAXED_LEFT_DIGITS and relaxed_right >= RELAXED_RIGHT_DIGITS then
        return true
    end

    local contiguous_left = count_digits(data, left_position, -1, false)
    if contiguous_left >= CONTIGUOUS_LEFT_DIGITS then
        return true
    end

    local contiguous_right = count_digits(data, right_position, 1, false)
    return contiguous_right >= CONTIGUOUS_RIGHT_DIGITS
end

return _M
