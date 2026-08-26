-- Hexa Inventory source.
RegisterNUICallback('DropItem', function(data, cb)
    if not data or not data.token or not ValidateInventoryCbToken(data.token) then
        cb(false)
        return
    end

    local dropId, identifier, merged, expiresIn, timerPaused = InventoryCallback.Await('hexa_inventory:server:createDrop', data)

    if not dropId then
        cb(false)
        return
    end

    ClearPedTasksImmediately(PlayerPedId())

    TaskStartScenarioInPlaceHash(
        PlayerPedId(),
        GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"),
        0,
        1,
        GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"),
        -1.0,
        0
    )

    if merged then
        cb({
            identifier = identifier,
            expiresIn = expiresIn,
            timerPaused = timerPaused,
            slots = HexaInventory.Config.DropSize.slots,
            maxweight = HexaInventory.Config.DropSize.maxweight,
        })
        return
    end

    local timeout = 100
    while not NetworkDoesNetworkIdExist(dropId) and timeout > 0 do
        Wait(50)
        timeout = timeout - 1
    end

    if not NetworkDoesNetworkIdExist(dropId) then
        cb(false)
        return
    end

    local bag = NetworkGetEntityFromNetworkId(dropId)

    SetModelAsNoLongerNeeded(HexaInventory.Config.ItemDropObject)

    local coords = GetEntityCoords(PlayerPedId())
    local forward = GetEntityForwardVector(PlayerPedId())

    local x, y, z = table.unpack(coords + forward * 0.57)

    SetEntityCoords(bag, x, y, z - 0.9, false, false, false, false)
    SetEntityRotation(bag, 0.0, 0.0, 0.0, 2)

    PlaceObjectOnGroundProperly(bag)

    FreezeEntityPosition(bag, true)

    InventoryCallback.Await('hexa_inventory:updateDrop', identifier, vector3(x, y, z - 0.9))
    cb({
        identifier = identifier,
        expiresIn = expiresIn,
        timerPaused = timerPaused,
        slots = HexaInventory.Config.DropSize.slots,
        maxweight = HexaInventory.Config.DropSize.maxweight,
    })
end)

RegisterNUICallback('PlayDropFail', function(data, cb)
    if not data or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end

    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)
