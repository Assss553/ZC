-- ROX Store | rox_admin | All rights reserved.
local Sessions = {}     -- [src] = { id, joined, license, steam, name, cid, char, kickedBy }
local Perms = {}        -- [rank][perm] = bool
local DbStaff = {}      -- [identifier] = rank
local Activity = {}     -- { {t, n} } player count samples (24h)
local START = os.time()

local function now() return os.time() end
local function ids(src)
    local t = {}
    for _, k in ipairs({ 'license', 'license2', 'steam', 'discord', 'ip', 'fivem' }) do t[k] = GetPlayerIdentifierByType(src, k) end
    return t
end
local function QPlayer(src) local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end) return ok and p or nil end
local function charOf(src)
    local p = QPlayer(src); if not p then return nil end
    local d, ci = p.PlayerData, p.PlayerData.charinfo or {}
    return { cid = d.citizenid, name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''),
        job = d.job and d.job.label or d.job and d.job.name, grade = d.job and d.job.grade and (d.job.grade.name or d.job.grade.level),
        duty = d.job and d.job.onduty, jobName = d.job and d.job.name,
        cash = d.money and d.money.cash, bank = d.money and d.money.bank }
end

---------------------------------------------------------------- database bootstrap
CreateThread(function()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'install.sql') or ''
    sql = sql:gsub('%-%-[^\n]*', '')
    for stmt in sql:gmatch('[^;]+') do if stmt:find('%S') then MySQL.query.await(stmt) end end
    for _, r in ipairs(Config.Ranks) do Perms[r.name] = {} end
    for perm, ranks in pairs(Config.Permissions) do for _, r in ipairs(ranks) do if Perms[r] then Perms[r][perm] = true end end end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM rox_admin_perms') or {}) do
        if Perms[row.rank] then Perms[row.rank][row.perm] = row.allowed == 1 end
    end
    for _, row in ipairs(MySQL.query.await('SELECT identifier, `rank` FROM rox_admin_staff') or {}) do DbStaff[row.identifier] = row.rank end
    -- close sessions left open by a crash / restart, then reopen for players still online
    MySQL.update.await("UPDATE rox_admin_sessions SET left_at = joined_at, duration = 0, quit_type = 'server', quit_reason = 'Server restart / resource stop' WHERE left_at IS NULL")
    for _, s in ipairs(GetPlayers()) do OpenSession(tonumber(s)) ; local c = charOf(tonumber(s)); if c then SetChar(tonumber(s), c) end end
    print('^2[rox_admin]^7 ready')
end)

---------------------------------------------------------------- staff / permissions
local function rankOf(src)
    local i = ids(src)
    for _, v in pairs(i) do if v and (DbStaff[v] or Config.Staff[v]) then return DbStaff[v] or Config.Staff[v] end end
    for _, r in ipairs(Config.AceRanks) do if IsPlayerAceAllowed(src, 'rox.' .. r) then return r end end
    return nil
end
local function can(src, perm)
    local r = rankOf(src); if not r then return false end
    if r == 'owner' then return true end
    return Perms[r] and Perms[r][perm] == true
end
local function permList(src)
    local r, t = rankOf(src), {}
    for perm in pairs(Config.Permissions) do t[perm] = can(src, perm) end
    return r, t
end

local function logAction(src, action, target, details)
    local i = ids(src)
    local tl, tc, tn
    if type(target) == 'number' then local s = Sessions[target]; tl = s and s.license; tc = s and s.cid; tn = s and (s.char or s.name)
    elseif type(target) == 'table' then tl, tc, tn = target.license, target.cid, target.name end
    MySQL.insert('INSERT INTO rox_admin_actions (admin_license, admin_name, action, target_license, target_cid, target_name, details, at) VALUES (?,?,?,?,?,?,?,?)',
        { i.license, GetPlayerName(src), action, tl, tc, tn, details and json.encode(details) or nil, now() })
end

