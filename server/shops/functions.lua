-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()
Shops = Shops or {}

Shops.SetupShopItems = function(shopItems, shopData)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = Core.Shared.Items[item.name:lower()]
            if itemInfo then
                local slotWidth, slotHeight = Inventory.GetItemDimensions(itemInfo.name)
                local amount
                if item.amount then
                    if shopData.persistentStock then
                        if ShopsStockCache[shopData.name] and ShopsStockCache[shopData.name].items[itemInfo['name']] then
                            amount = tonumber(ShopsStockCache[shopData.name].items[itemInfo['name']].stock)
                        else
                            amount = item.amount
                        end
                    else
                        amount = item.amount
                    end
                else
                    amount = nil
                end

                items[slot] = {
                    name = itemInfo['name'],
                    amount = amount,
                    maxStock = item.maxStock,
                    defaultstock = item.amount,
                    restock = item.restock,
                    info = item.info or {},
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    rarity = itemInfo['rarity'] or 'common',
                    unique = itemInfo['unique'],
                    stackable = Inventory.IsItemStackable(itemInfo['name']),
                    useable = Inventory.IsItemUsable(itemInfo['name']),
                    droppable = Inventory.IsItemDroppable(itemInfo['name']),
                    quickslot = Inventory.IsItemQuickSlotAllowed(itemInfo['name']),
                    slotSize = Inventory.GetItemBaseSlotSize(itemInfo['name']),
                    slotWidth = slotWidth,
                    slotHeight = slotHeight,
                    price = item.price,
                    buyPrice = item.buyPrice,
                    image = itemInfo['image'],
                    slot = slot,
                    minQuality = item.minQuality,
                }

                slot = slot + 1
            end
        end
    end
    return items
end

Shops.SaveItemsInStock = function()

    return true
end

Shops.LoadItemsInStock = function()
    ShopsStockCache = {}
    return true
end
