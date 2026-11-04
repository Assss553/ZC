--[[ ROX Store | rox_police | All rights reserved. ]]
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
    print(('[rox_police] framework: %s'):format(fw))
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
            gradeLevel = d.job and d.job.grade and tonumber(d.job.grade.level) or 0,
            isboss = d.job and d.job.isboss or false,
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
            gradeLevel = x.job and tonumber(x.job.grade) or 0,
            isboss = x.job and x.job.grade_name == 'boss' or false,
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
function Bridge.Framework() return fw end

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

---------------------------------------------------------------------------
-- boss / management
---------------------------------------------------------------------------
function Bridge.IsBoss(src)
    if not Bridge.IsPolice(src) then return false end
    local c = Bridge.GetChar(src)
    return c.isboss or (c.gradeLevel or 0) >= Config.BossMinGrade
end

-- { { level, name, payment } } sorted by level
function Bridge.GetGrades(job)
    local out = {}
    if fw == 'qb' or fw == 'qbx' then
        local jobs = fw == 'qbx' and exports.qbx_core:GetJobs() or QB.Shared.Jobs
        local j = jobs and jobs[job]
        for lvl, g in pairs(j and j.grades or {}) do
            out[#out + 1] = { level = tonumber(lvl), name = g.name, payment = g.payment, isboss = g.isboss }
        end
    elseif fw == 'esx' then
        local rows = sql('SELECT grade, label, salary, name FROM job_grades WHERE job_name = ?', { job }) or {}
        for _, r in ipairs(rows) do out[#out + 1] = { level = r.grade, name = r.label, payment = r.salary, isboss = r.name == 'boss' } end
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end

-- set job for an online (src) or offline (cid) player
function Bridge.SetJob(cid, job, grade)
    local src = Bridge.SourceFromCid(cid)
    if fw == 'qb' or fw == 'qbx' then
        if src then
            local p = qbPlayer(src)
            return p and p.Functions.SetJob(job, grade) ~= false
        end
        local jobs = fw == 'qbx' and exports.qbx_core:GetJobs() or QB.Shared.Jobs
        local j = jobs[job]
        if not j then return false end
        local g = j.grades[tostring(grade)] or j.grades[grade] or {}
        local data = { name = job, label = j.label, payment = g.payment or 0, onduty = false, isboss = g.isboss or false,
            grade = { name = g.name or 'none', level = tonumber(grade) or 0 } }
        sql('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(data), cid })
        return true
    elseif fw == 'esx' then
        if src then
            local x = ESX.GetPlayerFromId(src)
            if x then x.setJob(job, grade) return true end
        end
        sql('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', { job, grade, cid })
        return true
    end
    return false
end

-- all employees of a job: online + offline from the database
function Bridge.Employees(job)
    local out, seen = {}, {}
    for _, s in ipairs(GetPlayers()) do
        local c = Bridge.GetChar(s)
        if c and c.job == job then
            seen[c.cid] = true
            out[#out + 1] = { cid = c.cid, name = c.name, grade = c.grade, gradeLevel = c.gradeLevel, phone = c.phone, online = true, duty = c.duty ~= false, id = tonumber(s) }
        end
    end
    if fw == 'qb' or fw == 'qbx' then
        local rows = sql('SELECT citizenid, charinfo, job FROM players WHERE job LIKE ?', { '%"name":"' .. job .. '"%' }) or {}
        for _, r in ipairs(rows) do
            if not seen[r.citizenid] then
                local ok1, ci = pcall(json.decode, r.charinfo or '{}')
                local ok2, j = pcall(json.decode, r.job or '{}')
                ci = ok1 and ci or {}; j = ok2 and j or {}
                if j.name == job then
                    out[#out + 1] = { cid = r.citizenid, name = (ci.firstname or '') .. ' ' .. (ci.lastname or ''), grade = j.grade and j.grade.name, gradeLevel = j.grade and tonumber(j.grade.level) or 0, phone = ci.phone, online = false, duty = false }
                end
            end
        end
    elseif fw == 'esx' then
        local rows = sql('SELECT identifier, firstname, lastname, job_grade FROM users WHERE job = ?', { job }) or {}
        local names = {}
        for _, g in ipairs(Bridge.GetGrades(job)) do names[g.level] = g.name end
        for _, r in ipairs(rows) do
            if not seen[r.identifier] then
                out[#out + 1] = { cid = r.identifier, name = (r.firstname or '') .. ' ' .. (r.lastname or ''), grade = names[r.job_grade], gradeLevel = r.job_grade, online = false, duty = false }
            end
        end
    end
    table.sort(out, function(a, b) if a.gradeLevel ~= b.gradeLevel then return a.gradeLevel > b.gradeLevel end return (a.name or '') < (b.name or '') end)
    return out
end

function Bridge.AddMoney(src, amount, reason)
    if fw == 'qb' or fw == 'qbx' then
        local p = qbPlayer(src)
        return p and p.Functions.AddMoney(Config.Fine.account, amount, reason) or false
    elseif fw == 'esx' then
        local x = ESX.GetPlayerFromId(src)
        if x then x.addAccountMoney(Config.Fine.account, amount, reason) return true end
    end
    return false
end

-- society account (qb-banking / qb-management / Renewed-Banking / esx_addonaccount). nil = not available
function Bridge.Society(action, amount)
    local name = Config.Society
    if fw == 'esx' then
        local p = promise.new()
        TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. name, function(acc) p:resolve(acc) end)
        SetTimeout(1500, function() p:resolve(nil) end)
        local acc = Citizen.Await(p)
        if not acc then return nil end
        if action == 'add' then acc.addMoney(amount) return true end
        if action == 'remove' then if acc.money < amount then return false end acc.removeMoney(amount) return true end
        return acc.money
    end
    local tries = {
        { 'qb-banking', function() if action == 'get' then return exports['qb-banking']:GetAccountBalance(name) elseif action == 'add' then return exports['qb-banking']:AddMoney(name, amount, 'boss menu') else return exports['qb-banking']:RemoveMoney(name, amount, 'boss menu') end end },
        { 'Renewed-Banking', function() if action == 'get' then return exports['Renewed-Banking']:getAccountMoney(name) elseif action == 'add' then return exports['Renewed-Banking']:addAccountMoney(name, amount) else return exports['Renewed-Banking']:removeAccountMoney(name, amount) end end },
        { 'qb-management', function() if action == 'get' then return exports['qb-management']:GetAccount(name) elseif action == 'add' then return exports['qb-management']:AddMoney(name, amount) else return exports['qb-management']:RemoveMoney(name, amount) end end },
    }
    for _, t in ipairs(tries) do
        if GetResourceState(t[1]) == 'started' then
            local ok, r = pcall(t[2])
            if ok and r ~= nil then return r end
        end
    end
    return nil
end

function Bridge.UsableItem(item, cb)
    if not item then return end
    CreateThread(function()
        Wait(1000)
        if fw == 'qbx' then pcall(function() exports.qbx_core:CreateUseableItem(item, function(src) cb(src) end) end)
        elseif fw == 'qb' then QB.Functions.CreateUseableItem(item, function(src) cb(src) end)
        elseif fw == 'esx' then ESX.RegisterUsableItem(item, function(src) cb(src) end) end
    end)
end

-- vehicle tables: impound (owner pays) / depot (police hold)
function Bridge.ImpoundVehicleDB(plate, mode, price)
    if fw == 'qb' or fw == 'qbx' then
        sql('UPDATE player_vehicles SET state = 2, depotprice = ? WHERE plate = ?', { price, plate })
    elseif fw == 'esx' then
        sql('UPDATE owned_vehicles SET `stored` = 0 WHERE plate = ?', { plate })
    end
end
