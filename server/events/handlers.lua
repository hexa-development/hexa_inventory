-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

AddEventHandler('playerDropped', function()
    local src = source

    for invId, inv in pairs(Inventories) do
        if inv.isOpen == src then
            inv.isOpen = false
            VaultStore.Save(invId)
        end
    end

    for dropId, drop in pairs(Drops) do
        local touched = false

        if DropStore.IsOpenedBy(drop, src) then
            drop.isOpen = false
            drop.openedBy = nil
            touched = true
        end

        if drop.heldBy == src then
            drop.heldBy = nil
            touched = true
        end

        if touched then
            if next(drop.items or {}) == nil then
                DropStore.Delete(dropId)
            else
                DropStore.Resume(dropId)
                DropStore.Save(dropId)
            end
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            VaultStore.Save(inventory)
        end
    end
end)

AddEventHandler('HexaCore:Server:PlayerLoaded', function(xPlayer)
    local src = xPlayer.PlayerData.source
    Player(src).state.inv_busy = false
    Player(src).state.holdingDrop = false
    Player(src).state.heldDrop = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for k in pairs(Core.GetPlayerObjects()) do
        Player(k).state.inv_busy = false
        Player(k).state.holdingDrop = false
        Player(k).state.heldDrop = nil
    end
end)
