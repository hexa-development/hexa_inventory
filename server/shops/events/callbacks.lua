-- Hexa Inventory source.
Core = Core or exports['hexa_core']:GetCoreObject()

local purchaseCooldowns = {}

local function notifyPlayer(source, messageKey, type)
    TriggerClientEvent('hexa_inventory:client:notify', source, { title = locale(messageKey), type = type or 'error', duration = 5000 })
end

InventoryCallback.Register('hexa_inventory:server:attemptPurchase', function(source, data)

    local now = os.time()
    if purchaseCooldowns[source] and now - purchaseCooldowns[source] < 1 then return false end
    purchaseCooldowns[source] = now

    if type(data) ~= 'table' or type(data.item) ~= 'table' or type(data.item.name) ~= 'string' or type(data.shop) ~= 'string' then
        return false
    end

    local itemInfo      = data.item
    local amount        = math.floor(tonumber(data.amount) or 0)
    local shopName      = string.gsub(data.shop, '^shop%-', '')
    local sourceInvType = data.sourceinvtype

    if amount <= 0 then return false end

    if itemInfo.unique and amount > 1 then amount = 1 end

    local Player = Core.GetPlayer(source)
    if not Player then return false end

    local shopInfo = RegisteredShops[shopName]
    if not shopInfo then return false end

    if shopInfo.coords then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        local shopCoords   = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10.0 then return false end
    end

    if sourceInvType == 'player' then
        for _, shopItem in ipairs(shopInfo.items) do
            if itemInfo.name == shopItem.name and shopItem.buyPrice then

                local realItem = Inventory.GetItemBySlot(source, itemInfo.slot)
                if not realItem or realItem.name ~= itemInfo.name or realItem.amount < amount then
                    notifyPlayer(source, 'error.not_enough_items') return false
                end
                local realQuality = realItem.info.quality or 100

                if realQuality < (shopItem.minQuality or 1) then
                    notifyPlayer(source, 'error.quality_too_low') return false
                end

                if shopItem.maxStock and shopItem.maxStock < (shopItem.amount + amount) then
                    notifyPlayer(source, 'error.shop_fully_stocked') return false
                end

                if not Inventory.HasItem(source, itemInfo.name, amount) then
                    notifyPlayer(source, 'error.not_enough_items') return false
                end

                local buyPrice = shopItem.buyPrice * amount * (realQuality / 100)
                buyPrice = math.max(0.01, math.round(buyPrice, 2))

                if not Inventory.RemoveItem(source, itemInfo.name, amount, itemInfo.slot, 'shop-sell') then
                    notifyPlayer(source, 'error.not_enough_items')
                    return false
                end
                if shopItem.amount then shopItem.amount = shopItem.amount + amount end
                Player.AddMoney('cash', buyPrice, 'shop-sell')
                TriggerClientEvent('hexa_inventory:client:updateInventory', source)
                return true
            end
        end

        notifyPlayer(source, 'error.shop_does_not_buy') return false
    end

    local shopSlot = shopInfo.items[tonumber(itemInfo.slot)]
    if not shopSlot or shopSlot.name ~= itemInfo.name then return false end

    if shopSlot.amount and amount > shopSlot.amount then
        notifyPlayer(source, 'error.cannot_purchase_more_than_stock') return false
    end

    if not Inventory.CanAddItem(source, itemInfo.name, amount, shopSlot.info) then
        notifyPlayer(source, 'error.cannot_carry') return false
    end

    if not shopSlot.price then
        notifyPlayer(source, 'info.no_price_or_not_for_sale') return false
    end

    local price = math.round(shopSlot.price * amount, 2)
    if Player.PlayerData.money.cash < price then
        notifyPlayer(source, 'error.not_enough_money') return false
    end

    if shopSlot.amount then
        shopSlot.amount = shopSlot.amount - amount
    end

    Player.RemoveMoney('cash', price, 'shop-purchase')
    if not Inventory.AddItem(source, itemInfo.name, amount, false, shopSlot.info or {}, 'shop-purchase', false) then
        Player.AddMoney('cash', price, 'shop-purchase-refund')
        if shopSlot.amount then shopSlot.amount = shopSlot.amount + amount end
        return false
    end
    TriggerClientEvent('hexa_inventory:client:updateInventory', source)
    return true
end)
