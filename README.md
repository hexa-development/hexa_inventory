# hexa_inventory

`hexa_inventory` is a persistent grid inventory resource for RedM servers running `hexa_core`. It provides player inventories, stashes, shops, ground drops, quick slots, item history, secure player trading, large item footprints, durability warnings, and compatibility helpers for resources ported from RSG and VORP.

![Hexa Inventory UI preview](docs/ui-preview.png)

## Requirements

- `hexa_core` 3.x
- `oxmysql`

## Installation

Place the resource in your server resources directory using the exact folder name `hexa_inventory`, then start it after its dependencies.

```cfg
ensure oxmysql
ensure hexa_core
ensure hexa_inventory
```

The `users`, `users_vault`, and `item_drops` tables are managed by the `hexa_core` schema installer.

Set the locale in `server.cfg` when a language other than English is required.

```cfg
setr hexa_inventory:locale th
```

## Configuration

Configuration is separated by responsibility.

| File | Purpose |
| --- | --- |
| `config/general.lua` | Inventory size, drops, key bindings, quick slots, commands, give range, and compatibility |
| `config/items.lua` | Use, stack, drop, quick-slot, and grid-size item rules |
| `config/features.lua` | Sorting, durability warnings, history, and hotbar protection |
| `config/shops.lua` | Shop restocking and vending configuration |
| `config/cfg.weapons.lua` | Weapon classes, slots, and native weapon behavior |

Set either drop capacity to `-1` to make that limit unlimited.

```lua
DropSize = {
    maxweight = -1,
    slots = -1,
}
```

Unlimited drop grids expand as items are added without rendering an infinite number of UI slots.

Item behavior can be overridden in `config/items.lua`.

```lua
config.ItemRules = {
    DisableUse = {},
    DisableStack = {},
    DisableDrop = {},
    DisableQuickSlot = {},
    SlotSize = {
        ['water_bucket'] = { width = 2, height = 2 },
    },
}
```

Items in `DisableDrop` become transparent and locked with a cross while a ground drop is open. The server also rejects forged attempts to move those items into a drop.

## Controls

| Action | Default |
| --- | --- |
| Open inventory | `I` |
| Show hotbar | `Z` |
| Use quick slot | `Alt + 1` through `Alt + 5` |
| Sort open inventories | `B` |
| Open a ground drop | Hold `E` |
| Open a vending object | Hold `E` |
| Trade with a player | `/trade` |

Ground bags can be opened but cannot be picked up or carried.

## Features

- Persistent player inventories, stashes, and ground drops
- Separate quick-slot and normal inventory grids
- Configurable quick-slot availability per item
- Non-stackable and non-usable item rules
- Multi-cell items such as `2x2` containers
- Drag, split, stack, swap, bulk transfer, and amount entry
- Sort by type, rarity, and name
- Durability warnings with configurable sound and threshold
- Receive and loss history by citizen ID
- Secure item transfer and player trading
- Optional RSG and VORP compatibility APIs
- Drop cleanup countdown that pauses while a bag is open

## Common server exports

```lua
local stored, dropped = exports.hexa_inventory:AddItem(
    source,
    'bread',
    1,
    false,
    {},
    'reward'
)

local removed = exports.hexa_inventory:RemoveItem(
    source,
    'bread',
    1,
    false,
    'consume'
)

exports.hexa_inventory:OpenInventory(source, 'stash-ranch-1', {
    label = 'Ranch Storage',
    maxweight = 500,
    slots = 100,
})
```

Compatibility exports include RSG-style inventory events and VORP-shaped helpers such as `getUserInventoryItems`, `getItem`, `getItemCount`, `canCarryItem`, `addItem`, `subItem`, `registerUsableItem`, `registerInventory`, and `openInventory`.

## Tests

The smoke tests require Lua and Node.js.

```sh
lua tests/inventory_smoke.lua
node tests/ui_drag_smoke.js
```

## License

This project is derived from RSG Inventory and retains the upstream license in [LICENSE](LICENSE).
