-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

function HasItem(items, amount)
    local function isArray(t)
        if type(t) ~= 'table' then return false end
        if table.type then return table.type(t) == 'array' end
        local n = 0
        for k in pairs(t) do
            if type(k) ~= 'number' then return false end
            if k > n then n = k end
        end
        return n == #t
    end

    local playerData = Core.GetPlayerData()
    local inv = playerData and playerData.items
    if not inv then return false end

    local totalByName = {}
    for _, item in pairs(inv) do
        if item and item.name then
            local amt = item.amount or 0
            totalByName[item.name] = (totalByName[item.name] or 0) + amt
        end
    end

    if type(items) == 'string' then
        return (totalByName[items:lower()] or 0) >= (tonumber(amount) or 1)
    end
    if type(items) ~= 'table' then return false end

    if isArray(items) then
        for _, name in ipairs(items) do
            local have = totalByName[tostring(name):lower()] or 0
            if have < (tonumber(amount) or 1) then
                return false
            end
        end
        return true
    else
        for name, reqAmount in pairs(items) do
            local have = totalByName[tostring(name):lower()] or 0
            if have < (tonumber(reqAmount) or 1) then
                return false
            end
        end
        return true
    end
end

exports('HasItem', HasItem)
