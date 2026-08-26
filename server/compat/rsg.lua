-- Hexa Inventory source.
local config = HexaInventory.Config
if not config.Compatibility.RSG then return end

RegisterNetEvent('rsg-inventory:server:updateHotbar', function()
    local src = source
    local player = Core.GetPlayer(src)
    if not player then return end
    local items = {}
    if config.QuickSlotsEnabled ~= false then
        for slot = 1, config.QuickSlots do
            local item = Inventory.GetItemBySlot(src, slot)
            items[slot] = item and Inventory.IsItemQuickSlotAllowed(item) and item or nil
        end
    end
    TriggerClientEvent('hexa_inventory:client:updateHotbar', src, items)
end)

AddEventHandler('hexa_inventory:server:itemRemovedFromPlayerInventory', function(...)
    TriggerEvent('rsg-inventory:server:itemRemovedFromPlayerInventory', ...)
end)
