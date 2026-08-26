-- Hexa Inventory source.
CreateThread(function()
    Wait(5000)

    local config = HexaInventory.Config
    if not config.UseTarget or GetResourceState('ox_target') ~= 'started' then return end

    if not exports.ox_target.addGlobalPlayer then return end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'trade',
            label = 'Trade',
            icon = 'fas fa-handshake',
            onSelect = function(data)
                local entity = data.entity
                if IsPedAPlayer(entity) then
                    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                    local serverId = GetPlayerServerId(playerIndex)
                    if serverId then
                        TriggerServerEvent('hexa_inventory:server:initiateTrade', serverId)
                    end
                end
            end,
        },
    }, 2.5)
end)
