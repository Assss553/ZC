-- ROX Store | rox_phone | All rights reserved.
local open, layout, prop = false, 0, nil

local function clearProp()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop = nil
end

local function holdPhone()
    local ped, L = cache.ped, Config.Layouts[layout]
    clearProp()
    lib.requestModel(L.prop); lib.requestAnimDict(L.dict)
    local c = GetEntityCoords(ped)
    prop = CreateObject(L.prop, c.x, c.y, c.z + 0.2, true, true, false)
    SetEntityCollision(prop, false, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, L.bone), L.pos.x, L.pos.y, L.pos.z, L.rot.x, L.rot.y, L.rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(L.prop)
    TaskPlayAnim(ped, L.dict, L.anim, 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function playerData()
    local p = exports.qbx_core:GetPlayerData() or {}
    local ci, job, money = p.charinfo or {}, p.job or {}, p.money or {}
    return { src = GetPlayerServerId(PlayerId()), name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')), number = ci.phone or '', cid = p.citizenid,
        job = job.name, jobLabel = job.label, grade = job.grade and job.grade.name, duty = job.onduty, cash = money.cash or 0, bank = money.bank or 0 }
end

local function setOpen(state)
    if state == open then return end
    if state and Config.RequireItem and exports.ox_inventory:Search('count', Config.RequireItem) < 1 then
        return lib.notify({ type = 'error', description = 'You do not have a phone' })
    end
    open = state
    SetNuiFocus(state, state); SetNuiFocusKeepInput(state)
    SendNUIMessage({ action = 'open', open = state, me = state and playerData() or nil })
    if state then
        holdPhone()
        CreateThread(function()
            while open do  -- keep walking, block shooting / camera spin
                DisableControlAction(0, 1, true); DisableControlAction(0, 2, true); DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)
                DisableControlAction(0, 200, true); DisableControlAction(0, 199, true)
                if not IsEntityPlayingAnim(cache.ped, Config.Layouts[layout].dict, Config.Layouts[layout].anim, 3) then holdPhone() end
                Wait(0)
            end
        end)
    else
        clearProp(); StopAnimTask(cache.ped, Config.Layouts[layout].dict, Config.Layouts[layout].anim, 2.0)
    end
end

RegisterCommand(Config.Command, function() setOpen(not open) end, false)
RegisterKeyMapping(Config.Command, 'Open ROX Phone', 'keyboard', Config.Key)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then clearProp() end end)

RegisterNUICallback('close', function(_, cb) setOpen(false) cb(1) end)
RegisterNUICallback('fold', function(d, cb)   -- d.mode: 0 phone, 1 half, 2 tablet
    local m = tonumber(d.mode) or (d.open and 2 or 0)
    if m ~= layout then StopAnimTask(cache.ped, Config.Layouts[layout].dict, Config.Layouts[layout].anim, 2.0); layout = m; if open then holdPhone() end end
    cb(1)
end)

-- ---------------- garage ----------------
local function label(model)
    local h = tonumber(model) or joaat(model)
    local n = GetLabelText(GetDisplayNameFromVehicleModel(h))
    if n == 'NULL' then n = GetDisplayNameFromVehicleModel(h) end
    local make = GetLabelText(GetMakeNameFromVehicleModel(h))
    return n, (make ~= 'NULL' and make or ''), GetVehicleClassFromName(h)
end
local CLASSES = { [0] = 'Compact', 'Sedan', 'SUV', 'Coupe', 'Muscle', 'Sports Classic', 'Sports', 'Super', 'Motorcycle', 'Off-road', 'Industrial', 'Utility', 'Van', 'Cycle', 'Boat', 'Helicopter', 'Plane', 'Service', 'Emergency', 'Military', 'Commercial', 'Train' }
local function findVeh(plate)
    plate = plate:gsub('%s+', '')
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if GetVehicleNumberPlateText(v):gsub('%s+', '') == plate then return v end
    end
