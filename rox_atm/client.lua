-- ROX Store | rox_atm | All rights reserved.
local open = false
local function openAtm(entity)
    if open then return end
    local c = GetEntityCoords(entity or PlayerPedId())
    local data = lib.callback.await('rox_atm:open', false, c)
    if not data then return end
    open = true
    data.street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    data.title, data.quick = Config.Title, Config.Quick
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 800)
    lib.requestAnimDict('amb@prop_human_atm@male@enter')
    TaskPlayAnim(ped, 'amb@prop_human_atm@male@enter', 'enter', 8.0, -8.0, -1, 0, 0, false, false, false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end
exports('OpenATM', openAtm)

exports.ox_target:addModel(Config.Models, { {
    name = 'rox_atm', icon = 'fa-solid fa-credit-card', label = 'Use ATM', distance = Config.Distance,
    onSelect = function(d) openAtm(d.entity) end,
} })

RegisterNUICallback('close', function(_, cb)
    open = false; SetNuiFocus(false, false); ClearPedTasks(PlayerPedId()); cb(1)
end)
RegisterNUICallback('tx', function(d, cb)
    cb(lib.callback.await('rox_atm:tx', false, d.kind, d.amount) or { ok = false })
end)
