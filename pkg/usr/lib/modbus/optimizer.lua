local M = {}

local function sorted_unique(addresses)
    local seen = {}
    local list = {}

    for _, address in ipairs(addresses or {}) do
        local number = tonumber(address)
        if number and number >= 0 and not seen[number] then
            seen[number] = true
            list[#list + 1] = number
        end
    end

    table.sort(list)
    return list
end

function M.group_registers(addresses, max_group_size, max_gap)
    local group_size = tonumber(max_group_size) or 120
    local gap = tonumber(max_gap) or 1
    local sorted = sorted_unique(addresses)
    local groups = {}
    local current = nil

    for _, address in ipairs(sorted) do
        if current == nil then
            current = {
                start = address,
                stop = address,
                count = 1,
                registers = { address }
            }
        else
            local span = address - current.start + 1
            local distance = address - current.stop

            if distance <= (gap + 1) and span <= group_size then
                current.stop = address
                current.count = span
                current.registers[#current.registers + 1] = address
            else
                groups[#groups + 1] = current
                current = {
                    start = address,
                    stop = address,
                    count = 1,
                    registers = { address }
                }
            end
        end
    end

    if current ~= nil then
        groups[#groups + 1] = current
    end

    return groups
end

return M
