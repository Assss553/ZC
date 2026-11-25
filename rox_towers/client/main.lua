--[[ ROX Towers  ·  © ROX Store – All rights reserved. ]]
local origin = Config.Origin
local spawned, ents = false, {}

local function toWorld(x, y, z)
    local h = math.rad(origin.w)
    local c, s = math.cos(h), math.sin(h)
    return vector3(origin.x + x * c - y * s, origin.y + x * s + y * c, origin.z + z)
end

local function loadModel(list)
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

local function place(hash, pos, heading, snap)
    local o = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(o, heading)
    if snap then PlaceObjectOnGroundProperly(o) end
    FreezeEntityPosition(o, true)
    SetModelAsNoLongerNeeded(hash)
    ents[#ents + 1] = o
    return o
end

local function spawn()
    for _, piece in ipairs({ 'rox_towers_base', 'rox_towers_twin' }) do
        local h = loadModel({ piece })
        if h then place(h, toWorld(0, 0, 0), origin.w, false) end
    end
    for _, fl in ipairs(Config.Floors) do
        local named = {}
        for _, f in ipairs(Config.Furniture[fl.key] or {}) do
            local hash = loadModel(f.m)
            if hash then
                local z = fl.z + (f.z or 0.0)
                if f.on and named[f.on] then
                    local _, mx = GetModelDimensions(GetEntityModel(named[f.on]))
                    z = fl.z + mx.z
                end
                local o = place(hash, toWorld(f.x, f.y, z), origin.w + f.h + Config.PropFront - 180.0, false)
                if f.name then named[f.name] = o end
            end
        end
    end
    spawned = true
end

local function despawn()
    for _, e in ipairs(ents) do if DoesEntityExist(e) then DeleteObject(e) end end
    ents, spawned = {}, false
end

local function elevPoint(fl)
    local p = fl.elev == 'sky' and Config.SkyElevator or Config.Elevator
    return toWorld(p.x, p.y, fl.z + 1.0)
end

local function openMenu(current)
    local opts = {}
    for i, fl in ipairs(Config.Floors) do
        if i ~= current then opts[#opts + 1] = { i = i, label = (Config.Locale == 'ar' and fl.labelAr or fl.label) } end
    end
    local sel = 1
    while true do
        Wait(0)
        local txt = '~y~ROX Elevator~s~\n'
        for k, o in ipairs(opts) do txt = txt .. (k == sel and '~g~> ' or '   ') .. o.label .. '~s~\n' end
        txt = txt .. '~c~↑ ↓  ENTER  BACKSPACE'
        BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(txt); EndTextCommandDisplayHelp(0, false, false, -1)
        if IsControlJustPressed(0, 172) then sel = sel > 1 and sel - 1 or #opts end
        if IsControlJustPressed(0, 173) then sel = sel < #opts and sel + 1 or 1 end
        if IsControlJustPressed(0, 177) then return end
        if IsControlJustPressed(0, 191) then
            local fl = Config.Floors[opts[sel].i]
            DoScreenFadeOut(400); while not IsScreenFadedOut() do Wait(0) end
            local p = elevPoint(fl)
            SetEntityCoords(PlayerPedId(), p.x, p.y, p.z, false, false, false, false)
            SetEntityHeading(PlayerPedId(), origin.w + 180.0)
            Wait(600); DoScreenFadeIn(500)
            return
        end
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local d = #(pos - vector3(origin.x, origin.y, origin.z))
        if d < Config.SpawnDistance and not spawned then spawn()
        elseif d > Config.SpawnDistance + 50.0 and spawned then despawn() end
        local wait = 1000
        if spawned and d < 160.0 then
            wait = 0
            local near
            for i, fl in ipairs(Config.Floors) do
                local p = elevPoint(fl)
                if #(pos - p) < 1.6 then near = i; break end
                if #(pos - p) < 15.0 then DrawMarker(1, p.x, p.y, p.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.25, 255, 255, 255, 90, false, false, 2, false, nil, nil, false) end
            end
            if near then
                BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(Config.Locale == 'ar' and '~INPUT_CONTEXT~ المصعد' or '~INPUT_CONTEXT~ Elevator'); EndTextCommandDisplayHelp(0, false, true, -1)
                if IsControlJustPressed(0, 38) then openMenu(near) end
            end
        end
        Wait(wait)
    end
end)

RegisterNetEvent('rox_towers:origin', function(o)
    despawn(); origin = vec4(o.x, o.y, o.z, o.w)
end)
CreateThread(function() TriggerServerEvent('rox_towers:get') end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then despawn() end end)
