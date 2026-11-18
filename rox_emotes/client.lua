-- ROX Store | rox_emotes | All rights reserved.
local open, current, props, pending = false, nil, {}, nil
local BY = {}
for cat, list in pairs(Emotes) do for _, e in ipairs(list) do e.cat = cat; BY[e[1]] = e end end

local function notify(t, typ) TriggerEvent('ox_lib:notify', { description = t, type = typ or 'inform' }) end
local function loadDict(d) RequestAnimDict(d); local t = GetGameTimer() + 3000; while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end return HasAnimDictLoaded(d) end
local function clearProps() for _, p in ipairs(props) do if DoesEntityExist(p) then DeleteEntity(p) end end props = {} end
local function stop() local ped = PlayerPedId(); clearProps(); if current then StopAnimTask(ped, current[3], current[4], 2.0); ClearPedTasks(ped) end current = nil end
local function play(e, animOverride)
    local ped = PlayerPedId(); if IsPedInAnyVehicle(ped, false) and not e.move then return notify('You cannot do this in a vehicle', 'error') end
    stop(); if not loadDict(e[3]) then return notify('Animation not found', 'error') end
    local flag = (e.loop and 1 or 0) + (e.move and 48 or 0)
    TaskPlayAnim(ped, e[3], animOverride or e[4], 3.0, 3.0, -1, flag, 0, false, false, false); current = e
    if e.prop then local p = e.prop; local h = joaat(p[1]); RequestModel(h); local t = GetGameTimer() + 3000; while not HasModelLoaded(h) and GetGameTimer() < t do Wait(10) end
        local c = GetEntityCoords(ped); local o = CreateObject(h, c.x, c.y, c.z + .2, true, true, true)
        AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, p[2]), p[3], p[4], p[5], p[6], p[7], p[8], true, true, false, true, 1, true); SetModelAsNoLongerNeeded(h); props[#props + 1] = o end
end
local function closestPlayer()
    local me, best, bd = GetEntityCoords(PlayerPedId()), nil, Config.SharedDistance
    for _, id in ipairs(GetActivePlayers()) do if id ~= PlayerId() then local d = #(GetEntityCoords(GetPlayerPed(id)) - me); if d < bd then best, bd = id, d end end end
    return best and GetPlayerServerId(best)
end
local function run(name)
    local e = BY[name]; if not e then return notify('Unknown emote: ' .. tostring(name), 'error') end
    if e.cat == 'shared' then local t = closestPlayer(); if not t then return notify('No one close to you', 'error') end
        TriggerServerEvent('rox_emotes:request', t, name); return notify('Request sent') end
    play(e)
end
exports('Play', run); exports('Stop', stop)

local function setWalk(w) local ped = PlayerPedId()
    if not w then ResetPedMovementClipset(ped, 0.5); SetResourceKvp('rox_walk', ''); return end
    RequestAnimSet(w); local t = GetGameTimer() + 3000; while not HasAnimSetLoaded(w) and GetGameTimer() < t do Wait(10) end
    SetPedMovementClipset(ped, w, 0.4); SetResourceKvp('rox_walk', w) end
local function setFace(f) local ped = PlayerPedId(); if not f then ClearFacialIdleAnimOverride(ped) else SetFacialIdleAnimOverride(ped, f, 0) end SetResourceKvp('rox_face', f or '') end
CreateThread(function() Wait(4000); local w = GetResourceKvpString('rox_walk'); if w and w ~= '' then setWalk(w) end; local f = GetResourceKvpString('rox_face'); if f and f ~= '' then setFace(f) end end)

local function toggle(s) open = s; SetNuiFocus(s, s); SetNuiFocusKeepInput(false)
    if s then SendNUIMessage({ action = 'open', emotes = Emotes, walks = Walks, faces = Expressions, color = Config.Color,
        fav = json.decode(GetResourceKvpString('rox_emote_fav') or '[]'), binds = json.decode(GetResourceKvpString('rox_emote_binds') or '{}'),
        walk = GetResourceKvpString('rox_walk') or '', face = GetResourceKvpString('rox_face') or '' })
    else SendNUIMessage({ action = 'close' }) end end
RegisterCommand(Config.Command, function() toggle(not open) end, false)
RegisterKeyMapping(Config.Command, 'Open emote menu', 'keyboard', Config.Key)
RegisterCommand('e', function(_, a) if a[1] == 'c' or a[1] == 'cancel' then return stop() end run(a[1]) end, false)
RegisterCommand('emotecancel', stop, false); RegisterKeyMapping('emotecancel', 'Cancel emote', 'keyboard', Config.CancelKey)
for i = 1, 6 do RegisterCommand('emotebind' .. i, function() local b = json.decode(GetResourceKvpString('rox_emote_binds') or '{}')[tostring(i)]; if b then run(b) end end, false)
    RegisterKeyMapping('emotebind' .. i, 'Emote slot ' .. i, 'keyboard', '') end

RegisterNUICallback('close', function(_, cb) toggle(false) cb(1) end)
RegisterNUICallback('play', function(d, cb) cb(1); if d.close then toggle(false) end run(d.name) end)
RegisterNUICallback('stop', function(_, cb) stop() cb(1) end)
RegisterNUICallback('walk', function(d, cb) setWalk(d.walk ~= '' and d.walk or nil) cb(1) end)
RegisterNUICallback('face', function(d, cb) setFace(d.face ~= '' and d.face or nil) cb(1) end)
RegisterNUICallback('save', function(d, cb) SetResourceKvp('rox_emote_fav', json.encode(d.fav or {})); SetResourceKvp('rox_emote_binds', json.encode(d.binds or {})) cb(1) end)

RegisterNetEvent('rox_emotes:requested', function(from, name, who)
    pending = { from = from, name = name, t = GetGameTimer() + 10000 }
    notify(('%s wants to %s. Press Y to accept'):format(who, (BY[name] or {})[2] or name))
end)
RegisterCommand('emoteaccept', function() if pending and GetGameTimer() < pending.t then TriggerServerEvent('rox_emotes:accept', pending.from, pending.name) end pending = nil end, false)
RegisterKeyMapping('emoteaccept', 'Accept shared emote', 'keyboard', 'Y')
RegisterNetEvent('rox_emotes:playShared', function(other, name, first)
    local e = BY[name]; if not e then return end
    local ped, op = PlayerPedId(), GetPlayerPed(GetPlayerFromServerId(other))
    if op ~= 0 and not first then local c = GetOffsetFromEntityInWorldCoords(op, 0.0, 1.0, 0.0); SetEntityCoords(ped, c.x, c.y, c.z - 1.0); SetEntityHeading(ped, GetEntityHeading(op) - 180.0) end
    play(e, first and e[4] or e.other)
end)
CreateThread(function() while true do if current and IsControlJustPressed(0, 73) then stop() end Wait(current and 0 or 500) end end)
