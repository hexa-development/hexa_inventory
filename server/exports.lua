-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
Inventory = Inventory or {}
local config = HexaInventory.Config
Inventory.LoadInventory = function(source, citizenid)
    local loadedInventory = VaultStore.LoadPlayer(citizenid)
    if not next(loadedInventory) then return {} end
    local missingItems = {}

    local currentTime = os.time()

    for slot, item in pairs(loadedInventory) do
        if item and item.name then
            local itemInfo = Core.Shared.Items[item.name:lower()]
            local updated, quality, delete = Inventory.CheckItemDecay(item, itemInfo, currentTime, config.ItemsDecayWhileOffline and 1 or 0)
            local check = not (updated and delete and quality <= 0)

            if itemInfo and check then
                loadedInventory[slot] = item
            else
                loadedInventory[slot] = nil
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(GetPlayerName(source), table.concat(missingItems, ', ')))
    end

    return loadedInventory
end

exports('LoadInventory', Inventory.LoadInventory)

Inventory.SaveInventory = function(source, offline)
    local PlayerData
    if offline then
        PlayerData = source
    else
        local Player = Core.GetPlayer(source)
        if not Player then return end
        PlayerData = Player.PlayerData
    end

    return VaultStore.SavePlayer(PlayerData)
end

exports('SaveInventory', Inventory.SaveInventory)

