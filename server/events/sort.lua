-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

local TYPE_RANK = {
    weapon        = 1,
    weapon_thrown = 2,
    equipment     = 3,
    item          = 4,
}

local function definitionOf(item)
    return Core.Shared.Items[item.name] or Core.Shared.Items[tostring(item.name):lower()]
end

local function rankOf(item)
    local def = definitionOf(item)
    return TYPE_RANK[def and def.type] or TYPE_RANK.item
end

local function labelOf(item)
    local def = definitionOf(item)
    return tostring((def and def.label) or item.label or item.name):lower()
end

local function rarityOf(item)
    local def = definitionOf(item)
    local rarity = (def and def.rarity) or item.rarity or 'common'
    if type(rarity) == 'number' then return rarity end

    local sortConfig = HexaInventory.Config.SortInventory or {}
    local order = sortConfig.RarityOrder or {}
    return tonumber(order[tostring(rarity):lower()]) or 0
end

local function toList(items)
    local list = {}
    for slot, item in pairs(items or {}) do
        if type(item) == 'table' and item.name then
            item.slot = tonumber(item.slot) or tonumber(slot) or 0
            list[#list + 1] = item
        end
    end
    table.sort(list, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return list
end

local function reorder(items, maxSlots, isPlayer)
    local list = toList(items)
    local sortConfig = HexaInventory.Config.SortInventory or {}
    local criteria = sortConfig.Criteria or { 'type', 'rarity', 'name' }
    local quickSlots = isPlayer and (tonumber(HexaInventory.Config.QuickSlots) or 5) or 0
    local fixed, sortable = {}, {}

    for _, item in ipairs(list) do
        if isPlayer and item.slot <= quickSlots then
            fixed[item.slot] = item
        else
            sortable[#sortable + 1] = item
        end
    end

    table.sort(sortable, function(a, b)
        for _, criterion in ipairs(criteria) do
            local av, bv
            if criterion == 'type' then
                av, bv = rankOf(a), rankOf(b)
            elseif criterion == 'rarity' then
                av, bv = rarityOf(a), rarityOf(b)
            elseif criterion == 'name' then
                av, bv = labelOf(a), labelOf(b)
            end

            if av ~= nil and av ~= bv then
                if criterion == 'rarity' and sortConfig.RarityDescending == true then
                    return av > bv
                end
                return av < bv
            end
        end

        if a.name ~= b.name then return a.name < b.name end

        local aa, ab = tonumber(a.amount) or 0, tonumber(b.amount) or 0
        if aa ~= ab then return aa > ab end

        return (a.slot or 0) < (b.slot or 0)
    end)

    local sorted = fixed
    for _, item in ipairs(sortable) do
        local slot = Inventory.GetFirstFreeSlot(
            sorted, maxSlots, item, isPlayer, isPlayer and (quickSlots + 1) or 1
        )

        slot = slot or item.slot
        item.slot = slot
        sorted[slot] = item
    end
    return sorted
end

local function restack(items)
    local list = toList(items)

    local merged, index, freed = {}, {}, 0

    for i = 1, #list do
        local item = list[i]
        local key

        if Inventory.IsItemStackable(item) then

            local quality = item.info and item.info.quality
            key = ('%s|%s'):format(item.name, tostring(quality))
        end

        local into = key and index[key] or nil
        if into then
            into.amount = (tonumber(into.amount) or 0) + (tonumber(item.amount) or 0)
            freed = freed + 1
        else
            merged[item.slot] = item
            if key then index[key] = item end
        end
    end

    return merged, freed
end

local cooldowns = {}

local function takeCooldown(src)
    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < 500 then return false end
    cooldowns[src] = now
    return true
end

local function applyTo(src, inventoryId, transform)
    local Player = Core.GetPlayer(src)
    if not Player then return end

    if type(inventoryId) ~= 'string' or inventoryId == '' then inventoryId = 'player' end

    if inventoryId == 'player' then
        Player.SetPlayerData('items', transform(
            Player.PlayerData.items, Inventory.GetPlayerSlotLimit(Player), true
        ))
        TriggerClientEvent('hexa_inventory:client:updateInventory', src)
        return
    end

    if inventoryId:find('shop-', 1, true) == 1 then return end

    if inventoryId:find('otherplayer-', 1, true) == 1 then return end

    if inventoryId:find('drop-', 1, true) == 1 then
        local drop = Drops and Drops[inventoryId]
        if not drop or not DropStore.IsOpenedBy(drop, src) then return end
        drop.items = transform(drop.items, drop.slots, false)
        DropStore.Save(inventoryId)
        TriggerClientEvent('hexa_inventory:client:updateOtherInventory', src, drop.items, DropStore.Remaining(drop))
        return
    end

    local inventory = Inventories and Inventories[inventoryId]
    if not inventory or inventory.isOpen ~= src then return end
    inventory.items = transform(inventory.items, inventory.slots, false)
    VaultStore.Save(inventoryId)
    TriggerClientEvent('hexa_inventory:client:updateOtherInventory', src, inventory.items)
end

RegisterNetEvent('hexa_inventory:server:sortInventory', function(inventoryId)
    local sortConfig = HexaInventory.Config.SortInventory or {}
    if sortConfig.Enabled == false or not takeCooldown(source) then return end
    applyTo(source, inventoryId, reorder)
end)

RegisterNetEvent('hexa_inventory:server:sortOpenInventories', function(otherInventory)
    local src = source
    local sortConfig = HexaInventory.Config.SortInventory or {}
    if sortConfig.Enabled == false or not takeCooldown(src) then return end

    applyTo(src, 'player', reorder)
    if type(otherInventory) == 'string' and otherInventory ~= '' then
        applyTo(src, otherInventory, reorder)
    end
end)

RegisterNetEvent('hexa_inventory:server:stackInventory', function(inventoryId)
    if not takeCooldown(source) then return end
    applyTo(source, inventoryId, function(items)
        local merged = restack(items)
        return merged
    end)
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