end
RegisterNUICallback('garage', function(_, cb)
    local list = lib.callback.await('rox_phone:garage', false) or {}
    for _, v in ipairs(list) do
        v.name, v.make, v.class = label(v.model); v.class = CLASSES[v.class] or ''
        local e = findVeh(v.plate)
        if e then v.near = true; v.fuel = math.floor(GetVehicleFuelLevel(e)); v.engine = math.floor(GetVehicleEngineHealth(e) / 10); v.body = math.floor(GetVehicleBodyHealth(e) / 10); v.locked = GetVehicleDoorLockStatus(e) >= 2 end
    end
    cb(list)
end)
RegisterNUICallback('garageAction', function(d, cb)
    local e = d.plate and findVeh(d.plate)
    if d.action == 'track' then
        if not e then cb({ ok = false, msg = 'Vehicle not found nearby' }) return end
        local c = GetEntityCoords(e); SetNewWaypoint(c.x, c.y); cb({ ok = true, msg = 'GPS set to your vehicle' }) return
    elseif d.action == 'lock' then
        if not e or #(GetEntityCoords(e) - GetEntityCoords(cache.ped)) > 40.0 then cb({ ok = false, msg = 'Too far from the vehicle' }) return end
        local locked = GetVehicleDoorLockStatus(e) >= 2
        TriggerServerEvent('rox_phone:server:lock', NetworkGetNetworkIdFromEntity(e), not locked)
        cb({ ok = true, msg = locked and 'Vehicle unlocked' or 'Vehicle locked', locked = not locked }) return
    elseif d.action == 'impound' then
        cb(lib.callback.await('rox_phone:impound', false, d.plate)) return
    end
    cb({ ok = false })
end)

-- ---------------- bank ----------------
RegisterNUICallback('bank', function(d, cb) cb(lib.callback.await('rox_phone:transfer', false, d) or { ok = false }) end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function() if open then SendNUIMessage({ action = 'me', me = playerData() }) end end)

-- ================= data bridge =================
RegisterNUICallback('rpc', function(d, cb) cb(lib.callback.await('rox_phone:rpc', false, d.name, d.args) or false) end)
RegisterNetEvent('rox_phone:push', function(t, d)
    if t == 'call:accepted' then exports['pma-voice']:setCallChannel(d.id) end
    if t == 'call:ended' then exports['pma-voice']:setCallChannel(0) end
    if t == 'call:incoming' and not open then lib.notify({ title = 'Incoming call', description = d.name or d.from, type = 'inform' }) end
    if t == 'msg' and not open then lib.notify({ title = d.name or d.sender, description = d.kind == 'text' and d.body or 'New message', type = 'inform' }) end
    if t == 'alert' then lib.notify({ title = d.job:upper() .. ' · ' .. (d.reason or ''), description = d.street or '', type = 'warning' }) end
    SendNUIMessage({ action = 'push', type = t, data = d })
end)
RegisterNUICallback('waypoint', function(d, cb) if d.x and d.y then SetNewWaypoint(d.x + 0.0, d.y + 0.0) end cb(1) end)
RegisterNUICallback('places', function(_, cb) cb(Config.Places) end)
RegisterNUICallback('gifts', function(_, cb) cb(Config.Gifts) end)
RegisterNUICallback('whereami', function(_, cb)
    local c = GetEntityCoords(cache.ped)
    cb({ x = c.x, y = c.y, street = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z)) .. ', ' .. GetLabelText(GetNameOfZone(c.x, c.y, c.z)) })
end)
RegisterNUICallback('photo', function(_, cb)
    if Config.PhotoUpload == '' or GetResourceState('screenshot-basic') ~= 'started' then cb({ ok = false, msg = 'Camera needs screenshot-basic + Config.PhotoUpload' }) return end
    SendNUIMessage({ action = 'shoot', on = true }); Wait(150)
    exports['screenshot-basic']:requestScreenshotUpload(Config.PhotoUpload, Config.PhotoField, function(data)
        SendNUIMessage({ action = 'shoot', on = false })
        local ok, r = pcall(json.decode, data or '')
        local url = ok and r and ((r.attachments and r.attachments[1] and r.attachments[1].url) or r.url or (r.data and r.data.url))
        if not url then cb({ ok = false, msg = 'Upload failed' }) return end
        lib.callback.await('rox_phone:rpc', false, 'savePhoto', { url = url })
        cb({ ok = true, url = url })
    end)
end)
