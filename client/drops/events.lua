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

local function getBag(dropId, timeoutMs)
    local expires = GetGameTimer() + (timeoutMs or 5000)
    while not NetworkDoesNetworkIdExist(dropId) and GetGameTimer() < expires do Wait(10) end
    if not NetworkDoesNetworkIdExist(dropId) then return nil end
    local bag = NetworkGetEntityFromNetworkId(dropId)
    while not DoesEntityExist(bag) and GetGameTimer() < expires do
        Wait(10)
        bag = NetworkGetEntityFromNetworkId(dropId)
    end
    return DoesEntityExist(bag) and bag or nil
end

RegisterNetEvent('hexa_inventory:client:removeDropTarget', function(dropId)
    local bag = getBag(dropId, 500)
    Drops.UnregisterByNetworkId(dropId)
    if Drops.UsesTarget() and bag then exports.ox_target:removeLocalEntity(bag) end
end)

RegisterNetEvent('hexa_inventory:client:setupDropTarget', function(dropId, identifier)
    local newDropId = identifier or Helpers.CreateDropId(dropId)
    Drops.Register(newDropId, dropId)
    if not Drops.UsesTarget() or Drops.Targeted[newDropId] == dropId then return end

    local bag = getBag(dropId, 5000)
    if not bag then return end
    Drops.Targeted[newDropId] = dropId

    exports.ox_target:addLocalEntity(bag, {
        {
            name     = 'open_drop_' .. newDropId,
            icon     = 'fas fa-box',
            label    = locale('info.o_bag'),
            distance = 2.5,
            onSelect = function()
                Drops.Open(newDropId)
            end,
        }
    })
end)
