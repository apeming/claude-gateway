-- Brotli decompression using FFI
local ffi = require "ffi"

ffi.cdef[[
    typedef enum {
        BROTLI_DECODER_RESULT_ERROR = 0,
        BROTLI_DECODER_RESULT_SUCCESS = 1,
        BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT = 2,
        BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT = 3
    } BrotliDecoderResult;

    typedef struct BrotliDecoderStateStruct BrotliDecoderState;

    BrotliDecoderState* BrotliDecoderCreateInstance(void* (*alloc_func)(void*, size_t), void (*free_func)(void*, void*), void* opaque);
    void BrotliDecoderDestroyInstance(BrotliDecoderState* state);
    BrotliDecoderResult BrotliDecoderDecompressStream(BrotliDecoderState* state, size_t* available_in, const uint8_t** next_in, size_t* available_out, uint8_t** next_out, size_t* total_out);
]]

local brotli_lib = ffi.load("brotlidec")

local _M = {}

function _M.decompress(compressed_data)
    if not compressed_data or #compressed_data == 0 then
        return nil, "empty input"
    end

    local state = brotli_lib.BrotliDecoderCreateInstance(nil, nil, nil)
    if state == nil then
        return nil, "failed to create decoder"
    end

    local input = ffi.cast("const uint8_t*", compressed_data)
    local input_size = ffi.new("size_t[1]", #compressed_data)
    local input_ptr = ffi.new("const uint8_t*[1]", input)

    -- 预分配输出缓冲区（假设解压后最多是原始大小的10倍）
    local output_size = #compressed_data * 10
    local output = ffi.new("uint8_t[?]", output_size)
    local output_available = ffi.new("size_t[1]", output_size)
    local output_ptr = ffi.new("uint8_t*[1]", output)
    local total_out = ffi.new("size_t[1]", 0)

    local result = brotli_lib.BrotliDecoderDecompressStream(
        state,
        input_size,
        input_ptr,
        output_available,
        output_ptr,
        total_out
    )

    brotli_lib.BrotliDecoderDestroyInstance(state)

    if result == 1 then -- BROTLI_DECODER_RESULT_SUCCESS
        return ffi.string(output, total_out[0])
    else
        return nil, "decompression failed with result: " .. tostring(result)
    end
end

return _M