Inventory.SetInventory = function(source, items)
    local Player = Core.GetPlayer(source)
    if not Player then return end
    local hydrated = Inventory.HydrateItems(type(items) == 'table' and items or {})
    local bounded = {}
    local slotLimit = Inventory.GetPlayerSlotLimit(Player)
    for slot, item in pairs(hydrated) do
        if slot <= slotLimit then bounded[slot] = item end
    end
    Player.SetPlayerData('items', bounded)
    if not Player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(source), Player.PlayerData.citizenid, source, json.encode(items))
        TriggerEvent('hexa_log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
    end
end

exports('SetInventory', Inventory.SetInventory)

Inventory.SetItemData = function(source, itemName, key, val)
    if not itemName or not key then return false end
    local Player = Core.GetPlayer(source)
    if not Player then return end
    local item = Inventory.GetItemByName(source, itemName)
    if not item then return false end
    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.SetPlayerData('items', Player.PlayerData.items)
    return true
end

exports('SetItemData', Inventory.SetItemData)

Inventory.GetItemWeight = function(itemName)
    if type(itemName) ~= 'string' then return nil end
    itemName = itemName:lower()
    local itemInfo = Core.Shared.Items[itemName]
    if itemInfo then
        return itemInfo.weight
    else
        return nil
    end
end

exports('GetItemWeight', Inventory.GetItemWeight)

Inventory.UseItem = function(sourceOrItem, itemOrData, ...)
    local itemName, source, itemData
    if type(sourceOrItem) == 'number' then
        source = sourceOrItem
        itemData = type(itemOrData) == 'table' and itemOrData or Inventory.GetItemByName(source, itemOrData)
        itemName = itemData and itemData.name or tostring(itemOrData)
    else
        itemName = tostring(sourceOrItem)
        source = itemOrData
        itemData = select(1, ...)
    end

    if not Inventory.IsItemUsable(itemName) then return false end

    local usable = Core.GetUsableItem(itemName)
    local callback = type(usable) == 'table' and (rawget(usable, '__cfx_functionReference') and usable or usable.cb or usable.callback) or type(usable) == 'function' and usable
    if not callback then return end

    callback(source, itemData)
    return true
end

exports('UseItem', Inventory.UseItem)

Inventory.GetSlotsByItem = function(items, itemName)
    local slotsFound = {}
    if not items or type(itemName) ~= 'string' then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    return slotsFound
end

exports('GetSlotsByItem', Inventory.GetSlotsByItem)

Inventory.GetFirstSlotByItem = function(items, itemName, minimumSlot)
    if not items or type(itemName) ~= 'string' then return end
    minimumSlot = math.max(1, math.floor(tonumber(minimumSlot) or 1))
    for slot, item in pairs(items) do
        local numericSlot = tonumber(slot) or tonumber(item.slot) or 0
        if numericSlot >= minimumSlot and item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end

exports('GetFirstSlotByItem', Inventory.GetFirstSlotByItem)

Inventory.GetItemBySlot = function(source, slot)
    local Player = Core.GetPlayer(source)
    if not Player then return end
    local item = Player.PlayerData.items[tonumber(slot)]
    if not item then return end
    return Inventory.CheckPlayerItemDecay(Player, item)
end

exports('GetItemBySlot', Inventory.GetItemBySlot)

Inventory.GetTotalWeight = function(items)
    if not items then return 0 end
    local weight = 0
    for _, item in pairs(items) do
        weight = weight + ((tonumber(item.weight) or 0) * (tonumber(item.amount) or 0))
    end
    return tonumber(weight)
end

exports('GetTotalWeight', Inventory.GetTotalWeight)

Inventory.GetItemByName = function(source, item)
    local Player = Core.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    local slot = Inventory.GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end

exports('GetItemByName', Inventory.GetItemByName)

Inventory.GetItemsByName = function(source, item)
    local Player = Core.GetPlayer(source)
    if not Player then return end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(Inventory.GetSlotsByItem(PlayerItems, item)) do
        if slot then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end

exports('GetItemsByName', Inventory.GetItemsByName)

Inventory.GetSlots = function(identifier)
    local inventory, maxSlots
    local player = Core.GetPlayer(identifier)
    if player then
        inventory = player.PlayerData.items
        maxSlots = Inventory.GetPlayerSlotLimit(player)
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        maxSlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        maxSlots = Drops[identifier].slots
    end
    if not inventory then return 0, maxSlots or 0 end
    local occupied = Inventory.GetOccupiedSlots(inventory, maxSlots, player ~= nil)
    local slotsUsed = 0
    local firstCountedSlot = player and ((tonumber(config.QuickSlots) or 5) + 1) or 1
    for slot in pairs(occupied) do
        if slot >= firstCountedSlot then slotsUsed = slotsUsed + 1 end
    end
    local capacity = player and (tonumber(player.PlayerData.slots) or 0) or maxSlots
    if Inventory.IsUnlimitedCapacity(capacity) then return slotsUsed, -1 end
    local slotsFree = math.max(0, (capacity or 0) - slotsUsed)
    return slotsUsed, slotsFree
end

exports('GetSlots', Inventory.GetSlots)

Inventory.GetItemCount = function(source, items)
    local Player = Core.GetPlayer(source)
    if not Player then return end
    Inventory.CheckPlayerItemsDecay(Player)
    local isTable = type(items) == 'table'
    local itemsSet = isTable and {} or nil
    if isTable then
        for _, item in pairs(items) do
            itemsSet[item] = true
        end
    end
    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name]) or (not isTable and items == item.name) then
            count = count + item.amount
        end
    end
    return count
end

exports('GetItemCount', Inventory.GetItemCount)

