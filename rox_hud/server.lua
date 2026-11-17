--[[ ROX Store | rox_hud | All rights reserved. ]]
local QB, ESX
CreateThread(function()
    if GetResourceState('qb-core') == 'started' then QB = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then ESX = exports['es_extended']:getSharedObject() end
end)

local function inList(list, v) for _, x in ipairs(list) do if x == v then return true end end return false end

local function jobOf(src)
    if QB then local p = QB.Functions.GetPlayer(src) if p then return p.PlayerData.job.name, p.PlayerData.job.onduty ~= false end
    elseif ESX then local x = ESX.GetPlayerFromId(src) if x then return x.job.name, true end end
end

RegisterNetEvent('rox_hud:server:pause', function()
    local src = source
    local police, ems = 0, 0
    local players = GetPlayers()
    for _, s in ipairs(players) do
        local job, duty = jobOf(tonumber(s))
        if job and duty then
            if inList(Config.PoliceJobs, job) then police = police + 1 elseif inList(Config.EmsJobs, job) then ems = ems + 1 end
        end
    end
    local name, cid = GetPlayerName(src), nil
    if QB then local p = QB.Functions.GetPlayer(src) if p then local ci = p.PlayerData.charinfo or {}; name = (ci.firstname or '') .. ' ' .. (ci.lastname or ''); cid = p.PlayerData.citizenid end
    elseif ESX then local x = ESX.GetPlayerFromId(src) if x then name = x.getName(); cid = x.identifier and x.identifier:sub(-8) end end
    TriggerClientEvent('rox_hud:client:pause', src, {
        online = #players, max = GetConvarInt('sv_maxclients', 48), police = police, ems = ems, name = name, cid = cid,
    })
end)

RegisterNetEvent('rox_hud:server:quit', function()
    DropPlayer(source, 'Quit the game')
end)
