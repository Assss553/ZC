--[[ ROX Towers  ·  © ROX Store – All rights reserved. ]]
local function load()
    local s = GetResourceKvpString('origin')
    if s then local t = json.decode(s); return vec4(t.x, t.y, t.z, t.w) end
    return Config.Origin
end
local origin = load()
RegisterNetEvent('rox_towers:get', function() TriggerClientEvent('rox_towers:origin', source, { x = origin.x, y = origin.y, z = origin.z, w = origin.w }) end)
RegisterCommand('roxtowers_here', function(src)
    if src == 0 or not IsPlayerAceAllowed(src, Config.AdminAce) then return end
    local ped = GetPlayerPed(src)
    local p, h = GetEntityCoords(ped), GetEntityHeading(ped)
    origin = vec4(p.x, p.y, p.z - 1.0, h)
    SetResourceKvp('origin', json.encode({ x = origin.x, y = origin.y, z = origin.z, w = origin.w }))
    TriggerClientEvent('rox_towers:origin', -1, { x = origin.x, y = origin.y, z = origin.z, w = origin.w })
end, false)

-- security doors (keycard): ace or police job (QBCore / ESX auto-detected)
local doors = {}
local function hasKeycard(src)
    if IsPlayerAceAllowed(src, Config.KeycardAce) then return true end
    if GetResourceState('qb-core') == 'started' then
        local ok, QB = pcall(function() return exports['qb-core']:GetCoreObject() end)
        local p = ok and QB and QB.Functions.GetPlayer(src)
        if p and p.PlayerData.job and Config.KeycardJobs[p.PlayerData.job.name] then return true end
    end
    if GetResourceState('es_extended') == 'started' then
        local ok, ESX = pcall(function() return exports['es_extended']:getSharedObject() end)
        local p = ok and ESX and ESX.GetPlayerFromId(src)
        if p and p.job and Config.KeycardJobs[p.job.name] then return true end
    end
    return false
end
RegisterNetEvent('rox_towers:door', function(id, locked)
    local src = source
    if type(id) ~= 'string' or not id:match('^rox_towers_%d+_%d+$') then return end
    if not hasKeycard(src) then TriggerClientEvent('chat:addMessage', src, { args = { 'ROX', 'Access denied' } }); return end
    doors[id] = locked and true or false
    TriggerClientEvent('rox_towers:doorState', -1, id, doors[id])
end)
AddEventHandler('playerJoining', function() TriggerClientEvent('rox_towers:doors', source, doors) end)