Inventory.CanAddItem = function(source, item, amount, info)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or type(item) ~= 'string' then return false end

    item = item:lower()
    local itemData = Core.Shared.Items[item]
    if not itemData then return false end

    local player = Core.GetPlayer(source)
    local container = player and {
        items = player.PlayerData.items,
        maxweight = player.PlayerData.weight,
        slots = Inventory.GetPlayerSlotLimit(player),
    } or Inventories[source] or Drops[source]

    if not container or type(container.items) ~= 'table' then return false end
    if Drops[source] and not Inventory.IsItemDroppable(item) then return false, 'rule' end

    local addedWeight = (tonumber(itemData.weight) or 0) * amount
    local maxWeight = tonumber(container.maxweight) or 0
    if not Inventory.IsUnlimitedCapacity(maxWeight)
        and Inventory.GetTotalWeight(container.items) + addedWeight > maxWeight then
        return false, 'weight'
    end

    local canStack = false
    local desiredQuality = type(info) == 'table' and info.quality or nil
    local minimumSlot = player and ((tonumber(config.QuickSlots) or 5) + 1) or 1
    if desiredQuality == nil and itemData.decay then desiredQuality = 100 end
    for slot, inventoryItem in pairs(container.items) do
        if inventoryItem then
            local numericSlot = tonumber(inventoryItem.slot or slot) or 0
            if numericSlot >= minimumSlot and Inventory.IsItemStackable(item) and inventoryItem.name == item then
                local existingQuality = inventoryItem.info and inventoryItem.info.quality or nil
                if desiredQuality == nil or desiredQuality == existingQuality then canStack = true end
            end
        end
    end

    if not canStack then
        local simulated = {}
        for key, value in pairs(container.items) do simulated[key] = value end
        local placements = Inventory.IsItemStackable(item) and 1 or amount
        for _ = 1, placements do
            local freeSlot = Inventory.GetFirstFreeSlot(
                simulated, container.slots, item, player ~= nil, minimumSlot
            )
            if not freeSlot then return false, 'slots' end
            simulated[freeSlot] = {
                name = item,
                slot = freeSlot,
                slotSize = Inventory.GetItemBaseSlotSize(item),
                slotWidth = select(1, Inventory.GetItemDimensions(item)),
                slotHeight = select(2, Inventory.GetItemDimensions(item)),
            }
        end
    end

    return true
end

exports('CanAddItem', Inventory.CanAddItem)

Inventory.GetFreeWeight = function(source)
    if not source then
        warn('Source was not passed into GetFreeWeight')
        return 0
    end
    local Player = Core.GetPlayer(source)
    if not Player then return 0 end

    local totalWeight = Inventory.GetTotalWeight(Player.PlayerData.items)
    local freeWeight = math.max(0, (tonumber(Player.PlayerData.weight) or 0) - totalWeight)
    return freeWeight
end

exports('GetFreeWeight', Inventory.GetFreeWeight)

