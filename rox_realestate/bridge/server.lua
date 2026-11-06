--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

Bridge = {}

local FW = Config.Framework
local ESX, QBCore

local function detect()
    if FW ~= 'auto' then return FW end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    if GetResourceState('qbx_core') == 'started' or GetResourceState('qb-core') == 'started' then return 'qb' end
    return 'standalone'
end

FW = detect()

if FW == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
elseif FW == 'qb' then
    local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok then QBCore = obj else FW = 'standalone' end
end

print(('^2[rox_realestate]^7 framework: ^3%s^7'):format(FW))
Bridge.Framework = FW

local function getPlayer(src)
    if FW == 'esx' then return ESX.GetPlayerFromId(src) end
    if FW == 'qb' then return QBCore.Functions.GetPlayer(src) end
    return nil
end

function Bridge.GetIdentifier(src)
    local p = getPlayer(src)
    if FW == 'esx' and p then return p.identifier end
    if FW == 'qb' and p then return p.PlayerData.citizenid end
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

function Bridge.GetName(src)
    local p = getPlayer(src)
    if FW == 'esx' and p then return p.getName() end
    if FW == 'qb' and p then
        local c = p.PlayerData.charinfo
        return ('%s %s'):format(c.firstname, c.lastname)
    end
    return GetPlayerName(src) or ('#' .. src)
end

function Bridge.GetJob(src)
    local p = getPlayer(src)
    if FW == 'esx' and p then return p.job.name, tonumber(p.job.grade) or 0 end
    if FW == 'qb' and p then
        local j = p.PlayerData.job
        local grade = type(j.grade) == 'table' and j.grade.level or j.grade
        return j.name, tonumber(grade) or 0
    end
    return 'unemployed', 0
end

-- gang name (QBCore gang system, otherwise the job)
function Bridge.GetGang(src)
    local p = getPlayer(src)
    if FW == 'qb' and p and p.PlayerData.gang and p.PlayerData.gang.name and p.PlayerData.gang.name ~= 'none' then
        return p.PlayerData.gang.name
    end
    return (Bridge.GetJob(src))
end

local function account()
    if FW == 'esx' then
        return Config.PayAccount == 'cash' and 'money' or Config.PayAccount
    end
    return Config.PayAccount == 'money' and 'cash' or Config.PayAccount
end

function Bridge.GetMoney(src)
    local p = getPlayer(src)
    if FW == 'esx' and p then
        local a = p.getAccount(account())
        return a and a.money or 0
    end
    if FW == 'qb' and p then return p.Functions.GetMoney(account()) or 0 end
    return 999999999
end

function Bridge.RemoveMoney(src, amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if Bridge.GetMoney(src) < amount then return false end
    local p = getPlayer(src)
    if FW == 'esx' and p then p.removeAccountMoney(account(), amount, reason); return true end
    if FW == 'qb' and p then return p.Functions.RemoveMoney(account(), amount, reason) ~= false end
    return true
end

function Bridge.AddMoney(src, amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return end
    local p = getPlayer(src)
    if FW == 'esx' and p then p.addAccountMoney(account(), amount, reason) end
    if FW == 'qb' and p then p.Functions.AddMoney(account(), amount, reason) end
end

function Bridge.GetSourceByIdentifier(identifier)
    if not identifier then return nil end
    if FW == 'esx' then
        local p = ESX.GetPlayerFromIdentifier(identifier)
        return p and p.source
    end
    if FW == 'qb' then
        local p = QBCore.Functions.GetPlayerByCitizenId(identifier)
        return p and p.PlayerData.source
    end
    for _, src in ipairs(GetPlayers()) do
        if Bridge.GetIdentifier(tonumber(src)) == identifier then return tonumber(src) end
    end
end

function Bridge.RegisterUsableItem(name, cb)
    if not name then return end
    if FW == 'esx' then ESX.RegisterUsableItem(name, cb) end
    if FW == 'qb' then QBCore.Functions.CreateUseableItem(name, function(src) cb(src) end) end
end

function Bridge.Notify(src, msg, kind)
    TriggerClientEvent('rox_re:notify', src, msg, kind or 'info')
end
