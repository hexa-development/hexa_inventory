-- Hexa Inventory source.
Shops = Shops or {}

Shops.CreateShop = function(shopData)
    if shopData.name then
        if RegisteredShops[shopData.name] then
            local old = RegisteredShops[shopData.name]
            old.items = Shops.SetupShopItems(shopData.items, shopData)
            old.slots = #shopData.items
            old.persistentStock = shopData.persistentStock ~= nil and shopData.persistentStock or old.persistentStock
            return
        end

        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #shopData.items,
            items = Shops.SetupShopItems(shopData.items, shopData),
            persistentStock = shopData.persistentStock,
        }
    else
        for key, data in pairs(shopData) do
            if type(data) == 'table' then
                if data.name then
                    local shopName = type(key) == 'number' and data.name or key
                    if RegisteredShops[shopName] then
                        local old = RegisteredShops[shopName]
                        old.items = Shops.SetupShopItems(data.items, data)
                        old.slots = #data.items
                        old.persistentStock = data.persistentStock ~= nil and data.persistentStock or old.persistentStock
                    else
                        RegisteredShops[shopName] = {
                            name = shopName,
                            label = data.label,
                            coords = data.coords,
                            slots = #data.items,
                            items = Shops.SetupShopItems(data.items, data),
                            persistentStock = data.persistentStock,
                        }
                    end
                else
                    Shops.CreateShop(data)
                end
            end
        end
    end
end

exports('CreateShop', Shops.CreateShop)

Shops.OpenShop = function(source, name)
    if not name then return end
    Core = Core or exports['hexa_core']:GetCoreObject()
    local player = Core.GetPlayer(source)
    if not player then return end
    if not RegisteredShops[name] then return end
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if RegisteredShops[name].coords then
        local shopDistance = vector3(RegisteredShops[name].coords.x, RegisteredShops[name].coords.y, RegisteredShops[name].coords.z)
        if shopDistance then
            local distance = #(playerCoords - shopDistance)
            if distance > Inventory.MAX_DIST then return end
        end
    end
    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        maxweight = 500,
        slots = #RegisteredShops[name].items,
        inventory = RegisteredShops[name].items,
        persistentStock = RegisteredShops[name].persistentStock,
    }

    Player(source).state.inv_busy = true
    Inventory.CheckPlayerItemsDecay(player)
    TriggerClientEvent('hexa_inventory:client:openInventory', source, player.PlayerData.items, formattedInventory)
end

exports('OpenShop', Shops.OpenShop)

Shops.RestockShop = function(shopName, percentage)
    local shopData = RegisteredShops[shopName]
    if not shopData then return false end

    percentage = percentage or 100
    local mult = percentage / 100

    for slot, item in pairs(shopData.items) do
        if item.amount then
            local restock = math.round(item.defaultstock * mult, 0)
            item.amount = math.min(item.defaultstock, item.amount + restock)
        end
    end
    return true
end

exports('RestockShop', Shops.RestockShop)

function Shops.DoesShopExist(shopName)
    if type(shopName) ~= "string" then return false end
    return RegisteredShops and RegisteredShops[shopName] ~= nil
end

exports('DoesShopExist', Shops.DoesShopExist)
