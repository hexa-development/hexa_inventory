-- Hexa Inventory source.
WeaponItems = WeaponItems or {}

local INVENTORY_ID = 1
local REASON       = joaat('ADD_REASON_DEFAULT')

local N_ITEM_KEY_VALID   = 0x6D5D51B188333FD1
local N_GUID_FROM_ITEMID = 0x886DFD3E185C8A89
local N_ADD_ITEM         = 0xCB5D11F9508A928D
local N_EQUIP_ITEM       = 0x734311E2852760D0
local N_REMOVE_ITEM      = 0x3E4E811480B3AE79
local N_SET_WEAPON_GUID  = 0x12FB95FE3D579238

local CAT_CHARACTER  = joaat('CHARACTER')
local SLOT_CHARACTER = 0xA1212100
local CAT_WEAPONS    = 923904168
local SLOT_WEAPONS   = -740156546

local CAT_WARDROBE   = joaat('WARDROBE')
local SLOT_WARDROBE  = 0x3DABBFA7

local GUID_SIZE = 8 * 13

local held = {}

local supported = nil

local function nativeBool(hash, ...)
    local n    = select('#', ...)
    local args = table.pack(...)
    args[n + 1] = Citizen.ResultAsInteger()

    local res = Citizen.InvokeNative(hash, table.unpack(args, 1, n + 1))
    if type(res) == 'number' then return res ~= 0 end
    return res and true or false
end

local function guidOf(parent, category, slotId)
    local out = DataView.ArrayBuffer(GUID_SIZE)
    local res = nativeBool(N_GUID_FROM_ITEMID, INVENTORY_ID, parent or 0, category, slotId, out:Buffer())
    if res ~= true then return nil, res == nil end
    return out
end

local function containerOf(category, slotId)
    local character, dead = guidOf(nil, CAT_CHARACTER, SLOT_CHARACTER)
    if not character then return nil, dead end
    return guidOf(character:Buffer(), category, slotId)
end

local function weaponContainer()
    return containerOf(CAT_WEAPONS, SLOT_WEAPONS)
end

function WeaponItems.Clear()
    for _, entry in ipairs(held) do
        nativeBool(N_REMOVE_ITEM, INVENTORY_ID, entry.guid:Buffer(), 1, REASON)
    end
    held = {}
end

function WeaponItems.Count()
    return #held
end

WeaponItems.lastError = nil

local warned = false
local function fail(step)
    WeaponItems.lastError = step
    if not warned then
        warned = true
        print(('[hexa_inventory] ระบบไอเทมอาวุธของเกมใช้ไม่ได้ (ติดขั้น: %s) — '):format(step)
            .. 'ถอยไปใช้ GiveWeaponToPed แทน ปืนรุ่นเดียวกันจะถือคู่ไม่ได้ '
            .. 'และวงล้อจะไม่ขึ้นสถานะปืนคู่')
    end
    return false
end

local OFFHAND_DEFAULT = {
    enabled = true,
    clothing = {
        male   = 'CLOTHING_ITEM_M_OFFHAND_000_TINT_004',
        female = 'CLOTHING_ITEM_F_OFFHAND_000_TINT_004',
    },
    clothingSlot = 0xF20B6B4A,
    upgrade      = 'UPGRADE_OFFHAND_HOLSTER',
    upgradeSlot  = 0x39E57B01,
}

local offhandPed = nil

WeaponItems.offhandError = nil

local function addWardrobeItem(container, name, slotHash)
    local hash = joaat(name)
    if nativeBool(N_ITEM_KEY_VALID, hash, 0) ~= true then
        return false, ('%s ไม่มีในฐานไอเทมของเกม'):format(name)
    end

    local item = DataView.ArrayBuffer(GUID_SIZE)
    if nativeBool(N_ADD_ITEM, INVENTORY_ID, item:Buffer(), container:Buffer(),
                  hash, slotHash, 1, REASON) ~= true then
        return false, ('เพิ่ม %s เข้าตู้เสื้อผ้าไม่สำเร็จ'):format(name)
    end

    if nativeBool(N_EQUIP_ITEM, INVENTORY_ID, item:Buffer(), true) ~= true then
        return false, ('สวม %s ไม่สำเร็จ'):format(name)
    end

    return true
