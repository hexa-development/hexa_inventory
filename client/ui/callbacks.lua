-- Hexa Inventory source.
local callbackToken = nil

local function generateToken()
    callbackToken = tostring(math.random(100000, 999999)) .. tostring(GetGameTimer())
    return callbackToken
end

local function validateToken(token)
    if not token or not callbackToken or token ~= callbackToken then return false end
    return true
end

_G.GenerateInventoryCbToken = function(forceNew)

    if forceNew or not callbackToken then generateToken() end
    return callbackToken
end

_G.ValidateInventoryCbToken = function(token)
    return validateToken(token)
end

local function GetPlayerFromServerID(serverId)
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) == serverId then
            return pid
        end
    end
    return nil
end

local function GetOnlineIdentity(serverId)
    return InventoryCallback.Await('hexa_inventory:server:getPlayerIdentity', serverId)
end

local function GetNearbyPlayers(maxDistance)
    local options = {}
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local maxDist = maxDistance or 3.0
    local myId = PlayerId() or PlayerId()

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= myId then
            local ped = GetPlayerPed(pid)
            if DoesEntityExist(ped) then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist <= maxDist then
                    local sid = GetPlayerServerId(pid)
                    local identity = GetOnlineIdentity(sid)
                    options[#options+1] = {
                        value = identity and identity.citizenid or tostring(sid),
                        label = identity and identity.name or "Player : " .. sid,
                    }
                end
            end
        end
    end
    return options
end

local function GetClosestPlayerWithin(maxDistance)
    local myCoords = GetEntityCoords(PlayerPedId())
    local myId = PlayerId() or PlayerId()
    local maxDist = maxDistance or 3.0
    local closestPid, closestDist = -1, maxDist + 0.001

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= myId then
            local ped = GetPlayerPed(pid)
            if DoesEntityExist(ped) then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist < closestDist then
                    closestPid, closestDist = pid, dist
                end
            end
        end
    end
    return closestPid, closestDist
end

RegisterNUICallback('AttemptPurchase', function(data, cb)
    if not validateToken(data and data.token) then cb(false) return end
    local ok = InventoryCallback.Await('hexa_inventory:server:attemptPurchase', data)
    cb(ok)
end)

RegisterNUICallback('CloseInventory', function(data, cb)
    if not validateToken(data and data.token) then cb('ok') return end
    SetNuiFocus(false, false)
    if data and data.name then
        if data.name:find('trunk-') then
            CloseTrunk()
        end
        TriggerServerEvent('hexa_inventory:server:closeInventory', data.name)
    elseif LocalPlayer.state.currentDrop then
        TriggerServerEvent('hexa_inventory:server:closeInventory', LocalPlayer.state.currentDrop)
        LocalPlayer.state.currentDrop = nil
    end
    cb('ok')
end)

RegisterNUICallback('UseItem', function(data, cb)
    if not validateToken(data and data.token) then cb('ok') return end
    if data and data.item then
        TriggerServerEvent('hexa_inventory:server:useItem', data.item)
    end
    cb('ok')
end)

RegisterNUICallback('BulkTransfer', function(data, cb)
    if not validateToken(data and data.token) then cb('ok') return end
    TriggerServerEvent('hexa_inventory:server:bulkTransfer',
        data and data.inventory, data and data.direction)
    cb('ok')
end)

RegisterNUICallback('SortInventory', function(data, cb)
    if not validateToken(data and data.token) then cb('ok') return end
    TriggerServerEvent('hexa_inventory:server:sortInventory', data and data.inventory or 'player')
    cb('ok')
end)

RegisterNUICallback('SortOpenInventories', function(data, cb)
    if not validateToken(data and data.token) then cb('ok') return end
    TriggerServerEvent('hexa_inventory:server:sortOpenInventories', data and data.inventory)
    cb('ok')
end)

RegisterNUICallback('StackInventory', function(data, cb)
    if not validateToken(data and data.token) then cb('ok') return end
    TriggerServerEvent('hexa_inventory:server:stackInventory', data and data.inventory or 'player')
    cb('ok')
end)

RegisterNUICallback('GetInventoryHistory', function(data, cb)
    if not validateToken(data and data.token) then cb({}) return end
    cb(InventoryCallback.Await('hexa_inventory:server:getHistory') or {})
end)

RegisterNUICallback('SetInventoryData', function(data, cb)
    if not validateToken(data and data.token) then cb(false) return end
    if data then
        TriggerServerEvent('hexa_inventory:server:SetInventoryData',
            data.fromInventory, data.toInventory,
            data.fromSlot, data.toSlot,
            data.fromAmount, data.toAmount,
            data.requestId
        )
    end
    cb(true)
end)

