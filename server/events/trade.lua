-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
Trades = Trades or {}
local pendingRequests = {}

local function getCharName(source)
    local player = Core.GetPlayer(source)
    if not player then return GetPlayerName(source) end
    local char = player.PlayerData.charinfo
    if char and char.firstname then
        return char.firstname .. ' ' .. char.lastname
    end
    return GetPlayerName(source)
end

local tradeCooldowns = {}
local function isOnCooldown(src)
    local now = GetGameTimer()
    if tradeCooldowns[src] and now - tradeCooldowns[src] < 200 then return true end
    tradeCooldowns[src] = now
    return false
end

RegisterNetEvent('hexa_inventory:server:initiateTrade', function(targetId)
    local src = source
    if isOnCooldown(src) then return end

    local player = Core.GetPlayer(src)
    if not player then return end
    if player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand or player.PlayerData.metadata.ishandcuffed then
        TriggerClientEvent('hexa_inventory:client:notify', src, { title = locale('error.error'), description = locale('error.error'), type = 'error', duration = 5000 })
        return
    end

    local Target = Core.GetPlayer(targetId)
    if not Target then
        TriggerClientEvent('hexa_inventory:client:notify', src, { title = locale('error.error'), description = locale('error.no_player_nearby'), type = 'error', duration = 5000 })
        return
    end
    if Target.PlayerData.metadata.isdead or Target.PlayerData.metadata.inlaststand or Target.PlayerData.metadata.ishandcuffed then
        TriggerClientEvent('hexa_inventory:client:notify', src, { title = locale('error.error'), description = locale('error.error'), type = 'error', duration = 5000 })
        return
    end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > Inventory.MAX_DIST then
        TriggerClientEvent('hexa_inventory:client:notify', src, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })
        return
    end

    for _, trade in pairs(Trades) do
        if trade.initiator == src or trade.target == src then
            TriggerClientEvent('hexa_inventory:client:notify', src, { title = locale('error.error'), description = 'You are already in a trade', type = 'error', duration = 5000 })
            return
        end
        if trade.initiator == targetId or trade.target == targetId then
            TriggerClientEvent('hexa_inventory:client:notify', src, { title = locale('error.error'), description = 'That player is already in a trade', type = 'error', duration = 5000 })
            return
        end
    end

    pendingRequests[src] = targetId
    SetTimeout(30000, function()
        if pendingRequests[src] == targetId then
            pendingRequests[src] = nil
        end
    end)

    TriggerClientEvent('hexa_inventory:client:tradeRequest', targetId, src, getCharName(src))
    TriggerClientEvent('hexa_inventory:client:notify', src, { title = 'Trade', description = 'Trade request sent to ' .. getCharName(targetId), type = 'info', duration = 5000 })
end)

RegisterNetEvent('hexa_inventory:server:acceptTradeRequest', function(initiatorId)
    local src = source
    if isOnCooldown(src) then return end
    if pendingRequests[initiatorId] ~= src then return end

    local player = Core.GetPlayer(src)
    local initiator = Core.GetPlayer(initiatorId)
    if not player or not initiator then return end

    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(initiatorId))) > Inventory.MAX_DIST then
        TriggerClientEvent('hexa_inventory:client:notify', src, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })
        pendingRequests[initiatorId] = nil
        return
    end

    local tradeId = 'trade-' .. initiatorId .. '-' .. src
    Trades[tradeId] = {
        id = tradeId,
        initiator = initiatorId,
        target = src,
        initiatorItems = {},
        targetItems = {},
        initiatorAccepted = false,
        targetAccepted = false,
        nextSlot = { initiator = 1, target = 1 },
        executing = false,
    }

    Player(initiatorId).state.inv_busy = true
    Player(src).state.inv_busy = true

    pendingRequests[initiatorId] = nil

    local initiatorItems = initiator.PlayerData.items
    local targetItems = player.PlayerData.items
    TriggerClientEvent('hexa_inventory:client:openTrade', initiatorId, tradeId, src, getCharName(src), initiatorItems, player.PlayerData)
    TriggerClientEvent('hexa_inventory:client:openTrade', src, tradeId, initiatorId, getCharName(initiatorId), targetItems, initiator.PlayerData)
end)

RegisterNetEvent('hexa_inventory:server:declineTradeRequest', function(initiatorId)
    if pendingRequests[initiatorId] == source then
        TriggerClientEvent('hexa_inventory:client:notify', initiatorId, { title = 'Trade', description = 'Trade request declined', type = 'error', duration = 5000 })
        pendingRequests[initiatorId] = nil
    end
end)

