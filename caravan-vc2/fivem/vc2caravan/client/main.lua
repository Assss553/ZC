local MODEL = joaat(Config.Model)
local RV = {}            -- [vehicle] = { plate, p (0 packed .. 1 set up), parts = {}, furn = {}, screen }
local Data = {}          -- [plate] = { furniture = {}, exterior = {}, canEdit }
local catalog = {}
for _, f in ipairs(Config.Furniture) do catalog[f.model] = f end
local uiOpen, uiVeh, placing = false, nil, false

---------------------------------------------------------------- helpers
local function notify(msg, kind)
    if GetResourceState('qb-core') == 'started' then exports['qb-core']:GetCoreObject().Functions.Notify(msg, kind or 'primary') return end
    if GetResourceState('es_extended') == 'started' then exports['es_extended']:getSharedObject().ShowNotification(msg) return end
    BeginTextCommandThefeedPost('STRING') AddTextComponentSubstringPlayerName(msg) EndTextCommandThefeedPostTicker(false, true)
end
RegisterNetEvent('vc2rv:notify', notify)

local function help(msg)
    BeginTextCommandDisplayHelp('STRING') AddTextComponentSubstringPlayerName(msg) EndTextCommandDisplayHelp(0, false, false, -1)
end

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp01(v) return math.max(0.0, math.min(1.0, v)) end
local function ease(t) return t * t * (3 - 2 * t) end

local function loadModel(m)
    local h = type(m) == 'number' and m or joaat(m)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(h) do if GetGameTimer() > t then return nil end Wait(10) end
    return h
end

local function spawnProp(model, veh)
    local h = loadModel(model)
    if not h then return nil end
    local c = GetEntityCoords(veh)
    local o = CreateObject(h, c.x, c.y, c.z - 5.0, false, false, false)
    SetEntityInvincible(o, true)
    SetModelAsNoLongerNeeded(h)
    return o
end

local function attach(o, veh, off, rot)
    if o and DoesEntityExist(o) then
        AttachEntityToEntity(o, veh, 0, off.x, off.y, off.z, rot.x, rot.y, rot.z, false, false, true, false, 2, true)
    end
end

local function isDeployed(veh)
    local st = Entity(veh).state.vc2rv
    return st and st.deployed, st and st.door
end

local function control(veh)
    if NetworkGetEntityOwner(veh) == PlayerId() then return true end
    NetworkRequestControlOfEntity(veh)
    local t = GetGameTimer() + 1000
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do Wait(10) NetworkRequestControlOfEntity(veh) end
    return NetworkHasControlOfEntity(veh)
end

---------------------------------------------------------------- exterior
local function applyExterior(veh, e)
    if not e or not next(e) or not control(veh) then return end
    SetVehicleModKit(veh, 0)
    local p, s = GetVehicleColours(veh)
    SetVehicleColours(veh, e.primary or p, e.secondary or s)
    local pearl, wheel = GetVehicleExtraColours(veh)
    SetVehicleExtraColours(veh, e.pearl or pearl, e.wheel or wheel)
    if e.livery and GetVehicleLiveryCount(veh) > 0 then SetVehicleLivery(veh, e.livery) end
    if e.neon then
        for i = 0, 3 do SetVehicleNeonLightEnabled(veh, i, e.neon.on) end
        SetVehicleNeonLightsColour(veh, e.neon.r, e.neon.g, e.neon.b)
    end
end

---------------------------------------------------------------- parts (slide-outs, legs, wall screen) + furniture
local function partOffsets(rv)
    local P, t = Config.Parts, rv.p
    local legT = ease(clamp01(t / 0.35))             -- 0 .. 35 %: legs go down
    local slideT = ease(clamp01((t - 0.4) / 0.6))    -- 40 .. 100 %: slide-outs push out
    return legT, slideT, P
end

