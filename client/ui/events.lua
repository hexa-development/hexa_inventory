-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
local config = HexaInventory.Config

local function durabilityWarningPayload()
    local warning = config.DurabilityWarning or {}
    return {
        enabled = warning.Enabled ~= false,
        threshold = tonumber(warning.Threshold) or 10,
        soundEnabled = warning.SoundEnabled ~= false,
        volume = tonumber(warning.Volume) or 0.35,
    }
end

RegisterNetEvent('hexa_inventory:client:hotbar', function(items)
    if config.QuickSlotsEnabled == false then
        LocalPlayer.state.hotbarShown = false
        return
    end
    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    LocalPlayer.state.hotbarShown = not LocalPlayer.state.hotbarShown
    SendNUIMessage({
        action = 'toggleHotbar',
        open = LocalPlayer.state.hotbarShown,
        items = items,
        quickslots = config.QuickSlots,
        quickslotsEnabled = config.QuickSlotsEnabled ~= false,
        durabilityWarning = durabilityWarningPayload(),
        labels = buildLabels(),
        sortEnabled = not config.SortInventory or config.SortInventory.Enabled ~= false,
        sortKey = config.SortInventory and config.SortInventory.Key or 'KeyB',
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('hexa_inventory:client:closeInv', function()
    SetNuiFocus(false, false)
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'close',
        invToken = invToken,
    })
end)

RegisterNetEvent('hexa_inventory:client:updateInventory', function(authoritativeItems, requestId)

    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    local playerData = Core.GetPlayerData()
    SendNUIMessage({
        action = 'update',
        inventory = authoritativeItems or playerData.items,
        requestId = requestId,
        cash = playerData.money.cash,
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('hexa_inventory:client:updateOtherInventory', function(items, expiresIn, timerPaused, requestId)
    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'updateOther',
        inventory = items,
        expiresIn = expiresIn,
        timerPaused = timerPaused,
        requestId = requestId,
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('hexa_inventory:client:ItemBox', function(itemData, type, amount)

    local function sendItemBox()
        local invToken = GenerateInventoryCbToken()
        SendNUIMessage({
            action = 'itemBox',
            item = itemData,
            type = type,
            amount = amount,
            labels = buildLabels(),
            invToken = invToken,
        })

        if type == 'remove' or type == 'add' then
            TriggerServerEvent('hexa_inventory:server:updateHotbar')
        end
    end

    local lastItemBoxCall = LocalPlayer.state.lastItemBoxCall or 0
    local currentTime = GetGameTimer()
    local timeElapsed = currentTime - lastItemBoxCall

    if timeElapsed >= 1000 then
        sendItemBox()
        lastItemBoxCall = currentTime
    else
        local delay = 1000 - timeElapsed
        SetTimeout(delay, function()
            sendItemBox()
        end)
        lastItemBoxCall = currentTime + delay
    end

    LocalPlayer.state.lastItemBoxCall = lastItemBoxCall
end)

RegisterNetEvent('hexa_inventory:client:updateHotbar', function(items)

    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'updateHotbar',
        items = items,
        quickslotsEnabled = config.QuickSlotsEnabled ~= false,
        durabilityWarning = durabilityWarningPayload(),
        labels = buildLabels(),
        token = token,
        invToken = invToken,
    })
end)

local function L(k, d) return locale(k) or d end

function buildLabels()
    return {
        title   = L('ui.title', 'Hexa Inventory'),
        close   = L('ui.close', 'Close'),
        close_aria = L('ui.close_aria', 'Close inventory'),
        use     = L('ui.use', 'Use'),
        give    = L('ui.give', 'Give'),
        single  = L('ui.single', 'Single'),
        half    = L('ui.half', 'Half'),
        all     = L('ui.all', 'All'),
        split   = L('ui.split', 'Split'),
        amount  = L('ui.amount', 'Amount'),
        amount_placeholder = L('ui.amount_placeholder', 'amount'),
        move_amount = L('ui.move_amount', 'Move amount'),
        confirm = L('ui.confirm', 'Confirm'),
        drop    = L('ui.drop', 'Drop'),
        copy_serial = L('ui.copy_serial', 'Copy Serial'),
        sell    = L('ui.sell', 'Sell'),
        satchel = L('ui.satchel', 'Satchel'),
        weight  = L('ui.weight', 'Weight'),
        id      = L('ui.id', 'ID'),
        cash    = L('ui.cash', 'Cash'),
        received = L('ui.received', 'Received'),
        used     = L('ui.used', 'Used'),
        removed  = L('ui.removed', 'Removed'),
        trade    = L('ui.trade', 'Trade'),
        your_offer = L('ui.your_offer', 'Your Offer'),
        their_offer = L('ui.their_offer', 'Their Offer'),
        accept   = L('ui.accept', 'Accept'),
        waiting  = L('ui.waiting', 'Waiting for other player...'),
        cancel   = L('ui.cancel', 'Cancel'),
        accepted = L('ui.accepted', 'Accepted'),
        no_items_offered = L('ui.no_items_offered', 'No items offered'),
        quickslots = L('ui.quickslots', 'Quickslots'),
        quickslots_disabled = L('ui.quickslots_disabled', 'Quickslots disabled'),
        quickslot_off = L('ui.quickslot_off', 'OFF'),
        quickslot_hint = L('ui.quickslot_hint', 'Drag an item here, then press Alt+1-5 to use it'),
        inventory_hint = L('ui.inventory_hint', 'Drag to move / Right-click for actions / Double-click to use'),
        search  = L('ui.search', 'Search'),
        sort    = L('ui.sort', 'Sort'),
        clear   = L('ui.clear', 'Clear'),
        stack   = L('ui.stack', 'Stack'),
        take_all  = L('ui.take_all', 'Take All'),
        store_all = L('ui.store_all', 'Store All'),
        move_hint = L('ui.move_hint', 'Ctrl+click moves a whole stack'),
        expires_in = L('ui.expires_in', 'Deletes in'),
        wait_delete = L('ui.wait_delete', 'Waiting to delete when closed'),
        slots_used = L('ui.slots_used', 'slots'),
        durability_warning = L('ui.durability_warning', 'Low durability'),
        history = L('ui.history', 'History'),
        history_empty = L('ui.history_empty', 'No history yet'),
        history_receive = L('ui.history_receive', 'Received'),
        history_lost = L('ui.history_lost', 'Lost'),
        history_give = L('ui.history_give', 'Gave'),
        can_use = L('ui.can_use', 'Usable'),
        cannot_use = L('ui.cannot_use', 'Cannot use'),
        can_drop = L('ui.can_drop', 'Droppable'),
        cannot_drop = L('ui.cannot_drop', 'Cannot drop'),
        can_quickslot = L('ui.can_quickslot', 'Quickslot allowed'),
        cannot_quickslot = L('ui.cannot_quickslot', 'Quickslot blocked'),
        enter_player_id  = L('info.enter_player_id', 'Citizen ID'),
        no_player_nearby = L('error.no_player_nearby', 'No one nearby')
    }
end

RegisterNetEvent('hexa_inventory:client:openInventory', function(items, other)
    local token = exports['hexa_core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken(true)
    local Player = Core.GetPlayerData()
    local config = HexaInventory.Config
    local function L(k, d) return locale(k) or d end
    local labels = buildLabels()
    SetNuiFocus(true, true)
    if SetNuiFocusKeepInput then SetNuiFocusKeepInput(false) end

    SendNUIMessage({
        action    = 'open',
        inventory = items,
        slots     = (tonumber(Player.slots) or 0) + (tonumber(config.QuickSlots) or 5),
        quickslots = config.QuickSlots,
        quickslotsEnabled = config.QuickSlotsEnabled ~= false,
        sortEnabled = not config.SortInventory or config.SortInventory.Enabled ~= false,
        sortKey = config.SortInventory and config.SortInventory.Key or 'KeyB',
        historyEnabled = not config.History or config.History.Enabled ~= false,
        maxweight = Player.weight,
        playerId  = Player.citizenid or Player.source or Player.id,
        playerServerId = Player.source or Player.id,
        playerName = (Player.charinfo and Player.charinfo.firstname)
            and (Player.charinfo.firstname .. ' ' .. Player.charinfo.lastname)
            or Player.source,
        other     = other,
        token     = token,
        invToken  = invToken,
        closeKey  = config.Keybinds.Close,
        cash      = Player.money.cash,
        labels    = labels,

        categories = HexaInventory.CategoryPayload(L)
    })
end)
