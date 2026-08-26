-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
Inventory = Inventory or {}
local config = HexaInventory.Config

Inventory.TYPES = {
    PLAYER = 1,
    OTHER_PLAYER = 2,
    DROP = 3,
    STASH = 4,
}
Inventory.MAX_DIST = 5.0

Inventory.IsUnlimitedCapacity = function(value)
    return tonumber(value) == -1
end

local function normalizeSlotLimit(value)
    value = tonumber(value) or 0
    if value == -1 or value == math.huge then return math.huge end
    return math.max(0, math.floor(value))
end

local function hasItemRule(group, itemName)
    local rules = config.ItemRules and config.ItemRules[group]
    if type(rules) ~= 'table' then return false end

    itemName = tostring(itemName or ''):lower()
    if rules[itemName] == true then return true end
    for _, configuredName in ipairs(rules) do
        if tostring(configuredName):lower() == itemName then return true end
    end
    return false
end

Inventory.IsItemUsable = function(item)
    local name = type(item) == 'table' and item.name or item
    if type(name) ~= 'string' then return false end
    name = name:lower()

    local definition = Core.Shared.Items[name]
    if not definition or definition.useable ~= true then return false end
    return not hasItemRule('DisableUse', name)
end

Inventory.IsItemStackable = function(item)
    local name = type(item) == 'table' and item.name or item
    if type(name) ~= 'string' then return false end
    name = name:lower()

    local definition = Core.Shared.Items[name]
    if not definition or definition.unique == true or definition.stackable == false then return false end
    if type(item) == 'table' and (item.unique == true or item.stackable == false) then return false end
    return not hasItemRule('DisableStack', name)
end

Inventory.IsItemDroppable = function(item)
    local name = type(item) == 'table' and item.name or item
    if type(name) ~= 'string' then return false end
    name = name:lower()

    local definition = Core.Shared.Items[name]
    if not definition or definition.droppable == false then return false end
    if type(item) == 'table' and item.droppable == false then return false end
    return not hasItemRule('DisableDrop', name)
end

Inventory.IsItemQuickSlotAllowed = function(item)
    local name = type(item) == 'table' and item.name or item
    if type(name) ~= 'string' then return false end
    name = name:lower()

    if config.QuickSlotsEnabled == false then return false end

    local definition = Core.Shared.Items[name]
    if not definition or definition.quickslot == false then return false end
    if type(item) == 'table' and item.quickslot == false then return false end
    return not hasItemRule('DisableQuickSlot', name)
end

Inventory.GetItemDimensions = function(item)
    local name = type(item) == 'table' and item.name or item
    if type(name) ~= 'string' then return 1, 1 end
    name = name:lower()

    local definition = Core.Shared.Items[name] or {}
    local configured = config.ItemRules and config.ItemRules.SlotSize
    local rule = type(configured) == 'table' and configured[name] or nil
    local width, height

    if type(rule) == 'table' then
        width = rule.width or rule.w or rule[1]
        height = rule.height or rule.h or rule[2]
    elseif tonumber(rule) then
        width, height = tonumber(rule), 1
    else
        width = definition.slotWidth or (type(item) == 'table' and item.slotWidth)
        height = definition.slotHeight or (type(item) == 'table' and item.slotHeight)
        if not width and not height then
            width = definition.slotSize or (type(item) == 'table' and item.slotSize) or 1
            height = 1
        end
    end

    width = math.max(1, math.floor(tonumber(width) or 1))
    height = math.max(1, math.floor(tonumber(height) or 1))
    return width, height
end

Inventory.GetItemBaseSlotSize = function(item)
    local width, height = Inventory.GetItemDimensions(item)
    return width * height
end

Inventory.GetItemSlotSize = function(item, slot, isPlayer)
    slot = math.floor(tonumber(slot) or 0)
    if isPlayer and slot >= 1 and slot <= (tonumber(config.QuickSlots) or 5) then return 1 end
    return Inventory.GetItemBaseSlotSize(item)
end

Inventory.GetPlayerSlotLimit = function(playerOrSlots)
    local normalSlots = type(playerOrSlots) == 'table'
        and playerOrSlots.PlayerData and playerOrSlots.PlayerData.slots
        or playerOrSlots
    return math.max(0, math.floor(tonumber(normalSlots) or 0))
        + (tonumber(config.QuickSlots) or 5)
end