local function placeParts(veh, rv)
    local legT, slideT, P = partOffsets(rv)
    attach(rv.parts.side, veh, P.slideSide.closed + (P.slideSide.open - P.slideSide.closed) * slideT, P.slideSide.rot)
    attach(rv.parts.rear, veh, P.slideRear.closed + (P.slideRear.open - P.slideRear.closed) * slideT, P.slideRear.rot)
    for i, pos in ipairs(P.jack.positions) do
        attach(rv.parts['jack' .. i], veh, vector3(pos.x, pos.y, lerp(P.jack.closedZ, P.jack.openZ, legT)), vector3(0.0, 0.0, 0.0))
    end
    SetVehicleSuspensionHeight(veh, Config.LowerBody * legT)
end

local function clearFurniture(rv)
    for _, o in pairs(rv.furn) do if DoesEntityExist(o) then DeleteEntity(o) end end
    rv.furn = {}
end

local function buildFurniture(veh, rv)
    clearFurniture(rv)
    local d = Data[rv.plate]
    if not d then return end
    for _, f in ipairs(d.furniture or {}) do
        local o = spawnProp(f.model, veh)
        if o then
            AttachEntityToEntity(o, veh, 0, f.x, f.y, f.z, 0.0, 0.0, f.h, false, false, true, false, 2, true)
            rv.furn[f.id] = o
        end
    end
end

local function addTargetScreen(veh, rv)
    local o = rv.parts.screen
    if not o then return end
    local open = function() OpenTablet(veh) end
    if GetResourceState('ox_target') == 'started' and Config.Interaction ~= 'key' then
        exports.ox_target:addLocalEntity(o, { { name = 'vc2rv_screen', icon = 'fas fa-tablet-screen-button', label = 'Caravan control', distance = 1.6, onSelect = open } })
    elseif GetResourceState('qb-target') == 'started' and Config.Interaction ~= 'key' then
        exports['qb-target']:AddTargetEntity(o, { options = { { icon = 'fas fa-tablet', label = 'Caravan control', action = open } }, distance = 1.6 })
    end
end

local function track(veh)
    if RV[veh] then return end
    local rv = { plate = trim(GetVehicleNumberPlateText(veh)), parts = {}, furn = {} }
    local dep = isDeployed(veh)
    rv.p = dep and 1.0 or 0.0
    local P = Config.Parts
    rv.parts.side = spawnProp(P.slideSide.model, veh)
    rv.parts.rear = spawnProp(P.slideRear.model, veh)
    for i = 1, #P.jack.positions do rv.parts['jack' .. i] = spawnProp(P.jack.model, veh) end
    rv.parts.screen = spawnProp(P.screen.model, veh) or spawnProp(P.screen.fallback, veh)
    attach(rv.parts.screen, veh, P.screen.offset, P.screen.rot)
    RV[veh] = rv
    placeParts(veh, rv)
    addTargetScreen(veh, rv)
    if Data[rv.plate] then buildFurniture(veh, rv) else TriggerServerEvent('vc2rv:getData', rv.plate) end
end

local function untrack(veh)
    local rv = RV[veh]
    if not rv then return end
    for _, o in pairs(rv.parts) do if o and DoesEntityExist(o) then DeleteEntity(o) end end
    clearFurniture(rv)
    RV[veh] = nil
end

RegisterNetEvent('vc2rv:data', function(plate, furniture, exterior, canEdit)
    local d = Data[plate] or {}
    d.furniture, d.exterior = furniture or {}, exterior or {}
    if canEdit ~= nil then d.canEdit = canEdit end
    Data[plate] = d
    for veh, rv in pairs(RV) do
        if rv.plate == plate and DoesEntityExist(veh) then
            buildFurniture(veh, rv)
            if NetworkGetEntityOwner(veh) == PlayerId() then applyExterior(veh, d.exterior) end
        end
    end
    if uiOpen and uiVeh and RV[uiVeh] and RV[uiVeh].plate == plate then SendNUIMessage({ action = 'data', furniture = d.furniture, exterior = d.exterior }) end
end)

