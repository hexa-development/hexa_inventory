-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
local pendingTradeRequest

RegisterNetEvent('hexa_inventory:client:tradeRequest', function(initiatorId, initiatorName)
    pendingTradeRequest = initiatorId
    HexaInventory.Notify({
        title = locale('ui.trade'),
        description = ('%s /tradeaccept | /tradedecline'):format(initiatorName),
        type = 'info',
        duration = 10000,
    })
end)

RegisterNetEvent('hexa_inventory:client:tradeRequestCancelled', function()
    pendingTradeRequest = nil
end)

RegisterCommand('tradeaccept', function()
    if not pendingTradeRequest then return end
    TriggerServerEvent('hexa_inventory:server:acceptTradeRequest', pendingTradeRequest)
    pendingTradeRequest = nil
end, false)

RegisterCommand('tradedecline', function()
    if not pendingTradeRequest then return end
    TriggerServerEvent('hexa_inventory:server:declineTradeRequest', pendingTradeRequest)
    pendingTradeRequest = nil
end, false)

RegisterNetEvent('hexa_inventory:client:openTrade', function(tradeId, partnerId, partnerName, items, partnerData)
    pendingTradeRequest = nil

    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken(true)
    local Player = Core.GetPlayerData()
    local config = HexaInventory.Config

    if not IsNuiFocused() then
        SetNuiFocus(true, true)
        if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end
    end

    local myId = Player.citizenid or Player.source or Player.id
    local myServerId = Player.source or Player.id

    SendNUIMessage({
        action = 'openTrade',
        tradeId = tradeId,
        partnerId = partnerId,
        partnerName = partnerName,
        inventory = items or Player.items,
        slots = (tonumber(Player.slots) or 0) + (tonumber(config.QuickSlots) or 5),
        quickslots = config.QuickSlots,
        quickslotsEnabled = config.QuickSlotsEnabled ~= false,
        maxweight = Player.weight,
        playerId = myId,
        playerServerId = myServerId,
        playerName = (Player.charinfo and Player.charinfo.firstname)
            and (Player.charinfo.firstname .. ' ' .. Player.charinfo.lastname)
            or myId,
        cash = Player.money and Player.money.cash or 0,
        labels = buildLabels(),
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('hexa_inventory:client:updateTrade', function(tradeData)

    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'updateTrade',
        tradeData = tradeData,
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('hexa_inventory:client:cancelTrade', function()

    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'cancelTrade',
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('hexa_inventory:client:completeTrade', function()

    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'completeTrade',
        token = token,
        invToken = invToken,
    })
end)