RegisterNetEvent('hexa_inventory:server:addTradeItem', function(tradeId, item, amount)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade then return end
    if trade.initiator ~= src and trade.target ~= src then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or type(item) ~= 'table' then return end

    local side = src == trade.initiator and 'initiator' or 'target'
    local otherSide = src == trade.initiator and 'target' or 'initiator'

    if trade[side .. 'Accepted'] then return end

    local player = Core.GetPlayer(src)
    if not player then return end

    local invItem = Inventory.GetItemBySlot(src, item.slot)
    if not invItem or invItem.name ~= item.name or invItem.amount < amount then return end

    if not Inventory.RemoveItem(src, invItem.name, amount, item.slot, 'trade escrow', true) then return end

    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false

    local tradeItems = trade[side .. 'Items']
    local slot = trade.nextSlot[side]
    tradeItems[slot] = {
        name = invItem.name,
        amount = amount,
        slot = invItem.slot,
        info = invItem.info,
        label = invItem.label,
        description = invItem.description,
        weight = invItem.weight,
        type = invItem.type,
        rarity = invItem.rarity,
        unique = invItem.unique,
        stackable = invItem.stackable,
        useable = invItem.useable,
        droppable = invItem.droppable,
        quickslot = invItem.quickslot,
        slotSize = Inventory.GetItemBaseSlotSize(invItem),
        slotWidth = select(1, Inventory.GetItemDimensions(invItem)),
        slotHeight = select(2, Inventory.GetItemDimensions(invItem)),
        image = invItem.image,
        shouldClose = invItem.shouldClose,
        combinable = invItem.combinable
    }
    trade.nextSlot[side] = slot + 1

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }
    TriggerClientEvent('hexa_inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('hexa_inventory:client:updateTrade', trade.target, tradeData)
end)

RegisterNetEvent('hexa_inventory:server:removeTradeItem', function(tradeId, tradeSlot)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade then return end
    if trade.initiator ~= src and trade.target ~= src then return end

    tradeSlot = tonumber(tradeSlot)
    if not tradeSlot then return end

    local side = src == trade.initiator and 'initiator' or 'target'
    local otherSide = src == trade.initiator and 'target' or 'initiator'

    if trade[side .. 'Accepted'] then return end

    local tradeItems = trade[side .. 'Items']
    if not tradeItems[tradeSlot] then return end

    local escrowedItem = tradeItems[tradeSlot]
    tradeItems[tradeSlot] = nil

    Inventory.AddItem(src, escrowedItem.name, escrowedItem.amount, false, escrowedItem.info, 'trade remove return')

    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }
    TriggerClientEvent('hexa_inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('hexa_inventory:client:updateTrade', trade.target, tradeData)
end)

RegisterNetEvent('hexa_inventory:server:confirmTrade', function(tradeId)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade then return end
    if trade.initiator ~= src and trade.target ~= src then return end

    local side = src == trade.initiator and 'initiator' or 'target'
    local otherSide = src == trade.initiator and 'target' or 'initiator'

    trade[side .. 'Accepted'] = true

    local tradeData = {
        id = tradeId,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted
    }
    TriggerClientEvent('hexa_inventory:client:updateTrade', trade.initiator, tradeData)
    TriggerClientEvent('hexa_inventory:client:updateTrade', trade.target, tradeData)

    if trade.initiatorAccepted and trade.targetAccepted then
        local initiatorPlayer = Core.GetPlayer(trade.initiator)
        local targetPlayer = Core.GetPlayer(trade.target)
        if not initiatorPlayer or not targetPlayer then
            TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.initiator)
            TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.target)
            Trades[tradeId] = nil
            return
        end

        if #(GetEntityCoords(GetPlayerPed(trade.initiator)) - GetEntityCoords(GetPlayerPed(trade.target))) > Inventory.MAX_DIST then
            TriggerClientEvent('hexa_inventory:client:notify', trade.initiator, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })
            TriggerClientEvent('hexa_inventory:client:notify', trade.target, { title = locale('error.error'), description = locale('error.player_too_far'), type = 'error', duration = 5000 })

            for _, item in pairs(trade.initiatorItems) do
                Inventory.AddItem(trade.initiator, item.name, item.amount, false, item.info, 'trade cancel return')
            end
            for _, item in pairs(trade.targetItems) do
                Inventory.AddItem(trade.target, item.name, item.amount, false, item.info, 'trade cancel return')
            end
            TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.initiator)
            TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.target)
            Trades[tradeId] = nil
            return
        end

        trade.executing = true
        local success, errorItem = Inventory.ExecuteTrade(trade)
        if success then
            TriggerClientEvent('hexa_inventory:client:completeTrade', trade.initiator)
            TriggerClientEvent('hexa_inventory:client:completeTrade', trade.target)
            TriggerClientEvent('hexa_inventory:client:notify', trade.initiator, { title = 'Trade', description = 'Trade completed successfully', type = 'success', duration = 5000 })
            TriggerClientEvent('hexa_inventory:client:notify', trade.target, { title = 'Trade', description = 'Trade completed successfully', type = 'success', duration = 5000 })
        else
            if not Trades[tradeId] then
                TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.initiator)
                TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.target)
                return
            end
            trade.initiatorAccepted = false
            trade.targetAccepted = false
            local tradeData = {
                id = tradeId,
                initiator = trade.initiator,
                initiatorItems = trade.initiatorItems,
                targetItems = trade.targetItems,
                initiatorAccepted = false,
                targetAccepted = false
            }
            TriggerClientEvent('hexa_inventory:client:updateTrade', trade.initiator, tradeData)
            TriggerClientEvent('hexa_inventory:client:updateTrade', trade.target, tradeData)
            local itemLabel = errorItem and Core.Shared.Items[errorItem] and Core.Shared.Items[errorItem].label or 'item'
            TriggerClientEvent('hexa_inventory:client:notify', trade.initiator, { title = 'Trade', description = 'Trade failed - ' .. itemLabel .. ' could not be transferred', type = 'error', duration = 5000 })
            TriggerClientEvent('hexa_inventory:client:notify', trade.target, { title = 'Trade', description = 'Trade failed - ' .. itemLabel .. ' could not be transferred', type = 'error', duration = 5000 })
        end
    end
