local M = {}

local function xor(a, b)
    local value, bit = 0, 1
    while a > 0 or b > 0 do
        if a % 2 ~= b % 2 then value = value + bit end
        a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
    end
    return value
end

function M.crc(data)
    local crc = 65535
    for i = 1, #data do
        crc = xor(crc, data:byte(i))
        for _ = 1, 8 do
            local odd = crc % 2 == 1
            crc = math.floor(crc / 2)
            if odd then crc = xor(crc, 40961) end
        end
    end
    return crc
end

function M.frame(data)
    local crc = M.crc(data)
    return data .. string.char(crc % 256, math.floor(crc / 256))
end

local function integer(n, low, high)
    return type(n) == 'number' and n == math.floor(n) and n >= low and n <= high
end

function M.request(unit, fn, address, count)
    if not integer(unit, 1, 247) or not integer(fn, 1, 4)
        or not integer(address, 0, 65535)
        or not integer(count, 1, fn <= 2 and 2000 or 125)
        or address + count > 65536 then
        return nil, 'invalid read request'
    end
    return M.frame(string.char(unit, fn, math.floor(address / 256), address % 256,
        math.floor(count / 256), count % 256))
end

function M.decode(data, unit, fn, count)
    if #data < 5 then return nil, 'short response' end
    if M.crc(data:sub(1, -3)) ~= data:byte(-2) + 256 * data:byte(-1) then
        return nil, 'CRC mismatch'
    end
    if data:byte(1) ~= unit then return nil, 'unit mismatch' end
    if data:byte(2) == fn + 128 and #data == 5 then
        return nil, 'Modbus exception ' .. data:byte(3)
    end
    if data:byte(2) ~= fn then return nil, 'function mismatch' end
    local bytes = fn <= 2 and math.ceil(count / 8) or count * 2
    if data:byte(3) ~= bytes or #data ~= bytes + 5 then
        return nil, 'response length mismatch'
    end
    local values = {}
    for i = 1, count do
        if fn <= 2 then
            values[i] = math.floor(data:byte(4 + math.floor((i - 1) / 8)) / 2 ^ ((i - 1) % 8)) % 2
        else
            values[i] = data:byte(2 + i * 2) * 256 + data:byte(3 + i * 2)
        end
    end
    return values
end

return M
