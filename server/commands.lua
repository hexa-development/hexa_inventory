-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
local config = HexaInventory.Config

local function notify(source, messageKey, type)
    TriggerClientEvent('hexa_inventory:client:notify', source, { title = locale(messageKey), type = type or 'error', duration = 5000 })
end

local function getPlayer(source, notifyIfMissing)
    local ply = Core.GetPlayer(source)
    if not ply and notifyIfMissing then notify(source, 'error.pdne') end
    return ply
end

local function addItemToInventory(target, itemData, amount, info, context)
    amount = amount or 1
    local stored, dropped = Inventory.AddItem(target, itemData.name, amount, false, info or {}, context or 'server command')
    local success = stored or dropped
    if success then
        TriggerClientEvent('hexa_inventory:client:ItemBox', target, itemData, 'add', amount)
        if Player(target).state.inv_busy then
            TriggerClientEvent('hexa_inventory:client:updateInventory', target)
        end
    else
        notify(target, 'error.cgitem')
    end
    return success
end

HexaInventory.AddCommand(config.CommandNames.GiveItem, {
    help = locale('info.giveitem_help'),
    restricted = 'group.admin',
    params = {
        { name = 'target', type = 'playerId', help = locale('info.param_target') },
        { name = 'item', type = 'string', help = locale('info.param_item') },
        { name = 'amount', type = 'number', help = locale('info.param_amount'), optional = true },
    }
}, function(source, args)
    local player = getPlayer(args.target, true)
    if not player then return end

    local itemName = tostring(args.item):lower()
    local itemData = Core.Shared.Items[itemName]
    if not itemData then return notify(source, 'error.idne') end

    local amount = tonumber(args.amount) or 1
    local info = {}

    if itemData.name == 'id_card' then
        local char = player.PlayerData.charinfo
        info = {
            citizenid = player.PlayerData.citizenid,
            firstname = char.firstname,
            lastname = char.lastname,
            birthdate = char.birthdate,
            gender = char.gender,
            nationality = char.nationality
        }

    elseif itemData.type == 'weapon' then
        amount = 1
        info.serie = string.format(
            "%s%s%s%s%s%s",
            Core.Shared.RandomInt(2),
            Core.Shared.RandomStr(3),
            Core.Shared.RandomInt(1),
            Core.Shared.RandomStr(2),
            Core.Shared.RandomInt(3),
            Core.Shared.RandomStr(4)
        )
        info.quality = 100
    end
 if addItemToInventory(args.target, itemData, amount, info, 'give item command') then
    local message = string.format(locale('info.yhg'), itemData.label, amount)

    notify(source, message, 'success')
    end
end)

HexaInventory.AddCommand(config.CommandNames.RandomItems, {
    help = locale('info.randomitems_help'),
    restricted = 'group.god'
}, function(source)
    local player = getPlayer(source)
    if not player then return end

    local filteredItems = {}
    for _, v in pairs(Core.Shared.Items) do
        if v.type ~= 'weapon' then table.insert(filteredItems, v) end
    end

    local playerInventory = player.PlayerData.items

    for _ = 1, 10 do
        local randItem = filteredItems[math.random(#filteredItems)]
        local amount = randItem.unique and 1 or math.random(1, 10)

        if Inventory.CanAddItem(source, randItem.name, amount) then
            addItemToInventory(source, randItem, amount, false, 'random items command')
            playerInventory = Core.GetPlayer(source).PlayerData.items
        end

        Wait(1000)
    end
end)

HexaInventory.AddCommand(config.CommandNames.ClearInv, {
    help = locale('info.clearinv_help'),
    restricted = 'group.admin',
    params = {
        { name = 'target', type = 'playerId', help = locale('info.param_target'), optional = true }
    }
}, function(source, args)
    local target = args.target or source
    Inventory.ClearInventory(target)
    if target == source then
        TriggerClientEvent('hexa_inventory:client:notify', source, { title = locale('info.inventory_cleared'), type = 'success', duration = 5000 })
    else
        TriggerClientEvent('hexa_inventory:client:notify', target, { title = locale('info.inventory_cleared'), type = 'success', duration = 5000 })
        TriggerClientEvent('hexa_inventory:client:notify', source, { title = locale('info.inventory_cleared_for') .. GetPlayerName(target), type = 'success', duration = 5000 })
    end
end)

RegisterCommand(config.CommandNames.CloseInv, function(source)
    Inventory.CloseInventory(source)
    TriggerClientEvent('hexa_inventory:client:notify', source, { title = locale('info.inventory_closed'), type = 'success', duration = 5000 })
end, false)

RegisterCommand('serversidehotbar', function(source)
    if config.QuickSlotsEnabled == false then return end
    if Player(source).state.inv_busy then return end
    local ply = getPlayer(source)
    if not ply then return end
    if ply.PlayerData.metadata.isdead or ply.PlayerData.metadata.inlaststand or ply.PlayerData.metadata.ishandcuffed then return end

    local hotbarItems = {}
    for i = 1, config.QuickSlots do
        local item = ply.PlayerData.items[i]
        hotbarItems[i] = item and Inventory.IsItemQuickSlotAllowed(item) and item or nil
    end
    TriggerClientEvent('hexa_inventory:client:hotbar', source, hotbarItems)
end, false)

RegisterCommand(config.CommandNames.Inventory, function(source)
    if Player(source).state.inv_busy then return end
    local ply = getPlayer(source)
    if not ply then return end
    if ply.PlayerData.metadata.isdead or ply.PlayerData.metadata.ishandcuffed then return end

    Inventory.OpenInventory(source)
end, false)

RegisterCommand('hexa_unstick', function(source)
    local src = source
    if src == 0 then return end

    Player(src).state.inv_busy = false
    Player(src).state.holdingDrop = false
    Player(src).state.heldDrop = nil

    for dropId, drop in pairs(Drops or {}) do
        local touched = false
        if DropStore.IsOpenedBy(drop, src) then
            drop.isOpen, drop.openedBy = false, nil
            touched = true
        end
        if drop.heldBy == src then
            drop.heldBy = nil
            touched = true
        end
        if touched then DropStore.Save(dropId) end
    end

    TriggerClientEvent('hexa_inventory:client:notify', src, {
        title = 'Inventory',
        description = 'state cleared - try the bag again',
        type = 'success',
        duration = 5000,
    })
end, false)
