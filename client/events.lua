-- Hexa Inventory source.
RegisterNetEvent('HexaCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
end)

RegisterNetEvent('HexaCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
end)

RegisterNetEvent('hexa_inventory:client:notify', function(data)
    HexaInventory.Notify(data)
end)

RegisterNetEvent('hexa_inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) or IsPedOnMount(PlayerPedId()) then
        return
    end

    local dict = 'mech_butcher'
    HexaInventory.RequestAnimDict(dict)
    TaskPlayAnim(PlayerPedId(), dict, 'small_fish_give_player', 8.0, 1.0, -1, 16, 0, false, false, false)
    RemoveAnimDict(dict)
end)