---------------------------------------------------------------- sessions (join / quit)
local function webhook(title, color, fields)
    if Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({ embeds = { { title = title, color = color, fields = fields, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } } }), { ['Content-Type'] = 'application/json' })
end

function OpenSession(src)
    if Sessions[src] then return end
    local i = ids(src)
    local s = { joined = now(), license = i.license or i.license2, steam = i.steam, name = GetPlayerName(src) }
    Sessions[src] = s
    s.id = MySQL.insert.await('INSERT INTO rox_admin_sessions (license, steam, steam_name, discord, ip, server_id, joined_at) VALUES (?,?,?,?,?,?,?)',
        { s.license, s.steam, s.name, i.discord, Config.LogIPs and i.ip or nil, src, s.joined })
    webhook('Join', 3066993, { { name = 'Steam', value = s.name .. '\n' .. (s.steam or 'no steam'), inline = true }, { name = 'ID', value = tostring(src), inline = true } })
end

function SetChar(src, c)
    local s = Sessions[src]; if not s or not c or s.cid == c.cid then return end
    s.cid, s.char = c.cid, c.name
    MySQL.update('UPDATE rox_admin_sessions SET citizenid = ?, char_name = ? WHERE id = ?', { c.cid, c.name, s.id })
    MySQL.insert('INSERT INTO rox_admin_charlog (session_id, license, citizenid, char_name, at) VALUES (?,?,?,?,?)', { s.id, s.license, c.cid, c.name, now() })
end

AddEventHandler('playerJoining', function() OpenSession(source) end)
AddEventHandler('QBCore:Server:OnPlayerLoaded', function() local src = source; SetTimeout(500, function() SetChar(src, charOf(src)) end) end)
RegisterNetEvent('rox_admin:server:charLoaded', function() local src = source; SetChar(src, charOf(src)) end)

local function classify(reason, s)
    local r = (reason or ''):lower()
    if s.kickedBy then return 'kicked' end
    if r:find('exit') or r:find('quit') or r:find('disconnected%.') then return 'quit' end
    if r:find('kick') or r:find('ban') then return 'kicked' end
    if r:find('timed out') or r:find('timeout') or r:find('crash') or r:find('lost') or r:find('server%->client') then return 'dropped' end
    return 'quit'