local function NearbyPlayers(maxDistance)
    local myCoords = GetEntityCoords(PlayerPedId())
    local myId = PlayerId()
    local maxDist = maxDistance or 3.0
    local found = {}

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= myId then
            local ped = GetPlayerPed(pid)
            if DoesEntityExist(ped) then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist <= maxDist then
                    local serverId = GetPlayerServerId(pid)
                    local identity = GetOnlineIdentity(serverId)
                    found[#found + 1] = {
                        id       = identity and identity.citizenid or tostring(serverId),
                        serverId = serverId,
                        name     = identity and identity.name or GetPlayerName(pid),
                        distance = math.floor(dist * 10) / 10,
                    }
                end
            end
        end
    end

    table.sort(found, function(a, b) return a.distance < b.distance end)
    return found
end

RegisterNUICallback('GetNearbyPlayers', function(data, cb)
    if not validateToken(data and data.token) then cb({}) return end
    local config = HexaInventory.Config
    cb(NearbyPlayers(tonumber(config.GiveItemRange) or 3.0))
end)

RegisterNUICallback('GiveItemTo', function(data, cb)
    if not validateToken(data and data.token) then cb(false) return end
    if not data or not data.item or not data.item.name then cb(false) return end

    local targetCitizenId = tostring(data.target or '')
    if targetCitizenId == '' then cb(false) return end

    local config = HexaInventory.Config
    local range = tonumber(config.GiveItemRange) or 3.0

    local inRange = false
    for _, entry in ipairs(NearbyPlayers(range)) do
        if tostring(entry.id) == targetCitizenId then inRange = true break end
    end

    if not inRange then
        HexaInventory.Notify({
            title = locale('error.error'),
            description = locale('error.no_player_nearby'),
            type = 'error',
            duration = 7000,
        })
        cb(false)
        return
    end

    cb(InventoryCallback.Await('hexa_inventory:server:giveItem',
        targetCitizenId, data.item.name, data.amount, data.slot, data.info))
end)

RegisterNUICallback('GiveItem', function(data, cb)
    if not validateToken(data and data.token) then cb(false) return end
    if not data or not data.item or not data.item.name then
        cb(false)
        return
    end

    local function notifyNoPlayer()
        HexaInventory.Notify({
            title = locale('error.error'),
            description = locale('error.no_player_nearby'),
            type = 'error',
            duration = 7000
        })
    end

    local config = HexaInventory.Config

    if config.GiveItemType == "picker" then

        cb({ pick = true })
        return

    elseif config.GiveItemType == "nearby" then
        local pid, dist = GetClosestPlayerWithin(3.0)
        if pid ~= -1 and dist < 3.0 then
            local targetSid = GetPlayerServerId(pid)
            local identity = GetOnlineIdentity(targetSid)
            if not identity then cb(false) return end
            local success = InventoryCallback.Await('hexa_inventory:server:giveItem',
                identity.citizenid, data.item.name, data.amount, data.slot, data.info
            )
            cb(success)
        else
            notifyNoPlayer()
            cb(false)
        end

    elseif config.GiveItemType == "id" then
        local typedCitizenId = HexaInventory.PromptText(locale('info.enter_player_id'), nil, 64)
        if not typedCitizenId or typedCitizenId == '' then
            cb(false)
            return
        end
        local pid, dist = GetClosestPlayerWithin(3.0)
        local identity = pid ~= -1 and GetOnlineIdentity(GetPlayerServerId(pid)) or nil
        if identity and dist < 3.0 and tostring(identity.citizenid) == tostring(typedCitizenId) then
            local success = InventoryCallback.Await('hexa_inventory:server:giveItem',
                typedCitizenId, data.item.name, data.amount, data.slot, data.info
            )
            cb(success)
        else
            notifyNoPlayer()
            cb(false)
        end

    elseif config.GiveItemType == "nearby_menu" then
        local selectedPid, dist = GetClosestPlayerWithin(3.0)
        if selectedPid == -1 or dist >= 3.0 then
            cb(false)
            return
        end
        local selectedSid = GetPlayerServerId(selectedPid)
        local identity = GetOnlineIdentity(selectedSid)
        if dist < 3.0 then
            if not identity then cb(false) return end
            local success = InventoryCallback.Await('hexa_inventory:server:giveItem',
                identity.citizenid, data.item.name, data.amount, data.slot, data.info
            )
            cb(success)
        else
            notifyNoPlayer()
            cb(false)
        end
    else
        cb(false)
    end
end)

RegisterNUICallback('GiveItemAmount', function(data, cb)
    if not validateToken(data and data.token) then cb(0) return end
    local amount = HexaInventory.PromptNumber(locale('info.enter_amount'))
    if amount then
        cb(math.abs(amount))
    else
        cb(0)
    end
end)
