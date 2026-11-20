--[[ ROX NYC  ·  © ROX Store – All rights reserved. ]]
local origin, spawned, ents, fx, blip = nil, false, {}, {}, nil

local function W(x, y, z)   -- local -> world
    local r = math.rad(origin.w); local c, s = math.cos(r), math.sin(r)
    return vector3(origin.x + x * c - y * s, origin.y + x * s + y * c, origin.z + (z or 0.0))
end
local function pick(list)
    for _, n in ipairs(list or {}) do local h = joaat(n); if IsModelInCdimage(h) and IsModelValid(h) then return h end end
end
local function load(h)
    RequestModel(h); local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) and GetGameTimer() < t do Wait(0) end
    return HasModelLoaded(h)
end
local function prop(list, x, y, z, head, onFloor)
    local h = type(list) == 'number' and list or pick(list); if not h or not load(h) then return end
    local mn = GetModelDimensions(h)
    local p = W(x, y, (z or 0.0))
    local e = CreateObjectNoOffset(h, p.x, p.y, p.z - mn.z, false, false, false)
    SetEntityHeading(e, (origin.w + (head or 0.0)) % 360.0); FreezeEntityPosition(e, true); SetModelAsNoLongerNeeded(h)
    ents[#ents + 1] = e
    return e
end

local function clear()
    for _, e in ipairs(ents) do if DoesEntityExist(e) then DeleteEntity(e) end end
    for _, f in ipairs(fx) do StopParticleFxLooped(f, false) end
    ents, fx, spawned = {}, {}, false
end

local function spawn()
    spawned = true
    local P = Config.Props
    for _, name in ipairs(NycPieces) do           -- the generated map pieces (ground + 20 buildings)
        local h = joaat(name)
        if IsModelInCdimage(h) and load(h) then
            local e = CreateObjectNoOffset(h, origin.x, origin.y, origin.z, false, false, false)
            SetEntityHeading(e, origin.w); FreezeEntityPosition(e, true); SetEntityLodDist(e, 1500); SetModelAsNoLongerNeeded(h)
            ents[#ents + 1] = e
        end
        Wait(0)
    end
    local kerb = 0.16
    for _, p in ipairs(NycPoints.lamps) do prop(P.lamp, p[1], p[2], kerb, p[3]) end
    for i, p in ipairs(NycPoints.trees) do prop(P.tree, p[1], p[2], kerb, (i * 47) % 360) end
    for i, p in ipairs(NycPoints.corners) do   -- traffic lights + hydrant + news boxes on every corner
        local sx, sy = p[1] > 0 and 1 or -1, p[2] > 0 and 1 or -1
        prop(P.traffic, p[1], p[2], kerb, (sy > 0) and 180.0 or 0.0)
        prop(P.traffic, p[1] + sx * 0.4, p[2] + sy * 0.4, kerb, (sx > 0) and 90.0 or 270.0)
        prop(P.hydrant, p[1] + sx * 3.5, p[2] + sy * 0.3, kerb, 0.0)
        prop(P.news, p[1] + sx * 0.6, p[2] + sy * 3.0, kerb, sx > 0 and 270.0 or 90.0)
        prop(P.news, p[1] + sx * 0.6, p[2] + sy * 3.7, kerb, sx > 0 and 270.0 or 90.0)
        prop(P.bin, p[1] + sx * 1.6, p[2] + sy * 1.6, kerb, 0.0)
        prop(P.bollard, p[1] - sx * 0.5, p[2] + sy * 1.4, kerb, 0.0); prop(P.bollard, p[1] + sx * 1.4, p[2] - sy * 0.5, kerb, 0.0)
        prop(P.sign, p[1] + sx * 0.9, p[2] + sy * 0.9, kerb, 45.0 + 90.0 * i)
    end
    -- benches, phone, post box, hot dog stand, bus stop, dumpsters, cones
    prop(P.bench, -11.2, 30.0, 0.16, 270.0); prop(P.bench, 11.2, -36.0, 0.16, 90.0); prop(P.bench, 40.0, 9.2, 0.16, 180.0); prop(P.bench, -44.0, -9.2, 0.16, 0.0)
    prop(P.phone, -11.4, -24.0, 0.16, 270.0); prop(P.post, 11.4, 22.0, 0.16, 90.0)
    prop(P.hotdog, 18.0, -10.0, 0.16, 0.0); prop(P.busstop, -11.6, 52.0, 0.16, 270.0)
    prop(P.dumpster, -60.0, 10.0, 0.16, 180.0); prop(P.dumpster, 62.0, -10.2, 0.16, 0.0)
    for k = 0, 3 do prop(P.cone, 4.0 + k * 1.2, -40.0, 0.0, 0.0) end
    -- restaurant terraces: table, 4 chairs, parasol (+ a heater on every second one)
    for i, p in ipairs(NycPoints.dining or {}) do
        prop(P.rtable, p[1], p[2], kerb, 0.0)
        for k = 0, 3 do local a = math.rad(k * 90.0); prop(P.rchair, p[1] + math.sin(a) * 0.75, p[2] + math.cos(a) * 0.75, kerb, (k * 90.0 + 180.0) % 360.0) end
        prop(P.parasol, p[1], p[2], kerb, 0.0)
        if i % 2 == 0 then prop(P.heater, p[1] + 1.6, p[2], kerb, 0.0) end
    end
    -- parked cars
    if Config.ParkedCars then
        math.randomseed(7)
        for _, p in ipairs(NycPoints.parking) do
            if math.random() < Config.CarChance then
                local m = joaat(Config.CarModels[math.random(#Config.CarModels)])
                if IsModelInCdimage(m) and load(m) then
                    local w = W(p[1], p[2], 0.5)
                    local v = CreateVehicle(m, w.x, w.y, w.z, (origin.w + p[3]) % 360.0, false, false)
                    SetVehicleOnGroundProperly(v); FreezeEntityPosition(v, true); SetVehicleDoorsLocked(v, 2); SetEntityInvincible(v, true)
                    SetVehicleColours(v, math.random(0, 120), math.random(0, 120)); SetModelAsNoLongerNeeded(m)
                    ents[#ents + 1] = v
                end
            end
        end
    end
    -- steam out of the manholes
    if Config.Steam then
        RequestNamedPtfxAsset('core'); local t = GetGameTimer() + 3000
        while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < t do Wait(0) end
        for _, p in ipairs(NycPoints.steam) do
            local w = W(p[1], p[2], 0.05)
            UseParticleFxAssetNextCall('core')
            fx[#fx + 1] = StartParticleFxLoopedAtCoord('ent_amb_steam_vent_open_lgt', w.x, w.y, w.z, 0.0, 0.0, 0.0, 1.6, false, false, false, false)
        end
    end
end

RegisterNetEvent('rox_nyc:origin', function(o)
    origin = o; clear()
    if blip then RemoveBlip(blip) end
    blip = AddBlipForCoord(o.x, o.y, o.z); SetBlipSprite(blip, Config.Blip.sprite); SetBlipColour(blip, Config.Blip.color); SetBlipScale(blip, Config.Blip.scale); SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(Config.Blip.label); EndTextCommandSetBlipName(blip)
end)
CreateThread(function() Wait(1500) TriggerServerEvent('rox_nyc:hello') end)
CreateThread(function()
    while true do
        Wait(1500)
        if origin then
            local near = #(GetEntityCoords(PlayerPedId()) - origin.xyz) < Config.SpawnDistance
            if near and not spawned then spawn() elseif not near and spawned then clear() end
        end
    end
end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then clear() end end)
