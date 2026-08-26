-- Hexa Inventory source.
local separator = package.config:sub(1, 1)
local scriptPath = debug.getinfo(1, 'S').source:gsub('^@', '')
local projectRoot = scriptPath:match('^(.*)[/\\]tests[/\\][^/\\]+$') or '.'
local function projectFile(path)
    return projectRoot .. separator .. path:gsub('[/\\]', separator)
end

package.path = projectRoot .. separator .. '?.lua;'
    .. projectRoot .. separator .. '?' .. separator .. 'init.lua;'
    .. package.path

local registeredExports = {}

GetConvar = function(_, default) return default end
GetCurrentResourceName = function() return 'hexa_inventory' end
GetInvokingResource = function() return 'inventory_smoke' end
GetPlayerName = function(source) return 'player-' .. tostring(source) end
GetPlayerPed = function() return 0 end
GetSelectedPedWeapon = function() return 0 end
RemoveWeaponFromPed = function() end
TriggerEvent = function() end
TriggerClientEvent = function() end
DoesEntityExist = function() return false end
Player = function() return { state = { inv_busy = false } } end
joaat = function(value) return value end
vector3 = function(x, y, z) return { x = x, y = y, z = z } end
warn = function() end
json = { encode = function() return '{}' end }

local player = {
    Offline = false,
    PlayerData = {
        source = 1,
        citizenid = 'test-character',
        items = {},
        weight = 10,
        slots = 2,
    },
}

function player.SetPlayerData(key, value)
    player.PlayerData[key] = value
end

Core = {
    Shared = {
        Items = {
            bread = { name = 'bread', label = 'Bread', weight = 1, type = 'item', unique = false, useable = true, image = 'bread.png' },
            water = { name = 'water', label = 'Water', weight = 1, type = 'item', unique = false, useable = true, image = 'water.png' },
            badge = { name = 'badge', label = 'Badge', weight = 1, type = 'item', unique = true, useable = false, droppable = false, quickslot = false, image = 'badge.png' },
            water_bucket = { name = 'water_bucket', label = 'Water Bucket', weight = 1, type = 'item', unique = false, useable = false, image = 'water_bucket.png' },
        },
        RandomInt = function() return '1' end,
        RandomStr = function() return 'A' end,
    },
    GetPlayer = function(source) return tonumber(source) == 1 and player or nil end,
    GetUsableItem = function() return nil end,
}

exports = setmetatable({
    hexa_core = { GetCoreObject = function() return Core end },
}, {
    __call = function(_, name, handler) registeredExports[name] = handler end,
})

HexaInventory = {
    Merge = function(base, override)
        local result = {}
        for key, value in pairs(base or {}) do result[key] = value end
        for key, value in pairs(override or {}) do result[key] = value end
        return result
    end,
}

math.round = function(value) return math.floor(value + 0.5) end
Inventories, Drops = {}, {}
VaultStore = { LoadPlayer = function() return {} end, SavePlayer = function() return true end, Save = function() return true end, Delete = function() return true end }
DropStore = { Save = function() return true end }

dofile(projectFile('config/general.lua'))
dofile(projectFile('config/items.lua'))
dofile(projectFile('config/features.lua'))
dofile(projectFile('config/shops.lua'))
dofile(projectFile('shared/helpers.lua'))
dofile(projectFile('server/functions.lua'))
dofile(projectFile('server/exports.lua'))

local function expect(value, message)
    if not value then error(message, 2) end
end

expect(HexaInventory.Config.QuickSlots == 5, 'quickslot configuration should expose five slots')
expect(type(HexaInventory.Config.QuickSlotsEnabled) == 'boolean', 'quickslot system should be configurable')
expect(Inventory.GetPlayerSlotLimit(player) == 7, 'quick slots should extend normal player capacity')

