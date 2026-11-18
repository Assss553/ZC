-- ROX Store | All rights reserved
local closeTimer = 0
GlobalState.rox_secret_open = false

local function allowed(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return false end
    local g = p.PlayerData.gang
    local min = g and Config.Gangs[g.name]
    return min ~= nil and (g.grade.level or 0) >= min
end

local function near(src, offset, dist)
    return #(GetEntityCoords(GetPlayerPed(src)) - Config.ToWorld(offset)) <= dist
end

lib.callback.register('rox_maps:canEnter', function(src) return allowed(src) end)

RegisterNetEvent('rox_maps:toggleWall', function()
    local src = source
    if not allowed(src) or not near(src, Config.Wall.target, 4.0) then return end
    local open = not GlobalState.rox_secret_open
    GlobalState.rox_secret_open = open
    if open then
        local id = closeTimer + 1; closeTimer = id
        SetTimeout(Config.Wall.autoClose * 1000, function()
            if closeTimer == id then GlobalState.rox_secret_open = false end
        end)
    end
end)

RegisterNetEvent('rox_maps:lift', function(goDown)
    local src = source
    local from = goDown and Config.Lift.top or Config.Lift.bottom
    local to = goDown and Config.Lift.bottom or Config.Lift.top
    if not allowed(src) or not near(src, from.button, 3.0) then return end
    local p = Config.ToWorld(to.spawn.xyz)
    local ped = GetPlayerPed(src)
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(ped, (to.spawn.w + Config.Heading) % 360)
end)
