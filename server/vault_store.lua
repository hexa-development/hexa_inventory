-- Hexa Inventory source.
VaultStore = VaultStore or {
    UnreadablePlayers = {},
    UnreadableVaults = {},
}

local function waitForSchema()
    local ok = exports['hexa_core']:AwaitSchemaReady(15000)
    if not ok then print('[hexa_inventory] hexa_core schema wait timed out') end
    HexaInventory.AwaitCatalogue(15000)
end

local function encodeColumns(items)
    return json.encode(exports['hexa_core']:EncodeInventory(items) or {}),
        json.encode(exports['hexa_core']:EncodeLoadout(items) or {})
end

function VaultStore.LoadPlayer(citizenid)
    if not citizenid then return {} end
    waitForSchema()

    local row = MySQL.single.await(
        'SELECT inventory, loadout FROM users WHERE citizenid = ? LIMIT 1',
        { tostring(citizenid) }
    )
    if not row then return {} end

    local slots, unreadable = exports['hexa_core']:BuildSlots(row.inventory, row.loadout)
    VaultStore.UnreadablePlayers[tostring(citizenid)] = unreadable or nil
    if unreadable then
        print(('[hexa_inventory] refused to decode inventory for %s; original columns will not be overwritten'):format(citizenid))
    end
    return Inventory.HydrateItems(slots)
end

function VaultStore.SavePlayer(playerData)
    if not playerData or not playerData.citizenid then return false end
    if VaultStore.UnreadablePlayers[tostring(playerData.citizenid)] then return false end
    local inventory, loadout = encodeColumns(playerData.items)
    MySQL.update.await(
        'UPDATE users SET inventory = ?, loadout = ? WHERE citizenid = ?',
        { inventory, loadout, tostring(playerData.citizenid) }
    )
    return true
end

function VaultStore.Save(identifier)
    local vault = identifier and Inventories[identifier]
    if not vault then return false end
    if VaultStore.UnreadableVaults[tostring(identifier)] then return false end
    local items, loadout = encodeColumns(vault.items)
    MySQL.query.await([[
        INSERT INTO users_vault (identifier, items, loadout)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE items = VALUES(items), loadout = VALUES(loadout)
    ]], { tostring(identifier), items, loadout })
    return true
end

function VaultStore.Delete(identifier)
    if not identifier then return false end
    MySQL.update.await('DELETE FROM users_vault WHERE identifier = ?', { tostring(identifier) })
    VaultStore.UnreadableVaults[tostring(identifier)] = nil
    return true
end

function VaultStore.LoadAll()
    waitForSchema()
    local config = HexaInventory.Config
    local rows = MySQL.query.await('SELECT identifier, items, loadout FROM users_vault') or {}

    for _, row in ipairs(rows) do
        local slots, unreadable = exports['hexa_core']:BuildSlots(row.items, row.loadout)
        VaultStore.UnreadableVaults[tostring(row.identifier)] = unreadable or nil
        if unreadable then
            print(('[hexa_inventory] vault %s contains unreadable JSON; writes are disabled until it is repaired or deleted'):format(row.identifier))
        end
        Inventories[row.identifier] = {
            items = Inventory.HydrateItems(slots),
            isOpen = false,
            label = row.identifier,
            maxweight = config.StashSize.maxweight,
            slots = config.StashSize.slots,
        }
    end

    print(('[hexa_inventory] loaded %d persistent vaults'):format(#rows))
    return #rows
end
