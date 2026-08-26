-- Hexa Inventory source.
local config = HexaInventory.Config

config.SortInventory = {
    Enabled = true,
    Key = 'KeyB',
    Criteria = { 'type', 'rarity', 'name' },
    RarityDescending = true,
    RarityOrder = {
        common = 1,
        uncommon = 2,
        rare = 3,
        epic = 4,
        legendary = 5,
    },
}

config.DurabilityWarning = {
    Enabled = true,
    Threshold = 10,
    SoundEnabled = true,
    Volume = 0.35,
}

config.History = { Enabled = true, MaxEntries = 100 }
config.HotbarSpamProtectionTimeout = 500
config.HotbarSpamProtectionNotify = false

return config
