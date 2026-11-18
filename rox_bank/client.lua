-- ROX Store | rox_bank | All rights reserved.
local open = false
local function openBank(name)
    if open then return end
    local d = lib.callback.await('rox_bank:open', false); if not d then return end
    open = true; d.branch = name
    SetNuiFocus(true, true); SendNUIMessage({ action = 'open', data = d })
end
exports('OpenBank', openBank)
CreateThread(function()
    for i, b in ipairs(Config.Banks) do
        local bl = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(bl, Config.Blip.sprite); SetBlipColour(bl, Config.Blip.color); SetBlipScale(bl, Config.Blip.scale); SetBlipAsShortRange(bl, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString('Bank'); EndTextCommandSetBlipName(bl)
        exports.ox_target:addSphereZone({ coords = b.coords, radius = 1.6, options = { { name = 'rox_bank_' .. i, icon = 'fa-solid fa-building-columns', label = 'Open bank', onSelect = function() openBank(b.name) end } } })
    end
end)
RegisterNUICallback('close', function(_, cb) open = false; SetNuiFocus(false, false); cb(1) end)
RegisterNUICallback('action', function(d, cb) cb(lib.callback.await('rox_bank:action', false, d) or { ok = false }) end)