end

function WeaponItems.HasOffhandHolster()
    return offhandPed ~= nil and offhandPed == PlayerPedId()
end

function WeaponItems.EnsureOffhandHolster(force)
    if not force and WeaponItems.HasOffhandHolster() then return true end

    local opts = (cfg and cfg.weapons and cfg.weapons.offhandHolster) or OFFHAND_DEFAULT
    if not opts or opts.enabled == false then
        WeaponItems.offhandError = 'ปิดไว้ที่ cfg.weapons.offhandHolster.enabled'
        return false
    end

    if type(DataView) ~= 'table' then
        WeaponItems.offhandError = 'ไม่มี DataView'
        return false
    end

    local container = containerOf(CAT_WARDROBE, SLOT_WARDROBE)
    if not container then

        WeaponItems.offhandError = 'หา GUID ตู้เสื้อผ้าของตัวละครไม่เจอ'
        return false
    end

    local ped = PlayerPedId()

    local names = opts.clothing
    if type(names) == 'table' and not WeaponItems.HasOffhandHolster() then
        local cloth = (GetEntityModel(ped) == joaat('mp_female')) and names.female or names.male
        if cloth then

            addWardrobeItem(container, cloth, opts.clothingSlot or 0xF20B6B4A)
        end
    end

    local ok, err = addWardrobeItem(container, opts.upgrade or 'UPGRADE_OFFHAND_HOLSTER',
                                    opts.upgradeSlot or 0x39E57B01)
    if not ok then
        WeaponItems.offhandError = err
        return false
    end

    offhandPed = ped
    WeaponItems.offhandError = nil
    return true
end

function WeaponItems.Equip(guns, draw)
    if supported == false then return false end
    if type(DataView) ~= 'table' then
        supported = false
        return fail('ไม่มี DataView')
    end

    WeaponItems.Clear()

    if type(guns) ~= 'table' or #guns == 0 then return true end

    if #guns >= 1 then WeaponItems.EnsureOffhandHolster(true) end

    local container, dead = weaponContainer()
    if not container then

        if dead then supported = false end
        return fail('หา GUID ช่องเก็บอาวุธของตัวละครไม่เจอ (ตัวละครโหลดเสร็จหรือยัง?)')
    end

    local added = {}

    local function abort(step)
        for _, e in ipairs(added) do
            nativeBool(N_REMOVE_ITEM, INVENTORY_ID, e.guid:Buffer(), 1, REASON)
        end
        return fail(step)
    end

    for _, gun in ipairs(guns) do
        local hash = joaat(gun.name)

        if nativeBool(N_ITEM_KEY_VALID, hash, 0) ~= true then
            return abort(('%s ไม่มีในฐานไอเทมของเกม'):format(gun.name))
        end

        local item     = DataView.ArrayBuffer(GUID_SIZE)
        local slotHash = joaat('SLOTID_WEAPON_' .. tostring(gun.hand or 0))

        local okAdd = nativeBool(N_ADD_ITEM, INVENTORY_ID, item:Buffer(), container:Buffer(),
                                 hash, slotHash, 1, REASON)
        if okAdd ~= true then
            if okAdd == nil then supported = false end
            return abort('เพิ่มไอเทมอาวุธเข้ากระเป๋าไม่สำเร็จ')
        end

        local ok = nativeBool(N_EQUIP_ITEM, INVENTORY_ID, item:Buffer(), true)
        if ok ~= true then
            if ok == nil then supported = false end
            return abort('equip ไอเทมอาวุธไม่สำเร็จ')
        end

        added[#added + 1] = { guid = item, hash = hash, hand = gun.hand or 0, ammo = tonumber(gun.ammo) or 0 }
    end

    held      = added
    supported = true
    WeaponItems.lastError = nil

    warned = false

    local ped = PlayerPedId()

    for _, entry in ipairs(added) do

        if entry.ammo > 0 then
            SetPedAmmo(ped, entry.hash, entry.ammo)
        end
        if draw then
            nativeBool(N_SET_WEAPON_GUID, ped, entry.guid:Buffer(), true, entry.hand, false, false)
        end
    end

    return true
end
