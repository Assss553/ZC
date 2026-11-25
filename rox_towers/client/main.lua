--[[ ROX Towers  ·  © ROX Store – All rights reserved. ]]
-- Exterior pieces are always spawned near the towers. Interior floors (model + GTA furniture + real doors) are spawned
-- only for the floor you are on (± Config.FloorWindow), so 40+ floors cost about one floor of memory.
local origin = Config.Origin
local DATA = json.decode(LoadResourceFile(GetCurrentResourceName(), 'data/interior.json') or '{}') or {}
local FLOORS = DATA.floors or {}
local ext, extOn = {}, false
local live = {}            -- floor index -> { ents = {}, doors = {} }
local doorState = {}       -- door id -> locked (synced from server)

local function toWorld(x, y, z)
    local h = math.rad(origin.w); local c, s = math.cos(h), math.sin(h)
    return vector3(origin.x + x * c - y * s, origin.y + x * s + y * c, origin.z + z)
end
local function toLocal(p)
    local h = math.rad(-origin.w); local dx, dy = p.x - origin.x, p.y - origin.y
    return dx * math.cos(h) - dy * math.sin(h), dx * math.sin(h) + dy * math.cos(h), p.z - origin.z
end

local function loadModel(list)
    if type(list) == 'string' then list = { list } end
    for _, name in ipairs(list) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) then
            RequestModel(hash)
            local t = GetGameTimer() + 5000
            while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
            if HasModelLoaded(hash) then return hash end
        end
    end
end

local function place(list, hash, pos, heading, frozen)
    local o = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, frozen == false)
    SetEntityHeading(o, heading)
    if frozen ~= false then FreezeEntityPosition(o, true) end
    SetModelAsNoLongerNeeded(hash)
    list[#list + 1] = o
    return o
end

local function heading(h) return (origin.w + (h or 0.0) + Config.PropFront - 180.0) % 360.0 end

local function spawnFurniture(list, items, z0)
    local named = {}
    for _, f in ipairs(items or {}) do
        local hash = loadModel(f.m)
        if hash then
            local z = z0 + (f.z or 0.0)
            if f.on and named[f.on] then
                local _, mx = GetModelDimensions(GetEntityModel(named[f.on])); z = z0 + mx.z
            end
            local o = place(list, hash, toWorld(f.x, f.y, z), heading(f.h))
            if f.name then named[f.name] = o end
        end
    end
end

-- doors ---------------------------------------------------------------------------------------------------------
local function doorModel(kind, w)
    for _, name in ipairs(Config.DoorModels[kind] or Config.DoorModels.std) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) then
            RequestModel(hash); local t = GetGameTimer() + 3000
            while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
            if HasModelLoaded(hash) then
                local mn, mx = GetModelDimensions(hash)
                if (mx.x - mn.x) <= w + 0.15 then return hash end
                SetModelAsNoLongerNeeded(hash)
            end
        end
    end
end

local function spawnDoors(rec, fi, list, z0)
    for i, d in ipairs(list or {}) do
        local hash = doorModel(d.kind, d.w)
        if hash then
            local p = toWorld(d.x, d.y, z0)
            local o = place(rec.ents, hash, p, (origin.w + d.h) % 360.0, false)
            local id = ('rox_towers_%d_%d'):format(fi, i)
            local dh = joaat(id)
            AddDoorToSystem(dh, hash, p.x, p.y, p.z, false, false, false)
            local locked = d.kind == 'sec'
            if doorState[id] ~= nil then locked = doorState[id] end
            DoorSystemSetDoorState(dh, locked and 1 or 0, false, true)
            rec.doors[#rec.doors + 1] = { id = id, hash = dh, pos = p, kind = d.kind, key = d.key }
        end
    end
end

-- floors --------------------------------------------------------------------------------------------------------
local function spawnFloor(fi)
    local fl = FLOORS[fi]; local rec = { ents = {}, doors = {} }
    if fl.model then
        local h = loadModel(fl.model)
        if h then place(rec.ents, h, toWorld(0, 0, fl.z), origin.w) end
        spawnFurniture(rec.ents, DATA.furniture and DATA.furniture[fl.model], fl.z)
        spawnDoors(rec, fi, DATA.doors and DATA.doors[fl.model], fl.z)
    else
        spawnFurniture(rec.ents, Config.Furniture.skylounge, fl.z)
    end
    live[fi] = rec
end

local function despawnFloor(fi)
    local rec = live[fi]; if not rec then return end
    for _, d in ipairs(rec.doors) do if IsDoorRegisteredWithSystem(d.hash) then RemoveDoorFromSystem(d.hash) end end
    for _, e in ipairs(rec.ents) do if DoesEntityExist(e) then DeleteObject(e) end end
    live[fi] = nil
end

local function spawnExterior()
    for _, piece in ipairs({ 'rox_towers_base', 'rox_towers_twin' }) do
        local h = loadModel(piece); if h then place(ext, h, toWorld(0, 0, 0), origin.w) end
    end
    extOn = true
end
local function despawnAll()
    for fi in pairs(live) do despawnFloor(fi) end
    for _, e in ipairs(ext) do if DoesEntityExist(e) then DeleteObject(e) end end
    ext, extOn = {}, false
end

-- UI ------------------------------------------------------------------------------------------------------------
local function help(txt) BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(txt); EndTextCommandDisplayHelp(0, false, true, -1) end
local function label(fl) return Config.Locale == 'ar' and fl.labelAr or fl.label end

local function teleport(fl, x, y)
    DoScreenFadeOut(400); while not IsScreenFadedOut() do Wait(0) end
    local p = toWorld(x, y, fl.z + 1.0)
    for fi, f in ipairs(FLOORS) do if f == fl and not live[fi] then spawnFloor(fi) end end
    RequestCollisionAtCoord(p.x, p.y, p.z)
    SetEntityCoords(PlayerPedId(), p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), (origin.w + 180.0) % 360.0)
    Wait(700); DoScreenFadeIn(500)
