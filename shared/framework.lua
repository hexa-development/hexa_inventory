-- Hexa Inventory source.
HexaInventory = HexaInventory or {}
HexaInventory.Resource = GetCurrentResourceName()

local function refreshCore()
    local core = exports['hexa_core']:GetCoreObject()

    if core then
        Core = core
        HexaInventory.Core = core
    end

    return Core
end

HexaInventory.RefreshCore = refreshCore
refreshCore()

AddEventHandler(IsDuplicityVersion() and 'HexaCore:Server:UpdateObject' or 'HexaCore:Client:UpdateObject', refreshCore)

function HexaInventory.AwaitCatalogue(timeout)
    local expires = GetGameTimer() + (tonumber(timeout) or 15000)

    repeat
        refreshCore()
        if Core and Core.Shared and Core.Shared.Items and next(Core.Shared.Items) then
            return true
        end
        Wait(50)
    until GetGameTimer() >= expires

    return false
end
