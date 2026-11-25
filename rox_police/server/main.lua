--[[ ROX Police  ·  © ROX Store – All rights reserved. ]]
local function load()
    local s = GetResourceKvpString('origin')
    if s then local t = json.decode(s); return vec4(t.x, t.y, t.z, t.w) end
    return Config.Origin
end
local origin = load()
RegisterNetEvent('rox_police:get', function() TriggerClientEvent('rox_police:origin', source, { x = origin.x, y = origin.y, z = origin.z, w = origin.w }) end)
RegisterCommand('roxpolice_here', function(src)
    if src == 0 or not IsPlayerAceAllowed(src, Config.AdminAce) then return end
    local ped = GetPlayerPed(src)
    local p, h = GetEntityCoords(ped), GetEntityHeading(ped)
    origin = vec4(p.x, p.y, p.z - 1.0, h)
    SetResourceKvp('origin', json.encode({ x = origin.x, y = origin.y, z = origin.z, w = origin.w }))
    TriggerClientEvent('rox_police:origin', -1, { x = origin.x, y = origin.y, z = origin.z, w = origin.w })
end, false)
