--[[ ROX Store | rox_police | All rights reserved. ]]
local isOpen = false
local pending, reqSeq = {}, 0
local TABLET = { home = true, mdt = true, jail = true, fine = true, boss = true }

function ServerRequest(action, data)
    reqSeq = reqSeq + 1
    local id = reqSeq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('rox_police:server:req', id, action, data or {})
    SetTimeout(10000, function()
        if pending[id] then pending[id] = nil; p:resolve({ ok = false, msg = 'Server timeout' }) end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('rox_police:client:res', function(id, res)
    local p = pending[id]
    if p then pending[id] = nil; p:resolve(res) end
end)

local function access()
    reqSeq = reqSeq + 1
    local id = reqSeq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('rox_police:server:canOpen', id)
    SetTimeout(5000, function() if pending[id] then pending[id] = nil; p:resolve({ ok = false }) end end)
    return Citizen.Await(p)
end

---------------------------------------------------------------------------
-- tablet prop + animation
---------------------------------------------------------------------------
local tabletObj
local ANIM_DICT, ANIM = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'

local function loadDict(d) RequestAnimDict(d) local t = GetGameTimer() while not HasAnimDictLoaded(d) and GetGameTimer() - t < 3000 do Wait(10) end end
local function loadModel(m) RequestModel(m) local t = GetGameTimer() while not HasModelLoaded(m) and GetGameTimer() - t < 3000 do Wait(10) end end

local function tabletAnim(on)
    if not Config.Tablet.prop then return end
    local ped = PlayerPedId()
    if on then
        if tabletObj or IsPedInAnyVehicle(ped, false) then return end
        loadDict(ANIM_DICT)
        local model = `prop_cs_tablet`
        loadModel(model)
        tabletObj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(tabletObj, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(model)
        TaskPlayAnim(ped, ANIM_DICT, ANIM, 3.0, 3.0, -1, 49, 0, false, false, false)
    else
        if tabletObj then DeleteEntity(tabletObj) tabletObj = nil end
        StopAnimTask(ped, ANIM_DICT, ANIM, 1.0)
    end
end

---------------------------------------------------------------------------
-- open / close
---------------------------------------------------------------------------
local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    tabletAnim(false)
end

local function open(panel, opts)
    opts = opts or {}
    if isOpen then
        SendNUIMessage({ action = 'open', panel = panel, opts = opts })
        return
    end
    local a = access()
    if not a.ok then
        SendNUIMessage({ action = 'toast', kind = 'error', msg = 'Police only' })
        return
    end
    if panel == 'boss' and not a.boss then
        SendNUIMessage({ action = 'toast', kind = 'error', msg = 'Management only (Captain and above)' })
        return
    end
    local init = ServerRequest('init')
    isOpen = true
    SendNUIMessage({ action = 'open', panel = panel, opts = opts, init = init, color = Config.Color })
    SetNuiFocus(true, true)
    if TABLET[panel] then tabletAnim(true) end
end
OpenPolicePanel = open

RegisterNetEvent('rox_police:client:open', function(args)
    local panel = type(args) == 'table' and args.panel or args or 'mdt'
    CreateThread(function() open(panel, type(args) == 'table' and args or {}) end)
end)

RegisterCommand(Config.Commands.mdt,  function() open('mdt') end, false)
RegisterCommand(Config.Commands.jail, function(_, a) open('jail', { id = tonumber(a[1]) }) end, false)
RegisterCommand(Config.Commands.fine, function(_, a) open('fine', { id = tonumber(a[1]) }) end, false)
RegisterCommand(Config.Commands.boss, function() open('boss') end, false)
RegisterCommand(Config.Tablet.command, function() open('home') end, false)

RegisterNetEvent('rox_police:client:notify', function(msg, kind)
    SendNUIMessage({ action = 'toast', msg = msg, kind = kind })
end)

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function nearby(maxDist)
    local me = PlayerPedId()
    local my = GetEntityCoords(me)
    local list, ids = {}, {}
    for _, pl in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pl)
        if ped ~= me then
            local d = #(GetEntityCoords(ped) - my)
            if d <= (maxDist or Config.NearbyDistance) then
                local sid = GetPlayerServerId(pl)
                list[#list + 1] = { id = sid, dist = math.floor(d * 10) / 10, mask = GetPedDrawableVariation(ped, 1) > 0, hat = GetPedPropIndex(ped, 0) >= 0, glasses = GetPedPropIndex(ped, 1) >= 0, bag = GetPedDrawableVariation(ped, 5) > 0 }
                ids[#ids + 1] = sid
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    if #ids == 0 then return {} end
    local names = ServerRequest('names', { ids = ids }) or {}
    local byId = {}
    for _, n in ipairs(names) do byId[n.id] = n end
    for _, e in ipairs(list) do
        e.name = byId[e.id] and byId[e.id].name or ('Player ' .. e.id)
        e.cid = byId[e.id] and byId[e.id].cid
    end
    return list
end

local function vehicleData(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local plate = GetVehicleNumberPlateText(veh):gsub('^%s*(.-)%s*$', '%1')
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local label = GetLabelText(name)
    return { plate = plate, model = (label ~= 'NULL' and label) or name, netId = NetworkGetEntityIsNetworked(veh) and VehToNet(veh) or nil, class = GetVehicleClass(veh) }
end

local function closestVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local c = GetEntityCoords(ped)
        veh = GetClosestVehicle(c.x, c.y, c.z, 8.0, 0, 70)
        if veh == 0 then
            -- GetClosestVehicle skips player vehicles: scan the pool
            local best, bd = 0, 8.0
            for _, v in ipairs(GetGamePool('CVehicle')) do
                local d = #(GetEntityCoords(v) - c)
                if d < bd then best, bd = v, d end
            end
            veh = best
        end
    end
    return veh ~= 0 and veh or nil
end

---------------------------------------------------------------------------
-- impound / strip side panels
---------------------------------------------------------------------------
local impoundVeh = nil

function OpenImpound(veh)
    veh = veh or closestVehicle()
    local v = vehicleData(veh)
    if not v then return SendNUIMessage({ action = 'toast', kind = 'error', msg = 'No vehicle nearby' }) end
    impoundVeh = veh
    local info = ServerRequest('vehicleInfo', { plate = v.plate })
    if info and info.denied then return SendNUIMessage({ action = 'toast', kind = 'error', msg = 'Police only' }) end
    for k, val in pairs(info or {}) do v[k] = v[k] or val end
    v.owner, v.registered, v.hold, v.stolen = info.owner, info.registered, info.hold, info.stolen
    open('impound', { vehicle = v })
end

function OpenStrip(targetId)
    open('strip', { target = targetId })
end

RegisterNetEvent('rox_police:client:impoundNearest', function() CreateThread(function() OpenImpound() end) end)
RegisterNetEvent('rox_police:client:stripNearby', function() CreateThread(function() OpenStrip() end) end)
RegisterCommand(Config.Commands.impound, function() OpenImpound() end, false)
RegisterCommand(Config.Commands.unmask, function() OpenStrip() end, false)

local function clipboard(ms)
    if not Config.Impound.animation then return end
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    Wait(ms)
    ClearPedTasks(ped)
end

-- target client: remove accessories
RegisterNetEvent('rox_police:client:strip', function(items)
    local ped = PlayerPedId()
    for _, k in ipairs(items or {}) do
        if k == 'mask' then SetPedComponentVariation(ped, 1, 0, 0, 2)
        elseif k == 'hat' then ClearPedProp(ped, 0)
        elseif k == 'glasses' then ClearPedProp(ped, 1)
        elseif k == 'bag' then SetPedComponentVariation(ped, 5, 0, 0, 2) end
    end
end)

---------------------------------------------------------------------------
-- NUI
---------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb) close(); cb('ok') end)

RegisterNUICallback('req', function(data, cb)
    local action = data.action
    if action == 'nearby' then return CreateThread(function() cb(nearby()) end) end
    if action == 'closestPlate' then return cb(vehicleData(closestVehicle()) or {}) end
    if action == 'impound' then
        return CreateThread(function()
            local d = data.data or {}
            if impoundVeh and DoesEntityExist(impoundVeh) then d.netId = NetworkGetEntityIsNetworked(impoundVeh) and VehToNet(impoundVeh) or nil end
            SetNuiFocus(false, false)
            clipboard(2500)
            local r = ServerRequest('impound', d)
            if r and r.ok and impoundVeh and DoesEntityExist(impoundVeh) then
                SetEntityAsMissionEntity(impoundVeh, true, true)
                DeleteVehicle(impoundVeh)
            end
            impoundVeh = nil
            cb(r)
            if r and r.ok then close() else SetNuiFocus(true, true) end
        end)
    end
    if action == 'strip' then
        return CreateThread(function()
            local ped = PlayerPedId()
            loadDict('mp_common')
            TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 4.0, 4.0, 1200, 49, 0, false, false, false)
            local r = ServerRequest('strip', data.data)
            cb(r)
        end)
    end
    CreateThread(function() cb(ServerRequest(action, data.data)) end)
end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then close() end end)

---------------------------------------------------------------------------
-- third eye (ox_target / qb-target)
---------------------------------------------------------------------------
CreateThread(function()
    if not Config.Impound.useTarget then return end
    Wait(1000)
    local jobs = {}
    for _, j in ipairs(Config.PoliceJobs) do jobs[j] = 0 end
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addGlobalVehicle({
            { name = 'rox_impound', icon = 'fa-solid fa-truck-pickup', label = 'Impound / Depot Vehicle', groups = jobs, distance = Config.Impound.distance,
              onSelect = function(d) OpenImpound(d.entity) end },
        })
        exports.ox_target:addGlobalPlayer({
            { name = 'rox_strip', icon = 'fa-solid fa-masks-theater', label = 'Remove Mask / Hat', groups = jobs, distance = 2.5,
              onSelect = function(d) OpenStrip(GetPlayerServerId(NetworkGetPlayerIndexFromPed(d.entity))) end },
        })
    elseif GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddGlobalVehicle({
            options = { { icon = 'fas fa-truck-pickup', label = 'Impound / Depot Vehicle', job = jobs, action = function(ent) OpenImpound(ent) end } },
            distance = Config.Impound.distance,
        })
        exports['qb-target']:AddGlobalPlayer({
            options = { { icon = 'fas fa-masks-theater', label = 'Remove Mask / Hat', job = jobs, action = function(ent) OpenStrip(GetPlayerServerId(NetworkGetPlayerIndexFromPed(ent))) end } },
            distance = 2.5,
        })
    end
end)
