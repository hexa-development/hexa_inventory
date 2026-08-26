-- Hexa Inventory source.
local config = HexaInventory.Config

config.ItemRules = {
    DisableUse = {
        ['water_bucket'] = true,
        ['scarecrow'] = true,
    },
    DisableStack = {
        ['water_bucket'] = true,
        ['scarecrow'] = true,
    },
    DisableDrop = {
        ['weapon_repeater_carbine'] = true,
        ['weapon_sniperrifle_carcano'] = true,
    },
    DisableQuickSlot = {
        ['water_bucket'] = true,
        ['scarecrow'] = true,
    },
    SlotSize = {
        ['water_bucket'] = { width = 2, height = 2 },
        ['weapon_sniperrifle_carcano'] = { width = 2, height = 1 },
        ['weapon_repeater_carbine'] = { width = 2, height = 1 },
        ['scarecrow'] = { width = 1, height = 2 },
    },
}

return config.ItemRules
