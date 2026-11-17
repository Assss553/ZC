-- ROX Store | rox_phone | All rights reserved.
-- Real data for every app: contacts, messages, calls, notes, twitter, pic-it, gallery, bank log, crypto, clips/live, LSPD/EMS.
local now = os.time
local function dec(v, d) if type(v) == 'string' and v ~= '' then local ok, r = pcall(json.decode, v); if ok and r ~= nil then return r end end return d end
local function digits(s) return (tostring(s or ''):gsub('%D', '')) end
local function P(src) return exports.qbx_core:GetPlayer(src) end
local function cidOf(src) local p = P(src); return p and p.PlayerData.citizenid end
local function numOf(src) local p = P(src); return p and digits((p.PlayerData.charinfo or {}).phone) or '' end
local function nameOf(src) local p = P(src); local c = p and p.PlayerData.charinfo or {}; return ((c.firstname or '') .. ' ' .. (c.lastname or '')) end
local function srcByNum(n) n = digits(n); if n == '' then return nil end
    for _, p in pairs(exports.qbx_core:GetQBPlayers()) do if digits((p.PlayerData.charinfo or {}).phone) == n then return p.PlayerData.source end end end
local function push(src, t, d) TriggerClientEvent('rox_phone:push', src, t, d) end

---------------------------------------------------------------- schema
CreateThread(function()
    for _, q in ipairs({
        'CREATE TABLE IF NOT EXISTS rox_phone_kv (cid VARCHAR(50), k VARCHAR(20), v LONGTEXT, PRIMARY KEY (cid, k))',
        'CREATE TABLE IF NOT EXISTS rox_phone_messages (id INT AUTO_INCREMENT PRIMARY KEY, sender VARCHAR(20), receiver VARCHAR(20), body TEXT, kind VARCHAR(10), at INT, seen TINYINT DEFAULT 0, INDEX(sender), INDEX(receiver))',
        'CREATE TABLE IF NOT EXISTS rox_phone_calls (id INT AUTO_INCREMENT PRIMARY KEY, caller VARCHAR(20), callee VARCHAR(20), status VARCHAR(10), duration INT, at INT, INDEX(caller), INDEX(callee))',
        'CREATE TABLE IF NOT EXISTS rox_phone_tweets (id INT AUTO_INCREMENT PRIMARY KEY, cid VARCHAR(50), name VARCHAR(80), handle VARCHAR(40), body TEXT, img TEXT, at INT, likes INT DEFAULT 0)',
        'CREATE TABLE IF NOT EXISTS rox_phone_likes (kind VARCHAR(8), pid INT, cid VARCHAR(50), PRIMARY KEY (kind, pid, cid))',
        'CREATE TABLE IF NOT EXISTS rox_phone_ig (cid VARCHAR(50) PRIMARY KEY, user VARCHAR(30) UNIQUE, pw VARCHAR(200), name VARCHAR(80), bio VARCHAR(200))',
        'CREATE TABLE IF NOT EXISTS rox_phone_ig_posts (id INT AUTO_INCREMENT PRIMARY KEY, user VARCHAR(30), img TEXT, caption TEXT, loc VARCHAR(80), at INT, likes INT DEFAULT 0)',
        'CREATE TABLE IF NOT EXISTS rox_phone_ig_comments (id INT AUTO_INCREMENT PRIMARY KEY, post INT, user VARCHAR(30), body TEXT, at INT, INDEX(post))',
        'CREATE TABLE IF NOT EXISTS rox_phone_gallery (id INT AUTO_INCREMENT PRIMARY KEY, cid VARCHAR(50), url TEXT, at INT, INDEX(cid))',
        'CREATE TABLE IF NOT EXISTS rox_phone_bank (id INT AUTO_INCREMENT PRIMARY KEY, cid VARCHAR(50), kind VARCHAR(6), label VARCHAR(100), amount INT, at INT, INDEX(cid))',
        'CREATE TABLE IF NOT EXISTS rox_phone_clips (id INT AUTO_INCREMENT PRIMARY KEY, cid VARCHAR(50), user VARCHAR(40), img TEXT, caption TEXT, at INT, likes INT DEFAULT 0)',
        'CREATE TABLE IF NOT EXISTS rox_phone_alerts (id INT AUTO_INCREMENT PRIMARY KEY, job VARCHAR(20), reason VARCHAR(60), msg VARCHAR(200), x FLOAT, y FLOAT, z FLOAT, street VARCHAR(80), caller VARCHAR(20), at INT)',
    }) do MySQL.query.await(q) end
end)