-- find caravans around the player
CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if GetEntityModel(veh) == MODEL and #(GetEntityCoords(veh) - pc) < 80.0 then track(veh) end
        end
        for veh in pairs(RV) do
            if not DoesEntityExist(veh) or #(GetEntityCoords(veh) - pc) > 100.0 then untrack(veh) end
        end
        Wait(1000)
    end
end)

-- animation + door state
CreateThread(function()
    local last = GetGameTimer()
    while true do
        local now, busy = GetGameTimer(), false
        local dt = now - last
        last = now
        for veh, rv in pairs(RV) do
            if DoesEntityExist(veh) then
                local dep, door = isDeployed(veh)
                local target = dep and 1.0 or 0.0
                if rv.p ~= target then
                    busy = true
                    local step = dt / Config.DeployTime
                    rv.p = target > rv.p and math.min(target, rv.p + step) or math.max(target, rv.p - step)
                    placeParts(veh, rv)
                end
                local isOpen = GetVehicleDoorAngleRatio(veh, Config.EntryDoor) > 0.1
                if door and not isOpen then SetVehicleDoorOpen(veh, Config.EntryDoor, false, false)
                elseif not door and isOpen then SetVehicleDoorShut(veh, Config.EntryDoor, false) end
            end
        end
        Wait(busy and 0 or 200)
    end
end)

---------------------------------------------------------------- driver: Q to set up / pack up
CreateThread(function()
    while true do
        local ped, sleep = PlayerPedId(), 500
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetEntityModel(veh) == MODEL and GetPedInVehicleSeat(veh, -1) == ped then
            sleep = 0
            DisableControlAction(0, Config.DeployKey, true)
            local dep = isDeployed(veh)
            if dep then
                DisableControlAction(0, 71, true) DisableControlAction(0, 72, true)  -- no driving while set up
                SetVehicleEngineOn(veh, false, true, true)
                help('~INPUT_VEH_RADIO_WHEEL~ Pack up the caravan')
            elseif GetEntitySpeed(veh) < Config.MaxSpeed then
                help('~INPUT_VEH_RADIO_WHEEL~ Set up the caravan (legs + slide-outs)')
            end
            if IsDisabledControlJustPressed(0, Config.DeployKey) then
                if not dep and GetEntitySpeed(veh) > Config.MaxSpeed then notify('Stop the caravan first', 'error')
                else TriggerServerEvent('vc2rv:toggle', VehToNet(veh)) end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------- door (look at it with the target eye)
local function doorOpen(veh) local _, door = isDeployed(veh) return door end
local function useDoor(veh, open)
    TriggerServerEvent('vc2rv:door', VehToNet(veh), open)
end
local function goInside(veh)
    local p = GetOffsetFromEntityInWorldCoords(veh, Config.EnterOffset.x, Config.EnterOffset.y, Config.EnterOffset.z)
    SetEntityCoords(PlayerPedId(), p.x, p.y, p.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), GetEntityHeading(veh) - 90.0)
end
local function goOutside(veh)
    local p = GetOffsetFromEntityInWorldCoords(veh, Config.ExitOffset.x, Config.ExitOffset.y, Config.ExitOffset.z)
    SetEntityCoords(PlayerPedId(), p.x, p.y, p.z, false, false, false, false)
end

