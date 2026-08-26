-- Hexa Inventory source.
DropStore = DropStore or {}

local function dropKey(id)
    return Helpers.CreateDropId(tonumber(id))
end

function DropStore.Owner(drop)
    if not drop then return nil end
    local owner = drop.openedBy
    if owner == nil and drop.isOpen ~= true and drop.isOpen ~= false then owner = drop.isOpen end
    return tonumber(owner) or owner
end

function DropStore.IsOpenedBy(drop, source)
    local owner = DropStore.Owner(drop)
    if owner == nil then return false end
    return owner == (tonumber(source) or source)
end

function DropStore.Create(items, coords)
    local serialized = json.encode(Inventory.SerializeItems(items))
    return MySQL.insert.await([[
        INSERT INTO item_drops (items, x, y, z, created_at)
        VALUES (?, ?, ?, ?, ?)
    ]], { serialized, coords.x, coords.y, coords.z, os.time() })
end

function DropStore.Save(identifier)
    local drop = Drops[identifier]
    if not drop or not drop.storageId then return false end
    local coords = drop.coords
    MySQL.update.await([[
        UPDATE item_drops SET items = ?, x = ?, y = ?, z = ? WHERE id = ?
    ]], {
        json.encode(Inventory.SerializeItems(drop.items)),
        coords.x, coords.y, coords.z, drop.storageId,
    })
    return true
end

function DropStore.Remaining(drop)
    if not drop then return 0 end
    if drop.pausedRemaining ~= nil then
        return math.max(0, math.ceil(tonumber(drop.pausedRemaining) or 0))
    end
    local lifetime = (tonumber(HexaInventory.Config.CleanupDropTime) or 0) * 60
    local expiresAt = (tonumber(drop.createdTime) or os.time()) + lifetime
    return math.max(0, math.ceil(expiresAt - os.time()))
end

function DropStore.Pause(identifier)
    local drop = type(identifier) == 'table' and identifier or Drops[identifier]
    if not drop then return false end
    if drop.pausedRemaining == nil then drop.pausedRemaining = DropStore.Remaining(drop) end
    return true
end

function DropStore.Resume(identifier)
    local drop = type(identifier) == 'table' and identifier or Drops[identifier]
    if not drop or drop.pausedRemaining == nil then return false end

    local lifetime = (tonumber(HexaInventory.Config.CleanupDropTime) or 0) * 60
    local remaining = math.max(0, tonumber(drop.pausedRemaining) or 0)
    drop.createdTime = os.time() - math.max(0, lifetime - remaining)
    drop.pausedRemaining = nil

    if drop.storageId then
        MySQL.update.await('UPDATE item_drops SET created_at = ? WHERE id = ?',
            { drop.createdTime, drop.storageId })
    end
    return true
end

function DropStore.Coords(drop)
    local entity = drop and drop.entityId and NetworkGetEntityFromNetworkId(drop.entityId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return GetEntityCoords(entity)
    end
    return drop and drop.coords
end

function DropStore.DeleteIfEmpty(identifier)
    local drop = Drops and Drops[identifier]
    if not drop then return false end
    if next(drop.items or {}) ~= nil then return false end

    if drop.isOpen or drop.openedBy then
        DropStore.Save(identifier)
        return false
    end

    DropStore.Delete(identifier)
    return true
end

function DropStore.Touch(identifier)
    local drop = Drops[identifier]
    if not drop then return false end

    drop.createdTime = os.time()
    if drop.isOpen or drop.openedBy then
        drop.pausedRemaining = (tonumber(HexaInventory.Config.CleanupDropTime) or 0) * 60
    else
        drop.pausedRemaining = nil
    end
    if drop.storageId then
        MySQL.update.await('UPDATE item_drops SET created_at = ? WHERE id = ?',
            { drop.createdTime, drop.storageId })
    end
    return true
end

function DropStore.Delete(identifier)
    local drop = Drops[identifier]
    if not drop then return false end
    if drop.heldBy and Core.GetPlayer(drop.heldBy) then
        Player(drop.heldBy).state.holdingDrop = false
        Player(drop.heldBy).state.heldDrop = nil
    end
    if drop.storageId then
        MySQL.update.await('DELETE FROM item_drops WHERE id = ?', { drop.storageId })
    end
    local entity = drop.entityId and NetworkGetEntityFromNetworkId(drop.entityId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    Drops[identifier] = nil
    TriggerClientEvent('hexa_inventory:client:removeDrop', -1, drop.entityId)
    return true
end

function DropStore.LoadAll()
    exports['hexa_core']:AwaitSchemaReady(15000)
    HexaInventory.AwaitCatalogue(15000)

    local config = HexaInventory.Config
    local cutoff = os.time() - (config.CleanupDropTime * 60)
    MySQL.update.await('DELETE FROM item_drops WHERE created_at > 0 AND created_at < ?', { cutoff })
    local rows = MySQL.query.await('SELECT id, items, x, y, z, created_at FROM item_drops') or {}

    local loaded = 0
    for _, row in ipairs(rows) do
        local decoded = json.decode(row.items or '[]')
        if type(decoded) ~= 'table' then
            print(('[hexa_inventory] drop %s contains unreadable JSON and was left in the database'):format(row.id))
        else
            local coords = vector3(tonumber(row.x) or 0, tonumber(row.y) or 0, tonumber(row.z) or 0)
            local entity = CreateObjectNoOffset(config.ItemDropObject, coords.x, coords.y, coords.z, true, true, false)
            local timeout = 100
            while not DoesEntityExist(entity) and timeout > 0 do
                timeout = timeout - 1
                Wait(50)
            end

            if DoesEntityExist(entity) then
                local networkId = NetworkGetNetworkIdFromEntity(entity)
                local identifier = dropKey(row.id)
                Drops[identifier] = {
                    name = identifier,
                    label = locale('info.loot_bag'),
                    items = Inventory.HydrateItems(decoded),
                    entityId = networkId,
                    storageId = tonumber(row.id),
                    createdTime = tonumber(row.created_at) or os.time(),
                    coords = coords,
                    maxweight = config.DropSize.maxweight,
                    slots = config.DropSize.slots,
                    isOpen = false,
                }
                TriggerClientEvent('hexa_inventory:client:setupDrop', -1, networkId, identifier)
                loaded = loaded + 1
            end
        end
    end

    print(('[hexa_inventory] restored %d persistent drops'):format(loaded))
    return loaded
end
