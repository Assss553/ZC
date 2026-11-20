--[[ ROX NYC  ·  © ROX Store – All rights reserved. ]]
local origin = Config.Origin
CreateThread(function()
    local s = GetResourceKvpString('rox_nyc_origin')
    if s then local d = json.decode(s); if d then origin = vec4(d.x, d.y, d.z, d.w) end end
    TriggerClientEvent('rox_nyc:origin', -1, origin)
end)
RegisterNetEvent('rox_nyc:hello', function() TriggerClientEvent('rox_nyc:origin', source, origin) end)
RegisterCommand('roxnyc_here', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminAce) then return end
    local ped = GetPlayerPed(src); local c = GetEntityCoords(ped)
    origin = vec4(c.x, c.y, c.z - 1.0, GetEntityHeading(ped))
    SetResourceKvp('rox_nyc_origin', json.encode({ x = origin.x, y = origin.y, z = origin.z, w = origin.w }))
    TriggerClientEvent('rox_nyc:origin', -1, origin)
end, false)
