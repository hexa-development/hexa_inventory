-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

Inventories = {}
Drops = {}
RegisteredShops = {}
ShopsStockCache = {}

CreateThread(function()
    VaultStore.LoadAll()
    DropStore.LoadAll()
end)

local config = HexaInventory.Config
CreateThread(function()
    while true do

        for k, v in pairs(Drops) do
            if v and (v.createdTime + (config.CleanupDropTime * 60) < os.time()) and not Drops[k].isOpen and not Drops[k].heldBy then
                DropStore.Delete(k)
            end
        end
        Wait(config.CleanupDropInterval * 60000)
    end
end)

CreateThread(function()
    while true do
        Wait(15000)
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src and Core.GetPlayer(src) then
                Inventory.ClearStaleBusy(src)
            end
        end
    end
end)
