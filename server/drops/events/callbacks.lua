-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

InventoryCallback.Register('hexa_inventory:server:GetCurrentDrops', function(source)
    local result = {}
    for identifier, drop in pairs(Drops) do
        result[identifier] = { entityId = drop.entityId }
    end
    return result
end)

local function nearbyDrop(coords)
    local config = HexaInventory.Config
    local radius = tonumber(config.DropMergeRadius) or 1.5
    local best, bestDist

    for identifier, drop in pairs(Drops) do
        if drop and drop.coords and not drop.isOpen and not drop.heldBy then
            local dist = #(coords - (DropStore.Coords(drop) or drop.coords))
            if dist <= radius and (not bestDist or dist < bestDist) then
                best, bestDist = identifier, dist
            end
        end
    end

    return best
end

local function placeInDrop(identifier, itemData)
    local drop = Drops[identifier]
    if not drop then return false end

    local quality = itemData.info and itemData.info.quality

    for _, existing in pairs(drop.items) do
        if existing and existing.name == itemData.name
            and Inventory.IsItemStackable(existing) and Inventory.IsItemStackable(itemData)
            and (existing.info and existing.info.quality) == quality then
            existing.amount = (tonumber(existing.amount) or 0) + itemData.amount
            return true
        end
    end

    local free = Inventory.GetFirstFreeSlot(drop.items, drop.slots, itemData, false)
    if not free then return false end

    itemData.slot = free
    drop.items[free] = itemData
    return true
end

local function CreateItemDrop(coords, itemData, shouldRemoveFromInventory, source)
    local config = HexaInventory.Config
    if not coords or type(itemData) ~= 'table' or type(itemData.name) ~= 'string' then return false end
    if not Inventory.IsItemDroppable(itemData) then return false end
    itemData.amount = math.floor(tonumber(itemData.amount) or 0)
    if itemData.amount <= 0 then return false end
    if shouldRemoveFromInventory then
        itemData.fromSlot = tonumber(itemData.fromSlot)
        if not itemData.fromSlot then return false end
    end

    local bag = CreateObjectNoOffset(
        config.ItemDropObject,
        coords.x + 0.5,
        coords.y + 0.5,
        coords.z,
        true, true, false
    )

    local timeout = 100
    while not DoesEntityExist(bag) and timeout > 0 do
        Wait(50)
        timeout = timeout - 1
    end

    if not DoesEntityExist(bag) then return false end

    if shouldRemoveFromInventory and source then

        local realItem = Inventory.GetItemBySlot(source, itemData.fromSlot)
        if not realItem or realItem.name:lower() ~= itemData.name:lower() or realItem.amount < itemData.amount then
            DeleteEntity(bag)
            return false
        end

        itemData.name   = realItem.name
        itemData.amount = itemData.amount
        itemData.info   = realItem.info or {}
        itemData.type   = realItem.type
        itemData.label  = realItem.label
        itemData.weight = realItem.weight
        itemData.unique = realItem.unique
        itemData.stackable = Inventory.IsItemStackable(realItem)
        itemData.useable = Inventory.IsItemUsable(realItem)
        itemData.droppable = Inventory.IsItemDroppable(realItem)
        itemData.quickslot = Inventory.IsItemQuickSlotAllowed(realItem)
        itemData.slotSize = Inventory.GetItemBaseSlotSize(realItem)
        itemData.slotWidth, itemData.slotHeight = Inventory.GetItemDimensions(realItem)
        itemData.image = realItem.image

        local isMove = realItem.type == 'weapon'
        if isMove then
            Inventory.CheckWeapon(source, itemData)
        end

        if not Inventory.RemoveItem(source, realItem.name, itemData.amount, itemData.fromSlot, 'dropped item', isMove) then
            DeleteEntity(bag)
            return false
        end

    end

    itemData.info = type(itemData.info) == 'table' and itemData.info or {}

    local existingId = nearbyDrop(coords)
    if existingId then
        if not placeInDrop(existingId, itemData) then

            if shouldRemoveFromInventory and source then
                Inventory.AddItem(source, itemData.name, itemData.amount, itemData.fromSlot,
                    itemData.info, 'drop bag full rollback')
            end
            DeleteEntity(bag)
            return false
        end

        DropStore.Save(existingId)
        DropStore.Touch(existingId)
        DeleteEntity(bag)

        local drop = Drops[existingId]
        return drop.entityId, existingId, true, DropStore.Remaining(drop)
    end

    itemData.slot = 1
    local itemsTable = { itemData }
    local storageId = DropStore.Create(itemsTable, coords)
    if not storageId then
        if shouldRemoveFromInventory and source then
            Inventory.AddItem(source, itemData.name, itemData.amount, itemData.fromSlot, itemData.info, 'drop persistence rollback')
        end
        DeleteEntity(bag)
        return false
    end

    local networkId = NetworkGetNetworkIdFromEntity(bag)
    local newDropId = Helpers.CreateDropId(storageId)

    if not Drops[newDropId] then
        Drops[newDropId] = {
            name = newDropId,
            label = 'Drop',
            items = itemsTable,
            entityId = networkId,
            storageId = storageId,
            createdBy = source,
            createdTime = os.time(),
            coords = coords,
            maxweight = config.DropSize.maxweight,
            slots = config.DropSize.slots,
            isOpen = false
        }

        TriggerClientEvent('hexa_inventory:client:setupDropTarget', -1, networkId, newDropId)
    else

        placeInDrop(newDropId, itemData)
        DropStore.Save(newDropId)
        DropStore.Touch(newDropId)
    end

    return networkId, newDropId, false, DropStore.Remaining(Drops[newDropId])
end

Helpers.CreateItemDrop = CreateItemDrop

local dropCooldowns = {}

InventoryCallback.Register('hexa_inventory:server:createDrop', function(source, item)
    local player = Core.GetPlayer(source)
    if not player then return false end

    local now = os.time()
    if dropCooldowns[source] and now - dropCooldowns[source] < 1 then return false end
    dropCooldowns[source] = now

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)

    local networkId, identifier, merged = CreateItemDrop(playerCoords, item, true, source)
    local drop = identifier and Drops[identifier]
    if not networkId or not drop then return false end

    drop.isOpen = true
    drop.openedBy = source
    DropStore.Pause(drop)
    Player(source).state.inv_busy = true
    return networkId, identifier, merged, DropStore.Remaining(drop), true
end)