CreateThread(function()
    Wait(1000)
    local mode = Config.Interaction
    if mode == 'auto' then mode = GetResourceState('ox_target') == 'started' and 'ox_target' or GetResourceState('qb-target') == 'started' and 'qb-target' or 'key' end
    if mode == 'ox_target' then
        exports.ox_target:addModel(Config.Model, {
            { name = 'vc2rv_door_open', icon = 'fas fa-door-open', label = 'Open door', bones = { Config.DoorBone }, distance = 2.0,
              canInteract = function(e) return isDeployed(e) and not doorOpen(e) end, onSelect = function(d) useDoor(d.entity, true) end },
            { name = 'vc2rv_door_close', icon = 'fas fa-door-closed', label = 'Close door', bones = { Config.DoorBone }, distance = 2.0,
              canInteract = function(e) return doorOpen(e) end, onSelect = function(d) useDoor(d.entity, false) end },
            { name = 'vc2rv_enter', icon = 'fas fa-person-walking-arrow-right', label = 'Go inside', bones = { Config.DoorBone }, distance = 2.0,
              canInteract = function(e) return Config.EnterTeleport and doorOpen(e) end, onSelect = function(d) goInside(d.entity) end },
        })
    elseif mode == 'qb-target' then
        exports['qb-target']:AddTargetBone({ Config.DoorBone }, { options = {
            { icon = 'fas fa-door-open', label = 'Open / close door', action = function(e) useDoor(e, not doorOpen(e)) end, canInteract = function(e) return GetEntityModel(e) == MODEL and isDeployed(e) end },
            { icon = 'fas fa-person-walking', label = 'Go inside', action = function(e) goInside(e) end, canInteract = function(e) return GetEntityModel(e) == MODEL and Config.EnterTeleport and doorOpen(e) end },
        }, distance = 2.0 })
    end
    if mode ~= 'key' then return end
    -- key fallback: E near the door / near the wall screen
    while true do
        local sleep, pc = 500, GetEntityCoords(PlayerPedId())
        for veh, rv in pairs(RV) do
            if isDeployed(veh) then
                local bone = GetEntityBoneIndexByName(veh, Config.DoorBone)
                local dp = bone ~= -1 and GetWorldPositionOfEntityBone(veh, bone) or GetOffsetFromEntityInWorldCoords(veh, 1.25, -0.75, 1.0)
                local sp = rv.parts.screen and GetEntityCoords(rv.parts.screen)
                if sp and #(pc - sp) < 1.4 then
                    sleep = 0 help('~INPUT_CONTEXT~ Caravan control')
                    if IsControlJustReleased(0, 38) then OpenTablet(veh) end
                elseif #(pc - dp) < 1.8 then
                    sleep = 0
                    help(doorOpen(veh) and '~INPUT_CONTEXT~ Close door   ~INPUT_DETONATE~ Go inside' or '~INPUT_CONTEXT~ Open door')
                    if IsControlJustReleased(0, 38) then useDoor(veh, not doorOpen(veh)) end
                    if IsControlJustReleased(0, 47) and doorOpen(veh) and Config.EnterTeleport then goInside(veh) end
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------- tablet (wall screen)
local function catalogForUI()
    local out = {}
    for _, f in ipairs(Config.Furniture) do
        if IsModelInCdimage(joaat(f.model)) then out[#out + 1] = f end
    end
    return out
end

function OpenTablet(veh)
    local rv = RV[veh]
    if not rv or uiOpen or placing then return end
    local d = Data[rv.plate] or {}
    uiOpen, uiVeh = true, veh
    SetNuiFocus(true, true)
    local p, s = GetVehicleColours(veh)
    local pearl, wheel = GetVehicleExtraColours(veh)
    SendNUIMessage({
        action = 'open', plate = rv.plate, deployed = isDeployed(veh) and true or false, canEdit = d.canEdit ~= false,
        currency = Config.Currency, catalog = catalogForUI(), furniture = d.furniture or {}, max = Config.MaxFurniture,
        colors = Config.Colors, neon = Config.Neon, liveries = GetVehicleLiveryCount(veh),
        exterior = next(d.exterior or {}) and d.exterior or { primary = p, secondary = s, pearl = pearl, wheel = wheel },
        lights = IsVehicleInteriorLightOn and IsVehicleInteriorLightOn(veh) or false,
    })
end

local function closeTablet()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

RegisterNUICallback('close', function(_, cb) closeTablet() cb({}) end)

RegisterNUICallback('exterior', function(e, cb)
    cb({})
    if not uiVeh or not DoesEntityExist(uiVeh) then return end
    applyExterior(uiVeh, e)
    TriggerServerEvent('vc2rv:setExterior', VehToNet(uiVeh), e)
end)

RegisterNUICallback('remove', function(d, cb)
    cb({})
    if uiVeh then TriggerServerEvent('vc2rv:removeFurniture', VehToNet(uiVeh), d.id) end
end)

RegisterNUICallback('lights', function(d, cb)
    cb({})
    if uiVeh then SetVehicleInteriorlight(uiVeh, d.on == true) end
end)

RegisterNUICallback('exit', function(_, cb)
    cb({})
    local veh = uiVeh
    closeTablet()
    if veh then goOutside(veh) end
end)

---------------------------------------------------------------- furniture placement
local function camRay(ignore)
    local cam = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local rx, rz = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(rz) * math.abs(math.cos(rx)), math.cos(rz) * math.abs(math.cos(rx)), math.sin(rx))
    local to = cam + dir * 8.0
    local ray = StartShapeTestLosProbe(cam.x, cam.y, cam.z, to.x, to.y, to.z, 1 + 16, ignore, 4)
    local res, hit, pos
    repeat res, hit, pos = GetShapeTestResult(ray) Wait(0) until res ~= 1
    return hit == 1 and pos or to
end

RegisterNUICallback('place', function(d, cb)
    cb({})
    local veh, item = uiVeh, catalog[d.model]
    if not veh or not item then return end
    closeTablet()
    local h = loadModel(item.model)
    if not h then return notify('This item is not available on this server', 'error') end
    placing = true
    local ghost = CreateObject(h, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    local rot, lift = 0.0, 0.0
    CreateThread(function()
        while placing do
            Wait(0)
            local pos = camRay(ghost)
            local off = GetOffsetFromEntityGivenWorldCoords(veh, pos.x, pos.y, pos.z)
            local b = Config.InteriorBounds
            off = vector3(math.max(b.minX, math.min(b.maxX, off.x)), math.max(b.minY, math.min(b.maxY, off.y)), math.max(b.minZ, math.min(b.maxZ, off.z)) + lift)
            local w = GetOffsetFromEntityInWorldCoords(veh, off.x, off.y, off.z)
            SetEntityCoordsNoOffset(ghost, w.x, w.y, w.z, false, false, false)
            SetEntityHeading(ghost, GetEntityHeading(veh) + rot)
            for _, c in ipairs({ 14, 15, 174, 175, 172, 173, 177, 200 }) do DisableControlAction(0, c, true) end
            if IsDisabledControlPressed(0, 174) or IsDisabledControlJustPressed(0, 14) then rot = rot + 2.0 end
            if IsDisabledControlPressed(0, 175) or IsDisabledControlJustPressed(0, 15) then rot = rot - 2.0 end
            if IsDisabledControlPressed(0, 172) then lift = math.min(1.5, lift + 0.005) end
            if IsDisabledControlPressed(0, 173) then lift = math.max(-0.3, lift - 0.005) end
            help(('Placing: %s (%s%d)~n~~INPUT_CELLPHONE_LEFT~ ~INPUT_CELLPHONE_RIGHT~ rotate   ~INPUT_CELLPHONE_UP~ ~INPUT_CELLPHONE_DOWN~ height~n~~INPUT_CONTEXT~ place   ~INPUT_FRONTEND_RRIGHT~ cancel'):format(item.label, Config.Currency, item.price or 0))
            if IsControlJustReleased(0, 38) then
                placing = false
                TriggerServerEvent('vc2rv:addFurniture', VehToNet(veh), item.model, { x = off.x, y = off.y, z = off.z }, rot)
            elseif IsDisabledControlJustReleased(0, 177) or IsDisabledControlJustReleased(0, 200) then
                placing = false
            end
        end
        DeleteEntity(ghost)
        SetModelAsNoLongerNeeded(h)
    end)
end)

---------------------------------------------------------------- names + cleanup
CreateThread(function()
    AddTextEntry('VC2CARAVAN', 'VC2 Caravan')
    AddTextEntry('VC2', 'VC2')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiOpen then SetNuiFocus(false, false) end
    for veh in pairs(RV) do untrack(veh) end
end)
