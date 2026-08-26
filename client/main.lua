-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
local config = HexaInventory.Config

InventoryCallback.Register('hexa_inventory:client:isInMelee', function()
    local ped = PlayerPedId()
    return IsPedInMeleeCombat(ped)
end)

CreateThread(function()
    if not config.UseTarget or GetResourceState('ox_target') ~= 'started' then return end
    local models = config.VendingObjects
    if not models or #models == 0 then return end

    exports.ox_target:addModel(models, {
        label = locale('info.vending'),
        icon = 'fa-solid fa-cash-register',
        distance = 2.5,
        onSelect = function(data)
            data.coords = GetEntityCoords(data.entity)
            TriggerServerEvent('hexa_inventory:server:openVending', data)
        end,
    })
end)

CreateThread(function()

    local commands = {
        [config.Keybinds.Open] = { command = "inventory", disabled = false },
        [config.Keybinds.Hotbar] = { command = "hotbar", disabled = false },
    }

    local quickSlotModifier = config.Keybinds.QuickSlotModifier
        or Core.Shared.Keybinds.LALT
        or 0x8AAA0AD4

    while true do
        Wait(0)
        for control, meta in pairs(commands) do
            if meta.disabled then

                DisableControlAction(0, control, true)
                if IsDisabledControlJustPressed(0, control) then
                    if Inventory.CanPlayerUseInventory() then
                        ExecuteCommand(meta.command)
                    end
                    break
                end
            else

                if IsControlJustReleased(0, control) then
                    if Inventory.CanPlayerUseInventory() then
                        ExecuteCommand(meta.command)
                    end
                    break
                end
            end
        end

        if config.QuickSlotsEnabled ~= false
            and (IsControlPressed(0, quickSlotModifier) or IsDisabledControlPressed(0, quickSlotModifier)) then
            for slot = 1, config.QuickSlots do
                local control = Core.Shared.Keybinds[tostring(slot)]
                if control then
                    DisableControlAction(0, control, true)
                    if IsDisabledControlJustPressed(0, control) then
                        if Inventory.CanPlayerUseInventory() then
                            ExecuteCommand("slot_" .. slot)
                        end
                        break
                    end
                end
            end
        end
    end
end)