local function kvGet(cid, k, d) return dec(MySQL.scalar.await('SELECT v FROM rox_phone_kv WHERE cid = ? AND k = ?', { cid, k }), d) end
local function kvSet(cid, k, v) MySQL.prepare('REPLACE INTO rox_phone_kv (cid, k, v) VALUES (?,?,?)', { cid, k, json.encode(v) }) end
local function bankLog(cid, kind, label, amount) MySQL.insert('INSERT INTO rox_phone_bank (cid, kind, label, amount, at) VALUES (?,?,?,?,?)', { cid, kind, label, amount, now() }) end

---------------------------------------------------------------- duty / on-duty counts
local Dnd = {}   -- [src] = true
local function onDuty(job) local list = {}
    for _, p in pairs(exports.qbx_core:GetQBPlayers()) do local j = p.PlayerData.job or {}
        if j.name == job and j.onduty then list[#list + 1] = p.PlayerData.source end end return list end
local function svcState(src)
    local p = P(src); local job = p and p.PlayerData.job or {}
    local alerts = {}
    if job.name and Config.Services[job.name] then
        alerts = MySQL.query.await('SELECT * FROM rox_phone_alerts WHERE job = ? AND at > ? ORDER BY id DESC LIMIT 15', { job.name, now() - 1800 }) or {}
    end
    local counts = {} for j in pairs(Config.Services) do counts[j] = #onDuty(j) end
    return { counts = counts, alerts = alerts, duty = job.onduty == true, dnd = Dnd[src] == true }
end
local function svcBroadcast() for _, s in ipairs(GetPlayers()) do push(tonumber(s), 'svc', svcState(tonumber(s))) end end
AddEventHandler('QBCore:Server:SetDuty', function() SetTimeout(200, svcBroadcast) end)
AddEventHandler('QBCore:Server:OnJobUpdate', function() SetTimeout(200, svcBroadcast) end)

---------------------------------------------------------------- calls (pma-voice)
local Calls, InCall = {}, {}   -- Calls[id] = {a, b, an, bn, t0, ok}
local nextCall = 1000
local function endCall(id, by)
    local c = Calls[id]; if not c then return end
    Calls[id] = nil; InCall[c.a] = nil; if c.b then InCall[c.b] = nil end
    local dur = c.ok and (now() - c.t0) or 0
    local status = c.ok and 'answered' or (by == c.b and 'declined' or 'missed')
    MySQL.insert('INSERT INTO rox_phone_calls (caller, callee, status, duration, at) VALUES (?,?,?,?,?)', { c.an, c.bn, status, dur, now() })
    for _, s in ipairs({ c.a, c.b }) do if s then push(s, 'call:ended', { id = id, status = status, dur = dur, caller = c.an, callee = c.bn, at = now() }) end end
end
AddEventHandler('playerDropped', function() local src = source; Dnd[src] = nil; if InCall[src] then endCall(InCall[src], src) end end)

---------------------------------------------------------------- live (Clips)
local Lives = {}   -- [hostSrc] = { title, user, viewers = {[src]=true}, earn, peak, likes, gifts }
local function liveList() local t = {} for h, l in pairs(Lives) do local n = 0 for _ in pairs(l.viewers) do n += 1 end t[#t + 1] = { host = h, user = l.user, title = l.title, viewers = n } end return t end
local function liveSend(h, t, d) local l = Lives[h]; if not l then return end push(h, t, d) for v in pairs(l.viewers) do push(v, t, d) end end
local function liveCount(h) local l = Lives[h]; if not l then return end local n = 0 for _ in pairs(l.viewers) do n += 1 end l.peak = math.max(l.peak, n) liveSend(h, 'live:viewers', n) end

---------------------------------------------------------------- RPC
local H = {}

H.init = function(src, cid)
    local me = numOf(src)
    local msgs = MySQL.query.await('SELECT * FROM rox_phone_messages WHERE sender = ? OR receiver = ? ORDER BY id DESC LIMIT 600', { me, me }) or {}
    local calls = MySQL.query.await('SELECT * FROM rox_phone_calls WHERE caller = ? OR callee = ? ORDER BY id DESC LIMIT 60', { me, me }) or {}
    local tweets = MySQL.query.await('SELECT t.*, (SELECT 1 FROM rox_phone_likes l WHERE l.kind = "tw" AND l.pid = t.id AND l.cid = ?) liked FROM rox_phone_tweets t ORDER BY id DESC LIMIT 60', { cid }) or {}
    local ig = MySQL.single.await('SELECT cid, user, name, bio FROM rox_phone_ig WHERE cid = ?', { cid })
    local posts = MySQL.query.await('SELECT p.*, (SELECT 1 FROM rox_phone_likes l WHERE l.kind = "ig" AND l.pid = p.id AND l.cid = ?) liked FROM rox_phone_ig_posts p ORDER BY id DESC LIMIT 40', { cid }) or {}
    for _, p in ipairs(posts) do p.comments = MySQL.query.await('SELECT user, body FROM rox_phone_ig_comments WHERE post = ? ORDER BY id', { p.id }) or {} end
    local clips = MySQL.query.await('SELECT c.*, (SELECT 1 FROM rox_phone_likes l WHERE l.kind = "cl" AND l.pid = c.id AND l.cid = ?) liked FROM rox_phone_clips c ORDER BY id DESC LIMIT 40', { cid }) or {}
    local crypto = kvGet(cid, 'crypto', nil)
    if not crypto then crypto = { code = ('RX-%s-%s'):format(cid:sub(1, 4):upper(), tostring(math.random(1000, 9999))), h = {}, tx = {} } kvSet(cid, 'crypto', crypto) end
    return { me = me, profile = kvGet(cid, 'profile', {}), contacts = kvGet(cid, 'contacts', {}), notes = kvGet(cid, 'notes', {}), settings = kvGet(cid, 'settings', {}),
        messages = msgs, calls = calls, tweets = tweets, ig = ig, igPosts = posts, clips = clips,
        gallery = MySQL.query.await('SELECT id, url, at FROM rox_phone_gallery WHERE cid = ? ORDER BY id DESC LIMIT 120', { cid }) or {},
        bank = MySQL.query.await('SELECT kind, label, amount, at FROM rox_phone_bank WHERE cid = ? ORDER BY id DESC LIMIT 40', { cid }) or {},
        crypto = crypto, prices = Config.Crypto, wallet = kvGet(cid, 'wallet', { bal = 0, total = 0, lives = {}, gifts = 0, hist = {} }),
        lives = liveList(), svc = svcState(src), apps = kvGet(cid, 'apps', nil) }
end

-- per-character documents (whole list replaced; small)
for _, k in ipairs({ 'profile', 'contacts', 'notes', 'settings', 'apps' }) do
    H['save_' .. k] = function(_, cid, a) if type(a) == 'table' then kvSet(cid, k, a) end return true end
end

-- messages
H.sendMessage = function(src, cid, a)
    local me, to = numOf(src), digits(a.to); local body = tostring(a.body or ''):sub(1, 1000); local kind = ({ text = 1, img = 1, loc = 1, ct = 1, pay = 1 })[a.kind] and a.kind or 'text'
    if to == '' or body == '' then return false end
    local id = MySQL.insert.await('INSERT INTO rox_phone_messages (sender, receiver, body, kind, at) VALUES (?,?,?,?,?)', { me, to, body, kind, now() })
    local t = srcByNum(to); if t then push(t, 'msg', { id = id, sender = me, receiver = to, body = body, kind = kind, at = now(), name = nameOf(src) }) end
    return { id = id, at = now() }
end
H.readThread = function(src, _, a) MySQL.update('UPDATE rox_phone_messages SET seen = 1 WHERE receiver = ? AND sender = ?', { numOf(src), digits(a.with) }) return true end
H.deleteThread = function(src, _, a) local me = numOf(src); MySQL.update('DELETE FROM rox_phone_messages WHERE (sender = ? AND receiver = ?) OR (sender = ? AND receiver = ?)', { me, digits(a.with), digits(a.with), me }) return true end

-- calls
H.call = function(src, _, a)
    if InCall[src] then return { ok = false, msg = 'You are already in a call' } end
    local num = digits(a.number); local target
    local svcJob = Config.ServiceNumbers[num]
    if svcJob then local list = {} for _, s in ipairs(onDuty(svcJob)) do if s ~= src and not InCall[s] and not Dnd[s] then list[#list + 1] = s end end
        if #list == 0 then return { ok = false, msg = 'No one is available right now' } end target = list[math.random(#list)]
    else target = srcByNum(num) end
    if not target then return { ok = false, msg = 'The number you called is not available' } end
    if target == src then return { ok = false, msg = 'You cannot call yourself' } end
    if InCall[target] then return { ok = false, msg = 'Line busy' } end
    nextCall += 1; local id = nextCall
    Calls[id] = { a = src, b = target, an = numOf(src), bn = num, t0 = now() }; InCall[src] = id; InCall[target] = id
    push(target, 'call:incoming', { id = id, from = numOf(src), name = nameOf(src), service = svcJob })
    SetTimeout(Config.RingSeconds * 1000, function() local c = Calls[id]; if c and not c.ok then endCall(id, nil) end end)
    return { ok = true, id = id }
end
H.answer = function(src, _, a) local c = Calls[a.id]; if not c or c.b ~= src or c.ok then return false end
    c.ok = true; c.t0 = now(); push(c.a, 'call:accepted', { id = a.id }); push(c.b, 'call:accepted', { id = a.id }) return true end
H.hang = function(src, _, a) local c = Calls[a.id]; if c and (c.a == src or c.b == src) then endCall(a.id, src) end return true end

-- twitter
H.tweet = function(src, cid, a)
    local body = tostring(a.body or ''):sub(1, 280); if body == '' and not a.img then return false end
    local name = nameOf(src); local handle = name:lower():gsub('%s+', '')
    local id = MySQL.insert.await('INSERT INTO rox_phone_tweets (cid, name, handle, body, img, at) VALUES (?,?,?,?,?,?)', { cid, name, handle, body, a.img, now() })
    local t = { id = id, cid = cid, name = name, handle = handle, body = body, img = a.img, at = now(), likes = 0 }
    for _, s in ipairs(GetPlayers()) do if tonumber(s) ~= src then push(tonumber(s), 'tweet', t) end end
    return t
end
local function like(kind, tbl, cid, id, on)
    if on then if MySQL.insert.await('INSERT IGNORE INTO rox_phone_likes (kind, pid, cid) VALUES (?,?,?)', { kind, id, cid }) then MySQL.update(('UPDATE %s SET likes = likes + 1 WHERE id = ?'):format(tbl), { id }) end
    else if MySQL.update.await('DELETE FROM rox_phone_likes WHERE kind = ? AND pid = ? AND cid = ?', { kind, id, cid }) > 0 then MySQL.update(('UPDATE %s SET likes = GREATEST(likes - 1, 0) WHERE id = ?'):format(tbl), { id }) end end
    return true
end
H.likeTweet = function(_, cid, a) return like('tw', 'rox_phone_tweets', cid, tonumber(a.id), a.on) end

-- pic-it
H.igRegister = function(_, cid, a)
    local u = tostring(a.user or ''):lower()
    if not u:match('^[a-z0-9._]+$') or #u < 3 or #u > 20 or #tostring(a.pw or '') < 6 then return { ok = false, msg = 'Invalid username or password' } end
    if MySQL.scalar.await('SELECT 1 FROM rox_phone_ig WHERE user = ?', { u }) then return { ok = false, msg = 'That username is taken' } end
    MySQL.query.await('REPLACE INTO rox_phone_ig (cid, user, pw, name, bio) VALUES (?,?,?,?,?)', { cid, u, GetPasswordHash(a.pw), tostring(a.name or ''):sub(1, 80), tostring(a.bio or ''):sub(1, 200) })
    return { ok = true, acc = { user = u, name = a.name, bio = a.bio } }
end
H.igLogin = function(_, cid, a)
    local r = MySQL.single.await('SELECT * FROM rox_phone_ig WHERE user = ?', { tostring(a.user or ''):lower() })
    if not r or not VerifyPasswordHash(tostring(a.pw or ''), r.pw) then return { ok = false, msg = 'Wrong username or password' } end
    if r.cid ~= cid then MySQL.update.await('UPDATE rox_phone_ig SET cid = ? WHERE user = ?', { cid, r.user }) end
    return { ok = true, acc = { user = r.user, name = r.name, bio = r.bio } }
end
H.igLogout = function(_, cid) MySQL.update('UPDATE rox_phone_ig SET cid = CONCAT("x-", cid) WHERE cid = ?', { cid }) return true end
H.igBio = function(_, cid, a) MySQL.update('UPDATE rox_phone_ig SET bio = ? WHERE cid = ?', { tostring(a.bio or ''):sub(1, 200), cid }) return true end
local function igUser(cid) return MySQL.scalar.await('SELECT user FROM rox_phone_ig WHERE cid = ?', { cid }) end
H.igPost = function(src, cid, a) local u = igUser(cid); if not u or not a.img then return false end
    local id = MySQL.insert.await('INSERT INTO rox_phone_ig_posts (user, img, caption, loc, at) VALUES (?,?,?,?,?)', { u, a.img, tostring(a.caption or ''):sub(1, 500), tostring(a.loc or ''):sub(1, 80), now() })
    local p = { id = id, user = u, img = a.img, caption = a.caption, loc = a.loc, at = now(), likes = 0, comments = {} }
    for _, s in ipairs(GetPlayers()) do if tonumber(s) ~= src then push(tonumber(s), 'igpost', p) end end return p end
H.igLike = function(_, cid, a) return like('ig', 'rox_phone_ig_posts', cid, tonumber(a.id), a.on) end
H.igComment = function(_, cid, a) local u = igUser(cid); if not u then return false end
    MySQL.insert('INSERT INTO rox_phone_ig_comments (post, user, body, at) VALUES (?,?,?,?)', { tonumber(a.id), u, tostring(a.body or ''):sub(1, 300), now() }) return true end

-- gallery (photos taken with the in-game camera)
H.savePhoto = function(_, cid, a) if type(a.url) ~= 'string' or not a.url:match('^https?://') then return false end
    return MySQL.insert.await('INSERT INTO rox_phone_gallery (cid, url, at) VALUES (?,?,?)', { cid, a.url, now() }) end
H.deletePhoto = function(_, cid, a) MySQL.update('DELETE FROM rox_phone_gallery WHERE id = ? AND cid = ?', { tonumber(a.id), cid }) return true end

-- bank transfer by phone number (receiver must be online)
H.transfer = function(src, cid, a)
    local p = P(src); local amount = math.floor(tonumber(a.amount) or 0)
    if amount <= 0 or amount > 10000000 then return { ok = false, msg = 'Invalid amount' } end
    local t = srcByNum(a.to); if not t then return { ok = false, msg = 'No one with that number is in the city' } end
    if t == src then return { ok = false, msg = 'You cannot send money to yourself' } end
    if not p.Functions.RemoveMoney('bank', amount, 'rox_phone-transfer') then return { ok = false, msg = 'Not enough money' } end
    local tp = P(t); tp.Functions.AddMoney('bank', amount, 'rox_phone-transfer')
    bankLog(cid, 'out', 'To ' .. nameOf(t), amount); bankLog(tp.PlayerData.citizenid, 'in', 'From ' .. nameOf(src), amount)
    push(t, 'bank', { kind = 'in', label = 'From ' .. nameOf(src), amount = amount, at = now() })
    TriggerClientEvent('ox_lib:notify', t, { title = 'ROX Bank', description = ('You received $%s from %s'):format(amount, nameOf(src)), type = 'success' })
    return { ok = true }
end

-- crypto: holdings stored per character, prices from config (moving slowly)
local Prices = {} CreateThread(function() for _, c in ipairs(Config.Crypto) do Prices[c.s] = c.p end
    while true do Wait(60000) for _, c in ipairs(Config.Crypto) do Prices[c.s] = math.max(c.p * 0.5, Prices[c.s] * (1 + (math.random() - 0.5) * c.vol)) end end end)
H.prices = function() local t = {} for _, c in ipairs(Config.Crypto) do t[#t + 1] = { s = c.s, n = c.n, col = c.col, p = Prices[c.s] or c.p, base = c.p } end return t end
H.crypto = function(src, cid, a)
    local p = P(src); local w = kvGet(cid, 'crypto', { h = {}, tx = {} }); local s = a.coin; local price = Prices[s]; local amt = tonumber(a.amount) or 0
    if not price or amt <= 0 then return { ok = false, msg = 'Invalid amount' } end
    w.h[s] = w.h[s] or 0
    if a.action == 'buy' then local cost = math.ceil(amt * price); if not p.Functions.RemoveMoney('bank', cost, 'rox_phone-crypto') then return { ok = false, msg = 'Not enough money in the bank' } end
        w.h[s] = w.h[s] + amt; table.insert(w.tx, 1, { 'buy', s, amt, 'Bought', now() }); bankLog(cid, 'out', 'Bought ' .. s, cost)
    elseif a.action == 'sell' then if w.h[s] < amt then return { ok = false, msg = 'Not enough ' .. s } end
        local v = math.floor(amt * price); w.h[s] = w.h[s] - amt; p.Functions.AddMoney('bank', v, 'rox_phone-crypto'); table.insert(w.tx, 1, { 'sell', s, amt, 'Sold', now() }); bankLog(cid, 'in', 'Sold ' .. s, v)
    elseif a.action == 'send' then if w.h[s] < amt then return { ok = false, msg = 'Not enough ' .. s } end
        local to = tostring(a.to or ''); local tcid, tname
        if to:upper():match('^RX%-') then local r = MySQL.single.await('SELECT cid FROM rox_phone_kv WHERE k = "crypto" AND JSON_UNQUOTE(JSON_EXTRACT(v, "$.code")) = ?', { to:upper() }); tcid = r and r.cid; tname = to:upper()
        else local t = srcByNum(to); if t then tcid = P(t).PlayerData.citizenid; tname = nameOf(t) end end
        if not tcid then return { ok = false, msg = 'No ROX wallet found' } end
        if tcid == cid then return { ok = false, msg = 'That is your own wallet' } end
        local tw = kvGet(tcid, 'crypto', { h = {}, tx = {} }); tw.h[s] = (tw.h[s] or 0) + amt; table.insert(tw.tx, 1, { 'in', s, amt, 'From ' .. nameOf(src), now() }); kvSet(tcid, 'crypto', tw)
        w.h[s] = w.h[s] - amt; table.insert(w.tx, 1, { 'out', s, amt, 'To ' .. tname, now() })
        for _, pl in pairs(exports.qbx_core:GetQBPlayers()) do if pl.PlayerData.citizenid == tcid then push(pl.PlayerData.source, 'crypto', tw) end end
    else return { ok = false } end
    while #w.tx > 40 do table.remove(w.tx) end
    kvSet(cid, 'crypto', w); return { ok = true, wallet = w }
end

-- clips + live
H.clipPost = function(src, cid, a) if not a.img then return false end local u = nameOf(src):lower():gsub('%s+', '_')
    local id = MySQL.insert.await('INSERT INTO rox_phone_clips (cid, user, img, caption, at) VALUES (?,?,?,?,?)', { cid, u, a.img, tostring(a.caption or ''):sub(1, 200), now() })
    return { id = id, user = u, img = a.img, caption = a.caption, at = now(), likes = 0 } end
H.clipLike = function(_, cid, a) return like('cl', 'rox_phone_clips', cid, tonumber(a.id), a.on) end
H.liveStart = function(src, _, a) Lives[src] = { title = tostring(a.title or 'LIVE'):sub(1, 60), user = nameOf(src):lower():gsub('%s+', '_'), viewers = {}, earn = 0, peak = 0, likes = 0, gifts = 0 }
    for _, s in ipairs(GetPlayers()) do if tonumber(s) ~= src then push(tonumber(s), 'lives', liveList()) end end return true end
H.liveEnd = function(src, cid)
    local l = Lives[src]; if not l then return false end
    liveSend(src, 'live:ended', { host = src }); Lives[src] = nil
    local w = kvGet(cid, 'wallet', { bal = 0, total = 0, lives = {}, gifts = 0, hist = {} })
    w.bal += l.earn; w.total += l.earn; w.gifts += l.gifts; table.insert(w.lives, l.earn); table.insert(w.hist, 1, { 'LIVE', l.earn }); while #w.lives > 12 do table.remove(w.lives, 1) end
    kvSet(cid, 'wallet', w)
    for _, s in ipairs(GetPlayers()) do push(tonumber(s), 'lives', liveList()) end
    return { earn = l.earn, peak = l.peak, likes = l.likes, gifts = l.gifts, wallet = w }
end
H.liveJoin = function(src, _, a) local l = Lives[tonumber(a.host)]; if not l then return false end l.viewers[src] = true; liveCount(tonumber(a.host))
    liveSend(tonumber(a.host), 'live:chat', { join = true, user = nameOf(src) }) return { title = l.title, user = l.user } end
H.liveLeave = function(src, _, a) local l = Lives[tonumber(a.host)]; if l then l.viewers[src] = nil; liveCount(tonumber(a.host)) end return true end
H.liveChat = function(src, _, a) local h = tonumber(a.host); local l = Lives[h]; if not l then return false end
    if a.heart then l.likes += 1; liveSend(h, 'live:heart', {}) else liveSend(h, 'live:chat', { user = nameOf(src), body = tostring(a.body or ''):sub(1, 120) }) end return true end
H.liveGift = function(src, _, a) local h = tonumber(a.host); local l = Lives[h]; local g = Config.Gifts[tonumber(a.gift) or 0]
    if not l or not g or h == src then return { ok = false } end
    if not P(src).Functions.RemoveMoney('bank', g.price, 'rox_phone-gift') then return { ok = false, msg = 'Not enough money' } end
    bankLog(cidOf(src), 'out', 'Gift to @' .. l.user, g.price); l.earn += g.price; l.gifts += 1
    liveSend(h, 'live:gift', { user = nameOf(src), gift = tonumber(a.gift), price = g.price }) return { ok = true }
end
H.withdraw = function(src, cid) local w = kvGet(cid, 'wallet', nil); if not w or (w.bal or 0) <= 0 then return { ok = false } end
    P(src).Functions.AddMoney('bank', w.bal, 'rox_phone-clips'); bankLog(cid, 'in', 'Clips earnings', w.bal); table.insert(w.hist, 1, { 'Withdraw to bank', -w.bal }); w.bal = 0; kvSet(cid, 'wallet', w)
    return { ok = true, wallet = w } end

-- LSPD / EMS
H.duty = function(src, _, a) local p = P(src); local j = p.PlayerData.job or {}
    if not Config.Services[j.name] then return false end
    p.Functions.SetJobDuty(a.on == true); SetTimeout(200, svcBroadcast) return true end
H.dnd = function(src, _, a) Dnd[src] = a.on == true or nil; push(src, 'svc', svcState(src)) return true end
H.alert = function(src, _, a)
    if not Config.Services[a.job] then return false end
    local ped = GetPlayerPed(src); local c = GetEntityCoords(ped)
    local id = MySQL.insert.await('INSERT INTO rox_phone_alerts (job, reason, msg, x, y, z, street, caller, at) VALUES (?,?,?,?,?,?,?,?,?)',
        { a.job, tostring(a.reason or ''):sub(1, 60), tostring(a.msg or ''):sub(1, 200), c.x, c.y, c.z, tostring(a.street or ''):sub(1, 80), numOf(src), now() })
    local n = 0
    for _, s in ipairs(onDuty(a.job)) do if not Dnd[s] then n += 1; push(s, 'alert', { id = id, job = a.job, reason = a.reason, msg = a.msg, x = c.x, y = c.y, street = a.street, at = now() }) end end
    return { ok = true, units = n }
end

-- people near me (share contact)
H.nearby = function(src) local me = GetEntityCoords(GetPlayerPed(src)); local t = {}
    for _, s in ipairs(GetPlayers()) do s = tonumber(s); if s ~= src then local d = #(GetEntityCoords(GetPlayerPed(s)) - me); if d < 6.0 then t[#t + 1] = { nameOf(s), math.floor(d), s } end end end
    return t end
H.shareContact = function(src, _, a) local t = tonumber(a.to); if not t or #(GetEntityCoords(GetPlayerPed(t)) - GetEntityCoords(GetPlayerPed(src))) > 6.0 then return false end
    local p = P(src); push(t, 'contact', { name = nameOf(src), number = (p.PlayerData.charinfo or {}).phone }) return true end

lib.callback.register('rox_phone:rpc', function(src, name, args)
    local h = H[name]; local cid = cidOf(src); if not h or not cid then return nil end
    local ok, res = pcall(h, src, cid, args or {})
    if not ok then print(('^1[rox_phone] %s: %s^7'):format(name, res)) return nil end
    return res
end)
