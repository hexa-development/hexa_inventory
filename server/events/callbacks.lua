-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

InventoryCallback.Register('hexa_inventory:server:getPlayerName', function(source, targetId)
    local Player = Core.GetPlayer(targetId)
    if not Player then return GetPlayerName(targetId) end
    local char = Player.PlayerData.charinfo
    if char and char.firstname then
        return char.firstname .. ' ' .. char.lastname
    end
    return GetPlayerName(targetId)
end)

InventoryCallback.Register('hexa_inventory:server:getPlayerIdentity', function(source, targetId)
    local Player = Core.GetPlayer(tonumber(targetId))
    if not Player then return nil end
    local char = Player.PlayerData.charinfo or {}
    local name = char.firstname and ((char.firstname or '') .. ' ' .. (char.lastname or ''))
        or GetPlayerName(targetId)
    return {
        citizenid = tostring(Player.PlayerData.citizenid or ''),
        name = name,
        serverId = tonumber(Player.PlayerData.source) or tonumber(targetId),
    }
end)

local function resolveOnlineCitizen(target)
    if type(target) ~= 'string' and type(target) ~= 'number' then return nil end
    local key = tostring(target)
    local Player = Core.GetPlayerByCitizenId and Core.GetPlayerByCitizenId(key) or nil
    Player = Player or Core.GetPlayer(tonumber(key))
    if not Player then return nil end
    return Player, tonumber(Player.PlayerData.source)
end

InventoryCallback.Register('hexa_inventory:server:giveItem', function(source, target, item, amount, slot, info)
    local Target, targetSource = resolveOnlineCitizen(target)
    amount = math.floor(tonumber(amount) or 0)
    slot = tonumber(slot)
    if not Target or not targetSource or amount <= 0 or type(item) ~= 'string' or not slot then return false end

    local player = Core.GetPlayer(source)

    if not player or player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand or player.PlayerData.metadata.ishandcuffed then
        return false
    end

    if not Target or Target.PlayerData.metadata.isdead or Target.PlayerData.metadata.inlaststand or Target.PlayerData.metadata.ishandcuffed then
        return false
    end

    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(targetSource))) > Inventory.MAX_DIST then
        return false
    end

    local itemInfo = Core.Shared.Items[item:lower()]
    if not itemInfo then
        return false
    end

    local invItem = Inventory.GetItemBySlot(source, slot)
    if not invItem or invItem.name:lower() ~= item:lower() or invItem.amount <= 0 or amount > invItem.amount then
        return false
    end

    local serverInfo = invItem.info or {}

    if not Inventory.CanAddItem(targetSource, item, amount, serverInfo) then return false end

    local isMove = false
    if itemInfo.type == 'weapon' then
        isMove = true
        Inventory.CheckWeapon(source, item)
    end

    local targetCitizenId = tostring(Target.PlayerData.citizenid)
    local sourceCitizenId = tostring(player.PlayerData.citizenid)
    if not Inventory.RemoveItem(source, item, amount, slot,
        ('Item given to Citizen ID %s'):format(targetCitizenId), isMove) then
        return false
    end

    if not Inventory.AddItem(targetSource, item, amount, false, serverInfo,
        ('Item given from Citizen ID %s'):format(sourceCitizenId), false) then

        Inventory.AddItem(source, item, amount, false, serverInfo, 'rollback give item')
        return false
    end

    TriggerClientEvent('hexa_inventory:client:giveAnim', source)
    TriggerClientEvent('hexa_inventory:client:ItemBox', source, itemInfo, 'remove', amount)
    TriggerClientEvent('hexa_inventory:client:giveAnim', targetSource)
    TriggerClientEvent('hexa_inventory:client:ItemBox', targetSource, itemInfo, 'add', amount)

    if Player(targetSource).state.inv_busy then
        TriggerClientEvent('hexa_inventory:client:updateInventory', targetSource)
    end

    return true
end)
