-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

CreateThread(function()
    local promptGroup = GetRandomIntInRange(0, 0xffffff)
    local groupTitle = CreateVarString(10, 'LITERAL_STRING', locale('info.loot_bag'))

    local function createHoldPrompt(control, label)
        local prompt = UiPromptRegisterBegin()
        PromptSetControlAction(prompt, control)
        PromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', label))
        PromptSetEnabled(prompt, true)
        PromptSetVisible(prompt, true)
        PromptSetHoldMode(prompt, true)
        PromptSetGroup(prompt, promptGroup)
        PromptRegisterEnd(prompt)
        return prompt
    end

    local openPrompt = createHoldPrompt(Core.Shared.Keybinds.E, locale('info.o_bag'))

    while true do
        if Drops.UsesTarget() or LocalPlayer.state.holdingDrop or LocalPlayer.state.inv_busy then
            Wait(500)
        else
            local playerCoords = GetEntityCoords(PlayerPedId())
            local nearestId, nearestDistance

            for identifier, networkId in pairs(Drops.Active) do
                if NetworkDoesNetworkIdExist(networkId) then
                    local bag = NetworkGetEntityFromNetworkId(networkId)
                    if DoesEntityExist(bag) then
                        local distance = #(playerCoords - GetEntityCoords(bag))
                        if distance <= 2.5 and (not nearestDistance or distance < nearestDistance) then
                            nearestId, nearestDistance = identifier, distance
                        end
                    end
                end
            end

            if nearestId then
                PromptSetActiveGroupThisFrame(promptGroup, groupTitle)
                if PromptHasHoldModeCompleted(openPrompt) then
                    Drops.Open(nearestId)
                end
                Wait(0)
            else
                Wait(350)
            end
        end
    end
end)