HexaInventory.Config.QuickSlotsEnabled = false
expect(not Inventory.IsItemQuickSlotAllowed('bread'), 'global quickslot switch must block every item')
expect(not Inventory.CanPlaceItemAt({}, 'bread', 1, 7, true),
    'global quickslot switch must block server-side placement')
HexaInventory.Config.QuickSlotsEnabled = true

local stored, dropped = Inventory.AddItem(1, 'bread', 2, false, {}, 'test', false)
expect(stored and not dropped, 'bread should be stored')
expect(player.PlayerData.items[6].amount == 2, 'automatic placement must skip quick slots')

stored = Inventory.AddItem(1, 'bread', 3, false, {}, 'test', false)
expect(stored and player.PlayerData.items[6].amount == 5, 'bread should stack in normal inventory')

stored = Inventory.AddItem(1, 'water', 1, false, {}, 'test', false)
expect(stored and player.PlayerData.items[7].name == 'water', 'automatic placement should use the next normal slot')
expect(Inventory.CanAddItem(1, 'bread', 1), 'a full inventory should still accept a compatible stack')

local canAdd, reason = Inventory.CanAddItem(1, 'badge', 1)
expect(not canAdd and reason == 'slots', 'unique item should be rejected when slots are full')

stored = Inventory.AddItem(1, 'badge', 1, 7, {}, 'test', false)
expect(not stored and player.PlayerData.items[7].name == 'water', 'an occupied slot must not be overwritten')

expect(Inventory.RemoveItem(1, 'bread', 3, false, 'test'), 'bread removal should succeed')
expect(Inventory.HasItem(1, 'bread', 2), 'remaining bread count should be visible')
expect(not Inventory.HasItem(1, 'bread', 3), 'removed bread must not remain')

local moveItems = Inventory.HydrateItems({
    { name = 'bread', amount = 2, slot = 6, info = {} },
    { name = 'water', amount = 1, slot = 7, info = {} },
})
expect(Inventory.MoveItemWithin(moveItems, 6, 8, 2, 15, true),
    'a full stack should move to an empty slot atomically')
expect(not moveItems[6] and moveItems[8] and moveItems[8].name == 'bread',
    'the atomic move must not retain the old anchor')
expect(Inventory.MoveItemWithin(moveItems, 8, 9, 1, 15, true),
    'a stack should split atomically')
expect(moveItems[8].amount == 1 and moveItems[9].amount == 1,
    'the atomic split should preserve both amounts')
expect(Inventory.MoveItemWithin(moveItems, 9, 8, 1, 15, true),
    'matching stacks should combine atomically')
expect(not moveItems[9] and moveItems[8].amount == 2,
    'the atomic stack should remove the emptied source')
expect(Inventory.MoveItemWithin(moveItems, 7, 8, 1, 15, true),
    'different items should swap atomically')
expect(moveItems[7].name == 'bread' and moveItems[8].name == 'water',
    'the atomic swap must update both slot anchors')

player.PlayerData.weight = 3
stored, dropped = Inventory.AddItem(1, 'bread', 2, false, {}, 'test', false)
expect(not stored and not dropped, 'atomic add should neither store nor drop when overweight')

expect(Inventory.GetItemBaseSlotSize('water_bucket') == 4, 'configured bucket should consume four slots')
expect(not Inventory.IsItemStackable('water_bucket'), 'configured bucket must not stack')
expect(not Inventory.IsItemQuickSlotAllowed('water_bucket'), 'configured bucket must be blocked from quick slots')
expect(Inventory.GetItemSlotSize('water_bucket', 1, true) == 1, 'a large item in a quick slot should consume one slot')
expect(Inventory.GetItemSlotSize('water_bucket', 6, true) == 4, 'a large item outside quick slots should consume its full size')
expect(not Inventory.CanPlaceItemAt({}, 'water_bucket', 1, 7, true),
    'server layout validation must reject a configured item in a quick slot')