Inventory.ClearInventory = function(source, filterItems)
    local player = Core.GetPlayer(source)
    if not player then return false end
    local savedItemData = {}
    if filterItems then
        local keep = {}
        if type(filterItems) == 'string' then keep[filterItems:lower()] = true end
        if type(filterItems) == 'table' then
            for _, itemName in ipairs(filterItems) do keep[tostring(itemName):lower()] = true end
        end
        for slot, item in pairs(player.PlayerData.items or {}) do
            if item and keep[item.name:lower()] then savedItemData[slot] = item end
        end
    end
    player.SetPlayerData('items', savedItemData)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source), player.PlayerData.citizenid, source)
        TriggerEvent('hexa_log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)
        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= joaat('WEAPON_UNARMED') then
            RemoveWeaponFromPed(ped, weapon)
        end
        if Player(source).state.inv_busy then TriggerClientEvent('hexa_inventory:client:updateInventory', source) end
    end
    return true
end

exports('ClearInventory', Inventory.ClearInventory)

Inventory.HasItem = function(source, items, amount)
    local Player = Core.GetPlayer(source)
    if not Player then return false end
    Inventory.CheckPlayerItemsDecay(Player)

    local counts = {}
    for _, itemData in pairs(Player.PlayerData.items) do
        if itemData and itemData.name then
            counts[itemData.name] = (counts[itemData.name] or 0) + (tonumber(itemData.amount) or 0)
        end
    end

    if type(items) == 'string' then
        return (counts[items:lower()] or 0) >= (tonumber(amount) or 1)
    end
    if type(items) ~= 'table' then return false end

    if table.type(items) == 'array' then
        for _, itemName in ipairs(items) do
            if (counts[tostring(itemName):lower()] or 0) < (tonumber(amount) or 1) then return false end
        end
    else
        for itemName, required in pairs(items) do
            if (counts[tostring(itemName):lower()] or 0) < (tonumber(required) or 1) then return false end
        end
    end
    return true
end

exports('HasItem', Inventory.HasItem)

Inventory.CloseInventory = function(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false
    end
    Player(source).state.inv_busy = false
    TriggerClientEvent('hexa_inventory:client:closeInv', source)
end

exports('CloseInventory', Inventory.CloseInventory)

Inventory.OpenInventoryById = function(source, targetId)
    local HexaPlayer = Core.GetPlayer(source)
    local TargetPlayer = Core.GetPlayer(tonumber(targetId))
    if not HexaPlayer or not TargetPlayer then return end
    if Player(targetId).state.inv_busy then Inventory.CloseInventory(targetId) end
    Inventory.CheckPlayerItemsDecay(HexaPlayer)
    Inventory.CheckPlayerItemsDecay(TargetPlayer)
    local playerItems = HexaPlayer.PlayerData.items
    local targetItems = TargetPlayer.PlayerData.items
    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = (TargetPlayer.PlayerData.charinfo and TargetPlayer.PlayerData.charinfo.firstname)
            and (TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname)
            or GetPlayerName(targetId),
        maxweight = TargetPlayer.PlayerData.weight,
        slots = Inventory.GetPlayerSlotLimit(TargetPlayer),
        inventory = targetItems
    }
    Wait(1500)
    Player(targetId).state.inv_busy = true
    TriggerClientEvent('hexa_inventory:client:openInventory', source, playerItems, formattedInventory)
end

exports('OpenInventoryById', Inventory.OpenInventoryById)

Inventory.ClearStash = function(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    inventory.items = {}
    VaultStore.Save(identifier)
end

exports('ClearStash', Inventory.ClearStash)

Inventory.SaveStash = function(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    return VaultStore.Save(identifier)
end

exports("SaveStash", Inventory.SaveStash)

Inventory.OpenInventory = function (source, identifier, data)
    if Player(source).state.inv_busy then return end
    local HexaPlayer = Core.GetPlayer(source)
    if not HexaPlayer then return end

    if not identifier then
        Player(source).state.inv_busy = true
        Inventory.CheckPlayerItemsDecay(HexaPlayer)
        TriggerClientEvent('hexa_inventory:client:openInventory', source, HexaPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then
        return
    end

    local inventory = Inventories[identifier]

    if inventory and inventory.isOpen then
        TriggerClientEvent('hexa_inventory:client:notify', source, { title = locale('error.access_denied') or locale('error.error'), type = 'error', duration = 5000 })
        return
    end

    if not inventory then
        inventory = Inventory.InitializeInventory(identifier, data)
    else
        local decayRate = Helpers.ParseDecayRate(identifier)
        Inventory.CheckItemsDecay(inventory.items, decayRate or 1)
    end
    inventory.maxweight = (data and data.maxweight) or (inventory and inventory.maxweight) or config.StashSize.maxweight
    inventory.slots = (data and data.slots) or (inventory and inventory.slots) or config.StashSize.slots
    inventory.label = (data and data.label) or (inventory and inventory.label) or identifier
    inventory.isOpen = source

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        maxweight = inventory.maxweight,
        slots = inventory.slots,
        inventory = inventory.items
    }

    Player(source).state.inv_busy = true
    Inventory.CheckPlayerItemsDecay(HexaPlayer)
    TriggerClientEvent('hexa_inventory:client:openInventory', source, HexaPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventory', Inventory.OpenInventory)

Inventory.ForceDropItem = function(source, item, amount, info, reason)
    local Player = Core.GetPlayer(source)
    if not Player then return false end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    local itemInfo = Core.Shared.Items[item:lower()]
    if not itemInfo then return false end
    if not Inventory.IsItemDroppable(item) then return false end
    local slotWidth, slotHeight = Inventory.GetItemDimensions(item)

    local itemData = {
        name = item,
        amount = amount,
        info = info or {},
        slot = 1,
        label = itemInfo.label,
        description = itemInfo.description or '',
        weight = itemInfo.weight,
        type = itemInfo.type,
        rarity = itemInfo.rarity or 'common',
        unique = itemInfo.unique,
        stackable = Inventory.IsItemStackable(item),
        useable = Inventory.IsItemUsable(item),
        droppable = Inventory.IsItemDroppable(item),
        quickslot = Inventory.IsItemQuickSlotAllowed(item),
        slotSize = Inventory.GetItemBaseSlotSize(item),
        slotWidth = slotWidth,
        slotHeight = slotHeight,
        image = itemInfo.image,
        shouldClose = itemInfo.shouldClose,
        combinable = itemInfo.combinable
    }

    local networkId = Helpers.CreateItemDrop(coords, itemData, false, nil)

    if not networkId then
        TriggerClientEvent('hexa_inventory:client:notify', source, {
            type = 'error',
            title = locale('error.error'),
            description = locale('error.inventory_force_drop_failed'),
            duration = 7000
        })
        return false
    end

    local logMessage = string.format('**%s (citizenid: %s | id: %s)** item force dropped due to full inventory: %s x%s at %s',
        GetPlayerName(source), Player.PlayerData.citizenid, source, item, amount, coords)
    TriggerEvent('hexa_log:server:CreateLog', 'playerinventory', 'Force Drop', 'orange', logMessage)

    TriggerClientEvent('hexa_inventory:client:notify', source, {
        type = 'warning',
        title = locale('error.inventory_full'),
        description = locale('error.inventory_force_drop'),
        duration = 5000
    })

    return networkId
end

exports('ForceDropItem', Inventory.ForceDropItem)

Inventory.AddItem = function(identifier, item, amount, slot, info, reason, allowDrop)
    if type(item) ~= 'string' then return false, false end
    item = item:lower()
    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then
        return false
    end

    local itemInfo = Core.Shared.Items[item:lower()]
    if not itemInfo then
        return false
    end
    local slotWidth, slotHeight = Inventory.GetItemDimensions(item)

    local inventory, inventoryWeight, inventorySlots
    local decayRate = 1
    local player = Core.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
        inventoryWeight = player.PlayerData.weight
        inventorySlots = Inventory.GetPlayerSlotLimit(player)
    elseif Inventories[identifier] then
        decayRate = Helpers.ParseDecayRate(identifier) or 1
        inventory = Inventories[identifier].items
        inventoryWeight = Inventories[identifier].maxweight
        inventorySlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        inventoryWeight = Drops[identifier].maxweight
        inventorySlots = Drops[identifier].slots
    end

    if not inventory then
        return false
    end
    if Drops[identifier] and not Inventory.IsItemDroppable(item) then return false, false end

    if slot then
        slot = tonumber(slot)
        if not slot then return false, false end
        slot = math.floor(slot)
        if slot < 1 or (not Inventory.IsUnlimitedCapacity(inventorySlots)
            and slot > (tonumber(inventorySlots) or 0)) then return false, false end
    end

    Inventory.CheckItemsDecay(inventory, decayRate or 1)

    local totalWeight = Inventory.GetTotalWeight(inventory)
    local maxWeight = tonumber(inventoryWeight) or 0
    if not Inventory.IsUnlimitedCapacity(maxWeight)
        and totalWeight + ((tonumber(itemInfo.weight) or 0) * amount) > maxWeight then
        if player and allowDrop ~= false then
            local dropped = Inventory.ForceDropItem(identifier, item, amount, info, reason or 'inventory full - weight')
            return false, dropped ~= false and dropped ~= nil
        end
        return false, false
    end

    info = type(info) == 'table' and info or {}
    if itemInfo.decay then
        info.quality = info.quality or 100
        info.lastUpdate = info.lastUpdate or os.time()
    end

    local defaultInfo = itemInfo.info or {}

    info = HexaInventory.Merge(defaultInfo, info)

    local updated = false
    local minimumAutoSlot = player and ((tonumber(config.QuickSlots) or 5) + 1) or 1
    if Inventory.IsItemStackable(item) then
        if not slot then
            if itemInfo.decay or info.quality then
                slot = Inventory.GetFirstSlotByItemWithQuality(inventory, item, info.quality, minimumAutoSlot)
            else
                slot = Inventory.GetFirstSlotByItem(inventory, item, minimumAutoSlot)
            end
        end
        if slot then
            for _, invItem in pairs(inventory) do
                local invInfo = type(invItem.info) == 'table' and invItem.info or {}
                if invItem.slot == slot and invItem.name:lower() == item:lower() and info.quality == invInfo.quality then
                    invItem.amount = invItem.amount + amount
                    updated = true
                    break
                end
            end
        end
    end

    if not updated then
        local requestedSlot = slot
        local stackable = Inventory.IsItemStackable(item)
        local placementCount = stackable and 1 or amount
        local placements, simulated = {}, {}
        for key, value in pairs(inventory) do simulated[key] = value end

        for index = 1, placementCount do
            local candidate = index == 1 and requestedSlot or nil
            candidate = candidate or Inventory.GetFirstFreeSlot(
                simulated, inventorySlots, item, player ~= nil, minimumAutoSlot
            )

            if not candidate or not Inventory.CanPlaceItemAt(
                simulated, item, candidate, inventorySlots, player ~= nil
            ) then
                if not requestedSlot and player and allowDrop ~= false then
                    local dropped = Inventory.ForceDropItem(identifier, item, amount, info,
                        reason or 'inventory full - slots')
                    return false, dropped ~= false and dropped ~= nil
                end
                return false, false
            end

            placements[#placements + 1] = candidate
            simulated[candidate] = {
                name = item,
                slot = candidate,
                slotSize = Inventory.GetItemBaseSlotSize(item),
                slotWidth = slotWidth,
                slotHeight = slotHeight,
            }
        end

        slot = placements[1]
        for _, placementSlot in ipairs(placements) do
            local unitInfo = HexaInventory.Merge({}, info)
            inventory[placementSlot] = {
                name = item,
                amount = stackable and amount or 1,
                info = unitInfo,
                label = itemInfo.label,
                description = itemInfo.description or '',
                weight = itemInfo.weight,
                type = itemInfo.type,
                rarity = itemInfo.rarity or 'common',
                unique = itemInfo.unique,
                stackable = stackable,
                useable = Inventory.IsItemUsable(item),
                droppable = Inventory.IsItemDroppable(item),
                quickslot = Inventory.IsItemQuickSlotAllowed(item),
                slotSize = Inventory.GetItemBaseSlotSize(item),
                slotWidth = slotWidth,
                slotHeight = slotHeight,
                image = itemInfo.image,
                shouldClose = itemInfo.shouldClose,
                slot = placementSlot,
                combinable = itemInfo.combinable
            }

            if itemInfo.type == 'weapon' then
                if not unitInfo.serie then
                    unitInfo.serie = tostring(
                        Core.Shared.RandomInt(2) ..
                        Core.Shared.RandomStr(3) ..
                        Core.Shared.RandomInt(1) ..
                        Core.Shared.RandomStr(2) ..
                        Core.Shared.RandomInt(3) ..
                        Core.Shared.RandomStr(4)
                    )
                end
                unitInfo.quality = unitInfo.quality or 100
            end
        end
    end

    if player then
        player.SetPlayerData('items', inventory)
    elseif Inventories[identifier] then
        VaultStore.Save(identifier)
    elseif Drops[identifier] then
        DropStore.Save(identifier)
    end
    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local addReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'hexa_inventory'
    TriggerEvent(
        'hexa_log:server:CreateLog',
        'playerinventory',
        'Item Added',
        'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. addReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )

    if Drops[identifier] then DropStore.Touch(identifier) end

    if player and InventoryHistory and not InventoryHistory.IsInternalReason(addReason) then
        local counterpart = addReason:match('[Ff]rom ID #(%d+)')
            or addReason:match('[Ff]rom Citizen ID ([%w_%-]+)')
        InventoryHistory.Record(identifier, 'receive', item, amount, addReason, counterpart)
    end

    return true, false
end

exports('AddItem', Inventory.AddItem)

Inventory.RemoveItem = function(identifier, item, amount, slot, reason, isMove, deferDropCleanup)
    if type(item) ~= 'string' or not Core.Shared.Items[item:lower()] then
        return false
    end

    local inventory
    local decayRate = 1
    local player = Core.GetPlayer(identifier)
    local inventoryItem = nil

    if player then
        inventory = player.PlayerData.items
    elseif Inventories[identifier] then
        decayRate = Helpers.ParseDecayRate(identifier) or 1
        inventory = Inventories[identifier].items
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
    end

    if not inventory then
        return false
    end

    Inventory.CheckItemsDecay(inventory, decayRate or 1)

    amount = math.floor(tonumber(amount) or 1)
    if amount <= 0 then return false end

    if slot then
        slot = tonumber(slot)
        local itemKey = nil

        for key, invItem in pairs(inventory) do
            if invItem.slot == slot then
                inventoryItem = invItem
                itemKey = key
                break
            end
        end

        if not inventoryItem or inventoryItem.name:lower() ~= item:lower() then
            return false
        end

        if inventoryItem.amount < amount then
            return false
        end

        inventoryItem.amount = inventoryItem.amount - amount
        if inventoryItem.amount <= 0 then
            inventory[itemKey] = nil
        else
            inventory[itemKey] = inventoryItem
        end

    else
        local availableTotal = 0
        for _, invItem in pairs(inventory) do
            if invItem.name:lower() == item:lower() then
                availableTotal = availableTotal + (tonumber(invItem.amount) or 0)
            end
        end
        if availableTotal < amount then return false end

        local totalRemoved = 0

        for itemKey, invItem in pairs(inventory) do
            if invItem.name:lower() == item:lower() then
                local available = invItem.amount
                local removeAmount = math.min(available, amount - totalRemoved)
                invItem.amount = invItem.amount - removeAmount
                totalRemoved = totalRemoved + removeAmount
                inventoryItem = invItem

                if invItem.amount <= 0 then
                    inventory[itemKey] = nil
                else
                    inventory[itemKey] = invItem
                end

                if totalRemoved >= amount then
                    break
                end
            end
        end

        slot = 'Multiple'
    end

    if Core.Shared.Items[item:lower()]['type'] == 'weapon' and player and isMove then
        TriggerClientEvent('hexa_core:client:RemoveWeaponFromTab', identifier, item)
    end

    if player then
        player.SetPlayerData('items', inventory)

        local data = {
            amount = amount,
            slot = slot,
            info = inventoryItem and inventoryItem.info or {}
        }
        TriggerEvent("hexa_inventory:server:itemRemovedFromPlayerInventory", identifier, item, data, reason, isMove)
    elseif Inventories[identifier] then
        VaultStore.Save(identifier)
    elseif Drops[identifier] then

        if deferDropCleanup then
            DropStore.Save(identifier)
        elseif not DropStore.DeleteIfEmpty(identifier) then
            DropStore.Save(identifier)
        end
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'hexa_inventory'

    TriggerEvent(
        'hexa_log:server:CreateLog',
        'playerinventory',
        'Item Removed',
        'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. removeReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )

    if player and InventoryHistory and not InventoryHistory.IsInternalReason(removeReason) then
        local counterpart = removeReason:match('[Tt]o ID #(%d+)')
            or removeReason:match('[Cc]itizen ID ([%w_%-]+)')
        local action = counterpart and 'give' or 'lost'
        InventoryHistory.Record(identifier, action, item, amount, removeReason, counterpart)
    end

    return true
end

exports('RemoveItem', Inventory.RemoveItem)

Inventory.GetInventory = function(identifier)
    if not Inventories[identifier] then
        return nil
    end
    local decayRate = Helpers.ParseDecayRate(identifier)
    Inventory.CheckItemsDecay(Inventories[identifier].items, decayRate or 1)
    return Inventories[identifier]
end

exports('GetInventory', Inventory.GetInventory)

Inventory.CreateInventory = function (identifier, data)
    if Inventories[identifier] then
        if data.label then
            Inventories[identifier].label = data.label
        end

        if data.maxweight then
            Inventories[identifier].maxweight = data.maxweight
        end

        if data.slots then
            Inventories[identifier].slots = data.slots
        end
    else
        Inventories[identifier] = Inventory.InitializeInventory(identifier, data)
    end
end

exports('CreateInventory', Inventory.CreateInventory)

Inventory.DeleteInventory = function(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
        VaultStore.Delete(identifier)
        return true
    end
    return false
end

exports('DeleteInventory', Inventory.DeleteInventory)