end)

RegisterNetEvent('hexa_inventory:server:cancelTrade', function(tradeId)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade then return end
    if trade.initiator ~= src and trade.target ~= src then return end

    for _, item in pairs(trade.initiatorItems) do
        Inventory.AddItem(trade.initiator, item.name, item.amount, false, item.info, 'trade cancel return')
    end
    for _, item in pairs(trade.targetItems) do
        Inventory.AddItem(trade.target, item.name, item.amount, false, item.info, 'trade cancel return')
    end

    TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.initiator)
    TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.target)
    TriggerClientEvent('hexa_inventory:client:notify', src, { title = 'Trade', description = 'Trade cancelled', type = 'info', duration = 5000 })
    Trades[tradeId] = nil
end)

function Inventory.ExecuteTrade(trade)
    local initiatorPlayer = Core.GetPlayer(trade.initiator)
    local targetPlayer = Core.GetPlayer(trade.target)
    if not initiatorPlayer or not targetPlayer then

        for _, item in pairs(trade.initiatorItems) do
            Inventory.AddItem(trade.initiator, item.name, item.amount, false, item.info, 'trade rollback')
        end
        for _, item in pairs(trade.targetItems) do
            Inventory.AddItem(trade.target, item.name, item.amount, false, item.info, 'trade rollback')
        end
        Trades[trade.id] = nil
        return false, 'player not found'
    end

    local function canReceiveAll(player, incomingItems)
        local items = player.PlayerData.items or {}
        local totalWeight = Inventory.GetTotalWeight(items)
        local simulated = {}
        for key, value in pairs(items) do simulated[key] = value end
        local slotLimit = Inventory.GetPlayerSlotLimit(player)
        local minimumSlot = (tonumber(HexaInventory.Config.QuickSlots) or 5) + 1

        for _, item in pairs(incomingItems) do
            local definition = Core.Shared.Items[item.name]
            if not definition then return false, item.name end
            totalWeight = totalWeight + ((tonumber(definition.weight) or 0) * (tonumber(item.amount) or 0))
            if totalWeight > (tonumber(player.PlayerData.weight) or 0) then return false, item.name end

            local compatibleStack = false
            if Inventory.IsItemStackable(item) then
                local desiredQuality = item.info and item.info.quality
                for slot, existing in pairs(simulated) do
                    local numericSlot = tonumber(existing.slot or slot) or 0
                    local existingQuality = existing.info and existing.info.quality
                    if numericSlot >= minimumSlot and existing.name == item.name
                        and desiredQuality == existingQuality then
                        compatibleStack = true
                        break
                    end
                end
            end

            local placements = compatibleStack and 0
                or (Inventory.IsItemStackable(item) and 1 or math.floor(tonumber(item.amount) or 0))
            for _ = 1, placements do
                local freeSlot = Inventory.GetFirstFreeSlot(
                    simulated, slotLimit, item, true, minimumSlot
                )
                if not freeSlot then return false, item.name end
                simulated[freeSlot] = {
                    name = item.name,
                    slot = freeSlot,
                    slotSize = Inventory.GetItemBaseSlotSize(item),
                    slotWidth = select(1, Inventory.GetItemDimensions(item)),
                    slotHeight = select(2, Inventory.GetItemDimensions(item)),
                }
            end
        end
        return true
    end

    local targetCanReceive, targetError = canReceiveAll(targetPlayer, trade.initiatorItems)
    if not targetCanReceive then return false, targetError end
    local initiatorCanReceive, initiatorError = canReceiveAll(initiatorPlayer, trade.targetItems)
    if not initiatorCanReceive then return false, initiatorError end

    local transferred = {}

    for _, tradeItem in pairs(trade.initiatorItems) do
        if Inventory.AddItem(trade.target, tradeItem.name, tradeItem.amount, false, tradeItem.info, ('trade from %s'):format(trade.initiator), false) then
            transferred[#transferred+1] = { name = tradeItem.name, amount = tradeItem.amount, info = tradeItem.info, fromId = trade.initiator, toId = trade.target }
        else

            for _, t in ipairs(transferred) do
                Inventory.RemoveItem(t.toId, t.name, t.amount, false, 'trade rollback', true)
                Inventory.AddItem(t.fromId, t.name, t.amount, false, t.info, 'trade rollback')
            end
            for _, item in pairs(trade.initiatorItems) do
                Inventory.AddItem(trade.initiator, item.name, item.amount, false, item.info, 'trade rollback')
            end
            for _, item in pairs(trade.targetItems) do
                Inventory.AddItem(trade.target, item.name, item.amount, false, item.info, 'trade rollback')
            end
            Trades[trade.id] = nil
            return false, tradeItem.name
        end
    end

    for _, tradeItem in pairs(trade.targetItems) do
        if Inventory.AddItem(trade.initiator, tradeItem.name, tradeItem.amount, false, tradeItem.info, ('trade from %s'):format(trade.target), false) then
            transferred[#transferred+1] = { name = tradeItem.name, amount = tradeItem.amount, info = tradeItem.info, fromId = trade.target, toId = trade.initiator }
        else

            for _, t in ipairs(transferred) do
                Inventory.RemoveItem(t.toId, t.name, t.amount, false, 'trade rollback', true)
                Inventory.AddItem(t.fromId, t.name, t.amount, false, t.info, 'trade rollback')
            end
            for _, item in pairs(trade.initiatorItems) do
                Inventory.AddItem(trade.initiator, item.name, item.amount, false, item.info, 'trade rollback')
            end
            for _, item in pairs(trade.targetItems) do
                Inventory.AddItem(trade.target, item.name, item.amount, false, item.info, 'trade rollback')
            end
            Trades[trade.id] = nil
            return false, tradeItem.name
        end
    end

    local msgItems1, msgItems2 = {}, {}
    for _, item in pairs(trade.initiatorItems) do msgItems1[#msgItems1+1] = item.name .. ' x' .. item.amount end
    for _, item in pairs(trade.targetItems) do msgItems2[#msgItems2+1] = item.name .. ' x' .. item.amount end
    if InventoryHistory then
        for _, transfer in ipairs(transferred) do
            InventoryHistory.Record(transfer.fromId, 'give', transfer.name, transfer.amount,
                'trade completed', transfer.toId)
            InventoryHistory.Record(transfer.toId, 'receive', transfer.name, transfer.amount,
                'trade completed', transfer.fromId)
        end
    end
    TriggerEvent('hexa_log:server:CreateLog', 'playerinventory', 'Trade Completed', 'green',
        ('**%s (%s)** gave: %s\n**%s (%s)** gave: %s')
            :format(getCharName(trade.initiator), trade.initiator, table.concat(msgItems1, ', '),
                    getCharName(trade.target), trade.target, table.concat(msgItems2, ', ')))

    Trades[trade.id] = nil
    return true
end

AddEventHandler('playerDropped', function()
    local src = source
    for id, trade in pairs(Trades) do
        if trade.executing then

            local other = trade.initiator == src and trade.target or trade.initiator
            TriggerClientEvent('hexa_inventory:client:cancelTrade', other)
        elseif trade.initiator == src or trade.target == src then

            if trade.initiator == src then
                for _, item in pairs(trade.initiatorItems) do
                    Inventory.AddItem(src, item.name, item.amount, false, item.info, 'trade disconnect return')
                end
            end
            if trade.target == src then
                for _, item in pairs(trade.targetItems) do
                    Inventory.AddItem(src, item.name, item.amount, false, item.info, 'trade disconnect return')
                end
            end
            TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.initiator)
            TriggerClientEvent('hexa_inventory:client:cancelTrade', trade.target)
            Trades[id] = nil
        end
    end
    for initiatorId, targetId in pairs(pendingRequests) do
        if initiatorId == src or targetId == src then
            TriggerClientEvent('hexa_inventory:client:tradeRequestCancelled', initiatorId)
            TriggerClientEvent('hexa_inventory:client:tradeRequestCancelled', targetId)
            pendingRequests[initiatorId] = nil
        end
    end
end)
