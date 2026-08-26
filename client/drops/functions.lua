-- Hexa Inventory source.
Drops = {
    Active = {},
    Targeted = {},
    Opening = false,
}

function Drops.UsesTarget()
    local config = HexaInventory.Config
    return config.UseTarget and GetResourceState('ox_target') == 'started'
end

function Drops.Register(identifier, networkId)
    if identifier and networkId then Drops.Active[identifier] = networkId end
end

function Drops.UnregisterByNetworkId(networkId)
    for identifier, currentNetworkId in pairs(Drops.Active) do
        if currentNetworkId == networkId then
            Drops.Active[identifier] = nil
            Drops.Targeted[identifier] = nil
        end
    end
end

function Drops.Open(identifier)
    if type(identifier) ~= 'string' or identifier == '' then return false end
    if Drops.Opening or LocalPlayer.state.inv_busy or LocalPlayer.state.holdingDrop then return false end

    Drops.Opening = true
    LocalPlayer.state.currentDrop = identifier

    CreateThread(function()
        local ped = PlayerPedId()
        local canAnimate = DoesEntityExist(ped)
            and not IsEntityDead(ped)
            and not IsPedInAnyVehicle(ped, false)
            and not IsPedOnMount(ped)

        if canAnimate then
            ClearPedTasksImmediately(ped)
            TaskStartScenarioInPlaceHash(
                ped,
                GetHashKey('RANSACK_FALLBACK_PICKUP_CROUCH'),
                0,
                true,
                GetHashKey('RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH'),
                -1.0,
                false
            )
            Wait(650)
        end

        TriggerServerEvent('hexa_inventory:server:openDrop', identifier)

        Wait(canAnimate and 550 or 900)
        if canAnimate and DoesEntityExist(ped) then ClearPedTasksImmediately(ped) end
        Drops.Opening = false
    end)

    return true
end

function Drops.ResetPlayerState()
    if LocalPlayer.state.holdingDrop then

        ExecuteCommand('loadskin')
    end

    LocalPlayer.state.holdingDrop   = nil
    LocalPlayer.state.dropBagObject = nil
    LocalPlayer.state.heldDrop      = nil
end

function Drops.GetDrops()
    local drops = InventoryCallback.Await('hexa_inventory:server:GetCurrentDrops')
    if not drops then return end

    for k, v in pairs(drops) do
        TriggerEvent('hexa_inventory:client:setupDropTarget', v.entityId, k)
    end
end
