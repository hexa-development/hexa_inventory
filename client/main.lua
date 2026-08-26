-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
local config = HexaInventory.Config

InventoryCallback.Register('hexa_inventory:client:isInMelee', function()
    local ped = PlayerPedId()
    return IsPedInMeleeCombat(ped)
end)

CreateThread(function()
    local models = config.VendingObjects
    if not models or #models == 0 then return end

    local promptGroup = GetRandomIntInRange(0, 0xffffff)
    local groupTitle = CreateVarString(10, 'LITERAL_STRING', locale('info.vending'))
    local openPrompt = UiPromptRegisterBegin()
    PromptSetControlAction(openPrompt, Core.Shared.Keybinds.E)
    PromptSetText(openPrompt, CreateVarString(10, 'LITERAL_STRING', locale('info.vending')))
    PromptSetEnabled(openPrompt, true)
    PromptSetVisible(openPrompt, true)
    PromptSetHoldMode(openPrompt, true)
    PromptSetGroup(openPrompt, promptGroup)
    PromptRegisterEnd(openPrompt)

    while true do
        if LocalPlayer.state.inv_busy then
            Wait(500)
        else
            local playerCoords = GetEntityCoords(PlayerPedId())
            local nearestObject, nearestDistance

            for i = 1, #models do
                local object = GetClosestObjectOfType(
                    playerCoords.x,
                    playerCoords.y,
                    playerCoords.z,
                    2.5,
                    models[i],
                    false,
                    false,
                    false
                )

                if object ~= 0 and DoesEntityExist(object) then
                    local distance = #(playerCoords - GetEntityCoords(object))
                    if distance <= 2.5 and (not nearestDistance or distance < nearestDistance) then
                        nearestObject, nearestDistance = object, distance
                    end
                end
            end

            if nearestObject then
                PromptSetActiveGroupThisFrame(promptGroup, groupTitle)
                if PromptHasHoldModeCompleted(openPrompt) then
                    TriggerServerEvent('hexa_inventory:server:openVending', {
                        coords = GetEntityCoords(nearestObject),
                    })
                    Wait(750)
                else
                    Wait(0)
                end
            else
                Wait(350)
            end
        end
    end
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
