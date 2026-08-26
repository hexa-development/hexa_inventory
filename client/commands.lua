-- Hexa Inventory source.
local config = HexaInventory.Config
Core = Core or exports['hexa_core']:GetCoreObject()

local function getMeta()
    local data = Core.GetPlayerData()
    return data and data.metadata or {}
end

local function canOpen()
    local meta = getMeta()
    return (not IsNuiFocused() and not IsPauseMenuActive())
        and (not meta.isdead and not meta.ishandcuffed)
end

local function openErrorNotify()
    local meta = getMeta()
    if meta.isdead then
        HexaInventory.Notify({
            title       = 'hexa_inventory',
            description = locale('error.openinverror'),
            type        = 'error'
        })
    elseif meta.ishandcuffed then
        HexaInventory.Notify({
            title       = 'hexa_inventory',
            description = locale('error.cuffopeninv'),
            type        = 'error'
        })
    end
end

RegisterCommand(config.CommandNames.openInv, function()
    if canOpen() then
        ExecuteCommand(config.CommandNames.Inventory)
    else
        openErrorNotify()
    end
end, false)

RegisterCommand(config.CommandNames.Hotbar, function()
    if config.QuickSlotsEnabled == false then return end
    if canOpen() then
        ExecuteCommand('serversidehotbar')
    else
        openErrorNotify()
    end
end, false)

RegisterCommand('trade', function()
    if not canOpen() then
        openErrorNotify()
        return
    end

    local targetId = HexaInventory.PromptNumber(locale('info.enter_player_id'))
    if targetId then
        TriggerServerEvent('hexa_inventory:server:initiateTrade', targetId)
    end
end, false)

for i = 1, config.QuickSlots do
    RegisterCommand('slot_' .. i, function()
        Inventory.UseHotbarItem(i)
    end, false)
end
