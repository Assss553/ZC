local RES = GetCurrentResourceName()
local DB_FILE = 'data/db.json'

---------------------------------------------------------------------------
-- storage (json file, no database needed)
---------------------------------------------------------------------------
local db
local function loadDB()
    local raw = LoadResourceFile(RES, DB_FILE)
    local ok, data = pcall(json.decode, raw or '{}')
    db = (ok and type(data) == 'table') and data or {}
    for _, k in ipairs({ 'prisoners', 'people', 'vehicles' }) do db[k] = db[k] or {} end
    for _, k in ipairs({ 'jailHistory', 'fines', 'warrants', 'reports', 'bolos', 'activity' }) do db[k] = db[k] or {} end
    db.seq = db.seq or 0
end
loadDB()

local dirty = false
local function save() dirty = true end
CreateThread(function()
    while true do
        Wait(5000)
        if dirty then
            dirty = false
            SaveResourceFile(RES, DB_FILE, json.encode(db), -1)
        end
    end
end)
AddEventHandler('onResourceStop', function(r)
    if r == RES then SaveResourceFile(RES, DB_FILE, json.encode(db), -1) end
end)

local function nextId() db.seq = db.seq + 1; return db.seq end
local function trimList(list, max) while #list > max do table.remove(list, 1) end end

