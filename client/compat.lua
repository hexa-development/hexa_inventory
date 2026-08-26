-- Hexa Inventory source.
local config = HexaInventory.Config

if config.Compatibility.RSG then
    RegisterNetEvent('rsg-inventory:client:openInventory', function(...)
        TriggerEvent('hexa_inventory:client:openInventory', ...)
    end)
    RegisterNetEvent('rsg-inventory:client:closeInv', function(...)
        TriggerEvent('hexa_inventory:client:closeInv', ...)
    end)
    RegisterNetEvent('rsg-inventory:client:updateInventory', function(...)
        TriggerEvent('hexa_inventory:client:updateInventory', ...)
    end)
    RegisterNetEvent('rsg-inventory:client:ItemBox', function(...)
        TriggerEvent('hexa_inventory:client:ItemBox', ...)
    end)
    RegisterNetEvent('rsg-inventory:client:hotbar', function(...)
        TriggerEvent('hexa_inventory:client:hotbar', ...)
    end)
    RegisterNetEvent('rsg-inventory:client:giveAnim', function(...)
        TriggerEvent('hexa_inventory:client:giveAnim', ...)
    end)
end
