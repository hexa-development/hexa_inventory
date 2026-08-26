-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
local config = HexaInventory.Config
Inventory = {}

local function notifyHotbarSpamProtection()
    if not config.HotbarSpamProtectionNotify then return end
    HexaInventory.Notify({
        title       = locale('error.error'),
        description = locale('error.SpamProtection'),
        type        = 'error',
        duration    = 5000
    })
end

function Inventory.CanPlayerUseInventory()
    local player = Core.GetPlayerData()
    if not player or not player.metadata then return false end
    local meta = player.metadata
    return not meta.isdead and not meta.ishandcuffed
end

function Inventory.UseHotbarItem(slot)
    if config.QuickSlotsEnabled == false then return end
    local currentTime = GetGameTimer()
    local lastUsed    = LocalPlayer.state.hotbarLastUsed or 0

    if currentTime - lastUsed < config.HotbarSpamProtectionTimeout then
        return notifyHotbarSpamProtection()
    end

    LocalPlayer.state.hotbarLastUsed = currentTime

    local playerData = Core.GetPlayerData()
    local itemData   = playerData.items and playerData.items[slot]
    if not itemData then return end
    if itemData.quickslot == false then return end

    if itemData.type == "weapon" and LocalPlayer.state.holdingDrop then
        return HexaInventory.Notify({
            title       = locale('error.error'),
            description = locale('error.error_already_holding_bag'),
            type        = 'error',
            duration    = 5000
        })
    end

    TriggerServerEvent('hexa_inventory:server:useItem', itemData, true)
end
