-- Hexa Inventory source.
WeaponSlots = WeaponSlots or {}

local equipped = {}

local seqCounter = 0

local lastToggle = {}

local function stateOf(src)
    local list = equipped[src]
    if not list then
        list = {}
        equipped[src] = list
    end
    return list
end

local function freeSlot(src, class)
    local used = {}
    for _, piece in pairs(stateOf(src)) do
        if piece.wslot then used[piece.wslot] = true end
    end
    for _, def in ipairs(WeaponClass.SlotsOfClass(class)) do
        if not used[def.key] then return def.key end
    end
    return nil
end

local function oldestOfClass(src, class)
    local pick, pickSeq
    for slot, piece in pairs(stateOf(src)) do
        if piece.class == class and (not pickSeq or piece.seq < pickSeq) then
            pick, pickSeq = slot, piece.seq
        end
    end
    return pick
end

function WeaponSlots.ClearAll(src)
    equipped[src] = nil
end

function WeaponSlots.Release(src, slot)
    slot = tonumber(slot)
    if not slot then return end
    local list = equipped[src]
    if list then list[slot] = nil end
end

function WeaponSlots.Get(src)
    return equipped[src] or {}
end

exports('GetEquippedWeapons', WeaponSlots.Get)

local function passRateLimit(src)
    local cooldown = tonumber(cfg and cfg.weapons and cfg.weapons.toggleCooldown) or 0
    if cooldown <= 0 then return true end
    local now = GetGameTimer()
    local last = lastToggle[src]
    if last and (now - last) < cooldown then return false end
    lastToggle[src] = now
    return true
end

function WeaponSlots.Decide(src, itemData)
    if type(itemData) ~= 'table' or type(itemData.name) ~= 'string' then return nil, 'invalid' end

    if not passRateLimit(src) then return nil, 'spam' end

    local slot = tonumber(itemData.slot)
    if not slot then

        return { action = 'toggle' }
    end

    local live = Inventory.GetItemBySlot(src, slot)
    if not live or type(live.name) ~= 'string' then return nil, 'not_owned' end
    if live.name:lower() ~= itemData.name:lower() then return nil, 'not_owned' end
    if (tonumber(live.amount) or 0) <= 0 then return nil, 'not_owned' end

    itemData = live

    local list = WeaponSlots.Get(src)
    local info = WeaponClass.Resolve(itemData.name)

    local current = list[slot]
    if current and current.name == itemData.name then
        WeaponSlots.Release(src, slot)
        return { action = 'unequip', wslot = current.wslot }
    end

    if current then WeaponSlots.Release(src, slot) end

    local release = nil

    if info.slot then
        local target = freeSlot(src, info.slot)

        if not target then
            local behaviour = (cfg and cfg.weapons and cfg.weapons.slotFullBehaviour) or 'swap'
            if behaviour == 'reject' then
                return nil, 'slot_full'
            end

            local victimSlot = oldestOfClass(src, info.slot)
            if victimSlot then
                local victim = stateOf(src)[victimSlot]
                release = { slot = victimSlot, name = victim.name, wslot = victim.wslot }
                WeaponSlots.Release(src, victimSlot)
                target = freeSlot(src, info.slot)
            end

            if not target then return nil, 'slot_full' end
        end

        if not WeaponClass.SlotAccepts(itemData.name, target) then
            return nil, 'slot_mismatch'
        end

        seqCounter = seqCounter + 1
        stateOf(src)[slot] = {
            name  = itemData.name,
            slot  = slot,
            wslot = target,
            class = info.slot,
            seq   = seqCounter,
        }

        return { action = 'equip', wslot = target, release = release }
    end

    seqCounter = seqCounter + 1
    stateOf(src)[slot] = {
        name  = itemData.name,
        slot  = slot,
        wslot = nil,
        class = false,
        seq   = seqCounter,
    }

    return { action = 'equip' }
end

AddEventHandler('hexa_inventory:server:itemRemovedFromPlayerInventory', function(src, itemName, data)
    if type(data) ~= 'table' then return end

    local list = equipped[src]
    if not list then return end

    local slot = tonumber(data.slot)

    if not slot then

        local lower = tostring(itemName):lower()
        local hit = false
        for pieceSlot, piece in pairs(list) do
            if piece.name:lower() == lower then
                list[pieceSlot] = nil
                hit = true
            end
        end
        if hit then
            TriggerClientEvent('hexa_inventory:client:RemoveWeaponFromTab', src, { name = itemName })
        end
        return
    end

    local piece = list[slot]
    if not piece then return end

    list[slot] = nil
    TriggerClientEvent('hexa_inventory:client:RemoveWeaponFromTab', src, {
        name = piece.name,
        slot = slot,
    })
end)

AddEventHandler('playerDropped', function()
    local src = source
    WeaponSlots.ClearAll(src)
    lastToggle[src] = nil
end)

RegisterNetEvent('hexa_inventory:server:releaseWeaponSlots', function(slots)
    local src = source

    if slots == nil or slots == true then
        WeaponSlots.ClearAll(src)
        return
    end

    if type(slots) ~= 'table' then return end
    for _, slot in ipairs(slots) do
        WeaponSlots.Release(src, tonumber(slot))
    end
end)
