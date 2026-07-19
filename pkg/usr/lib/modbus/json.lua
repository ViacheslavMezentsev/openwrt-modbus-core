local M = {}

local function escape_string(value)
    return value
        :gsub("\\", "\\\\")
        :gsub("\"", "\\\"")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function is_array(tbl)
    local count = 0
    for key, _ in pairs(tbl) do
        if type(key) ~= "number" then
            return false
        end
        count = count + 1
    end

    for index = 1, count do
        if tbl[index] == nil then
            return false
        end
    end

    return true
end

local function encode_value(value)
    local kind = type(value)

    if kind == "nil" then
        return "null"
    end

    if kind == "boolean" or kind == "number" then
        return tostring(value)
    end

    if kind == "string" then
        return "\"" .. escape_string(value) .. "\""
    end

    if kind == "table" then
        local chunks = {}
        if is_array(value) then
            for index = 1, #value do
                chunks[#chunks + 1] = encode_value(value[index])
            end
            return "[" .. table.concat(chunks, ",") .. "]"
        end

        for key, item in pairs(value) do
            chunks[#chunks + 1] = encode_value(tostring(key)) .. ":" .. encode_value(item)
        end
        return "{" .. table.concat(chunks, ",") .. "}"
    end

    return encode_value(tostring(value))
end

function M.encode(value)
    return encode_value(value)
end

function M.decode(value)
    local ok, jsonc = pcall(require, "luci.jsonc")
    if ok and jsonc and jsonc.parse then
        return jsonc.parse(value)
    end

    return nil, "decoder unavailable"
end

return M
