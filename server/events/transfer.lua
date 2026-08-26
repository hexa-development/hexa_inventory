-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

local cooldowns = {}

local function resolveContainer(src, inventoryId)
    if inventoryId == 'player' then
        local Player = Core.GetPlayer(src)
        return Player and Player.PlayerData.items or nil
    end

    if inventoryId:find('shop-', 1, true) == 1 then return nil, 'shop' end

    if inventoryId:find('otherplayer-', 1, true) == 1 then return nil, 'other_player' end

    if inventoryId:find('drop-', 1, true) == 1 then
        local drop = Drops and Drops[inventoryId]
        if not drop or not DropStore.IsOpenedBy(drop, src) then return nil, 'not_open' end
        return drop.items
    end

    local inventory = Inventories and Inventories[inventoryId]
    if not inventory or inventory.isOpen ~= src then return nil, 'not_open' end
    return inventory.items
end

local function snapshot(items)
    local list = {}
    for slot, item in pairs(items or {}) do
        if type(item) == 'table' and item.name and (tonumber(item.amount) or 0) > 0 then
            list[#list + 1] = {
                name   = item.name,
                amount = math.floor(tonumber(item.amount) or 0),
                info   = item.info,
                slot   = tonumber(item.slot) or tonumber(slot),
            }
        end
    end
    table.sort(list, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return list
end

local function containerIds(src, inventoryId)
    if inventoryId == 'player' then return 'player', src end
    return inventoryId, inventoryId
end

local function moveEverything(src, fromId, toId)
    local moved, skipped = 0, 0

    local fromLookup, fromWrite = containerIds(src, fromId)
    local _, toWrite = containerIds(src, toId)

    for _, entry in ipairs(snapshot(select(1, resolveContainer(src, fromId)))) do

        local live = Inventory.GetItem(fromLookup, src, entry.slot)
        local amount = live and math.min(entry.amount, math.floor(tonumber(live.amount) or 0)) or 0

        if amount > 0 and Inventory.CanAddItem(toWrite, entry.name, amount, entry.info) then
            if Inventory.RemoveItem(fromWrite, entry.name, amount, entry.slot, 'bulk transfer', true) then
                if Inventory.AddItem(toWrite, entry.name, amount, false, entry.info, 'bulk transfer') then
                    moved = moved + 1
                    if InventoryHistory then
                        local action = toId == 'player' and 'receive' or 'lost'
                        InventoryHistory.Record(src, action, entry.name, amount, 'bulk transfer')
                    end
                else

                    if not Inventory.AddItem(fromWrite, entry.name, amount, entry.slot, entry.info, 'bulk transfer rollback') then
                        Inventory.AddItem(src, entry.name, amount, false, entry.info, 'bulk transfer rescue')
                    end
                    skipped = skipped + 1
                end
            else
                skipped = skipped + 1
            end
        elseif amount > 0 then
            skipped = skipped + 1
        end
    end

    return moved, skipped
end

local function commit(src, inventoryId)
    if inventoryId == 'player' then return end

    if inventoryId:find('drop-', 1, true) == 1 then
        local drop = Drops and Drops[inventoryId]
        if not drop then return end
        DropStore.Save(inventoryId)
        TriggerClientEvent('hexa_inventory:client:updateOtherInventory', src, drop.items, DropStore.Remaining(drop))
        return
    end

    local inventory = Inventories and Inventories[inventoryId]
    if not inventory then return end
    VaultStore.Save(inventoryId)
    TriggerClientEvent('hexa_inventory:client:updateOtherInventory', src, inventory.items)
end

RegisterNetEvent('hexa_inventory:server:bulkTransfer', function(otherInventory, direction)
    local src = source

    local now = GetGameTimer()
    if cooldowns[src] and now - cooldowns[src] < 750 then return end
    cooldowns[src] = now

    local Player = Core.GetPlayer(src)
    if not Player then return end
    if type(otherInventory) ~= 'string' or otherInventory == '' or otherInventory == 'player' then return end

    local _, reason = resolveContainer(src, otherInventory)
    if reason then
        if reason ~= 'not_open' then
            TriggerClientEvent('hexa_inventory:client:notify', src, {
                title = locale('error.error'),
                description = reason == 'shop' and locale('error.error') or locale('error.access_denied'),
                type = 'error',
                duration = 4000,
            })
        end
        return
    end

    local fromId, toId
    if direction == 'store' then
        fromId, toId = 'player', otherInventory
    else
        fromId, toId = otherInventory, 'player'
    end

    local moved, skipped = moveEverything(src, fromId, toId)

    if moved > 0 then
        commit(src, otherInventory)
        TriggerClientEvent('hexa_inventory:client:updateInventory', src)
    end

    if skipped > 0 then
        TriggerClientEvent('hexa_inventory:client:notify', src, {
            title = locale('error.error'),
            description = ('%d / %d'):format(moved, moved + skipped),
            type = 'error',
            duration = 4000,
        })
    end
end)

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)
