-- ROX Store | All rights reserved
local wall, current = nil, 0.0

CreateThread(function()
    local b = AddBlipForCoord(Config.Origin.x, Config.Origin.y, Config.Origin.z)
    SetBlipSprite(b, Config.Blip.sprite); SetBlipColour(b, Config.Blip.color); SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.Blip.label); EndTextCommandSetBlipName(b)
end)

-- ---------------------------------------------------------------- moving secret wall
local function setAngle(a)
    current = a
    if wall and DoesEntityExist(wall) then SetEntityHeading(wall, (Config.Heading + a) % 360) end
end

local function animateTo(target)
    local start, t0 = current, GetGameTimer()
    local dur = Config.Wall.speed * 1000
    local hinge = Config.ToWorld(Config.Wall.hinge)
    PlaySoundFromCoord(-1, 'OPENED', hinge.x, hinge.y, hinge.z, 'MP_PROPERTIES_ELEVATOR_DOORS', false, 10, false)
    CreateThread(function()
        while true do
            local k = math.min(1.0, (GetGameTimer() - t0) / dur)
            local e = k < 0.5 and 2 * k * k or 1 - (-2 * k + 2) ^ 2 / 2   -- ease in/out
            setAngle(start + (target - start) * e)
            if k >= 1.0 then break end
            Wait(0)
        end
    end)
end

local function spawnWall()
    lib.requestModel(Config.Wall.model, 10000)
    local p = Config.ToWorld(Config.Wall.hinge)
    wall = CreateObjectNoOffset(Config.Wall.model, p.x, p.y, p.z, false, false, false)
    FreezeEntityPosition(wall, true)
    SetEntityInvincible(wall, true)
    SetModelAsNoLongerNeeded(Config.Wall.model)
    setAngle(GlobalState.rox_secret_open and Config.Wall.openAngle or 0.0)
end

CreateThread(function()            -- stream the wall in/out by distance
    while true do
        local d = #(GetEntityCoords(cache.ped) - Config.Origin)
        if d < 80.0 and not wall then spawnWall()
        elseif d > 100.0 and wall then DeleteEntity(wall); wall = nil end
        Wait(1500)
    end
end)

AddStateBagChangeHandler('rox_secret_open', 'global', function(_, _, open)
    if wall then animateTo(open and Config.Wall.openAngle or 0.0) end
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() and wall then DeleteEntity(wall) end
end)

-- ---------------------------------------------------------------- interactions
local function knock()
    if not lib.callback.await('rox_maps:canEnter', false) then
        return lib.notify({ type = 'error', description = 'Just a brick wall...' })
    end
    lib.requestAnimDict('timetable@jimmy@doorknock@')
    TaskPlayAnim(cache.ped, 'timetable@jimmy@doorknock@', 'knockdoor_idle', 8.0, -8.0, 1800, 0, 0, false, false, false)
    Wait(1600)
    TriggerServerEvent('rox_maps:toggleWall')
end

local function ride(goDown)
    if not lib.callback.await('rox_maps:canEnter', false) then
        return lib.notify({ type = 'error', description = 'Access denied' })
    end
    lib.requestAnimDict('anim@apt_trans@elevator')
    TaskPlayAnim(cache.ped, 'anim@apt_trans@elevator', 'elev_1', 8.0, -8.0, 1500, 0, 0, false, false, false)
    local c = GetEntityCoords(cache.ped)
    PlaySoundFromCoord(-1, 'CLOSED', c.x, c.y, c.z, 'MP_PROPERTIES_ELEVATOR_DOORS', false, 5, false)
    Wait(1200)
    DoScreenFadeOut(500); Wait(550)
    TriggerServerEvent('rox_maps:lift', goDown)
    Wait(Config.Lift.rideTime)
    c = GetEntityCoords(cache.ped)
    PlaySoundFromCoord(-1, 'OPENED', c.x, c.y, c.z, 'MP_PROPERTIES_ELEVATOR_DOORS', false, 5, false)
    DoScreenFadeIn(600)
end

exports.ox_target:addSphereZone({ coords = Config.ToWorld(Config.Wall.target), radius = 0.9,
    options = { { name = 'rox_secret_wall', icon = 'fa-solid fa-hand-fist', label = 'Knock on wall',
        onSelect = knock } } })
exports.ox_target:addSphereZone({ coords = Config.ToWorld(Config.Lift.top.button), radius = 0.5,
    options = { { name = 'rox_lift_down', icon = 'fa-solid fa-elevator', label = 'Elevator: Down',
        onSelect = function() ride(true) end } } })
exports.ox_target:addSphereZone({ coords = Config.ToWorld(Config.Lift.bottom.button), radius = 0.5,
    options = { { name = 'rox_lift_up', icon = 'fa-solid fa-elevator', label = 'Elevator: Up',
        onSelect = function() ride(false) end } } })
