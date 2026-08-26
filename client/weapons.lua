-- Hexa Inventory source.
function HexaNotify(data)
    if type(data) ~= 'table' then return end
    TriggerEvent('hexa_inventory:client:notify', {
        title       = data.title,
        description = data.description,
        type        = data.type or 'info',
        duration    = data.duration or 4000,
    })
end

function SyncEquippedWeapons()
    local slots = {}
    for _, piece in pairs(HexaInvEquipped or {}) do
        if piece.slot then slots[#slots + 1] = piece.slot end
    end
    SendNUIMessage({ action = 'equippedSlots', slots = slots })
end

local UNARMED = joaat('WEAPON_UNARMED')

local HAND_PRIMARY, HAND_SECONDARY = 0, 1

local GIVE_P7, GIVE_P8, GIVE_P9 = 0.5, 1.0, 752097756

HexaInvEquipped = HexaInvEquipped or {}

local seqCounter = 0

local function syncBadges()
    if SyncEquippedWeapons then SyncEquippedWeapons() end
end

local function ammoManaged(name)
    if GetResourceState('hexa_ammo') ~= 'started' then return false end
    return exports['hexa_ammo']:IsManagedWeapon(name) == true
end

local function withAmmoGuard(fn, ...)
    if GetResourceState('hexa_ammo') ~= 'started' then
        fn(...)
        return
    end

    exports['hexa_ammo']:CaptureAmmo()
    fn(...)
    exports['hexa_ammo']:SyncAmmo()
end

local function pieceKey(name, slot)
    slot = tonumber(slot)
    if slot then return 'slot:' .. slot end
    return 'name:' .. name
end

local function slotAttach(wslot)
    if not wslot then return nil end
    local def = WeaponClass.SlotDef(wslot)
    local attach = def and def.attach
    if attach == false or attach == nil then return nil end
    return attach
end

local function freeWeaponSlot(class)
    if not class then return nil end
    local used = {}
    for _, piece in pairs(HexaInvEquipped) do
        if piece.wslot then used[piece.wslot] = true end
    end
    for _, def in ipairs(WeaponClass.SlotsOfClass(class)) do
        if not used[def.key] then return def.key end
    end
    return nil
end

local function oldestPieceOfClass(class)
    local pick, pickSeq
    for key, piece in pairs(HexaInvEquipped) do
        if piece.class == class and (not pickSeq or (piece.seq or 0) < pickSeq) then
            pick, pickSeq = key, piece.seq or 0
        end
    end
    return pick
end

local function otherPieceHasHash(hash, exceptKey)
    for key, piece in pairs(HexaInvEquipped) do
        if key ~= exceptKey and piece.hash == hash then return true end
    end
    return false
end

local function setAllowDualWield(ped, allow)
    Citizen.InvokeNative(0x83B8D50EB9446BBA, ped, allow and true or false)
end

local function getAllowDualWield(ped)
    local res = Citizen.InvokeNative(0x918990BD9CE08582, ped, Citizen.ResultAsInteger())
    if type(res) == 'number' then return res ~= 0 end
    return res and true or false
end

local DUAL_WIELD_UNLOCK = -200143754

local function unlockDualWield()
    Citizen.InvokeNative(0x1B7C5ADA8A6910A0, DUAL_WIELD_UNLOCK, true)
    Citizen.InvokeNative(0x46B901A8ECDB5A61, DUAL_WIELD_UNLOCK, true)
end

local function dualWieldConfigured()
    local weapons = cfg and cfg.weapons
    return (weapons and weapons.dualWield and weapons.dualWieldInHand) and true or false
end

local function sidearmCount()
    local n = 0
    for _, piece in pairs(HexaInvEquipped) do
        if piece.class == 'sidearm' then n = n + 1 end
    end
    return n
end

local function refreshDualWield(ped)
    if not dualWieldConfigured() then return false end

    local allow = sidearmCount() >= 2

    if allow then unlockDualWield() end
    setAllowDualWield(ped or PlayerPedId(), allow)
    return allow
end

local function giveAtAttach(ped, hash, ammo, attach, inHand)
    GiveWeaponToPed(ped, hash, ammo, inHand and true or false, true, attach, true,
        GIVE_P7, GIVE_P8, GIVE_P9, false, 0.0, false)
end

local function slotHand(wslot)
    if not wslot then return HAND_PRIMARY end
    local def  = WeaponClass.SlotDef(wslot)
    local hand = def and def.hand
    if hand == nil or hand == false then return HAND_PRIMARY end
    return hand
end

local function pieceAtSlot(wslot)
    if not wslot then return nil end
    for _, piece in pairs(HexaInvEquipped) do
        if piece.wslot == wslot then return piece end
    end
    return nil
end

local function firstPieceOfClass(class)
    if not class then return nil end
    local slots = WeaponClass.SlotsOfClass(class)
    return slots[1] and pieceAtSlot(slots[1].key) or nil
end

local function weaponInHand(ped, hand)
    local _, weapon = GetCurrentPedWeapon(ped, true, hand, false)
    return weapon
end

local function drawPiece(ped, piece)
    if not piece then return end

    if piece.class == 'sidearm' and dualWieldConfigured() then
        local slots = WeaponClass.SlotsOfClass('sidearm')
        local right = slots[1] and pieceAtSlot(slots[1].key) or nil
        local left  = slots[2] and pieceAtSlot(slots[2].key) or nil

        if right and left then
            giveAtAttach(ped, right.hash, right.ammo or 0, slotAttach(right.wslot), true)
            giveAtAttach(ped, left.hash,  left.ammo  or 0, slotAttach(left.wslot),  true)
            SetCurrentPedWeapon(ped, right.hash, false, slotHand(right.wslot), false, false)
            SetCurrentPedWeapon(ped, left.hash,  false, slotHand(left.wslot),  false, false)
            return
        end
    end

    SetCurrentPedWeapon(ped, piece.hash, true, HAND_PRIMARY, false, false)
end

local function drawOnUse()
    return not (cfg and cfg.weapons and cfg.weapons.drawOnUse == false)
end

local function itemModeOn()
    local mode = cfg and cfg.weapons and cfg.weapons.dualWieldMode
    return mode ~= 'legacy' and WeaponItems ~= nil
end

local function syncSidearms(draw)
    if not itemModeOn() then return false end

    local slots = WeaponClass.SlotsOfClass('sidearm')
    local guns  = {}

    for _, def in ipairs(slots) do
        local piece = pieceAtSlot(def.key)
        if piece then
            guns[#guns + 1] = { piece = piece, hand = slotHand(def.key) }
        end
    end

    if #guns == 1 then guns[1].hand = HAND_PRIMARY end

    local list = {}
    for i, gun in ipairs(guns) do
        list[i] = { name = gun.piece.name, ammo = gun.piece.ammo, hand = gun.hand }
    end

    return WeaponItems.Equip(list, draw and true or false)
end

local function compactClass(class)
    if not class then return end

    local order = {}
    for key, piece in pairs(HexaInvEquipped) do
        if piece.class == class and piece.wslot then order[#order + 1] = key end
    end
    if #order == 0 then return end

    table.sort(order, function(a, b)
        return (HexaInvEquipped[a].seq or 0) < (HexaInvEquipped[b].seq or 0)
    end)

    local slots = WeaponClass.SlotsOfClass(class)
    local ped = PlayerPedId()

    for i, key in ipairs(order) do
        local piece = HexaInvEquipped[key]
        local def   = slots[i]
        if def and piece.wslot ~= def.key then
            piece.wslot = def.key
            local attach = slotAttach(def.key)
            piece.attach = attach

            if attach and not (class == 'sidearm' and itemModeOn()) then
                giveAtAttach(ped, piece.hash, piece.ammo or 0, attach)
            end
        end
    end
end

local function unequipPiece(key, skipSync)
    local piece = HexaInvEquipped[key]
    if not piece then return nil end

    HexaInvEquipped[key] = nil

    local class = piece.class
    local ped   = PlayerPedId()

    local wasInHand = weaponInHand(ped, HAND_PRIMARY) == piece.hash
                   or weaponInHand(ped, HAND_SECONDARY) == piece.hash
    if wasInHand then
        SetCurrentPedWeapon(ped, UNARMED, true)
    end

    if not otherPieceHasHash(piece.hash, key) then
        if HasPedGotWeapon(ped, piece.hash) then
            RemoveWeaponFromPed(ped, piece.hash)
        end
    end

    refreshDualWield(ped)

    if not skipSync then
        compactClass(class)

        local rebuilt = (class == 'sidearm') and syncSidearms(wasInHand and drawOnUse())

        if not rebuilt and wasInHand and drawOnUse() then
            drawPiece(ped, firstPieceOfClass(class))
        end
        syncBadges()
    end

    return piece
end

local function reportRelease(slots)
    if slots ~= true and (type(slots) ~= 'table' or #slots == 0) then return end
    TriggerServerEvent('hexa_inventory:server:releaseWeaponSlots', slots)
end

local function equipPiece(key, itemData, hash, order)
    local ped  = PlayerPedId()
    local info = type(itemData.info) == 'table' and itemData.info or {}
    local ammo = tonumber(info.ammo) or 0

    if ammoManaged(itemData.name) then ammo = 0 end

    local class = WeaponClass.SlotClass(itemData.name)
    local wslot = nil

    if class then

        if order and order.wslot and WeaponClass.SlotAccepts(itemData.name, order.wslot) then
            wslot = order.wslot

            for otherKey, piece in pairs(HexaInvEquipped) do
                if otherKey ~= key and piece.wslot == wslot then
                    unequipPiece(otherKey, true)
                end
            end
        else
            wslot = freeWeaponSlot(class)

            if not wslot then
                local behaviour = (cfg and cfg.weapons and cfg.weapons.slotFullBehaviour) or 'swap'
                if behaviour == 'reject' then return false, 'slot_full' end

                local victim = oldestPieceOfClass(class)
                if victim then
                    local dropped = unequipPiece(victim, true)

                    if dropped and dropped.slot then reportRelease({ dropped.slot }) end
                end

                wslot = freeWeaponSlot(class)
                if not wslot then return false, 'slot_full' end
            end
        end
    end

    local attach = slotAttach(wslot)

    local itemMode = (class == 'sidearm') and itemModeOn()

    if not itemMode then
        if attach then
            giveAtAttach(ped, hash, ammo, attach)
        elseif not HasPedGotWeapon(ped, hash) then
            GiveWeaponToPed(ped, hash, ammo, false, true)
        end
    end

    seqCounter = seqCounter + 1
    HexaInvEquipped[key] = {
        name   = itemData.name,
        slot   = tonumber(itemData.slot),
        hash   = hash,
        ammo   = ammo,
        attach = attach,
        wslot  = wslot,
        class  = class,
        seq    = seqCounter,
    }

    refreshDualWield(ped)

    if itemMode and not syncSidearms(drawOnUse()) then

        itemMode = false
        if attach then
            giveAtAttach(ped, hash, ammo, attach)
        elseif not HasPedGotWeapon(ped, hash) then
            GiveWeaponToPed(ped, hash, ammo, false, true)
        end
    end

    if drawOnUse() and not itemMode then
        drawPiece(ped, HexaInvEquipped[key])
    end

    syncBadges()
    return true
end

local function unequipAll()
    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, UNARMED, true)

    for key in pairs(HexaInvEquipped) do
        unequipPiece(key, true)
    end

    HexaInvEquipped = {}

    if WeaponItems then WeaponItems.Clear() end

    refreshDualWield(ped)
    setAllowDualWield(ped, false)
    reportRelease(true)
    syncBadges()
end

function UnequipAllWeapons()
    withAmmoGuard(unequipAll)
end

function UnarmPlayer()
    SetCurrentPedWeapon(PlayerPedId(), UNARMED, true)
end

HolsterDrawnWeapon = UnarmPlayer

local SLOT_FULL_LABEL = {
    sidearm = 'ซองปืนสั้น',
    longarm = 'ช่องอาวุธยาว',
}

local function notifySlotFull(class)
    if not HexaNotify then return end
    HexaNotify({
        title = 'กระเป๋าสัมภาระ',
        description = ('%s เต็มแล้ว ถอดกระบอกเดิมออกก่อน'):format(SLOT_FULL_LABEL[class] or 'ช่องอาวุธ'),
        type = 'error',
    })
end

local function togglePiece(itemData, order)
    if type(itemData) ~= 'table' or type(itemData.name) ~= 'string' then return end

    local key  = pieceKey(itemData.name, itemData.slot)
    local hash = joaat(itemData.name)

    if order and type(order.release) == 'table' and order.release.slot then
        local victimKey = pieceKey(order.release.name or '', order.release.slot)
        if HexaInvEquipped[victimKey] then unequipPiece(victimKey, true) end
    end

    local action = order and order.action or nil

    if action == 'unequip' then
        unequipPiece(key)
        return
    end

    if action == 'equip' then

        if HexaInvEquipped[key] then unequipPiece(key, true) end
    elseif HexaInvEquipped[key] then

        unequipPiece(key)
        return
    end

    local ok, reason = equipPiece(key, itemData, hash, order)
    if not ok then
        compactClass(WeaponClass.SlotClass(itemData.name))
        syncBadges()
        if reason == 'slot_full' then
            notifySlotFull(WeaponClass.SlotClass(itemData.name))
        end
    end
end

local function toggleWeapon(itemData, order)
    withAmmoGuard(togglePiece, itemData, order)
end

RegisterNetEvent('hexa_inventory:client:UseWeapon', toggleWeapon)
RegisterNetEvent('hexa_inventory:client:UseThrownWeapon', toggleWeapon)
RegisterNetEvent('hexa_inventory:client:UseEquipment', toggleWeapon)

RegisterNetEvent('hexa_inventory:client:WeaponSlotDenied', function(reason, class)
    if reason == 'slot_full' then
        notifySlotFull(class)
    elseif reason == 'slot_mismatch' and HexaNotify then
        HexaNotify({
            title = 'กระเป๋าสัมภาระ',
            description = 'อาวุธชิ้นนี้ลงช่องที่เลือกไม่ได้',
            type = 'error',
        })
    end
end)

local function removeWeaponFromTab(item)
    local name = type(item) == 'table' and item.name or item
    if type(name) ~= 'string' then return end

    local slot = type(item) == 'table' and tonumber(item.slot) or nil

    if slot then
        unequipPiece(pieceKey(name, slot))
        return
    end

    local hit, classes = false, {}
    for key, piece in pairs(HexaInvEquipped) do
        if piece.name == name then
            if piece.class then classes[piece.class] = true end
            unequipPiece(key, true)
            hit = true
        end
    end
    if hit then
        for class in pairs(classes) do compactClass(class) end
        syncBadges()
    end

    local ped  = PlayerPedId()
    local hash = joaat(name)
    if not hit and HasPedGotWeapon(ped, hash) then
        RemoveWeaponFromPed(ped, hash)
    end
end

RegisterNetEvent('hexa_inventory:client:RemoveWeaponFromTab', function(item)
    withAmmoGuard(removeWeaponFromTab, item)
end)

RegisterCommand('hexa_dualwield', function()
    local ped = PlayerPedId()

    local lines = {}
    for _, piece in pairs(HexaInvEquipped) do
        if piece.class == 'sidearm' then
            lines[#lines + 1] = ('    %s -> %s (มือ %d)')
                :format(piece.name, piece.wslot or '-', slotHand(piece.wslot))
        end
    end

    local allow = getAllowDualWield(ped)
    print(('[hexa_inventory] ถือปืนคู่: config=%s / ปืนสั้นที่พก=%d / เกมให้สิทธิ์=%s')
        :format(tostring(dualWieldConfigured()), sidearmCount(),
                allow == nil and 'ถามไม่ได้ (บิลด์นี้ไม่มี native)' or tostring(allow)))
    print(('[hexa_inventory] โหมดพก=%s / ไอเทมอาวุธในกระเป๋าเกม=%d ชิ้น%s')
        :format(itemModeOn() and 'item' or 'legacy',
                WeaponItems and WeaponItems.Count() or 0,
                (WeaponItems and WeaponItems.lastError)
                    and (' / ล้มเหลวล่าสุด: ' .. WeaponItems.lastError) or ''))
    print(('[hexa_inventory] มือหลักถือ=%s / มือรองถือ=%s')
        :format(tostring(weaponInHand(ped, HAND_PRIMARY)), tostring(weaponInHand(ped, HAND_SECONDARY))))
    if #lines > 0 then
        print('[hexa_inventory] ปืนสั้นที่พกอยู่:')
        for _, line in ipairs(lines) do print(line) end
    end
end, false)

CreateThread(function()
    while true do
        Wait(2000)

        if next(HexaInvEquipped) ~= nil then
            local ped = PlayerPedId()
            local lost, classes, slots = nil, {}, {}

            local skipSidearms = itemModeOn() and WeaponItems.Count() > 0

            for key, piece in pairs(HexaInvEquipped) do
                if not (skipSidearms and piece.class == 'sidearm')
                   and not HasPedGotWeapon(ped, piece.hash) then
                    lost = lost or {}
                    lost[#lost + 1] = key
                    if piece.class then classes[piece.class] = true end
                    if piece.slot then slots[#slots + 1] = piece.slot end
                end
            end

            if lost then
                withAmmoGuard(function()
                    for _, key in ipairs(lost) do
                        HexaInvEquipped[key] = nil
                    end
                    for class in pairs(classes) do compactClass(class) end

                    reportRelease(slots)
                    syncBadges()
                end)
            end
        end
    end
end)
