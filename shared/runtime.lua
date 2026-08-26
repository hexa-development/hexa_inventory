-- Hexa Inventory source.
HexaInventory = HexaInventory or {}

local localeName = GetConvar('hexa_inventory:locale', GetConvar('locale', 'en'))
local localeData = {}

local function readLocale(name)
    local raw = LoadResourceFile(GetCurrentResourceName(), ('locales/%s.json'):format(name))
    if not raw then return nil end
    local decoded = json.decode(raw)
    return type(decoded) == 'table' and decoded or nil
end

local function mergeLocale(base, override)
    local result = {}
    for key, value in pairs(base or {}) do
        result[key] = type(value) == 'table' and mergeLocale(value, {}) or value
    end
    for key, value in pairs(override or {}) do
        if type(value) == 'table' and type(result[key]) == 'table' then
            result[key] = mergeLocale(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

local english = readLocale('en') or {}
localeData = localeName == 'en' and english or mergeLocale(english, readLocale(localeName) or {})

function locale(path)
    local current = localeData
    for part in tostring(path):gmatch('[^.]+') do
        if type(current) ~= 'table' then return path end
        current = current[part]
    end
    return type(current) == 'string' and current or path
end

function math.round(value, decimals)
    local power = 10 ^ (tonumber(decimals) or 0)
    return math.floor((tonumber(value) or 0) * power + 0.5) / power
end

function HexaInventory.Merge(base, override)
    local result = {}
    for key, value in pairs(type(base) == 'table' and base or {}) do result[key] = value end
    for key, value in pairs(type(override) == 'table' and override or {}) do result[key] = value end
    return result
end

function HexaInventory.Notify(data, source)
    data = type(data) == 'table' and data or { description = tostring(data) }
    data.title = data.title or 'hexa_inventory'
    data.duration = data.duration or 5000

    if IsDuplicityVersion() then
        return Core.Notify(source, data)
    end

    TriggerEvent('HexaCore:Notify', data)
end

InventoryCallback = InventoryCallback or {}

if IsDuplicityVersion() then
    function HexaInventory.AddCommand(name, options, handler)
        options = options or {}
        RegisterCommand(name, function(source, rawArgs)
            local restricted = options.restricted
            local permission = restricted and restricted:match('group%.(.+)')
            if source > 0 and permission and not Core.HasPermission(source, permission) then
                return HexaInventory.Notify({
                    type = 'error',
                    description = locale('error.access_denied'),
                }, source)
            end

            local args = {}
            for index, definition in ipairs(options.params or {}) do
                local value = rawArgs[index]
                if definition.type == 'number' or definition.type == 'playerId' then
                    value = tonumber(value)
                end
                args[definition.name] = value
            end
            handler(source, args)
        end, false)
    end

    function InventoryCallback.Register(name, handler)
        Core.CreateCallback(name, function(source, cb, ...)
            cb(handler(source, ...))
        end)
    end

    function InventoryCallback.AwaitClient(name, source, ...)
        local pending = promise.new()
        Core.TriggerClientCallback(name, source, function(...)
            pending:resolve({ ... })
        end, ...)
        local result = Citizen.Await(pending)
        return table.unpack(result)
    end
else
    function InventoryCallback.Register(name, handler)
        Core.CreateCallback(name, function(cb, ...)
            cb(handler(...))
        end)
    end

    function InventoryCallback.Await(name, ...)
        local pending = promise.new()
        Core.TriggerCallback(name, function(...)
            pending:resolve({ ... })
        end, ...)
        local result = Citizen.Await(pending)
        return table.unpack(result)
    end

    function HexaInventory.RequestAnimDict(dict)
        if HasAnimDictLoaded(dict) then return true end
        RequestAnimDict(dict)
        local expires = GetGameTimer() + 5000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < expires do Wait(0) end
        return HasAnimDictLoaded(dict)
    end

    function HexaInventory.PromptNumber(title, defaultValue)
        AddTextEntry('HEXA_INV_NUMBER', title or locale('info.enter_amount'))
        DisplayOnscreenKeyboard(1, 'HEXA_INV_NUMBER', '', tostring(defaultValue or ''), '', '', '', 10)
        while UpdateOnscreenKeyboard() == 0 do Wait(0) end
        if UpdateOnscreenKeyboard() ~= 1 then return nil end
        local value = tonumber(GetOnscreenKeyboardResult())
        return value and math.floor(value) or nil
    end

    function HexaInventory.PromptText(title, defaultValue, maxLength)
        AddTextEntry('HEXA_INV_TEXT', title or '')
        DisplayOnscreenKeyboard(1, 'HEXA_INV_TEXT', '', tostring(defaultValue or ''), '', '', '', maxLength or 64)
        while UpdateOnscreenKeyboard() == 0 do Wait(0) end
        if UpdateOnscreenKeyboard() ~= 1 then return nil end
        local value = GetOnscreenKeyboardResult()
        return value and tostring(value) or nil
    end
end
