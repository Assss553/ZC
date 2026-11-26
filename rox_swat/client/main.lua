--[[ ROX SWAT TEAM HQ  ·  © ROX Store – All rights reserved. ]]
local origin = Config.Origin
local D = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/swat.json') or '{}') or {}
local DEPTH, PLAZA = D.depth or 11.0, D.plaza or 1.0
local HW, HD = D.hatch and D.hatch[1] or 3.6, D.hatch and D.hatch[2] or 4.6
local PH = D.pillarHeight or 7.0
local ents, parts, doorRecs, on = {}, {}, {}, false
local state, startAt = { pillars = 0, doors = 0, lift = 0 }, { pillars = 0, doors = 0, lift = 0 }
local prev = { pillars = 0, doors = 0, lift = 0 }
local doorState = {}
local L = Config.Locale == 'ar'

local function toWorld(x, y, z)
    local h = math.rad(origin.w); local c, s = math.cos(h), math.sin(h)
    return vector3(origin.x + x * c - y * s, origin.y + x * s + y * c, origin.z + z)
end
local function toLocal(p)
    local h = math.rad(-origin.w); local dx, dy = p.x - origin.x, p.y - origin.y
    return dx * math.cos(h) - dy * math.sin(h), dx * math.sin(h) + dy * math.cos(h), p.z - origin.z
end
local function loadModel(name)
    local hash = type(name) == 'number' and name or joaat(name)
    if not IsModelInCdimage(hash) then return end
    RequestModel(hash); local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
    if HasModelLoaded(hash) then return hash end
