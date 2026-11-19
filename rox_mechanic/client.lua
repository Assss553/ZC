-- ROX Store | All rights reserved
local open, cam, veh = false, nil, 0

CreateThread(function()
    for _, c in ipairs(Config.Locations) do
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, Config.Blip.sprite); SetBlipColour(b, Config.Blip.color); SetBlipScale(b, 0.75); SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.Blip.label); EndTextCommandSetBlipName(b)
    end
end)

local function stats()
    local m = GetEntityModel(veh)
    local s = GetVehicleModelEstimatedMaxSpeed(m) * (1 + (GetVehicleMod(veh, 11) + 1) * 0.04)
    local a = GetVehicleModelAcceleration(m) * (1 + (GetVehicleMod(veh, 13) + 1) * 0.06 + (IsToggleModOn(veh, 18) and 0.1 or 0))
    local b = GetVehicleModelMaxBraking(m) * (1 + (GetVehicleMod(veh, 12) + 1) * 0.08)
    local t = GetVehicleModelMaxTraction(m) * (1 + (GetVehicleMod(veh, 15) + 1) * 0.04)
    local arm = (GetVehicleMod(veh, 16) + 1) / 5
    local r = {
        speed = math.min(10, s / 9.0), accel = math.min(10, a * 25), asphalt = math.min(10, t * 3.2), offroad = math.min(10, t * 2.2 * (GetVehicleClass(veh) == 9 and 1.4 or 1)),
        strength = math.min(10, 3 + arm * 7), braking = math.min(10, b * 8),
    }
    r.rating = (r.speed + r.accel + r.asphalt + r.strength) / 4
    return r
end

local function parts()
    local list = {}
    for i, p in ipairs(Config.Parts) do
        local e = { label = p.label, desc = p.desc }
        if p.repair then
            e.repair = true; e.price = Config.RepairPrice; e.done = GetVehicleEngineHealth(veh) >= 999 and GetVehicleBodyHealth(veh) >= 999
        else
            local max = p.toggle and 1 or GetNumVehicleMods(veh, p.mod)
            local cur = p.toggle and (IsToggleModOn(veh, p.mod) and 0 or -1) or GetVehicleMod(veh, p.mod)
            e.level = cur + 1; e.max = math.min(max, #p.prices); e.locked = max == 0
            e.price = p.prices[cur + 2]
        end
        list[i] = e
    end
    return list
end

local function payload(extra)
    local d = { name = Config.Name, make = GetLabelText(GetMakeNameFromVehicleModel(GetEntityModel(veh))),
                model = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))), parts = parts(), stats = stats() }
    if extra then for k, v in pairs(extra) do d[k] = v end end
    return d
end

local function openShop()
    local ped = PlayerPedId()
    veh = GetVehiclePedIsIn(ped, false)
    if open or veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    open = true
    SetVehicleModKit(veh, 0); FreezeEntityPosition(veh, true)
    local p = GetOffsetFromEntityInWorldCoords(veh, 2.4, 3.6, 1.2)
    local t = GetOffsetFromEntityInWorldCoords(veh, 0.0, 1.2, 0.3)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, 0.0, 0.0, 0.0, 48.0, false, 0)
    PointCamAtCoord(cam, t.x, t.y, t.z); SetCamActive(cam, true); RenderScriptCams(true, true, 700, true, false)
    SetVehicleDoorOpen(veh, 4, false, false)
    SetNuiFocus(true, true)
    SendNUIMessage(payload({ action = 'open', wallet = lib.callback.await('rox_mechanic:wallet', false) }))
end

local function closeShop()
    if not open then return end
    open = false; SetNuiFocus(false, false)
    if DoesEntityExist(veh) then SetVehicleDoorShut(veh, 4, false); FreezeEntityPosition(veh, false) end
    RenderScriptCams(false, true, 600, true, false); if cam then DestroyCam(cam, false); cam = nil end
end

RegisterNUICallback('buy', function(d, cb)
    local i = tonumber(d.part) or 0
    local p = Config.Parts[i]; if not p then return cb({ ok = false }) end
    local cur = p.repair and 0 or (p.toggle and (IsToggleModOn(veh, p.mod) and 0 or -1) or GetVehicleMod(veh, p.mod))
    local ok, err, wallet = lib.callback.await('rox_mechanic:buy', false, i, cur)
    if ok then
        if p.repair then SetVehicleFixed(veh); SetVehicleDeformationFixed(veh); SetVehicleEngineHealth(veh, 1000.0)
        elseif p.toggle then ToggleVehicleMod(veh, p.mod, true)
        else SetVehicleMod(veh, p.mod, cur + 1, false) end
        PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true)
        if GetResourceState('qbx_core') == 'started' then
            local props = lib.getVehicleProperties(veh)
            TriggerServerEvent('rox_mechanic:save', NetworkGetNetworkIdFromEntity(veh), props)
        end
    end
    cb(payload({ ok = ok, err = err, wallet = wallet }))
end)
RegisterNUICallback('nav', function(_, cb) PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true); cb('ok') end)
RegisterNUICallback('close', function(_, cb) cb('ok'); closeShop() end)

CreateThread(function()
    local shown = false
    while true do
        local sleep, nearby = 700, false
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local p = GetEntityCoords(ped)
            for _, c in ipairs(Config.Locations) do local d = #(p - c); if d < 20 then sleep = 0 end; if d < 5.0 then nearby = true end end
        end
        if nearby and not open then
            if not shown and GetResourceState('rox_interact') == 'started' then exports.rox_interact:Prompt('Auto Care', 'E'); shown = true end
            if IsControlJustReleased(0, 38) then if shown then exports.rox_interact:Prompt(nil) end; shown = false; openShop() end
        elseif shown then shown = false; exports.rox_interact:Prompt(nil) end
        Wait(sleep)
    end
end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then closeShop() end end)
