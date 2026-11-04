-- Framework bridge: QBCore / Qbox / ESX / standalone
Bridge = {}

local QB, ESX
local fw = 'standalone'

CreateThread(function()
    if GetResourceState('qbx_core') == 'started' then
        fw = 'qbx'
    elseif GetResourceState('qb-core') == 'started' then
        fw = 'qb'; QB = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then
        fw = 'esx'; ESX = exports['es_extended']:getSharedObject()
    end
    print(('[zc_police] framework: %s'):format(fw))
end)

local function license(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return 'player:' .. src
end

local function qbPlayer(src)
    if fw == 'qbx' then return exports.qbx_core:GetPlayer(src) end
    if fw == 'qb' then return QB.Functions.GetPlayer(src) end
end

-- { cid, name, job, jobLabel, grade, duty, phone }
function Bridge.GetChar(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return nil end
    if fw == 'qb' or fw == 'qbx' then
        local p = qbPlayer(src)
        if not p then return nil end
        local d = p.PlayerData
        local ci = d.charinfo or {}
        return {
            cid = d.citizenid,
            name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''),
            job = d.job and d.job.name, jobLabel = d.job and d.job.label,
            grade = d.job and d.job.grade and (d.job.grade.name or d.job.grade.level),
            duty = d.job and d.job.onduty,
            phone = ci.phone, dob = ci.birthdate, gender = ci.gender == 1 and 'Female' or 'Male',
        }
    elseif fw == 'esx' then
        local x = ESX.GetPlayerFromId(src)
        if not x then return nil end
        local name = x.getName and x.getName() or GetPlayerName(src)
        return {
            cid = x.identifier, name = name,
            job = x.job and x.job.name, jobLabel = x.job and x.job.label,
            grade = x.job and x.job.grade_label, duty = true,
            dob = x.get and x.get('dateofbirth'), gender = x.get and (x.get('sex') == 'f' and 'Female' or 'Male'),
        }
    end
    return { cid = license(src), name = GetPlayerName(src), job = nil, duty = true }
end

function Bridge.IsPolice(src)
    local c = Bridge.GetChar(src)
    if not c or not c.job then return false end
    for _, j in ipairs(Config.PoliceJobs) do
        if j == c.job then
            if Config.RequireDuty and c.duty == false then return false end
            return true
        end
    end
    return false
end

function Bridge.RemoveMoney(src, amount, reason)
    if amount <= 0 then return true end
    if fw == 'qb' or fw == 'qbx' then
        local p = qbPlayer(src)
        return p and p.Functions.RemoveMoney(Config.Fine.account, amount, reason) or false
    elseif fw == 'esx' then
        local x = ESX.GetPlayerFromId(src)
        if not x then return false end
        local acc = x.getAccount(Config.Fine.account)
        if not acc or acc.money < amount then return false end
        x.removeAccountMoney(Config.Fine.account, amount, reason)
        return true
    end
    return true -- standalone: no economy
end

-- online player by citizen id
function Bridge.SourceFromCid(cid)
    for _, s in ipairs(GetPlayers()) do
        local c = Bridge.GetChar(s)
        if c and c.cid == cid then return tonumber(s) end
    end
end

-- optional database lookups (oxmysql). Return nil when not available.
local function sql(query, params)
    if GetResourceState('oxmysql') ~= 'started' then return nil end
    local p = promise.new()
    exports.oxmysql:query(query, params, function(r) p:resolve(r or {}) end)
    return Citizen.Await(p)
end

function Bridge.SearchCitizensDB(text)
    local like = '%' .. text .. '%'
    if fw == 'qb' or fw == 'qbx' then
        local rows = sql('SELECT citizenid, charinfo FROM players WHERE charinfo LIKE ? OR citizenid LIKE ? LIMIT 20', { like, like })
        if not rows then return {} end
        local out = {}
        for _, r in ipairs(rows) do
            local ok, ci = pcall(json.decode, r.charinfo or '{}')
            ci = ok and ci or {}
            out[#out + 1] = { cid = r.citizenid, name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')), phone = ci.phone, dob = ci.birthdate }
        end
        return out
    elseif fw == 'esx' then
        local rows = sql('SELECT identifier, firstname, lastname, dateofbirth FROM users WHERE CONCAT(firstname, " ", lastname) LIKE ? LIMIT 20', { like })
        if not rows then return {} end
        local out = {}
        for _, r in ipairs(rows) do
            out[#out + 1] = { cid = r.identifier, name = (r.firstname or '') .. ' ' .. (r.lastname or ''), dob = r.dateofbirth }
        end
        return out
    end
    return {}
end

function Bridge.VehicleByPlate(plate)
    if fw == 'qb' or fw == 'qbx' then
        local rows = sql('SELECT pv.plate, pv.vehicle, pv.citizenid, p.charinfo FROM player_vehicles pv LEFT JOIN players p ON p.citizenid = pv.citizenid WHERE pv.plate LIKE ? LIMIT 10', { '%' .. plate .. '%' })
        if not rows then return nil end
        local out = {}
        for _, r in ipairs(rows) do
            local ok, ci = pcall(json.decode, r.charinfo or '{}')
            ci = ok and ci or {}
            out[#out + 1] = { plate = r.plate, model = r.vehicle, cid = r.citizenid, owner = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')) }
        end
        return out
    elseif fw == 'esx' then
        local rows = sql('SELECT ov.plate, ov.vehicle, ov.owner, u.firstname, u.lastname FROM owned_vehicles ov LEFT JOIN users u ON u.identifier = ov.owner WHERE ov.plate LIKE ? LIMIT 10', { '%' .. plate .. '%' })
        if not rows then return nil end
        local out = {}
        for _, r in ipairs(rows) do
            local ok, v = pcall(json.decode, r.vehicle or '{}')
            out[#out + 1] = { plate = r.plate, model = ok and v and v.model or '?', cid = r.owner, owner = (r.firstname or '') .. ' ' .. (r.lastname or '') }
        end
        return out
    end
    return nil
end
