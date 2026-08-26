-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

RegisterNetEvent('hexa_inventory:server:closeInventory', function(inventory)
    local src = source
    local HexaPlayer = Core.GetPlayer(src)
    if not HexaPlayer then return end

    Player(src).state.inv_busy = false

    if type(inventory) ~= 'string' then return end
    if inventory:find('shop-') then return end

    if inventory:find('otherplayer-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))

        local targetPed = GetPlayerPed(targetId)
        local srcPed = GetPlayerPed(src)
        if targetPed and DoesEntityExist(targetPed) and DoesEntityExist(srcPed) then
            if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) <= Inventory.MAX_DIST then
                Player(targetId).state.inv_busy = false
            end
        end
        return
    end

    if Drops[inventory] then
        if DropStore.Owner(Drops[inventory]) and not DropStore.IsOpenedBy(Drops[inventory], src) then return end
        Drops[inventory].isOpen = false
        Drops[inventory].openedBy = nil
        if next(Drops[inventory].items) == nil then
            DropStore.Delete(inventory)
        else
            DropStore.Resume(inventory)
            DropStore.Save(inventory)
        end
        return
    end

    if not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false
    VaultStore.Save(inventory)
end)

RegisterNetEvent('hexa_inventory:server:useItem', function(item, fromHotbar)
    local src = source
    local Player = Core.GetPlayer(src)
    if not Player then return false end
    local itemData = Inventory.GetItemBySlot(src, item.slot)
    if not itemData then return end
    if fromHotbar == true and not Inventory.IsItemQuickSlotAllowed(itemData) then return end
    local itemInfo = Core.Shared.Items[itemData.name]
    if not itemInfo or not Inventory.IsItemUsable(itemData) then return end
    local allowedDuringMelee = {
        weapon = true,
        weapon_thrown = true,

    }

    local inMelee = InventoryCallback.AwaitClient('hexa_inventory:client:isInMelee', src)
    if inMelee and not allowedDuringMelee[itemData.type] then
        TriggerClientEvent('hexa_inventory:client:notify', src, {
            title = 'Inventory',
            description = locale('error.error'),
            type = 'error'
        })
        return
    end
    local WEAPON_EVENT = {
        weapon        = 'hexa_inventory:client:UseWeapon',
        weapon_thrown = 'hexa_inventory:client:UseThrownWeapon',
        equipment     = 'hexa_inventory:client:UseEquipment',
    }

    local weaponEvent = WEAPON_EVENT[itemData.type]
    if weaponEvent then

        local order, reason = WeaponSlots.Decide(src, itemData)
        if not order then
            if reason and reason ~= 'spam' then
                local info = WeaponClass.Resolve(itemData.name)
                TriggerClientEvent('hexa_inventory:client:WeaponSlotDenied', src, reason, info.slot)
            end
            return
        end

        TriggerClientEvent(weaponEvent, src, itemData, order)
        TriggerClientEvent('hexa_inventory:client:ItemBox', src, itemInfo, 'use')

    else
        Inventory.UseItem(itemData.name, src, itemData)
        TriggerClientEvent('hexa_inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

RegisterNetEvent('hexa_inventory:server:updateHotbar', function()
    local src = source
    local Player = Core.GetPlayer(src)
    if not Player then return end

    local items = {}
    if HexaInventory.Config.QuickSlotsEnabled ~= false then
        for slot = 1, HexaInventory.Config.QuickSlots do
            local item = Player.GetItemBySlot(slot)
            items[slot] = item and Inventory.IsItemQuickSlotAllowed(item) and item or nil
        end
    end

    TriggerClientEvent('hexa_inventory:client:updateHotbar', src, items)
end)

local lastInventoryMoves = {}

local function processInventoryMove(src, fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount, requestId)
    if type(fromInventory) ~= 'string' or type(toInventory) ~= 'string' then return end
    if not fromSlot or not toSlot or not fromAmount or not toAmount then return end

    if toInventory:find('shop-', 1, true) == 1 then return end

    local Player = Core.GetPlayer(src)
    if not Player then return end

    local isMove = false
    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)
    if not fromSlot or not toSlot or not fromAmount or not toAmount then return end
    fromSlot, toSlot = math.floor(fromSlot), math.floor(toSlot)
    fromAmount, toAmount = math.floor(fromAmount), math.floor(toAmount)

    local now = GetGameTimer()
    local moveSignature = table.concat({
        fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount
    }, ':')
    local previousMove = lastInventoryMoves[src]
    if previousMove and previousMove.signature == moveSignature
        and now - previousMove.time < 100 then
        return
    end
    lastInventoryMoves[src] = { signature = moveSignature, time = now }

    if fromSlot <= 0 or toSlot <= 0 or fromAmount < 0 or toAmount <= 0 then return end

    local function getOtherPlayerId(inv)
        if inv:find('otherplayer-') then
            return tonumber(inv:match('otherplayer%-(.+)'))
        end
    end
    local targetId = getOtherPlayerId(fromInventory) or getOtherPlayerId(toInventory)
    if targetId then
        local Target = Core.GetPlayer(targetId)
        if not Target then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            return
        end
        local srcPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
        if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 3.0 then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            TriggerClientEvent('hexa_inventory:client:notify', src, { title = 'Error', description = locale('error.player_too_far'), type = 'error', duration = 5000 })
            return
        end
        local targetMeta = Target.PlayerData.metadata
        if not targetMeta.isdead and not targetMeta.ishandcuffed then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            TriggerClientEvent('hexa_inventory:client:notify', src, { title = 'Error', description = locale('error.target_needs_restrained'), type = 'error', duration = 5000 })
            return
        end
        local hasPerm = Core.HasPermission(src, 'police') or Player.PlayerData.job.name == 'police' or Player.PlayerData.job.name == 'marshal'
        if not hasPerm and not targetMeta.isdead then
            Inventory.CloseInventory(src, fromInventory)
            Inventory.CloseInventory(src, toInventory)
            return
        end
    end

    local restrictedPatterns = { '^police%-', '^marshal%-', '^gang%-', '^admin%-', '^evidence%-' }
    for _, invName in pairs({ fromInventory, toInventory }) do
        for _, pattern in ipairs(restrictedPatterns) do
            if invName:match(pattern) then
                local stashType = pattern:gsub('[%-^]', ''):gsub('%-', '')
                local hasAccess = false
                if stashType == 'police' or stashType == 'marshal' then
                    hasAccess = Core.HasPermission(src, 'police') or Player.PlayerData.job.name == 'police' or Player.PlayerData.job.name == 'marshal'
                elseif stashType == 'gang' then
                    local gangName = invName:match('gang%-(.+)%-')
                    hasAccess = Player.PlayerData.gang and Player.PlayerData.gang.name == gangName
                else
                    hasAccess = Core.HasPermission(src, 'admin')
                end
                if not hasAccess then
                    Inventory.CloseInventory(src, invName)
                    TriggerClientEvent('hexa_inventory:client:notify', src, { title = 'Access Denied', description = 'No permission', type = 'error', duration = 5000 })
                    return
                end
            end
        end
    end

    local fromId, fromType = Inventory.GetIdentifier(fromInventory, src)
    local toId, toType = Inventory.GetIdentifier(toInventory, src)
    if fromId ~= toId then isMove = true end

    local function removeForTransfer(identifier, itemName, amount, slot, reason, move)
        local isDrop = (identifier == fromId and fromType == Inventory.TYPES.DROP)
            or (identifier == toId and toType == Inventory.TYPES.DROP)
        return Inventory.RemoveItem(identifier, itemName, amount, slot, reason, move, isDrop)
    end

    if not Core.HasPermission(src, 'admin') then
        local srcCoords = GetEntityCoords(GetPlayerPed(src))
        local maxDist = Inventory.MAX_DIST
        local isInventoryTooFar = function(inventoryCoords)
            return inventoryCoords and #(srcCoords - inventoryCoords) > maxDist
        end
        local fromTooFar = isInventoryTooFar(Inventory.GetCoords(fromInventory, src))
        local toTooFar = isInventoryTooFar(Inventory.GetCoords(toInventory, src))
        if fromTooFar or toTooFar then
            Inventory.CloseInventory(src, fromId)
            Inventory.CloseInventory(src, toId)
            local message = fromTooFar and locale('error.source_inv_too_far') or locale('error.target_inv_too_far')
            TriggerClientEvent('hexa_inventory:client:notify', src, { title = message, type = 'error', duration = 5000 })
            return
        end
    end

    local fromItem = Inventory.GetItem(fromInventory, src, fromSlot)
    local toItem = Inventory.GetItem(toInventory, src, toSlot)
    local historyBefore = {}
    if fromItem then historyBefore[fromItem.name] = Inventory.GetItemCount(src, fromItem.name) end
    if toItem then historyBefore[toItem.name] = Inventory.GetItemCount(src, toItem.name) end

    local quickSlots = tonumber(HexaInventory.Config.QuickSlots) or 5
    local function isPlayerType(inventoryType)
        return inventoryType == Inventory.TYPES.PLAYER
            or inventoryType == Inventory.TYPES.OTHER_PLAYER
    end
    local isCrossInventory = fromId ~= toId
    local blockedByItemRule = isCrossInventory and (
        (toType == Inventory.TYPES.DROP and fromItem and not Inventory.IsItemDroppable(fromItem))
        or (fromType == Inventory.TYPES.DROP and toItem and not Inventory.IsItemDroppable(toItem))
    ) or false

    if fromItem and isPlayerType(toType) and toSlot <= quickSlots
        and not Inventory.IsItemQuickSlotAllowed(fromItem) then
        blockedByItemRule = true
    end
    if toItem and isPlayerType(fromType) and fromSlot <= quickSlots
        and not Inventory.IsItemQuickSlotAllowed(toItem) then
        blockedByItemRule = true
    end

    local handledSameInventory = false
    if fromItem and not blockedByItemRule and fromId == toId then
        handledSameInventory = true
        local items, maxSlots, isPlayer, owner
        owner = Core.GetPlayer(fromId)
        if owner then
            items = owner.PlayerData.items
            maxSlots = Inventory.GetPlayerSlotLimit(owner)
            isPlayer = true
        elseif Inventories[fromId] then
            items = Inventories[fromId].items
            maxSlots = Inventories[fromId].slots
            isPlayer = false
        elseif Drops[fromId] then
            items = Drops[fromId].items
            maxSlots = Drops[fromId].slots
            isPlayer = false
        end

        if items and Inventory.MoveItemWithin(items, fromSlot, toSlot, toAmount, maxSlots, isPlayer) then
            if owner then
                owner.SetPlayerData('items', items)
            elseif Inventories[fromId] then
                VaultStore.Save(fromId)
            elseif Drops[fromId] then
                DropStore.Save(fromId)
                DropStore.Touch(fromId)
            end
        end
    end

    if fromItem and not blockedByItemRule and not handledSameInventory then
        if not toItem and toAmount > fromItem.amount then return end

        if fromInventory == 'player' and toInventory ~= 'player' then
            isMove = true
            Inventory.CheckWeapon(src, fromItem)
        end

        if toItem and fromItem.name == toItem.name
            and Inventory.IsItemStackable(fromItem) and Inventory.IsItemStackable(toItem)
            and fromItem.info.quality == toItem.info.quality then
            if toId ~= fromId then
                if Inventory.CanAddItem(toId, fromItem.name, toAmount, fromItem.info) then
                    if removeForTransfer(fromId, fromItem.name, toAmount, fromSlot, 'stacked item', isMove) then
                        if not Inventory.AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item', false) then
                            Inventory.AddItem(fromId, fromItem.name, toAmount, fromSlot, fromItem.info, 'rollback stacked item')
                        end
                    end
                else
                    Inventory.SaveStash(fromId)
                    Inventory.CloseInventory(src, fromId)
                    Inventory.CloseInventory(src, toId)
                end
            else
                if removeForTransfer(fromId, fromItem.name, toAmount, fromSlot, 'stacked item', isMove) then
                    Inventory.AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item')
                end
            end

        elseif not toItem and toAmount < fromItem.amount then
            if fromId ~= toId then
                if Inventory.CanAddItem(toId, fromItem.name, toAmount, fromItem.info) then
                    if removeForTransfer(fromId, fromItem.name, toAmount, fromSlot, 'split item', isMove) then
                        if not Inventory.AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item', false) then
                            Inventory.AddItem(fromId, fromItem.name, toAmount, fromSlot, fromItem.info, 'rollback split item')
                        end
                    end
                else
                    Inventory.SaveStash(fromId)
                    Inventory.CloseInventory(src, fromId)
                    Inventory.CloseInventory(src, toId)
                end
            else
                if removeForTransfer(fromId, fromItem.name, toAmount, fromSlot, 'split item', isMove) then
                    if not Inventory.AddItem(toId, fromItem.name, toAmount, toSlot,
                        fromItem.info, 'split item', false) then
                        Inventory.AddItem(fromId, fromItem.name, toAmount, fromSlot,
                            fromItem.info, 'rollback split item')
                    end
                end
            end

        else
            if toItem then
                local fromItemAmount = fromItem.amount
                local toItemAmount = toItem.amount

                if toId ~= fromId then
                    local function canExchange(identifier, outgoingItem, incomingItem, targetSlot)
                        local player = Core.GetPlayer(identifier)
                        local container = player and {
                            items = player.PlayerData.items,
                            maxweight = player.PlayerData.weight,
                            slots = Inventory.GetPlayerSlotLimit(player),
                        } or Inventories[identifier] or Drops[identifier]
                        if not container then return false end
                        local weight = Inventory.GetTotalWeight(container.items)
                            - ((tonumber(outgoingItem.weight) or 0) * (tonumber(outgoingItem.amount) or 0))
                            + ((tonumber(incomingItem.weight) or 0) * (tonumber(incomingItem.amount) or 0))
                        local maxWeight = tonumber(container.maxweight) or 0
                        if not Inventory.IsUnlimitedCapacity(maxWeight) and weight > maxWeight then return false end
                        return Inventory.CanPlaceItemAt(container.items, incomingItem, targetSlot,
                            container.slots, player ~= nil, outgoingItem.slot)
                    end

                    local addSuccessFrom = canExchange(toId, toItem, fromItem, toSlot)
                    local addSuccessTo = canExchange(fromId, fromItem, toItem, fromSlot)

                    if not addSuccessFrom or not addSuccessTo then
                        Inventory.SaveStash(fromId)
                        Inventory.CloseInventory(src, fromId)
                        Inventory.CloseInventory(src, toId)
                    end

                    if addSuccessFrom and addSuccessTo then
                        if removeForTransfer(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', isMove) then
                            if not removeForTransfer(toId, toItem.name, toItemAmount, toSlot, 'swapped item', isMove) then
                                Inventory.AddItem(fromId, fromItem.name, fromItemAmount, fromSlot,
                                    fromItem.info, 'swap rollback')
                            elseif not Inventory.AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item', false) then
                                Inventory.AddItem(fromId, fromItem.name, fromItemAmount, fromSlot, fromItem.info, 'swap rollback')
                                Inventory.AddItem(toId, toItem.name, toItemAmount, toSlot, toItem.info, 'swap rollback')
                            elseif not Inventory.AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item', false) then
                                removeForTransfer(toId, fromItem.name, fromItemAmount, toSlot, 'swap rollback', true)
                                Inventory.AddItem(fromId, fromItem.name, fromItemAmount, fromSlot, fromItem.info, 'swap rollback')
                                Inventory.AddItem(toId, toItem.name, toItemAmount, toSlot, toItem.info, 'swap rollback')
                            end
                        end
                    end
                else
                    local items, maxSlots, isPlayer
                    local samePlayer = Core.GetPlayer(fromId)
                    if samePlayer then
                        items, maxSlots, isPlayer = samePlayer.PlayerData.items,
                            Inventory.GetPlayerSlotLimit(samePlayer), true
                    elseif Inventories[fromId] then
                        items, maxSlots, isPlayer = Inventories[fromId].items, Inventories[fromId].slots, false
                    elseif Drops[fromId] then
                        items, maxSlots, isPlayer = Drops[fromId].items, Drops[fromId].slots, false
                    end
                    local ignoreBoth = { [fromSlot] = true, [toSlot] = true }
                    local layoutFits = items
                        and Inventory.CanPlaceItemAt(items, fromItem, toSlot, maxSlots, isPlayer, ignoreBoth)
                        and Inventory.CanPlaceItemAt(items, toItem, fromSlot, maxSlots, isPlayer, ignoreBoth)

                    if layoutFits and removeForTransfer(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', isMove) then
                        if not removeForTransfer(toId, toItem.name, toItemAmount, toSlot, 'swapped item', isMove) then
                            Inventory.AddItem(fromId, fromItem.name, fromItemAmount, fromSlot, fromItem.info, 'swap rollback')
                        elseif not Inventory.AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item', false) then
                            Inventory.AddItem(fromId, fromItem.name, fromItemAmount, fromSlot, fromItem.info, 'swap rollback')
                            Inventory.AddItem(toId, toItem.name, toItemAmount, toSlot, toItem.info, 'swap rollback')
                        elseif not Inventory.AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item', false) then
                            removeForTransfer(toId, fromItem.name, fromItemAmount, toSlot, 'swap rollback', true)
                            Inventory.AddItem(fromId, fromItem.name, fromItemAmount, fromSlot, fromItem.info, 'swap rollback')
                            Inventory.AddItem(toId, toItem.name, toItemAmount, toSlot, toItem.info, 'swap rollback')
                        end
                    end
                end

            else
                if toId ~= fromId then
                    local fromItemAmount = fromItem.amount
                    if not Inventory.CanAddItem(toId, fromItem.name, fromItemAmount, fromItem.info) then
                        Inventory.SaveStash(fromId)
                        Inventory.CloseInventory(src, fromId)
                        Inventory.CloseInventory(src, toId)
                    else
                        if removeForTransfer(fromId, fromItem.name, toAmount, fromSlot, 'moved item', isMove) then
                            if not Inventory.AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item', false) then
                                Inventory.AddItem(fromId, fromItem.name, toAmount, fromSlot, fromItem.info, 'rollback moved item')
                            end
                        end
                    end
                else
                    if removeForTransfer(fromId, fromItem.name, toAmount, fromSlot, 'moved item', isMove) then
                        if not Inventory.AddItem(toId, fromItem.name, toAmount, toSlot,
                            fromItem.info, 'moved item', false) then
                            Inventory.AddItem(fromId, fromItem.name, toAmount, fromSlot,
                                fromItem.info, 'rollback moved item')
                        end
                    end
                end
            end
        end
    end

    local involvedDrops = {}
    if fromType == Inventory.TYPES.DROP then involvedDrops[fromId] = true end
    if toType == Inventory.TYPES.DROP then involvedDrops[toId] = true end
    for dropId in pairs(involvedDrops) do DropStore.DeleteIfEmpty(dropId) end

    local openDropId = fromType == Inventory.TYPES.DROP and fromId
        or (toType == Inventory.TYPES.DROP and toId or nil)
    local openDrop = openDropId and Drops[openDropId]
    if openDrop and DropStore.IsOpenedBy(openDrop, src) then
        TriggerClientEvent('hexa_inventory:client:updateOtherInventory', src,
            openDrop.items, DropStore.Remaining(openDrop), true, requestId)
    end

    if not openDrop then
        local otherName = fromInventory ~= 'player' and fromInventory
            or (toInventory ~= 'player' and toInventory or nil)
        if otherName and otherName:find('otherplayer-', 1, true) == 1 then
            local otherId = tonumber(otherName:match('otherplayer%-(.+)'))
            local otherPlayer = otherId and Core.GetPlayer(otherId)
            if otherPlayer then
                TriggerClientEvent('hexa_inventory:client:updateOtherInventory', src,
                    otherPlayer.PlayerData.items, nil, nil, requestId)
            end
        elseif otherName and Inventories[otherName] and Inventories[otherName].isOpen == src then
            TriggerClientEvent('hexa_inventory:client:updateOtherInventory', src,
                Inventories[otherName].items, nil, nil, requestId)
        end
    end

    if InventoryHistory then
        for itemName, beforeAmount in pairs(historyBefore) do
            local afterAmount = Inventory.GetItemCount(src, itemName)
            local delta = afterAmount - beforeAmount
            if delta > 0 then
                InventoryHistory.Record(src, 'receive', itemName, delta, 'inventory transfer', targetId)
            elseif delta < 0 then
                local action = toType == Inventory.TYPES.OTHER_PLAYER and 'give' or 'lost'
                InventoryHistory.Record(src, action, itemName, -delta, 'inventory transfer', targetId)
            end
        end
    end
end

RegisterNetEvent('hexa_inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount, requestId)
    local src = source
    requestId = math.max(0, math.floor(tonumber(requestId) or 0))
    local ok, err = xpcall(function()
        processInventoryMove(src, fromInventory, toInventory, fromSlot, toSlot,
            fromAmount, toAmount, requestId)
    end, debug.traceback)
    if not ok then
        print(('[hexa_inventory] SetInventoryData failed for %s: %s'):format(src, err))
    end

    local owner = Core.GetPlayer(src)
    if owner then
        TriggerClientEvent('hexa_inventory:client:updateInventory', src,
            owner.PlayerData.items, requestId)
    end
end)
RegisterNetEvent('hexa_inventory:server:openPlayerInventory', function(targetId)
    local src = source
    local Player = Core.GetPlayer(src)
    local Target = Core.GetPlayer(targetId)

    if not Player or not Target then return end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(srcCoords - targetCoords)

    if distance > 3.0 then
        TriggerClientEvent('hexa_inventory:client:notify', src, {
            title = 'Error',
            description = locale('error.player_too_far'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local targetMeta = Target.PlayerData.metadata
    if not targetMeta.isdead and not targetMeta.ishandcuffed then
        TriggerClientEvent('hexa_inventory:client:notify', src, {
            title = 'Error',
            description = locale('error.target_needs_restrained'),
            type = 'error',
            duration = 5000
        })
        return
    end

    local hasPermission = Core.HasPermission(src, 'police') or
                         Player.PlayerData.job.name == 'police' or
                         Player.PlayerData.job.name == 'marshal'

    if not hasPermission and not targetMeta.isdead then
        TriggerClientEvent('hexa_inventory:client:notify', src, {
            title = 'Error',
            description = 'Insufficient permissions',
            type = 'error',
            duration = 5000
        })
        return
    end

    Inventory.OpenInventoryById(src, targetId)
end)

RegisterNetEvent('hexa_inventory:server:openStash', function(stashId)
    local src = source
    local Player = Core.GetPlayer(src)

    if not Player then return end

    if not stashId or type(stashId) ~= 'string' then
        return TriggerClientEvent('hexa_inventory:client:notify', src, {
            title = 'Error',
            description = locale('error.invalid_stash_identifier'),
            type = 'error',
            duration = 5000
        })
    end

    local restrictedPatterns = {
        '^police%-',
        '^marshal%-',
        '^gang%-',
        '^admin%-',
        '^evidence%-'
    }

    local isRestricted = false
    local stashType = nil

    for _, pattern in ipairs(restrictedPatterns) do
        if stashId:match(pattern) then
            isRestricted = true
            stashType = pattern:gsub('[%-^]', ''):gsub('%-', '')
            break
        end
    end

    if isRestricted then
        local hasAccess = false

        if stashType == 'police' or stashType == 'marshal' then
            hasAccess = Core.HasPermission(src, 'police') or
                       Player.PlayerData.job.name == 'police' or
                       Player.PlayerData.job.name == 'marshal'
        elseif stashType == 'gang' then

            local gangName = stashId:match('gang%-(.+)%-')
            hasAccess = Player.PlayerData.gang and Player.PlayerData.gang.name == gangName
        elseif stashType == 'admin' or stashType == 'evidence' then
            hasAccess = Core.HasPermission(src, 'admin')
        end

        if not hasAccess then
            return TriggerClientEvent('hexa_inventory:client:notify', src, {
                title = locale('error.access_denied'),
                description = locale('error.no_permission_stash'),
                type = 'error',
                duration = 5000
            })
        end
    end

    local stashCoords = Inventory.GetCoords(stashId, src)
    if stashCoords then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local distance = #(playerCoords - stashCoords)

        if distance > Inventory.MAX_DIST then
            return TriggerClientEvent('hexa_inventory:client:notify', src, {
                title = 'Error',
                description = locale('error.stash_too_far'),
                type = 'error',
                duration = 5000
            })
        end
    end

    Inventory.OpenInventory(src, stashId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastInventoryMoves[src] = nil
    for dropId, drop in pairs(Drops) do
        if DropStore.IsOpenedBy(drop, src) then
            drop.isOpen = false
            drop.openedBy = nil
        end
        if drop.heldBy == src then drop.heldBy = nil end
    end
end)
