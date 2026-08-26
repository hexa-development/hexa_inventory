-- Hexa Inventory source.
local config = HexaInventory.Config

config.ShopsRestockMinutes = 60
config.VendingObjects = {
    joaat('s_inv_whiskey02x'),
    joaat('p_whiskeycrate01x'),
    joaat('p_bal_whiskeycrate01'),
    joaat('p_whiskeybarrel01x'),
}
config.VendingItems = {
    { name = 'water', price = 0.1, amount = 50 },
    { name = 'bread', price = 0.1, amount = 50 },
}

return config
