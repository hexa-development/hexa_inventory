-- Hexa Inventory source.
local config = HexaInventory.Config
if not config.Compatibility.VORP then return end

local function finish(callback, ...)
    if type(callback) == 'function' then callback(...) end
    return ...
end

local function vorpItem(item)
    if not item then return nil end
    return {
        id = item.slot,
        mainid = item.slot,
        name = item.name,
        label = item.label,
        count = item.amount,
        amount = item.amount,
        limit = -1,
        type = item.type,
        weight = item.weight,
        metadata = item.info or {},
        percentage = item.info and item.info.quality or 100,
    }
end

exports('getUserInventoryItems', function(source, callback)
    local player = Core.GetPlayer(source)
    local result = {}
    if player then
        for _, item in pairs(player.PlayerData.items or {}) do
            result[#result + 1] = vorpItem(item)
        end
    end
    return finish(callback, result)
end)

exports('getItem', function(source, name, callback, metadata)
    local candidates = Inventory.GetItemsByName(source, name) or {}
    local found
    for _, item in ipairs(candidates) do
        local matches = true
        for key, value in pairs(type(metadata) == 'table' and metadata or {}) do
            if not item.info or item.info[key] ~= value then matches = false break end
        end
        if matches then found = item break end
    end
    return finish(callback, vorpItem(found))
end)

exports('getItemCount', function(source, name, callback)
    local count = Inventory.GetItemCount(source, name) or 0
    return finish(callback, count)
end)

exports('canCarryItem', function(source, name, amount, callback)
    local allowed = Inventory.CanAddItem(source, name, amount)
    return finish(callback, allowed == true)
end)

exports('addItem', function(source, name, amount, metadata, callback)
    if type(metadata) == 'function' and callback == nil then
        callback, metadata = metadata, {}
    end
    local stored, dropped = Inventory.AddItem(source, name, amount, false, metadata, 'vorp compatibility:addItem')
    return finish(callback, stored or dropped)
end)

exports('subItem', function(source, name, amount, metadata, callback)
    if type(metadata) == 'function' and callback == nil then
        callback, metadata = metadata, {}
    end
    local items = Inventory.GetItemsByName(source, name) or {}
    local slot
    local requiresMetadata = type(metadata) == 'table' and next(metadata) ~= nil
    if requiresMetadata then
        for _, item in ipairs(items) do
            local matches = true
            for key, value in pairs(metadata) do
                if not item.info or item.info[key] ~= value then matches = false break end
            end
            if matches then slot = item.slot break end
        end
    end
    if requiresMetadata and not slot then return finish(callback, false) end
    local success = Inventory.RemoveItem(source, name, amount, slot, 'vorp compatibility:subItem')
    return finish(callback, success)
end)

exports('subItemById', function(source, id, callback, allow, amount)
    local item = Inventory.GetItemBySlot(source, id)
    local success = item and Inventory.RemoveItem(source, item.name, amount or 1, id, 'vorp compatibility:subItemById') or false
    return finish(callback, success)
end)

exports('subAllItems', function(source, callback)
    Inventory.ClearInventory(source)
    return finish(callback, true)
end)

exports('registerUsableItem', function(name, callback)
    Core.CreateUseableItem(name, callback)
    return true
end)

exports('registerInventory', function(data)
    if type(data) ~= 'table' or not data.id then return false end
    Inventory.CreateInventory(data.id, {
        label = data.name or data.id,
        maxweight = data.maxweight or data.maxWeight or config.StashSize.maxweight,
        slots = data.slots or data.limit or config.StashSize.slots,
    })

    return {
        id = data.id,
        open = function(source) Inventory.OpenInventory(source, data.id) end,
        addItem = function(name, amount, metadata) return Inventory.AddItem(data.id, name, amount, false, metadata, 'vorp custom inventory') end,
        subItem = function(name, amount, slot) return Inventory.RemoveItem(data.id, name, amount, slot, 'vorp custom inventory') end,
        getItems = function() return Inventory.GetInventory(data.id) end,
        remove = function() return Inventory.DeleteInventory(data.id) end,
    }
end)

exports('openInventory', function(source, identifier)
    return Inventory.OpenInventory(source, identifier)
end)
