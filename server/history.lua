-- Hexa Inventory source.
InventoryHistory = InventoryHistory or {}

local config = HexaInventory.Config.History or {}
local ready = false

CreateThread(function()
    exports['hexa_core']:AwaitSchemaReady(15000)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS inventory_history (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            citizenid VARCHAR(64) NOT NULL,
            action VARCHAR(16) NOT NULL,
            item VARCHAR(96) NOT NULL,
            label VARCHAR(160) NOT NULL,
            amount INT UNSIGNED NOT NULL,
            reason VARCHAR(255) NULL,
            counterpart VARCHAR(128) NULL,
            created_at BIGINT UNSIGNED NOT NULL,
            PRIMARY KEY (id),
            KEY idx_inventory_history_owner (citizenid, id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    ready = true
end)

local function ownerOf(source)
    local player = Core.GetPlayer(tonumber(source))
    if not player then return nil end
    return player, tostring(player.PlayerData.citizenid or '')
end

local function playerLabel(source)
    local player = Core.GetPlayer(tonumber(source))
    local char = player and player.PlayerData.charinfo
    if char and char.firstname then
        return (('%s %s'):format(char.firstname, char.lastname or '')):gsub('%s+$', '')
    end
    return GetPlayerName(tonumber(source)) or tostring(source)
end

local function prune(citizenid)
    local maximum = math.max(1, math.floor(tonumber(config.MaxEntries) or 100))
    local query = ([=[
        DELETE FROM inventory_history
        WHERE citizenid = ? AND id NOT IN (
            SELECT id FROM (
                SELECT id FROM inventory_history
                WHERE citizenid = ? ORDER BY id DESC LIMIT %d
            ) AS recent
        )
    ]=]):format(maximum)
    MySQL.update(query, { citizenid, citizenid })
end

function InventoryHistory.Record(source, action, itemName, amount, reason, counterpart)
    if config.Enabled == false or not ready then return false end
    if action ~= 'receive' and action ~= 'lost' and action ~= 'give' then return false end

    local _, citizenid = ownerOf(source)
    amount = math.floor(tonumber(amount) or 0)
    if not citizenid or citizenid == '' or amount <= 0 or type(itemName) ~= 'string' then return false end

    itemName = itemName:lower()
    local definition = Core.Shared.Items[itemName]
    local counterpartLabel = counterpart
    if tonumber(counterpart) then counterpartLabel = playerLabel(tonumber(counterpart)) end

    MySQL.insert([[
        INSERT INTO inventory_history
            (citizenid, action, item, label, amount, reason, counterpart, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid,
        action,
        itemName,
        definition and definition.label or itemName,
        amount,
        reason and tostring(reason):sub(1, 255) or nil,
        counterpartLabel and tostring(counterpartLabel):sub(1, 128) or nil,
        os.time(),
    }, function()
        prune(citizenid)
    end)
    return true
end

local ignoredReasons = {
    'rollback',
    'rescue',
    'stacked item',
    'split item',
    'moved item',
    'swapped item',
    'bulk transfer',
    'trade ',
}

function InventoryHistory.IsInternalReason(reason)
    reason = tostring(reason or ''):lower()
    for _, fragment in ipairs(ignoredReasons) do
        if reason:find(fragment, 1, true) then return true end
    end
    return false
end

function InventoryHistory.Get(source)
    if config.Enabled == false or not ready then return {} end
    local _, citizenid = ownerOf(source)
    if not citizenid or citizenid == '' then return {} end

    local maximum = math.max(1, math.floor(tonumber(config.MaxEntries) or 100))
    return MySQL.query.await(([=[
        SELECT action, item, label, amount, reason, counterpart, created_at
        FROM inventory_history
        WHERE citizenid = ?
        ORDER BY id DESC
        LIMIT %d
    ]=]):format(maximum), { citizenid }) or {}
end

InventoryCallback.Register('hexa_inventory:server:getHistory', function(source)
    return InventoryHistory.Get(source)
end)
