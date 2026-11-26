--[[ ROX SWAT TEAM HQ  ·  © ROX Store – All rights reserved. ]]
local function loadOrigin()
    local s = GetResourceKvpString('origin')
    if s then local t = json.decode(s); return vec4(t.x, t.y, t.z, t.w) end
    return Config.Origin
end
local origin = loadOrigin()
local state = { pillars = 0, doors = 0, lift = 0, t = { pillars = 0, doors = 0, lift = 0 } }   -- 0 = down / closed, 1 = up / open
local doors, busy, lastUse = {}, false, 0

local function now() return GetGameTimer() end
local function send(target) TriggerClientEvent('rox_swat:state', target or -1, state, now()) end
local function set(k, v) state[k] = v; state.t[k] = now(); send() end

local function allowed(src)
    if IsPlayerAceAllowed(src, Config.AccessAce) then return true end
    if GetResourceState('qb-core') == 'started' then
        local ok, QB = pcall(function() return exports['qb-core']:GetCoreObject() end)
        local p = ok and QB and QB.Functions.GetPlayer(src)
        if p and p.PlayerData.job and Config.Jobs[p.PlayerData.job.name] then return true end
    end
    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        local p = ok and ESX and ESX.GetPlayerFromId(src)
        if p and p.job and Config.Jobs[p.job.name] then return true end
    end
    return false
end
local function deny(src) TriggerClientEvent('rox_swat:msg', src, 'denied') end

-- open the hatch and bring the lift up (call from the street or from the garage)
local function openAndRaise()
    if state.pillars == 0 then set('pillars', 1); Wait(Config.PillarTime * 1000) end
    if state.doors == 0 then set('doors', 1); Wait(Config.DoorTime * 1000) end
    if state.lift == 0 then set('lift', 1); Wait(Config.LiftTime * 1000) end
end
local function lowerAndClose()
    if state.lift == 1 then set('lift', 0); Wait(Config.LiftTime * 1000) end
    if state.doors == 1 then set('doors', 0); Wait(Config.DoorTime * 1000) end
    Wait(2000)
    if state.pillars == 1 then set('pillars', 0) end
end

RegisterNetEvent('rox_swat:call', function(action)
    local src = source
    if not allowed(src) then return deny(src) end
    if busy then return end
    busy = true; lastUse = now()
    CreateThread(function()
        if action == 'up' then openAndRaise()                 -- street: open + lift up / garage: lift brings you up
        elseif action == 'down' then lowerAndClose() end      -- on the lift at the top: go down and close
        busy = false; lastUse = now()
    end)
end)

-- auto close when left open
CreateThread(function()
    while true do
        Wait(5000)
        if not busy and (state.doors == 1 or state.pillars == 1) and now() - lastUse > Config.AutoClose * 1000 then
            busy = true; lowerAndClose(); busy = false
        end
    end
end)

RegisterNetEvent('rox_swat:get', function()
    local src = source
    TriggerClientEvent('rox_swat:origin', src, { x = origin.x, y = origin.y, z = origin.z, w = origin.w })
    send(src); TriggerClientEvent('rox_swat:doors', src, doors)
end)
RegisterNetEvent('rox_swat:foot', function() local src = source; if not allowed(src) then deny(src) else TriggerClientEvent('rox_swat:footOk', src) end end)
RegisterNetEvent('rox_swat:door', function(id, locked)
    local src = source
    if type(id) ~= 'string' or not id:match('^rox_swat_%d+$') then return end
    if not allowed(src) then return deny(src) end
    doors[id] = locked and true or false
    TriggerClientEvent('rox_swat:doorState', -1, id, doors[id])
end)
RegisterCommand('roxswat_here', function(src)
    if src == 0 or not IsPlayerAceAllowed(src, Config.AdminAce) then return end
    local ped = GetPlayerPed(src); local p, h = GetEntityCoords(ped), GetEntityHeading(ped)
    origin = vec4(p.x, p.y, p.z - 1.0, h)
    SetResourceKvp('origin', json.encode({ x = origin.x, y = origin.y, z = origin.z, w = origin.w }))
    TriggerClientEvent('rox_swat:origin', -1, { x = origin.x, y = origin.y, z = origin.z, w = origin.w })
end, false)