expect(not Inventory.IsItemDroppable('badge'), 'catalogue droppable=false must be authoritative')
expect(not Inventory.IsItemQuickSlotAllowed('badge'), 'catalogue quickslot=false must be authoritative')
local bucketCells = Inventory.GetItemCells('water_bucket', 1, false, 10)
expect(bucketCells and bucketCells[1] == 1 and bucketCells[2] == 2 and bucketCells[3] == 6 and bucketCells[4] == 7,
    'bucket footprint must be a two-by-two grid')

Inventories.bucket_test = { items = {}, maxweight = 100, slots = 10 }
stored = Inventory.AddItem('bucket_test', 'water_bucket', 1, 1, {}, 'test', false)
expect(stored, 'large bucket should fit in four empty consecutive slots')
stored = Inventory.AddItem('bucket_test', 'badge', 1, 2, {}, 'test', false)
expect(not stored, 'an explicitly reserved large-item slot must reject another item')
stored = Inventory.AddItem('bucket_test', 'badge', 1, false, {}, 'test', false)
expect(stored and Inventories.bucket_test.items[3], 'automatic placement should skip all reserved cells')

Inventories.bucket_batch = { items = {}, maxweight = 100, slots = 15 }
stored = Inventory.AddItem('bucket_batch', 'water_bucket', 2, false, {}, 'test', false)
expect(stored, 'two non-stackable buckets should be inserted atomically')
local bucketCount, bucketStacks = 0, 0
for _, item in pairs(Inventories.bucket_batch.items) do
    bucketCount = bucketCount + item.amount
    bucketStacks = bucketStacks + 1
    expect(item.amount == 1, 'a non-stackable bucket row must contain one item')
end
expect(bucketCount == 2 and bucketStacks == 2, 'non-stackable bucket amount must occupy separate footprints')

dofile(projectFile('server/drops/store.lua'))

Drops['drop-unlimited-test'] = {
    items = {},
    createdTime = os.time(),
    maxweight = -1,
    slots = -1,
    isOpen = true,
    openedBy = '1',
}
expect(DropStore.IsOpenedBy(Drops['drop-unlimited-test'], 1),
    'drop ownership must accept a numeric source stored as text')
expect(Inventory.CanAddItem('drop-unlimited-test', 'water_bucket', 2),
    'an unlimited drop must accept large non-stackable items')
stored = Inventory.AddItem('drop-unlimited-test', 'water_bucket', 2, false, {}, 'test', false)
expect(stored and Drops['drop-unlimited-test'].items[1] and Drops['drop-unlimited-test'].items[3],
    'unlimited slot scanning must allocate multiple large-item footprints')
stored = Inventory.AddItem('drop-unlimited-test', 'bread', 1000000, 500, {}, 'test', false)
expect(stored and Drops['drop-unlimited-test'].items[500],
    'an unlimited drop must accept an explicit slot and bypass its weight limit')
local unlimitedUsed, unlimitedFree = Inventory.GetSlots('drop-unlimited-test')
expect(unlimitedUsed > 0 and unlimitedFree == -1,
    'slot reporting must preserve the unlimited sentinel')
Drops['drop-unlimited-test'] = nil

Drops['drop-pause-test'] = {
    items = {},
    createdTime = os.time() - 30,
    isOpen = true,
}
expect(DropStore.Pause('drop-pause-test'), 'opening a drop should pause cleanup')
local pausedRemaining = DropStore.Remaining(Drops['drop-pause-test'])
expect(pausedRemaining > 0, 'paused drop should retain its remaining lifetime')
expect(not DropStore.DeleteIfEmpty('drop-pause-test'), 'an empty open drop must wait for close before deletion')
Drops['drop-pause-test'].isOpen = false
expect(DropStore.DeleteIfEmpty('drop-pause-test'), 'an empty closed drop should be deleted')
expect(Drops['drop-pause-test'] == nil, 'deleted drop should leave the runtime registry')

expect(type(registeredExports.AddItem) == 'function', 'AddItem export should be registered')
print('inventory-smoke: ok')
