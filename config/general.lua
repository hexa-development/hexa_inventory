-- Hexa Inventory source.
HexaInventory = HexaInventory or {}

HexaInventory.Config = {
    UseTarget = GetConvar('UseTarget', 'false') == 'true',
    StashSize = { maxweight = 500, slots = 100 },
    DropSize = { maxweight = -1, slots = -1 },
    DropMergeRadius = 1.5,
    Keybinds = {
        Open = 0xC1989F95,
        Hotbar = 0x26E9DC00,
        QuickSlotModifier = 0x8AAA0AD4,
    },
    QuickSlotsEnabled = true,
    QuickSlots = 5,
    InventoryColumns = 5,
    CleanupDropTime = 5,
    CleanupDropInterval = 1,
    ItemDropObject = joaat('P_MONEYBAG02X'),
    GiveItemType = 'picker',
    GiveItemRange = 3.0,
    CommandNames = {
        GiveItem = 'giveitem',
        RandomItems = 'randomitems',
        ClearInv = 'clearinv',
        CloseInv = 'closeinv',
        Hotbar = 'hotbar',
        Inventory = 'inventory',
        openInv = 'openinv',
    },
    ItemsDecayWhileOffline = false,
    Compatibility = { RSG = true, VORP = true },
}

return HexaInventory.Config
