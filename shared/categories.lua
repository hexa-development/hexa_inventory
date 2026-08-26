-- Hexa Inventory source.
HexaInventory = HexaInventory or {}

HexaInventory.Categories = {
    {
        key = 'all',
        label = 'ทั้งหมด',
    },
    {
        key = 'drink',
        label = 'น้ำ',
        names = {
            'water', 'coffee', 'beer',
        },
        prefixes = {
            'canteen',
            'consumable_canteen',
        },
    },
    {
        key = 'food',
        label = 'อาหาร',
        names = {
            'apple', 'bread', 'stew', 'sugarcube',
            'carrot', 'corn', 'cabbage', 'onion', 'potato', 'pumpkin',
            'consumable_apple', 'consumable_carrot', 'consumable_herb_tomato',
            'consumable_sugarcube', 'consumable_haycube', 'consumable_horse_meal',
            'hay', 'hay_cube', 'horse_apple', 'horse_carrot',
        },
        prefixes = {
            'fish_', 'a_c_fish',

            'carrot_', 'corn_', 'cabbage_', 'onion_', 'potato_', 'pumpkin_',
        },
    },
    {
        key = 'tool',
        label = 'อุปกรณ์ทำงาน',
        names = {
            'axe', 'hoe', 'pickaxe', 'shovel', 'shovelgarden', 'ironhammer',
            'guncraft', 'watering_can', 'wateringbucket', 'water_bucket',
            'animal_brush', 'animal_feed', 'horse_brush', 'handcuffs', 'birdpost',
            'firstaid', 'bandage',
        },
        prefixes = {
            'seed_', 'tomato_seed',
            'bait_', 'p_bait', 'p_lgoc', 'p_finis',
            'fertilizer',
            'scarecrow',
            'kit_',
            'provision_horse',
        },
    },
}

function HexaInventory.ItemInCategory(category, itemName)
    if type(category) ~= 'table' then return false end

    if not category.names and not category.prefixes then return true end

    local name = tostring(itemName or ''):lower()

    for _, exact in ipairs(category.names or {}) do
        if name == exact then return true end
    end

    for _, prefix in ipairs(category.prefixes or {}) do
        if name:sub(1, #prefix) == prefix then return true end
    end

    return false
end

function HexaInventory.CategoryPayload(translate)
    local payload = {}
    for i, category in ipairs(HexaInventory.Categories) do
        payload[i] = {
            key      = category.key,
            label    = translate and translate('ui.category_' .. category.key, category.label)
                       or category.label,
            names    = category.names,
            prefixes = category.prefixes,
        }
    end
    return payload
end