local function log(kind, text, officer)
    db.activity[#db.activity + 1] = { t = os.time(), kind = kind, text = text, officer = officer }
    trimList(db.activity, 200)
    save()
end

local function notify(src, msg, kind)
    TriggerClientEvent('zc_police:client:notify', src, msg, kind or 'info')
end

local function person(cid, name)
    local p = db.people[cid]
    if not p then p = { cid = cid, name = name, notes = '', flags = {} }; db.people[cid] = p end
    if name and name ~= '' then p.name = name end
    return p
end

local function chargeByLabel(label)
    for _, c in ipairs(Config.Charges) do if c.label == label then return c end end
end

local function closeEnough(src, target)
    if not Config.MaxActionDistance or Config.MaxActionDistance <= 0 then return true end
    local a, b = GetPlayerPed(src), GetPlayerPed(target)
    if a == 0 or b == 0 then return true end
    local ca, cb = GetEntityCoords(a), GetEntityCoords(b)
    if ca.x == 0.0 and ca.y == 0.0 then return true end
    return #(ca - cb) <= Config.MaxActionDistance
end

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

---------------------------------------------------------------------------
-- jail
---------------------------------------------------------------------------
local onlinePrisoners = {} -- cid -> src

local function sendJailState(src, rec)
    TriggerClientEvent('zc_police:client:jailed', src, {
        type = rec.type, remaining = rec.remaining, life = rec.life, total = rec.total,
        charges = rec.charges, bail = rec.bail,
    })
end

local function releasePrisoner(cid, reason, officer)
    local rec = db.prisoners[cid]
    if not rec then return false end
    db.prisoners[cid] = nil
    for i = #db.jailHistory, 1, -1 do
        local h = db.jailHistory[i]
        if h.cid == cid and not h.releasedAt then h.releasedAt = os.time(); h.releaseReason = reason break end
    end
    local src = onlinePrisoners[cid] or Bridge.SourceFromCid(cid)
    onlinePrisoners[cid] = nil
    if src then
        TriggerClientEvent('zc_police:client:released', src, rec.type)
        notify(src, reason == 'served' and 'You served your sentence. You are free.' or ('You were released (' .. reason .. ')'), 'success')
    end
    log('release', ('%s released (%s)'):format(rec.name, reason), officer)
    save()
    return true
end

CreateThread(function()
    local TICK = 15
    while true do
        Wait(TICK * 1000)
        for cid, src in pairs(onlinePrisoners) do
            local rec = db.prisoners[cid]
            if not rec or not GetPlayerName(src) then
                onlinePrisoners[cid] = nil
            elseif not rec.life then
                rec.remaining = rec.remaining - TICK
                if rec.remaining <= 0 then releasePrisoner(cid, 'served') end
                save()
            end
        end
    end
end)

RegisterNetEvent('zc_police:server:checkIn', function()
    local src = source
    local c = Bridge.GetChar(src)
    if not c then return end
    local rec = db.prisoners[c.cid]
    if rec then
        onlinePrisoners[c.cid] = src
        sendJailState(src, rec)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for cid, s in pairs(onlinePrisoners) do if s == src then onlinePrisoners[cid] = nil end end
end)

RegisterCommand(Config.Commands.paybail, function(src)
    local c = Bridge.GetChar(src)
    local rec = c and db.prisoners[c.cid]
    if not rec then return notify(src, 'You are not in prison', 'error') end
    if not rec.bail or rec.bail <= 0 then return notify(src, 'Bail is not allowed for your sentence', 'error') end
    if not Bridge.RemoveMoney(src, rec.bail, 'bail') then return notify(src, 'Not enough money for bail ($' .. rec.bail .. ')', 'error') end
    releasePrisoner(c.cid, 'bail paid')
end, false)

---------------------------------------------------------------------------
-- request handlers (from the tablet)
---------------------------------------------------------------------------
local H = {}

local function officerName(src) local c = Bridge.GetChar(src) return c and c.name or GetPlayerName(src) end

local function stats()
    local unpaid, today = 0, 0
    local dayStart = os.time() - 86400
    for _, f in ipairs(db.fines) do
        if not f.paid then unpaid = unpaid + 1 end
        if f.t >= dayStart then today = today + 1 end
    end
    local warrants, bolos = 0, 0
    for _, w in ipairs(db.warrants) do if w.active then warrants = warrants + 1 end end
    for _, b in ipairs(db.bolos) do if b.active then bolos = bolos + 1 end end
    local online = 0
    for _, s in ipairs(GetPlayers()) do if Bridge.IsPolice(s) then online = online + 1 end end
    return { prisoners = count(db.prisoners), finesToday = today, unpaid = unpaid, warrants = warrants, bolos = bolos, reports = #db.reports, officers = online }
end

H.init = function(src)
    local c = Bridge.GetChar(src) or {}
    local types = {}
    for key, t in pairs(Config.Jail.types) do types[#types + 1] = { key = key, label = t.label, icon = t.icon } end
    table.sort(types, function(a, b) return a.key > b.key end)
    return {
        officer = { name = c.name, grade = c.grade, jobLabel = c.jobLabel, duty = c.duty ~= false },
        charges = Config.Charges, jailTypes = types, presets = Config.Jail.presets, maxMinutes = Config.Jail.maxMinutes,
        stats = stats(),
    }
end

H.names = function(src, d)
    local out = {}
    for _, id in ipairs(d.ids or {}) do
        local c = Bridge.GetChar(id)
        if c then out[#out + 1] = { id = tonumber(id), name = c.name, cid = c.cid } end
    end
    return out
end

H.player = function(src, d)
    local c = Bridge.GetChar(d.id)
    if not c then return { ok = false } end
    local p = db.people[c.cid]
    local w = 0
    for _, x in ipairs(db.warrants) do if x.active and x.cid == c.cid then w = w + 1 end end
    return { ok = true, name = c.name, cid = c.cid, jailed = db.prisoners[c.cid] ~= nil, warrants = w, flags = p and p.flags or {} }
end

H.jail = function(src, d)
    local target = tonumber(d.id)
    local t = Bridge.GetChar(target)
    if not t then return { ok = false, msg = 'Player not found' } end
    if target == src then return { ok = false, msg = "You can't jail yourself" } end
    if not closeEnough(src, target) then return { ok = false, msg = 'Player is too far away' } end
    local jt = Config.Jail.types[d.type] and d.type or 'prison'
    local life = d.life == true
    local minutes = math.floor(tonumber(d.minutes) or 0)
    if not life and (minutes < 1 or minutes > Config.Jail.maxMinutes) then return { ok = false, msg = 'Invalid sentence time' } end
    if db.prisoners[t.cid] then return { ok = false, msg = t.name .. ' is already in prison' } end

    local charges, fine = {}, 0
    for _, label in ipairs(d.charges or {}) do
        local c = chargeByLabel(label)
        if c then charges[#charges + 1] = c.label; fine = fine + (c.fine or 0) end
    end
    local extra = tostring(d.extra or ''):sub(1, 300)
    local bail = (d.bail and not life) and math.max(0, math.floor(tonumber(d.bailAmount) or 0)) or 0

    local rec = {
        cid = t.cid, name = t.name, type = jt, life = life,
        total = minutes * 60, remaining = minutes * 60,
        charges = charges, extra = extra, bail = bail, fine = fine,
        officer = officerName(src), at = os.time(),
    }
    db.prisoners[t.cid] = rec
    db.jailHistory[#db.jailHistory + 1] = { id = nextId(), cid = t.cid, name = t.name, type = jt, minutes = minutes, life = life, charges = charges, extra = extra, officer = rec.officer, t = os.time() }
    trimList(db.jailHistory, 1000)
    person(t.cid, t.name)

    if d.chargeFine and fine > 0 then
        local paid = Bridge.RemoveMoney(target, fine, 'court fine')
        db.fines[#db.fines + 1] = { id = nextId(), cid = t.cid, name = t.name, charges = charges, amount = fine, paid = paid, notes = 'Sentence fine', officer = rec.officer, t = os.time() }
    end

    onlinePrisoners[t.cid] = target
    if Config.Jail.builtIn then sendJailState(target, rec) end
    pcall(Config.OnJail, src, target, { type = jt, minutes = minutes, life = life, charges = charges, bail = bail })

    log('jail', ('%s sent to %s for %s'):format(t.name, Config.Jail.types[jt].label, life and 'life' or (minutes .. ' min')), rec.officer)
    notify(target, ('You were sentenced: %s'):format(life and 'life' or (minutes .. ' minutes')), 'error')
    save()
    return { ok = true, msg = t.name .. ' was sent to ' .. Config.Jail.types[jt].label }
end

H.prisoners = function()
    local out = {}
    for _, r in pairs(db.prisoners) do
        out[#out + 1] = {
            cid = r.cid, name = r.name, type = r.type, typeLabel = Config.Jail.types[r.type] and Config.Jail.types[r.type].label or r.type,
            life = r.life, total = r.total, remaining = r.remaining, charges = r.charges, extra = r.extra,
            bail = r.bail, officer = r.officer, at = r.at, online = onlinePrisoners[r.cid] ~= nil,
        }
    end
    table.sort(out, function(a, b) return a.at > b.at end)
    return out
end

H.release = function(src, d)
    local ok = releasePrisoner(tostring(d.cid), 'released by ' .. officerName(src), officerName(src))
    return { ok = ok, msg = ok and 'Prisoner released' or 'Prisoner not found' }
end

H.fine = function(src, d)
    local target = tonumber(d.id)
    local t = Bridge.GetChar(target)
    if not t then return { ok = false, msg = 'Player not found' } end
    if target == src then return { ok = false, msg = "You can't fine yourself" } end
    if not closeEnough(src, target) then return { ok = false, msg = 'Player is too far away' } end
    local charges, amount = {}, 0
    for _, label in ipairs(d.charges or {}) do
        local c = chargeByLabel(label)
        if c then charges[#charges + 1] = c.label; amount = amount + (c.fine or 0) end
    end
    if #charges == 0 then return { ok = false, msg = 'Select at least one violation' } end
    local paid = Bridge.RemoveMoney(target, amount, 'citation')
    if not paid and not Config.Fine.allowUnpaid then return { ok = false, msg = t.name .. " can't pay $" .. amount } end
    local rec = { id = nextId(), cid = t.cid, name = t.name, charges = charges, amount = amount, paid = paid,
        notes = tostring(d.notes or ''):sub(1, 300), plate = tostring(d.plate or ''):sub(1, 12), officer = officerName(src), t = os.time() }
    db.fines[#db.fines + 1] = rec
    trimList(db.fines, 2000)
    person(t.cid, t.name)
    log('fine', ('%s fined $%d (%s)'):format(t.name, amount, paid and 'paid' or 'unpaid'), rec.officer)
    notify(target, ('You received a citation: $%d%s'):format(amount, paid and '' or ' (unpaid)'), 'warning')
    save()
    return { ok = true, msg = ('Citation issued to %s — $%d %s'):format(t.name, amount, paid and 'paid' or 'unpaid') }
end

H.fines = function(src, d)
    local out, q = {}, d and d.q and d.q:lower() or nil
    for i = #db.fines, 1, -1 do
        local f = db.fines[i]
        if not q or q == '' or (f.name or ''):lower():find(q, 1, true) or tostring(f.cid):lower():find(q, 1, true) then out[#out + 1] = f end
        if #out >= 100 then break end
    end
    return out
end

H.markPaid = function(src, d)
    for _, f in ipairs(db.fines) do
        if f.id == d.id then f.paid = true; save(); log('fine', ('Fine #%d of %s marked paid'):format(f.id, f.name), officerName(src)) return { ok = true } end
    end
    return { ok = false }
end

-- MDT ---------------------------------------------------------------------
H.dashboard = function()
    local act = {}
    for i = #db.activity, math.max(1, #db.activity - 14), -1 do act[#act + 1] = db.activity[i] end
    local w, b = {}, {}
    for i = #db.warrants, 1, -1 do if db.warrants[i].active then w[#w + 1] = db.warrants[i] end if #w >= 5 then break end end
    for i = #db.bolos, 1, -1 do if db.bolos[i].active then b[#b + 1] = db.bolos[i] end if #b >= 5 then break end end
    return { stats = stats(), activity = act, warrants = w, bolos = b }
end

H.searchCitizens = function(src, d)
    local q = tostring(d.q or ''):lower()
    local found, out = {}, {}
    local function add(cid, name, extra)
        if not cid or found[cid] then return end
        found[cid] = true
        local w = 0
        for _, x in ipairs(db.warrants) do if x.active and x.cid == cid then w = w + 1 end end
        local e = { cid = cid, name = name, warrants = w, jailed = db.prisoners[cid] ~= nil }
        for k, v in pairs(extra or {}) do e[k] = v end
        out[#out + 1] = e
    end
    for _, s in ipairs(GetPlayers()) do
        local c = Bridge.GetChar(s)
        if c and (q == '' or (c.name or ''):lower():find(q, 1, true) or tostring(c.cid):lower():find(q, 1, true) or tostring(s) == q) then
            add(c.cid, c.name, { online = true, id = tonumber(s), phone = c.phone })
        end
    end
    for cid, p in pairs(db.people) do
        if q == '' or (p.name or ''):lower():find(q, 1, true) or cid:lower():find(q, 1, true) then add(cid, p.name) end
    end
    if #q >= 2 then
        for _, r in ipairs(Bridge.SearchCitizensDB(q)) do add(r.cid, r.name, { phone = r.phone, dob = r.dob }) end
    end
    return out
end

H.citizen = function(src, d)
    local cid = tostring(d.cid)
    local p = db.people[cid] or { cid = cid, name = d.name, notes = '', flags = {} }
    local res = { cid = cid, name = p.name, notes = p.notes, flags = p.flags, fines = {}, jail = {}, warrants = {}, reports = {} }
    local s = Bridge.SourceFromCid(cid)
    if s then
        local c = Bridge.GetChar(s)
        res.online, res.id, res.phone, res.dob, res.gender, res.job = true, s, c.phone, c.dob, c.gender, c.jobLabel
        res.name = c.name
    end
    local owed = 0
    for i = #db.fines, 1, -1 do local f = db.fines[i] if f.cid == cid then res.fines[#res.fines + 1] = f if not f.paid then owed = owed + f.amount end end end
    for i = #db.jailHistory, 1, -1 do local j = db.jailHistory[i] if j.cid == cid then res.jail[#res.jail + 1] = j end end
    for i = #db.warrants, 1, -1 do local w = db.warrants[i] if w.cid == cid then res.warrants[#res.warrants + 1] = w end end
    for i = #db.reports, 1, -1 do
        local r = db.reports[i]
        if r.involved and (r.involved:lower():find((res.name or '~'):lower(), 1, true)) then res.reports[#res.reports + 1] = { id = r.id, title = r.title, t = r.t } end
    end
    res.owed = owed
    res.prisoner = db.prisoners[cid]
    return res
end

H.saveCitizen = function(src, d)
    local p = person(tostring(d.cid), d.name)
    p.notes = tostring(d.notes or ''):sub(1, 2000)
    p.flags = {}
    for _, f in ipairs(d.flags or {}) do p.flags[#p.flags + 1] = tostring(f):sub(1, 24) end
    log('citizen', ('Profile of %s updated'):format(p.name or p.cid), officerName(src))
    save()
    return { ok = true }
end

H.searchVehicle = function(src, d)
    local plate = tostring(d.plate or ''):upper():gsub('%s+', '')
    if #plate < 2 then return { rows = {} } end
    local rows = Bridge.VehicleByPlate(plate) or {}
    local seen = {}
    for _, r in ipairs(rows) do
        seen[r.plate:gsub('%s+', ''):upper()] = true
    end
    for p, v in pairs(db.vehicles) do
        if p:find(plate, 1, true) and not seen[p] then rows[#rows + 1] = { plate = p, model = v.model or '?', owner = v.owner or 'Unknown' } end
    end
    for _, r in ipairs(rows) do
        local key = r.plate:gsub('%s+', ''):upper()
        local v = db.vehicles[key]
        r.stolen = v and v.stolen or false
        r.notes = v and v.notes or ''
        r.bolo = false
        for _, b in ipairs(db.bolos) do if b.active and b.plate and b.plate ~= '' and b.plate:upper():gsub('%s+', '') == key then r.bolo = true end end
        r.fines = 0
        for _, f in ipairs(db.fines) do if f.plate and f.plate:upper():gsub('%s+', '') == key then r.fines = r.fines + 1 end end
    end
    if #rows == 0 then rows[1] = { plate = plate, model = 'Unknown', owner = 'Not registered', unregistered = true, stolen = db.vehicles[plate] and db.vehicles[plate].stolen or false, notes = db.vehicles[plate] and db.vehicles[plate].notes or '' } end
    return { rows = rows }
end

H.flagVehicle = function(src, d)
    local key = tostring(d.plate or ''):upper():gsub('%s+', '')
    if key == '' then return { ok = false } end
    local v = db.vehicles[key] or {}
    v.stolen = d.stolen == true
    v.notes = tostring(d.notes or ''):sub(1, 500)
    v.model = d.model or v.model
    v.owner = d.owner or v.owner
    db.vehicles[key] = v
    log('vehicle', ('Vehicle %s %s'):format(key, v.stolen and 'flagged stolen' or 'updated'), officerName(src))
    save()
    return { ok = true }
end

H.warrants = function()
    local out = {}
    for i = #db.warrants, 1, -1 do out[#out + 1] = db.warrants[i] end
    return out
end

H.createWarrant = function(src, d)
    local name = tostring(d.name or ''):sub(1, 60)
    if name == '' or tostring(d.reason or '') == '' then return { ok = false, msg = 'Name and reason are required' } end
    local w = { id = nextId(), cid = d.cid and tostring(d.cid) or nil, name = name, reason = tostring(d.reason):sub(1, 500),
        danger = ({ low = 'low', medium = 'medium', high = 'high' })[d.danger] or 'medium', active = true, officer = officerName(src), t = os.time() }
    db.warrants[#db.warrants + 1] = w
    if w.cid then person(w.cid, name) end
    log('warrant', ('Warrant issued for %s'):format(name), w.officer)
    for _, s in ipairs(GetPlayers()) do if Bridge.IsPolice(s) then notify(s, 'New warrant: ' .. name, 'warning') end end
    save()
    return { ok = true, msg = 'Warrant issued' }
end

H.closeWarrant = function(src, d)
    for _, w in ipairs(db.warrants) do
        if w.id == d.id then w.active = false; w.closedBy = officerName(src); save(); log('warrant', ('Warrant for %s closed'):format(w.name), w.closedBy) return { ok = true } end
    end
    return { ok = false }
end

H.reports = function(src, d)
    local out, q = {}, d and d.q and d.q:lower() or ''
    for i = #db.reports, 1, -1 do
        local r = db.reports[i]
        if q == '' or (r.title .. ' ' .. (r.involved or '') .. ' ' .. (r.location or '')):lower():find(q, 1, true) then out[#out + 1] = r end
        if #out >= 100 then break end
    end
    return out
end

H.createReport = function(src, d)
    local title = tostring(d.title or ''):sub(1, 100)
    if title == '' then return { ok = false, msg = 'Title is required' } end
    local r = { id = nextId(), title = title, kind = tostring(d.kind or 'Incident'):sub(1, 30), location = tostring(d.location or ''):sub(1, 100),
        involved = tostring(d.involved or ''):sub(1, 300), body = tostring(d.body or ''):sub(1, 5000), officer = officerName(src), t = os.time() }
    db.reports[#db.reports + 1] = r
    log('report', ('Report #%d: %s'):format(r.id, title), r.officer)
    save()
    return { ok = true, msg = 'Report #' .. r.id .. ' saved', id = r.id }
end

H.bolos = function()
    local out = {}
    for i = #db.bolos, 1, -1 do out[#out + 1] = db.bolos[i] end
    return out
end

H.createBolo = function(src, d)
    local title = tostring(d.title or ''):sub(1, 80)
    if title == '' then return { ok = false, msg = 'Title is required' } end
    local b = { id = nextId(), title = title, plate = tostring(d.plate or ''):upper():sub(1, 12), body = tostring(d.body or ''):sub(1, 1000), active = true, officer = officerName(src), t = os.time() }
    db.bolos[#db.bolos + 1] = b
    log('bolo', 'BOLO: ' .. title, b.officer)
    for _, s in ipairs(GetPlayers()) do if Bridge.IsPolice(s) then notify(s, 'New BOLO: ' .. title, 'warning') end end
    save()
    return { ok = true, msg = 'BOLO created' }
end

H.closeBolo = function(src, d)
    for _, b in ipairs(db.bolos) do if b.id == d.id then b.active = false; save() return { ok = true } end end
    return { ok = false }
end

---------------------------------------------------------------------------
RegisterNetEvent('zc_police:server:req', function(reqId, action, data)
    local src = source
    local h = H[action]
    local res
    if not h then
        res = { ok = false, msg = 'Unknown action' }
    elseif not Bridge.IsPolice(src) then
        res = { ok = false, msg = 'Police only', denied = true }
    else
        local ok, r = pcall(h, src, type(data) == 'table' and data or {})
        if ok then res = r else print('[zc_police] ' .. action .. ': ' .. tostring(r)); res = { ok = false, msg = 'Server error' } end
    end
    TriggerClientEvent('zc_police:client:res', src, reqId, res)
end)

-- open check for the client (job gate)
RegisterNetEvent('zc_police:server:canOpen', function(reqId)
    local src = source
    TriggerClientEvent('zc_police:client:res', src, reqId, { ok = Bridge.IsPolice(src) })
end)
