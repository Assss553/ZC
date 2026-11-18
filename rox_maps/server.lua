-- ROX Store | All rights reserved
local function allowed(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return false end
    local g = p.PlayerData.gang
    local min = g and Config.Gangs[g.name]
    return min ~= nil and (g.grade.level or 0) >= min
end
lib.callback.register('rox_maps:canEnter', function(src) return allowed(src) end)
RegisterNetEvent('rox_maps:enter', function(inside)
    local src = source
    if not allowed(src) then return end
    local t = inside and Config.HQ.exit or Config.HQ.coords
    SetEntityCoords(GetPlayerPed(src), t.x, t.y, t.z, false, false, false, false)
    SetEntityHeading(GetPlayerPed(src), t.w)
end)
