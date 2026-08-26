-- Hexa Inventory source.
WeaponClass = WeaponClass or {}

local IS_SERVER = IsDuplicityVersion()

local UNKNOWN = {
    name      = nil,
    category  = 'unknown',
    label     = 'อาวุธ',
    hands     = 1,
    twoHanded = false,
    slot      = false,
}

local byName, byHash = {}, {}

local nameOfHash = {}
local catalogueIndexed = false

local hashFn = rawget(_G, 'joaat') or GetHashKey

local function hashOf(name)

    return hashFn(name)
end

function WeaponClass.Register(name)
    if type(name) ~= 'string' or name == '' then return end
    local lower = name:lower()
    local hash = hashOf(lower)
    if nameOfHash[hash] == nil then nameOfHash[hash] = lower end
end

local function indexKnownNames()
    local weapons = cfg and cfg.weapons or nil
    if weapons then
        for name in pairs(weapons.categoryOf or {}) do
            WeaponClass.Register(name)
        end
    end

    local core = rawget(_G, 'HexaCore') or rawget(_G, 'Core')
    local catalogue = core and core.Shared and core.Shared.Weapons
    if type(catalogue) == 'table' and next(catalogue) ~= nil then
        for name in pairs(catalogue) do
            WeaponClass.Register(name)
        end
        catalogueIndexed = true
    end
end

local function nativeBool(nativeHash, arg)
    if IS_SERVER then return nil end
    local res = Citizen.InvokeNative(nativeHash, arg, Citizen.ResultAsInteger())
    if type(res) == 'number' then return res ~= 0 end
    return res and true or false
end

local N_IS_GUN        = 0x705BE297EEBDB95D
local N_IS_ONE_HANDED = 0xD955FEE4B87AFA07

local function nativeSaysSidearm(hash)
    local gun = nativeBool(N_IS_GUN, hash)
    local one = nativeBool(N_IS_ONE_HANDED, hash)
    if gun == nil or one == nil then return nil end
    return gun and one
end

local function categoryFromConfig(lower)
    local weapons = cfg and cfg.weapons or nil
    if not weapons then return nil end

    local exact = weapons.categoryOf and weapons.categoryOf[lower]
    if exact then return exact end

    for _, rule in ipairs(weapons.categoryByPrefix or {}) do
        local prefix, category = rule[1], rule[2]
        if type(prefix) == 'string' and lower:sub(1, #prefix) == prefix then
            return category
        end
    end

    return nil
end

local function build(lower, category)
    local weapons = cfg and cfg.weapons or nil
    local meta = weapons and weapons.categories and weapons.categories[category]
    if not meta then
        return { name = lower, category = UNKNOWN.category, label = UNKNOWN.label,
                 hands = UNKNOWN.hands, twoHanded = false, slot = false }
    end

    local hands = tonumber(meta.hands) or 1
    local slot  = meta.slot or false

    if hands >= 2 and slot == 'sidearm' then slot = 'longarm' end

    return {
        name      = lower,
        category  = category,
        label     = meta.label or category,
        hands     = hands,
        twoHanded = hands >= 2,
        slot      = slot,
    }
end

function WeaponClass.Resolve(weapon)
    local lower

    if type(weapon) == 'number' then
        local cached = byHash[weapon]
        if cached then return cached end

        if not catalogueIndexed then indexKnownNames() end
        lower = nameOfHash[weapon]

        if not lower then

            local sidearm = nativeSaysSidearm(weapon)
            if sidearm == true then return build(nil, 'sidearm') end
            return UNKNOWN
        end
    elseif type(weapon) == 'string' then
        lower = weapon:lower()
        local cached = byName[lower]
        if cached then return cached end
    else
        return UNKNOWN
    end

    local category = categoryFromConfig(lower)

    if not category then

        local sidearm = nativeSaysSidearm(hashOf(lower))
        if sidearm == true then
            category = 'sidearm'
        end
    end

    local info = category and build(lower, category) or {
        name = lower, category = UNKNOWN.category, label = UNKNOWN.label,
        hands = UNKNOWN.hands, twoHanded = false, slot = false,
    }

    byName[lower] = info
    byHash[hashOf(lower)] = info
    WeaponClass.Register(lower)

    return info
end

function WeaponClass.IsTwoHanded(weapon)
    return WeaponClass.Resolve(weapon).twoHanded == true
end

function WeaponClass.IsSidearm(weapon)
    return WeaponClass.Resolve(weapon).slot == 'sidearm'
end

function WeaponClass.IsLongarm(weapon)
    return WeaponClass.Resolve(weapon).slot == 'longarm'
end

function WeaponClass.SlotClass(weapon)
    return WeaponClass.Resolve(weapon).slot
end

function WeaponClass.SlotDef(key)
    for _, def in ipairs((cfg and cfg.weapons and cfg.weapons.slots) or {}) do
        if def.key == key then return def end
    end
    return nil
end

function WeaponClass.SlotsOfClass(class)
    local list = {}
    if not class then return list end

    local weapons = cfg and cfg.weapons or nil
    local singleSidearm = (class == 'sidearm') and weapons and weapons.dualWield == false

    for _, def in ipairs((weapons and weapons.slots) or {}) do
        if def.class == class then
            list[#list + 1] = def
            if singleSidearm then break end
        end
    end
    return list
end

function WeaponClass.SlotAccepts(weapon, slotKey)
    local info = WeaponClass.Resolve(weapon)

    if not slotKey then

        return info.slot == false
    end

    if not info.slot then return false end

    for _, def in ipairs(WeaponClass.SlotsOfClass(info.slot)) do
        if def.key == slotKey then return true end
    end
    return false
end

function IsTwoHandedWeapon(weapon) return WeaponClass.IsTwoHanded(weapon) end
function IsSidearmWeapon(weapon)   return WeaponClass.IsSidearm(weapon) end
function IsLongarmWeapon(weapon)   return WeaponClass.IsLongarm(weapon) end
function GetWeaponClass(weapon)    return WeaponClass.Resolve(weapon) end

exports('IsTwoHandedWeapon', function(weapon) return WeaponClass.IsTwoHanded(weapon) end)
exports('IsSidearmWeapon',   function(weapon) return WeaponClass.IsSidearm(weapon) end)
exports('IsLongarmWeapon',   function(weapon) return WeaponClass.IsLongarm(weapon) end)
exports('GetWeaponClass',    function(weapon) return WeaponClass.Resolve(weapon) end)

indexKnownNames()