end

local function menu(title, opts)
    local sel, top, N = 1, 1, 10
    while true do
        Wait(0)
        if sel < top then top = sel elseif sel >= top + N then top = sel - N + 1 end
        local txt = '~y~' .. title .. '~s~\n'
        for k = top, math.min(#opts, top + N - 1) do txt = txt .. (k == sel and '~g~> ' or '   ') .. opts[k].label .. '~s~\n' end
        txt = txt .. ('~c~%d/%d   ↑ ↓  ENTER  BACKSPACE'):format(sel, #opts)
        BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(txt); EndTextCommandDisplayHelp(0, false, false, -1)
        if IsControlJustPressed(0, 172) then sel = sel > 1 and sel - 1 or #opts end
        if IsControlJustPressed(0, 173) then sel = sel < #opts and sel + 1 or 1 end
        if IsControlJustPressed(0, 177) then return end
        if IsControlJustPressed(0, 191) then return opts[sel] end
    end
end

local function elevator(cur)
    local opts = {}
    for i, fl in ipairs(FLOORS) do if i ~= cur then opts[#opts + 1] = { i = i, label = label(fl) } end end
    local o = menu(Config.Locale == 'ar' and 'مصعد ROX' or 'ROX Elevator', opts)
    if o then local fl = FLOORS[o.i]; teleport(fl, fl.ex, fl.ey) end
end

local function stairs(cur)
    local opts = {}
    for _, d in ipairs({ -1, 1 }) do
        local fl = FLOORS[cur + d]
        if fl and fl.model and fl.model:find('rox_towers_f_') then opts[#opts + 1] = { i = cur + d, label = (d > 0 and '↑ ' or '↓ ') .. label(fl) } end
    end
    if #opts == 0 then return end
    local o = menu(Config.Locale == 'ar' and 'درج الطوارئ' or 'Emergency stairs', opts)
    if o then teleport(FLOORS[o.i], Config.StairsPoint.x, Config.StairsPoint.y) end
end

-- main loop -----------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        local ped = PlayerPedId(); local pos = GetEntityCoords(ped)
        local d = #(pos.xy - vector2(origin.x, origin.y))
        if d < Config.SpawnDistance and not extOn then spawnExterior()
        elseif d > Config.SpawnDistance + 50.0 and extOn then despawnAll() end
        local wait = 1000
        if extOn and d < 40.0 + Config.StreamRadius then
            local lx, ly, lz = toLocal(pos)
            local inside = math.abs(lx) < 31.0 + Config.StreamRadius * 0.2 and math.abs(ly) < 26.0 + Config.StreamRadius * 0.2
            for fi, fl in ipairs(FLOORS) do
                local want = inside and ((fi == 1 and lz < 16.0) or math.abs(lz - fl.z) < Config.FloorWindow)
                if want and not live[fi] then spawnFloor(fi) elseif not want and live[fi] then despawnFloor(fi) end
            end
            if inside then
                wait = 0
                for fi, rec in pairs(live) do
                    local fl = FLOORS[fi]
                    local e = toWorld(fl.ex, fl.ey, fl.z + 1.0)
                    local de = #(pos - e)
                    if de < 12.0 then DrawMarker(1, e.x, e.y, e.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.2, 255, 140, 60, 90, false, false, 2, false, nil, nil, false) end
                    if de < 1.4 then
                        help(Config.Locale == 'ar' and '~INPUT_CONTEXT~ المصعد' or '~INPUT_CONTEXT~ Elevator')
                        if IsControlJustPressed(0, 38) then elevator(fi) end
                    end
                    if fl.model and fl.model:find('rox_towers_f_') then
                        local sp = toWorld(Config.StairsPoint.x, Config.StairsPoint.y, fl.z + 1.0)
                        if #(pos - sp) < 1.4 then
                            help(Config.Locale == 'ar' and '~INPUT_CONTEXT~ درج الطوارئ' or '~INPUT_CONTEXT~ Emergency stairs')
                            if IsControlJustPressed(0, 38) then stairs(fi) end
                        end
                    end
                    for _, dr in ipairs(rec.doors) do
                        if dr.kind == 'sec' and #(pos - dr.pos) < 1.8 then
                            local locked = DoorSystemGetDoorState(dr.hash) ~= 0
                            help((Config.Locale == 'ar' and '~INPUT_CONTEXT~ بطاقة الدخول: ' or '~INPUT_CONTEXT~ Keycard: ') .. (locked and '~r~🔒' or '~g~🔓'))
                            if IsControlJustPressed(0, 38) then TriggerServerEvent('rox_towers:door', dr.id, not locked) end
                        end
                    end
                end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('rox_towers:doorState', function(id, locked)
    doorState[id] = locked
    local h = joaat(id)
    if IsDoorRegisteredWithSystem(h) then DoorSystemSetDoorState(h, locked and 1 or 0, false, true) end
end)
RegisterNetEvent('rox_towers:doors', function(all) for id, l in pairs(all or {}) do doorState[id] = l end end)
RegisterNetEvent('rox_towers:origin', function(o) despawnAll(); origin = vec4(o.x, o.y, o.z, o.w) end)
CreateThread(function() TriggerServerEvent('rox_towers:get') end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then despawnAll() end end)