Inventory.GetItemCells = function(item, slot, isPlayer, maxSlots)
    slot = math.floor(tonumber(slot) or 0)
    maxSlots = normalizeSlotLimit(maxSlots)
    if slot < 1 or slot > maxSlots then return nil end
    if isPlayer and slot <= (tonumber(config.QuickSlots) or 5) then return { slot } end

    local width, height = Inventory.GetItemDimensions(item)
    local columns = math.max(1, math.floor(tonumber(config.InventoryColumns) or 5))
    local column = ((slot - 1) % columns) + 1
    if column + width - 1 > columns then return nil end

    local cells = {}
    for row = 0, height - 1 do
        for offset = 0, width - 1 do
            local cell = slot + row * columns + offset
            if cell > maxSlots then return nil end
            cells[#cells + 1] = cell
        end
    end
    return cells
end

local function ignoredSlot(ignoreSlots, slot)
    if type(ignoreSlots) == 'number' then return tonumber(ignoreSlots) == tonumber(slot) end
    return type(ignoreSlots) == 'table' and ignoreSlots[slot] == true
end

Inventory.GetOccupiedSlots = function(items, maxSlots, isPlayer, ignoreSlots)
    maxSlots = normalizeSlotLimit(maxSlots)
    local occupied, anchors = {}, {}

    for key, item in pairs(items or {}) do
        local anchor = math.floor(tonumber(item and (item.slot or key)) or 0)
        if item and item.name and anchor >= 1 and anchor <= maxSlots and not ignoredSlot(ignoreSlots, anchor) then
            anchors[anchor] = true
            occupied[anchor] = anchor
        end
    end

    for key, item in pairs(items or {}) do
        local anchor = math.floor(tonumber(item and (item.slot or key)) or 0)
        if item and item.name and anchors[anchor] and not ignoredSlot(ignoreSlots, anchor) then
            local cells = Inventory.GetItemCells(item, anchor, isPlayer, maxSlots) or { anchor }
            for _, cell in ipairs(cells) do
                if cell ~= anchor and not anchors[cell] and not occupied[cell] then occupied[cell] = anchor end
            end
        end
    end

    return occupied
end

Inventory.CanPlaceItemAt = function(items, item, slot, maxSlots, isPlayer, ignoreSlots)
    slot = math.floor(tonumber(slot) or 0)
    maxSlots = normalizeSlotLimit(maxSlots)
    if slot < 1 or slot > maxSlots then return false end
    if isPlayer and slot <= (tonumber(config.QuickSlots) or 5)
        and not Inventory.IsItemQuickSlotAllowed(item) then
        return false
    end

    local cells = Inventory.GetItemCells(item, slot, isPlayer, maxSlots)
    if not cells then return false end

    local occupied = Inventory.GetOccupiedSlots(items, maxSlots, isPlayer, ignoreSlots)
    for _, cell in ipairs(cells) do
        if occupied[cell] then return false end
    end
    return true
end

Inventory.MoveItemWithin = function(items, fromSlot, toSlot, amount, maxSlots, isPlayer)
    if type(items) ~= 'table' then return false end
    fromSlot = math.floor(tonumber(fromSlot) or 0)
    toSlot = math.floor(tonumber(toSlot) or 0)
    amount = math.floor(tonumber(amount) or 0)
    maxSlots = normalizeSlotLimit(maxSlots)
    if fromSlot < 1 or toSlot < 1 or fromSlot == toSlot or amount < 1 then return false end

    local function itemAt(slot)
        for key, item in pairs(items) do
            if item and math.floor(tonumber(item.slot or key) or 0) == slot then
                return item, key
            end
        end
        return nil, nil
    end

    local fromItem, fromKey = itemAt(fromSlot)
    local toItem, toKey = itemAt(toSlot)
    if not fromItem or amount > (tonumber(fromItem.amount) or 0) then return false end

    local fromInfo = type(fromItem.info) == 'table' and fromItem.info or {}
    local toInfo = toItem and type(toItem.info) == 'table' and toItem.info or {}
    local sameStack = toItem
        and fromItem.name == toItem.name
        and Inventory.IsItemStackable(fromItem)
        and Inventory.IsItemStackable(toItem)
        and fromInfo.quality == toInfo.quality

    if sameStack then
        toItem.amount = (tonumber(toItem.amount) or 0) + amount
        fromItem.amount = (tonumber(fromItem.amount) or 0) - amount
        if fromItem.amount <= 0 then items[fromKey] = nil end
        return true
    end

    if toItem then
        local ignored = { [fromSlot] = true, [toSlot] = true }
        if not Inventory.CanPlaceItemAt(items, fromItem, toSlot, maxSlots, isPlayer, ignored)
            or not Inventory.CanPlaceItemAt(items, toItem, fromSlot, maxSlots, isPlayer, ignored) then
            return false
        end

        items[fromKey] = nil
        items[toKey] = nil
        fromItem.slot = toSlot
        toItem.slot = fromSlot
        items[toSlot] = fromItem
        items[fromSlot] = toItem
        return true
    end

    local movesWholeStack = amount == (tonumber(fromItem.amount) or 0)
    local ignored = movesWholeStack and fromSlot or nil
    if not Inventory.CanPlaceItemAt(items, fromItem, toSlot, maxSlots, isPlayer, ignored) then
        return false
    end

    if movesWholeStack then
        items[fromKey] = nil
        fromItem.slot = toSlot
        items[toSlot] = fromItem
    else
        local splitItem = {}
        for key, value in pairs(fromItem) do splitItem[key] = value end
        fromItem.amount = (tonumber(fromItem.amount) or 0) - amount
        splitItem.amount = amount
        splitItem.slot = toSlot
        items[toSlot] = splitItem
    end
    return true
end

Inventory.HydrateItems = function(items)
    local hydrated = {}

    for key, stored in pairs(items or {}) do
        if stored and stored.name then
            local name = tostring(stored.name):lower()
            local definition = Core.Shared.Items[name]
            local amount = tonumber(stored.amount or stored.count) or 0
            local slot = tonumber(stored.slot or key)
            local slotWidth, slotHeight = Inventory.GetItemDimensions(name)

            if definition and amount > 0 and slot and slot > 0 then
                hydrated[slot] = {
                    name = name,
                    amount = amount,
                    info = type(stored.info or stored.metadata) == 'table' and (stored.info or stored.metadata) or {},
                    label = definition.label or name,
                    description = definition.description or '',
                    weight = tonumber(definition.weight) or 0,
                    type = definition.type or 'item',
                    rarity = definition.rarity or 'common',
                    unique = definition.unique == true,
                    stackable = Inventory.IsItemStackable(name),
                    useable = Inventory.IsItemUsable(name),
                    droppable = Inventory.IsItemDroppable(name),
                    quickslot = Inventory.IsItemQuickSlotAllowed(name),
                    slotSize = Inventory.GetItemBaseSlotSize(name),
                    slotWidth = slotWidth,
                    slotHeight = slotHeight,
                    image = definition.image or (name .. '.png'),
                    shouldClose = definition.shouldClose ~= false,
                    slot = slot,
                    combinable = definition.combinable,
                }
            elseif not definition then
                print(('[hexa_inventory] skipped unknown persisted item %s'):format(name))
            end
        end
    end

    return hydrated
end

Inventory.SerializeItems = function(items)
    local serialized = {}

    for slot, item in pairs(items or {}) do
        local amount = tonumber(item and item.amount) or 0
        if item and item.name and amount > 0 then
            serialized[#serialized + 1] = {
                name = tostring(item.name):lower(),
                amount = amount,
                slot = tonumber(item.slot or slot),
                info = type(item.info) == 'table' and item.info or {},
            }
        end
    end

    table.sort(serialized, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return serialized
end

Inventory.InitializeInventory = function(inventoryId, data)
    Inventories[inventoryId] = {
        coords = data and data.coords,
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or config.StashSize.maxweight,
        slots = data and data.slots or config.StashSize.slots
    }
    return Inventories[inventoryId]
end

Inventory.GetItem = function(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = Core.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = Core.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

Inventory.GetFirstFreeSlot = function(items, maxSlots, item, isPlayer, startSlot)
    local configuredLimit = tonumber(maxSlots) or 0
    local firstSlot = math.max(1, math.floor(tonumber(startSlot) or 1))
    local scanLimit = normalizeSlotLimit(configuredLimit)

    if Inventory.IsUnlimitedCapacity(configuredLimit) then
        local highestCell = firstSlot - 1
        for key, existing in pairs(items or {}) do
            local anchor = math.floor(tonumber(existing and (existing.slot or key)) or 0)
            if existing and existing.name and anchor >= 1 then
                local cells = Inventory.GetItemCells(existing, anchor, isPlayer, -1) or { anchor }
                for _, cell in ipairs(cells) do highestCell = math.max(highestCell, cell) end
            end
        end

        local _, height = Inventory.GetItemDimensions(item or {})
        local columns = math.max(1, math.floor(tonumber(config.InventoryColumns) or 5))
        scanLimit = math.max(firstSlot, highestCell + columns * math.max(1, height))
    end

    for i = firstSlot, scanLimit do
        if Inventory.CanPlaceItemAt(items, item or {}, i, maxSlots, isPlayer) then return i end
    end
    return nil
end

Inventory.GetIdentifier = function(inventoryId, src)
    if inventoryId == 'player' then
        return src, Inventory.TYPES.PLAYER
    elseif type(inventoryId) == 'string' and inventoryId:find('otherplayer-', 1, true) == 1 then
        return tonumber(inventoryId:match('otherplayer%-(.+)')), Inventory.TYPES.OTHER_PLAYER
    elseif type(inventoryId) == 'string' and inventoryId:find('drop-', 1, true) == 1 then
        return inventoryId, Inventory.TYPES.DROP
    else
        return inventoryId, Inventory.TYPES.STASH
    end
end

local function clearStaleBusy(source)
    if not Player(source).state.inv_busy then return end

    for _, drop in pairs(Drops or {}) do
        if DropStore.IsOpenedBy(drop, source) then return end
    end

    for _, inventory in pairs(Inventories or {}) do
        if inventory.isOpen == source then return end
    end

    Player(source).state.inv_busy = false
    print(('[hexa_inventory] cleared a stale inv_busy flag for %s - nothing was open')
        :format(tostring(source)))
end

Inventory.ClearStaleBusy = clearStaleBusy

Inventory.CheckWeapon = function(source, item)
    local name = type(item) == 'table' and item.name or item
    if type(name) ~= 'string' then return end

    local slot = type(item) == 'table' and tonumber(item.slot or item.fromSlot) or nil

    if slot then WeaponSlots.Release(source, slot) end

    TriggerClientEvent('hexa_inventory:client:RemoveWeaponFromTab', source, {
        name = name,
        slot = slot,
    })
end

Inventory.GetFirstSlotByItemWithQuality = function(items, itemName, quality, minimumSlot)
    if not items then return end
    minimumSlot = math.max(1, math.floor(tonumber(minimumSlot) or 1))
    for slot, item in pairs(items) do
        local numericSlot = tonumber(slot) or tonumber(item.slot) or 0
        local info = type(item.info) == 'table' and item.info or {}
        if numericSlot >= minimumSlot and item.name:lower() == itemName:lower() and info.quality == quality then
            return tonumber(slot)
        end
    end
    return nil
end

Inventory.CheckItemDecay = function(item, itemInfo, currentTime, decayRateModifier)
    itemInfo = itemInfo or Core.Shared.Items[item.name:lower()]
    currentTime = currentTime or os.time()

    if not itemInfo or not itemInfo.decay then return false, nil, false end

    item.info = type(item.info) == 'table' and item.info or {}
    if not item.info.quality or not item.info.lastUpdate then
        item.info.quality = item.info.quality or 100
        item.info.lastUpdate = currentTime
        return true, item.info.quality, itemInfo.delete == true
    end
    decayRateModifier = decayRateModifier or 1
    local timeElapsed = currentTime - item.info.lastUpdate
    local decayRate = (100 / (itemInfo.decay * 60)) * decayRateModifier
    local newQuality = math.max(0, item.info.quality - timeElapsed * decayRate)
    item.info.quality = math.round(newQuality, 1)
    item.info.lastUpdate = currentTime

    return true, item.info.quality, itemInfo.delete == true
end

Inventory.CheckItemsDecay = function(items, decayRateModifier)
    local needsUpdate = false
    local currentTime = os.time()
    local removedItems = {}

    for slot, item in pairs(items) do
        local updated, quality, delete = Inventory.CheckItemDecay(item, nil, currentTime, decayRateModifier)
        if updated then
            if delete and quality <= 0 then
                removedItems[slot] = items[slot]
                items[slot] = nil
            end
            needsUpdate = true
        end
    end

    return needsUpdate, removedItems
end

Inventory.CheckPlayerItemsDecay = function(player)
    local needsUpdate, removedItems = Inventory.CheckItemsDecay(player.PlayerData.items)

    if needsUpdate then
        player.SetPlayerData('items', player.PlayerData.items)
        for _, item in pairs(removedItems) do
            TriggerClientEvent('hexa_inventory:client:ItemBox', player.PlayerData.source, Core.Shared.Items[item.name], 'remove', item.amount)
        end
    end
end

Inventory.CheckPlayerItemDecay = function(player, item)
    local updated, quality, delete = Inventory.CheckItemDecay(item)
    if updated then
        if delete and quality <= 0 then
            player.PlayerData.items[item.slot] = nil
            TriggerClientEvent('hexa_inventory:client:ItemBox', player.PlayerData.source, Core.Shared.Items[item.name], 'remove', item.amount)
        end

        player.SetPlayerData('items', player.PlayerData.items)
    end

    return player.PlayerData.items[item.slot]
end

Inventory.GetCoords = function(inventoryId, src)
    local resolvedId, inventoryType = Inventory.GetIdentifier(inventoryId, src)
    if inventoryType == Inventory.TYPES.PLAYER then
        local ped = GetPlayerPed(src)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.OTHER_PLAYER then
        local ped = GetPlayerPed(resolvedId)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.DROP then
        local drop = Drops[inventoryId]

        return drop and DropStore.Coords(drop)
    elseif inventoryType == Inventory.TYPES.STASH then
        local inventory = Inventories[inventoryId]
        return inventory and inventory.coords
    else
        warn(("Unexpected inventory type - '%s'"):format(inventoryType))
    end
end
