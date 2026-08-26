-- Hexa Inventory source.
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    Shops.SaveItemsInStock()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Shops.SaveItemsInStock()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Shops.LoadItemsInStock()
end)

local config = HexaInventory.Config
CreateThread(function()
    local interval = math.max(1, tonumber(config.ShopsRestockMinutes) or 60) * 60000
    while true do
        Wait(interval)
        for _, shopData in pairs(RegisteredShops) do
            for _, item in pairs(shopData.items) do
                if item.restock and item.amount then
                    item.amount = math.min(item.defaultstock, item.amount + item.restock)
                end
            end
        end
    end
end)
