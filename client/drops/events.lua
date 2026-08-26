-- Hexa Inventory source.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Drops.ResetPlayerState()
    end
end)

RegisterNetEvent('HexaCore:Client:OnPlayerLoaded', function()
    Drops.ResetPlayerState()
    Drops.GetDrops()
end)

RegisterNetEvent('hexa_inventory:client:removeDrop', function(dropId)
    Drops.UnregisterByNetworkId(dropId)
end)

RegisterNetEvent('hexa_inventory:client:setupDrop', function(dropId, identifier)
    local newDropId = identifier or Helpers.CreateDropId(dropId)
    Drops.Register(newDropId, dropId)
end)
