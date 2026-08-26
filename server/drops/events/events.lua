-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

local function refuseOpen(src, dropId, reason, detail)
    print(('[hexa_inventory] %s refused to open %s: %s%s')
        :format(tostring(src), tostring(dropId), reason, detail and (' (' .. detail .. ')') or ''))

    TriggerClientEvent('hexa_inventory:client:notify', src, {
        title       = locale('error.error'),
        description = detail and (reason .. ' - ' .. detail) or reason,
        type        = 'error',
        duration    = 5000,
    })
end

RegisterNetEvent('hexa_inventory:server:openDrop', function(dropId)
    local src = source
    local xPlayer = Core.GetPlayer(src)
    if not xPlayer then return end

    Inventory.ClearStaleBusy(src)

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)

    local drop = Drops[dropId]
    if not drop then
        refuseOpen(src, dropId, 'bag no longer exists')
        return
    end

    if drop.heldBy and not Core.GetPlayer(tonumber(drop.heldBy) or drop.heldBy) then drop.heldBy = nil end
    local currentOwner = DropStore.Owner(drop)
    if currentOwner and not Core.GetPlayer(currentOwner) then
        drop.isOpen = false
        drop.openedBy = nil
        currentOwner = nil
    end

    if (drop.isOpen or currentOwner) and DropStore.IsOpenedBy(drop, src) then return end

    if drop.isOpen and not currentOwner then drop.isOpen = false end

    if drop.isOpen or currentOwner then
        refuseOpen(src, dropId, 'someone else has it open', 'openedBy=' .. tostring(currentOwner))
        return
    end

    if drop.heldBy then
        refuseOpen(src, dropId, 'someone is carrying it', 'heldBy=' .. tostring(drop.heldBy))
        return
    end

    if Player(src).state.inv_busy then
        print(('[hexa_inventory] %s opened %s while inv_busy was still set - if bags ' ..
               'stopped responding, that flag is stuck; /hexa_unstick clears it')
            :format(tostring(src), tostring(dropId)))
    end

    local bagCoords = DropStore.Coords(drop)
    if not bagCoords then
        refuseOpen(src, dropId, 'bag has no position on the server')
        return
    end

    local distance = #(playerCoords - bagCoords)
    if distance > 2.5 then
        refuseOpen(src, dropId, 'too far from the bag',
            ('%.1fm away, limit 2.5m'):format(distance))
        return
    end

    Inventory.CheckItemsDecay(drop.items)

    drop.isOpen = true
    drop.openedBy = src
    DropStore.Pause(drop)

    local formattedInventory = {
        name      = dropId,
        label     = dropId,
        maxweight = drop.maxweight,
        slots     = drop.slots,
        inventory = drop.items,
        expiresIn = DropStore.Remaining(drop),
        timerPaused = true,
    }

    Player(src).state.inv_busy = true

    TriggerClientEvent('hexa_inventory:client:openInventory', src, xPlayer.PlayerData.items, formattedInventory)
end)

InventoryCallback.Register('hexa_inventory:updateDrop', function(source, dropId, coords)
    local drop = Drops and Drops[dropId]
    if not drop then
        return false, 'no bag'
    end

    local isHolder = drop.heldBy == source and Player(source).state.heldDrop == dropId
    local isInitialPlacement = drop.createdBy == source
    if not isHolder and not isInitialPlacement then
        return false, 'not holder'
    end

    local newCoords = (type(coords) == 'vector3' and coords)
        or (type(coords) == 'table' and coords.x and coords.y and coords.z and vector3(coords.x, coords.y, coords.z))

    if not newCoords then
        return false, 'no coords'
    end

    local ped = GetPlayerPed(source)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - newCoords) > Inventory.MAX_DIST then
        return false, 'error distance'
    end

    drop.coords = newCoords
    drop.createdBy = nil
    drop.heldBy = nil
    Player(source).state.holdingDrop = false
    Player(source).state.heldDrop = nil
    DropStore.Save(dropId)
    return true, 'Good'
end)