end
local function obj(list, name, x, y, z, h, frozen)
    local hash = loadModel(name); if not hash then return end
    local p = toWorld(x, y, z)
    local o = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, frozen == false)
    SetEntityHeading(o, (origin.w + (h or 0.0)) % 360.0)
    if frozen ~= false then FreezeEntityPosition(o, true) end
    SetModelAsNoLongerNeeded(hash); list[#list + 1] = o
    return o
end
local function help(t) BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(t); EndTextCommandDisplayHelp(0, false, true, -1) end
local function notify(t) BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(t); EndTextCommandThefeedPostTicker(false, true) end

-- moving parts: progress 0..1 for each group -------------------------------------------------------------------
local DUR = { pillars = Config.PillarTime, doors = Config.DoorTime, lift = Config.LiftTime }
local function progress(k)
    local t = math.min(1.0, (GetGameTimer() - startAt[k]) / (DUR[k] * 1000.0))
    local e = t * t * (3 - 2 * t)
    return prev[k] + (state[k] - prev[k]) * e, t >= 1.0
end
local function pose()
    if not parts.lift then return end
    local pp = progress('pillars')
    for i, p in ipairs(D.pillars or {}) do
        local o = parts['pillar' .. i]
        if o then local w = toWorld(p[1], p[2], (PLAZA - PH) + PH * pp); SetEntityCoordsNoOffset(o, w.x, w.y, w.z, false, false, false) end
    end
    if parts.sign then local w = toWorld(0.0, -HD - 1.6, (PLAZA + PH - 1.6 - PH) + PH * pp); SetEntityCoordsNoOffset(parts.sign, w.x, w.y, w.z, false, false, false) end
    local dp = progress('doors')
    for sgn, o in pairs({ [-1] = parts.leafL, [1] = parts.leafR }) do
        local x, z
        if dp < 0.2 then x, z = HW / 2, PLAZA - 0.4 * (dp / 0.2) else x, z = HW / 2 + HW * ((dp - 0.2) / 0.8), PLAZA - 0.4 end
        local w = toWorld(sgn * x, 0.0, z); SetEntityCoordsNoOffset(o, w.x, w.y, w.z, false, false, false)
    end
    local lp = progress('lift')
    local w = toWorld(0.0, 0.0, -DEPTH + (DEPTH + PLAZA) * lp); SetEntityCoordsNoOffset(parts.lift, w.x, w.y, w.z, false, false, false)
end

-- doors ---------------------------------------------------------------------------------------------------------
local function doorModel(kind, w)
    for _, name in ipairs(Config.DoorModels[kind] or Config.DoorModels.std) do
        local hash = loadModel(name)
        if hash then
            local mn, mx = GetModelDimensions(hash)
            if (mx.x - mn.x) <= w + 0.15 then return hash end
        end
    end
end
local function spawnDoors()
    for i, d in ipairs(D.doors or {}) do
        local leaves = d.w > 1.7 and 2 or 1
        for k = 1, leaves do
            local lw = d.w / leaves; local hash = doorModel(d.kind, lw)
            if hash then
                local a = math.rad(d.h); local hx, hy = d.x, d.y
                local hd = d.h
                if k == 2 then hx, hy, hd = d.x + math.cos(a) * d.w, d.y + math.sin(a) * d.w, d.h + 180.0 end
                local o = obj(ents, hash, hx, hy, -DEPTH, hd, false)
                local id = ('rox_swat_%d'):format(i * 10 + k); local dh = joaat(id); local p = toWorld(hx, hy, -DEPTH)
                AddDoorToSystem(dh, hash, p.x, p.y, p.z, false, false, false)
                local locked = d.kind == 'sec'; if doorState[id] ~= nil then locked = doorState[id] end
                DoorSystemSetDoorState(dh, locked and 1 or 0, false, true)
                doorRecs[#doorRecs + 1] = { id = id, hash = dh, pos = p, kind = d.kind }
            end
        end
    end
end

local function spawn()
    obj(ents, 'rox_swat_plaza', 0, 0, 0, 0)
    obj(ents, 'rox_swat_hq', 0, 0, -DEPTH, 0)
    parts.lift = obj(ents, 'rox_swat_lift', 0, 0, -DEPTH, 0)
    parts.leafL = obj(ents, 'rox_swat_leaf', -HW / 2, 0, PLAZA, 0); parts.leafR = obj(ents, 'rox_swat_leaf', HW / 2, 0, PLAZA, 0)
    for i, p in ipairs(D.pillars or {}) do parts['pillar' .. i] = obj(ents, 'rox_swat_pillar', p[1], p[2], PLAZA - PH, 0) end
    parts.sign = obj(ents, 'rox_swat_sign', 0, -HD - 1.6, PLAZA - 1.6, 0)
    local named = {}
    for _, f in ipairs(D.furniture or {}) do
        local hash = loadModel(f.m)
        if hash then
            local z = -DEPTH + (f.z or 0.0)
            if f.on and named[f.on] then local _, mx = GetModelDimensions(GetEntityModel(named[f.on])); z = -DEPTH + mx.z end
            local o = obj(ents, hash, f.x, f.y, z, (f.h or 0.0) + Config.PropFront - 180.0)
            if f.name then named[f.name] = o end
        end
    end
    spawnDoors(); pose(); on = true
end
local function despawn()
    for _, d in ipairs(doorRecs) do if IsDoorRegisteredWithSystem(d.hash) then RemoveDoorFromSystem(d.hash) end end
    for _, e in ipairs(ents) do if DoesEntityExist(e) then DeleteObject(e) end end
    ents, parts, doorRecs, on = {}, {}, {}, false
end

-- carry the player's car / ped with the lift --------------------------------------------------------------------
local carried
local function onLift(ent)
    local lx, ly, lz = toLocal(GetEntityCoords(ent))
    local top = -DEPTH + (DEPTH + PLAZA) * (progress('lift'))
    return math.abs(lx) < HW and math.abs(ly) < HD and lz > top - 1.0 and lz < top + 4.0
end
local function carry()
    local ped = PlayerPedId(); local veh = GetVehiclePedIsIn(ped, false)
    local ent = (veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped) and veh or ped
    local _, done = progress('lift')
    if not done and not carried and onLift(ent) and parts.lift then
        local off = GetOffsetFromEntityGivenWorldCoords(parts.lift, GetEntityCoords(ent))
        local rh = GetEntityHeading(ent) - GetEntityHeading(parts.lift)
        AttachEntityToEntity(ent, parts.lift, 0, off.x, off.y, off.z, 0.0, 0.0, rh, false, false, true, false, 2, true)
        carried = ent
    elseif done and carried then
        DetachEntity(carried, true, true); carried = nil
    end
end

-- main loop -----------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        local ped = PlayerPedId(); local pos = GetEntityCoords(ped)
        local d = #(pos.xy - vector2(origin.x, origin.y))
        if d < Config.SpawnDistance and not on then spawn() elseif d > Config.SpawnDistance + 50.0 and on then despawn() end
        local wait = 500
        if on and d < 120.0 then
            wait = 0; pose(); carry()
            local lx, ly, lz = toLocal(pos)
            local function point(x, y, z, txt, cb)
                local w = toWorld(x, y, z); local dd = #(pos - w)
                if dd < 15.0 then DrawMarker(1, w.x, w.y, w.z - 1.0, 0, 0, 0, 0, 0, 0, 1.4, 1.4, 0.25, 232, 180, 20, 110, false, false, 2, false, nil, nil, false) end
                if dd < 2.0 then help(txt); if IsControlJustPressed(0, 38) then cb() end end
            end
            -- street call point in front of the hatch, and on the lift (top / bottom)
            point(0.0, -HD - 4.0, PLAZA + 1.0, L and '~INPUT_CONTEXT~ فتح مقر SWAT' or '~INPUT_CONTEXT~ Open SWAT hatch', function() TriggerServerEvent('rox_swat:call', 'up') end)
            local _, liftDone = progress('lift')
            if liftDone and math.abs(lx) < HW and math.abs(ly) < HD then
                if state.lift == 1 and lz > PLAZA - 1.0 and lz < PLAZA + 4.0 then
                    help(L and '~INPUT_CONTEXT~ النزول للمقر' or '~INPUT_CONTEXT~ Go down'); if IsControlJustPressed(0, 38) then TriggerServerEvent('rox_swat:call', 'down') end
                elseif state.lift == 0 and lz < -DEPTH + 4.0 then
                    help(L and '~INPUT_CONTEXT~ الصعود للشارع' or '~INPUT_CONTEXT~ Go up'); if IsControlJustPressed(0, 38) then TriggerServerEvent('rox_swat:call', 'up') end
                end
            end
            -- pedestrian access booth <-> garage
            local fu, fd = D.footUp or { 7.5, 7.6 }, D.footDown or { -15.0, -4.6 }
            point(fu[1], fu[2], PLAZA + 1.0, L and '~INPUT_CONTEXT~ النزول للمقر (درج)' or '~INPUT_CONTEXT~ Stairs down', function() TriggerServerEvent('rox_swat:foot'); _G.__roxswat_go = 'down' end)
            point(fd[1], fd[2], -DEPTH + 1.0, L and '~INPUT_CONTEXT~ الصعود للشارع (درج)' or '~INPUT_CONTEXT~ Stairs up', function() TriggerServerEvent('rox_swat:foot'); _G.__roxswat_go = 'up' end)
            for _, dr in ipairs(doorRecs) do
                if dr.kind == 'sec' and #(pos - dr.pos) < 1.8 then
                    local locked = DoorSystemGetDoorState(dr.hash) ~= 0
                    help((L and '~INPUT_CONTEXT~ بطاقة الدخول: ' or '~INPUT_CONTEXT~ Keycard: ') .. (locked and '~r~🔒' or '~g~🔓'))
                    if IsControlJustPressed(0, 38) then TriggerServerEvent('rox_swat:door', dr.id, not locked) end
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('rox_swat:footOk', function()
    local fu, fd = D.footUp or { 7.5, 7.6 }, D.footDown or { -15.0, -4.6 }
    local p = _G.__roxswat_go == 'down' and toWorld(fd[1], fd[2] + 1.5, -DEPTH + 1.0) or toWorld(fu[1], fu[2] - 1.5, PLAZA + 1.0)
    DoScreenFadeOut(400); while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(p.x, p.y, p.z); SetEntityCoords(PlayerPedId(), p.x, p.y, p.z, false, false, false, false)
    Wait(700); DoScreenFadeIn(500)
end)
RegisterNetEvent('rox_swat:state', function(s, serverNow)
    for _, k in ipairs({ 'pillars', 'doors', 'lift' }) do
        if s[k] ~= state[k] then
            prev[k] = state[k]; state[k] = s[k]
            startAt[k] = GetGameTimer() - math.max(0, (serverNow - (s.t and s.t[k] or serverNow)))
        end
    end
end)
RegisterNetEvent('rox_swat:msg', function(m) if m == 'denied' then notify(L and '~r~غير مصرح لك بالدخول لمقر SWAT' or '~r~SWAT access only') end end)
RegisterNetEvent('rox_swat:doorState', function(id, locked) doorState[id] = locked; local h = joaat(id); if IsDoorRegisteredWithSystem(h) then DoorSystemSetDoorState(h, locked and 1 or 0, false, true) end end)
RegisterNetEvent('rox_swat:doors', function(all) for id, l in pairs(all or {}) do doorState[id] = l end end)
RegisterNetEvent('rox_swat:origin', function(o) despawn(); origin = vec4(o.x, o.y, o.z, o.w) end)
CreateThread(function() TriggerServerEvent('rox_swat:get') end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then if carried then DetachEntity(carried, true, true) end; despawn() end end)