end
AddEventHandler('playerDropped', function(reason)
    local src = source
    local s = Sessions[src]; if not s then return end
    local c = charOf(src); if c then SetChar(src, c) end
    local t, dur = now(), now() - s.joined
    local typ = classify(reason, s)
    local why = s.kickedBy and ('Kicked by ' .. s.kickedBy .. ': ' .. (reason or '')) or reason
    MySQL.update('UPDATE rox_admin_sessions SET left_at = ?, duration = ?, quit_type = ?, quit_reason = ?, citizenid = COALESCE(citizenid, ?), char_name = COALESCE(char_name, ?) WHERE id = ?',
        { t, dur, typ, why, s.cid, s.char, s.id })
    webhook('Quit (' .. typ .. ')', 15158332, { { name = 'Steam', value = s.name, inline = true }, { name = 'Character', value = (s.char or '-') .. ' / ' .. (s.cid or '-'), inline = true },
        { name = 'Session', value = ('%dm'):format(dur // 60), inline = true }, { name = 'Reason', value = why or '-' } })
    Sessions[src] = nil
end)

CreateThread(function()
    while true do
        Activity[#Activity + 1] = { t = now(), n = #GetPlayers() }
        while #Activity > 0 and Activity[1].t < now() - 86400 do table.remove(Activity, 1) end
        Wait(60000)
    end
end)

---------------------------------------------------------------- helpers for the UI
local function decode(v) if type(v) == 'string' then local ok, r = pcall(json.decode, v); return ok and r or nil end return v end
local function charRow(r, onlineCid)
    local ci, job, pos = decode(r.charinfo) or {}, decode(r.job) or {}, decode(r.position)
    return { cid = r.citizenid, name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')), birth = ci.birthdate, gender = ci.gender, phone = r.phone_number or ci.phone,
        nationality = ci.nationality, job = job.label or job.name, grade = job.grade and (job.grade.name or job.grade.level), license = r.license,
        lastSeen = r.last_seen, created = r.created, lastPos = pos, online = onlineCid ~= nil and onlineCid == r.citizenid }
end
local function onlineByCid() local t = {} for src, s in pairs(Sessions) do if s.cid then t[s.cid] = src end end return t end

local function playerEntry(src)
    local s = Sessions[src]; if not s then return nil end
    local c = charOf(src) or {}
    local ped = GetPlayerPed(src)
    local co = ped ~= 0 and GetEntityCoords(ped)
    return { id = src, name = s.name, steam = s.steam, license = s.license, cid = c.cid or s.cid, char = c.name or s.char,
        job = c.job, grade = c.grade, duty = c.duty, joined = s.joined, ping = GetPlayerPing(src), staff = rankOf(src),
        coords = co and { x = co.x, y = co.y, z = co.z, h = GetEntityHeading(ped) } or nil }
end

local function licenseList(lic)
    if not lic then return {} end
    local core = lic:gsub('^license2?:', '')
    return { 'license:' .. core, 'license2:' .. core }
end

-- first/last time we saw a character (Qbox has no creation column; we use the oldest known log, else players.id order)
local function charQuery(where, args)
    return MySQL.query.await(([[SELECT p.citizenid, p.license, p.charinfo, p.job, p.position, p.phone_number,
        UNIX_TIMESTAMP(p.last_updated) AS last_seen,
        (SELECT MIN(at) FROM rox_admin_charlog l WHERE l.citizenid = p.citizenid) AS created
        FROM players p WHERE %s ORDER BY p.id ASC LIMIT 200]]):format(where), args) or {}
end

---------------------------------------------------------------- RPC
local H = {}
H.me = { fn = function(src)
    local r, p = permList(src)
    return { rank = r, perms = p, ranks = Config.Ranks, permNames = Config.Permissions, keybinds = Config.Keybinds, locale = Config.Locale, name = GetPlayerName(src), id = src }
end }

H.dashboard = { perm = 'view_players', fn = function(src)
    local police, ems, staff, list = 0, 0, {}, {}
    for _, s in ipairs(GetPlayers()) do
        local id = tonumber(s); local c = charOf(id)
        if c and c.duty then if c.jobName == 'police' or c.jobName == 'sheriff' then police += 1 elseif c.jobName == 'ambulance' or c.jobName == 'ems' then ems += 1 end end
        local r = rankOf(id); if r then staff[#staff + 1] = { id = id, name = GetPlayerName(id), rank = r } end
    end
    local ping, n = 0, #GetPlayers()
    for _, s in ipairs(GetPlayers()) do ping += GetPlayerPing(s) end
    local today = MySQL.scalar.await('SELECT COUNT(DISTINCT license) FROM rox_admin_sessions WHERE joined_at > ?', { now() - 86400 })
    return { online = n, max = GetConvarInt('sv_maxclients', 48), police = police, ems = ems, staff = staff, uptime = now() - START,
        ping = n > 0 and math.floor(ping / n) or 0, today = today or 0, activity = Activity }
end }

H.players = { perm = 'view_players', fn = function()
    local t = {} for src in pairs(Sessions) do t[#t + 1] = playerEntry(src) end
    table.sort(t, function(a, b) return a.id < b.id end) return t
end }

-- full profile by server id (online) or license (offline)
H.profile = { perm = 'view_players', fn = function(src, a)
    local lic = a.license
    local live = a.id and playerEntry(tonumber(a.id))
    if live then lic = live.license end
    if not lic then return nil end
    local L = licenseList(lic)
    local acc = MySQL.single.await('SELECT steam, steam_name, MIN(joined_at) first, MAX(joined_at) last, SUM(COALESCE(duration,0)) total, COUNT(*) sessions FROM rox_admin_sessions WHERE license IN (?,?)', L) or {}
    if live then acc.total = (acc.total or 0) + (now() - live.joined) end
    local chars = can(src, 'view_characters') and charQuery('p.license IN (?,?)', L) or {}
    local onl = onlineByCid(); local cl = {}
    for _, r in ipairs(chars) do cl[#cl + 1] = charRow(r, live and live.cid) end
    local cols = 'id, steam_name, server_id, citizenid, char_name, joined_at, left_at, duration, quit_type, quit_reason' .. (can(src, 'view_ips') and ', ip' or '')
    local sessions = can(src, 'view_logs') and MySQL.query.await('SELECT ' .. cols .. ' FROM rox_admin_sessions WHERE license IN (?,?) ORDER BY id DESC LIMIT 50', L) or {}
    local actions = can(src, 'view_actions') and MySQL.query.await('SELECT * FROM rox_admin_actions WHERE target_license IN (?,?) ORDER BY id DESC LIMIT 50', L) or {}
    local switches = MySQL.query.await('SELECT citizenid, char_name, at FROM rox_admin_charlog WHERE license IN (?,?) ORDER BY id DESC LIMIT 30', L) or {}
    local lastCid = live and live.cid or (sessions[1] and sessions[1].citizenid)
    return { live = live, license = lic, steam = (live and live.steam) or acc.steam, steamName = (live and live.name) or acc.steam_name, first = acc.first, last = acc.last,
        total = acc.total or 0, sessionCount = acc.sessions or 0, chars = cl, sessions = sessions, actions = actions, switches = switches, lastCid = lastCid }
end }

H.characters = { perm = 'view_characters', fn = function(_, a)
    local q = a and a.q or ''
    local rows
    if q == '' then rows = charQuery('1=1', {})
    else local l = '%' .. q .. '%'
        rows = charQuery([[p.citizenid LIKE ? OR p.license LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.firstname')) LIKE ? OR JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.lastname')) LIKE ?
            OR CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.firstname')),' ',JSON_UNQUOTE(JSON_EXTRACT(p.charinfo,'$.lastname'))) LIKE ?
            OR p.license IN (SELECT license FROM rox_admin_sessions WHERE steam_name LIKE ? OR steam LIKE ?)]], { l, l, l, l, l, l, l })
    end
    local onl, names, out = onlineByCid(), {}, {}
    for _, r in ipairs(rows) do
        local c = charRow(r, nil); c.online = onl[c.cid] ~= nil; c.serverId = onl[c.cid]
        local L = licenseList(r.license)
        names[r.license] = names[r.license] or MySQL.scalar.await('SELECT steam_name FROM rox_admin_sessions WHERE license IN (?,?) ORDER BY id DESC LIMIT 1', L) or '—'
        c.steamName = names[r.license]; out[#out + 1] = c
    end
    return out
end }

H.charHistory = { perm = 'view_characters', fn = function(_, a)
    return MySQL.query.await('SELECT steam_name, server_id, joined_at, left_at, duration, quit_type FROM rox_admin_sessions WHERE citizenid = ? ORDER BY id DESC LIMIT 50', { a.cid }) or {}
end }

H.logs = { perm = 'view_logs', fn = function(src, a)
    a = a or {}
    local w, args = { '1=1' }, {}
    if a.q and a.q ~= '' then local l = '%' .. a.q .. '%'
        w[#w + 1] = '(steam_name LIKE ? OR steam LIKE ? OR license LIKE ? OR citizenid LIKE ? OR char_name LIKE ? OR server_id = ?)'
        for _ = 1, 5 do args[#args + 1] = l end args[#args + 1] = tonumber(a.q) or -1 end
    if a.from then w[#w + 1] = 'joined_at >= ?'; args[#args + 1] = a.from end
    if a.to then w[#w + 1] = 'joined_at <= ?'; args[#args + 1] = a.to end
    if a.type == 'online' then w[#w + 1] = 'left_at IS NULL' elseif a.type and a.type ~= '' then w[#w + 1] = 'quit_type = ?'; args[#args + 1] = a.type end
    local cols = 'id, license, steam, steam_name, server_id, citizenid, char_name, joined_at, left_at, duration, quit_type, quit_reason' .. (can(src, 'view_ips') and ', ip' or '')
    return MySQL.query.await(('SELECT %s FROM rox_admin_sessions WHERE %s ORDER BY id DESC LIMIT 300'):format(cols, table.concat(w, ' AND ')), args) or {}
end }

H.actions = { perm = 'view_actions', fn = function(_, a)
    local q = a and a.q or ''
    if q == '' then return MySQL.query.await('SELECT * FROM rox_admin_actions ORDER BY id DESC LIMIT 300') end
    local l = '%' .. q .. '%'
    return MySQL.query.await('SELECT * FROM rox_admin_actions WHERE admin_name LIKE ? OR target_name LIKE ? OR target_cid LIKE ? OR action LIKE ? ORDER BY id DESC LIMIT 300', { l, l, l, l })
end }

-- coordinates
H.coordsList = { perm = 'coords', fn = function(src)
    return MySQL.query.await('SELECT * FROM rox_admin_coords WHERE shared = 1 OR owner_license = ? ORDER BY id DESC', { ids(src).license })
end }
H.coordsSave = { perm = 'coords_save', fn = function(src, a)
    if type(a.label) ~= 'string' or a.label == '' or not tonumber(a.x) then return false end
    MySQL.insert.await('INSERT INTO rox_admin_coords (label, x, y, z, h, shared, owner_license, owner_name, at) VALUES (?,?,?,?,?,?,?,?,?)',
        { a.label:sub(1, 80), a.x, a.y, a.z, a.h or 0, a.shared and 1 or 0, ids(src).license, GetPlayerName(src), now() })
    logAction(src, 'coords_save', nil, a) return true
end }
H.coordsDelete = { perm = 'coords_save', fn = function(src, a)
    local own = rankOf(src) == 'owner'
    MySQL.update.await('DELETE FROM rox_admin_coords WHERE id = ? AND (owner_license = ? OR ?)', { a.id, ids(src).license, own and 1 or 0 }) return true
end }
H.teleport = { perm = 'teleport', fn = function(src, a)
    local x, y, z = tonumber(a.x), tonumber(a.y), tonumber(a.z); if not x then return false end
    TriggerClientEvent('rox_admin:client:tp', src, x, y, z, tonumber(a.h)); logAction(src, 'teleport', nil, { x = x, y = y, z = z }) return true
end }

-- player actions
local function target(a) local t = tonumber(a.id); return t and Sessions[t] and t or nil end
H['goto'] = { perm = 'goto', fn = function(src, a) local t = target(a); if not t then return false end
    local c = GetEntityCoords(GetPlayerPed(t)); TriggerClientEvent('rox_admin:client:tp', src, c.x, c.y, c.z); logAction(src, 'goto', t) return true end }
H.bring = { perm = 'bring', fn = function(src, a) local t = target(a); if not t then return false end
    local c = GetEntityCoords(GetPlayerPed(src)); TriggerClientEvent('rox_admin:client:tp', t, c.x, c.y, c.z); logAction(src, 'bring', t) return true end }
H.freeze = { perm = 'freeze', fn = function(src, a) local t = target(a); if not t then return false end
    local s = Sessions[t]; s.frozen = not s.frozen; FreezeEntityPosition(GetPlayerPed(t), s.frozen); logAction(src, s.frozen and 'freeze' or 'unfreeze', t) return s.frozen end }
H.revive = { perm = 'revive', fn = function(src, a) local t = target(a); if not t then return false end
    TriggerClientEvent('qbx_medical:client:playerRevived', t); TriggerClientEvent('hospital:client:Revive', t); logAction(src, 'revive', t) return true end }
H.kick = { perm = 'kick', fn = function(src, a) local t = target(a); if not t or t == src then return false end
    if (rankOf(t) and (rankOf(t) == 'owner')) then return false end
    logAction(src, 'kick', t, { reason = a.reason }); Sessions[t].kickedBy = GetPlayerName(src)
    DropPlayer(t, 'Kicked: ' .. tostring(a.reason or 'No reason')) return true end }
H.setJob = { perm = 'set_job', fn = function(src, a) local t = target(a); local p = t and QPlayer(t); if not p then return false end
    local ok = p.Functions.SetJob(tostring(a.job), tonumber(a.grade) or 0); logAction(src, 'set_job', t, { job = a.job, grade = a.grade }) return ok ~= false end }
H.money = { perm = 'give_money', fn = function(src, a) local t = target(a); local p = t and QPlayer(t); local amt = math.floor(tonumber(a.amount) or 0)
    if not p or amt == 0 or (a.account ~= 'cash' and a.account ~= 'bank') then return false end
    if amt > 0 then p.Functions.AddMoney(a.account, amt, 'rox_admin') else p.Functions.RemoveMoney(a.account, -amt, 'rox_admin') end
    logAction(src, 'money', t, { account = a.account, amount = amt }) return true end }

-- staff & permissions (owner)
H.staffList = { perm = 'manage_staff', fn = function()
    local t = MySQL.query.await('SELECT * FROM rox_admin_staff ORDER BY at DESC') or {}
    for k, v in pairs(Config.Staff) do t[#t + 1] = { identifier = k, rank = v, name = '(config.lua)', locked = true } end
    return t
end }
H.staffSet = { perm = 'manage_staff', fn = function(src, a)
    local ident = a.identifier
    if a.id and Sessions[tonumber(a.id)] then ident = Sessions[tonumber(a.id)].license end
    if type(ident) ~= 'string' or not ident:find(':') then return false end
    if a.rank == '' or not a.rank then MySQL.update.await('DELETE FROM rox_admin_staff WHERE identifier = ?', { ident }); DbStaff[ident] = nil
    else
        local okRank = false for _, r in ipairs(Config.Ranks) do if r.name == a.rank then okRank = true end end
        if not okRank then return false end
        local nm = a.id and GetPlayerName(tonumber(a.id)) or a.name
        MySQL.insert.await('REPLACE INTO rox_admin_staff (identifier, name, `rank`, added_by, at) VALUES (?,?,?,?,?)', { ident, nm, a.rank, GetPlayerName(src), now() })
        DbStaff[ident] = a.rank
    end
    logAction(src, 'staff_set', { license = ident, name = a.name }, { rank = a.rank })
    for p in pairs(Sessions) do TriggerClientEvent('rox_admin:client:refreshMe', p) end
    return true
end }
H.permsGet = { perm = 'manage_perms', fn = function() return Perms end }
H.permsSet = { perm = 'manage_perms', fn = function(src, a)
    if a.rank == 'owner' or not Perms[a.rank] or not Config.Permissions[a.perm] then return false end
    Perms[a.rank][a.perm] = a.allowed == true
    MySQL.insert.await('REPLACE INTO rox_admin_perms (`rank`, perm, allowed) VALUES (?,?,?)', { a.rank, a.perm, a.allowed and 1 or 0 })
    logAction(src, 'perm_set', nil, a) return true
end }

lib.callback.register('rox_admin:call', function(src, name, args)
    local h = H[name]; if not h then return nil end
    if name ~= 'me' and not rankOf(src) then return nil end
    if h.perm and not can(src, h.perm) then return { denied = true } end
    local ok, res = pcall(h.fn, src, args or {})
    if not ok then print(('^1[rox_admin] %s: %s^7'):format(name, res)) return nil end
    return res
end)

lib.callback.register('rox_admin:can', function(src, perm) return can(src, perm) end)
exports('GetRank', rankOf)
exports('HasPermission', can)
