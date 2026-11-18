-- ROX Store | rox_bank | All rights reserved.
CreateThread(function()
    MySQL.query.await('CREATE TABLE IF NOT EXISTS rox_bank_tx (id INT AUTO_INCREMENT PRIMARY KEY, cid VARCHAR(50), kind VARCHAR(10), label VARCHAR(120), amount INT, balance INT, at INT, INDEX(cid))')
end)
local function log(cid, kind, label, amount, bal) MySQL.insert('INSERT INTO rox_bank_tx (cid, kind, label, amount, balance, at) VALUES (?,?,?,?,?,?)', { cid, kind, label, amount, bal, os.time() }) end
local function state(p)
    local d, ci = p.PlayerData, p.PlayerData.charinfo or {}
    return { name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')), cid = d.citizenid, phone = ci.phone, account = ci.account or d.citizenid,
        cash = d.money.cash or 0, bank = d.money.bank or 0, job = d.job and d.job.label,
        tx = MySQL.query.await('SELECT kind, label, amount, balance, at FROM rox_bank_tx WHERE cid = ? ORDER BY id DESC LIMIT 60', { d.citizenid }) or {} }
end
lib.callback.register('rox_bank:open', function(src)
    local p = exports.qbx_core:GetPlayer(src); if not p then return nil end
    local near = false; local c = GetEntityCoords(GetPlayerPed(src))
    for _, b in ipairs(Config.Banks) do if #(c - b.coords) < 5.0 then near = true end end
    if not near then return nil end
    return state(p)
end)
local function findTarget(v)
    v = tostring(v or ''); local dg = v:gsub('%D', '')
    for _, t in pairs(exports.qbx_core:GetQBPlayers()) do local d = t.PlayerData; local ci = d.charinfo or {}
        if d.citizenid == v:upper() or (dg ~= '' and tostring(ci.phone or ''):gsub('%D', '') == dg) or tostring(ci.account or '') == v or tostring(d.source) == v then return t end end
end
lib.callback.register('rox_bank:action', function(src, d)
    local p = exports.qbx_core:GetPlayer(src); if not p then return { ok = false } end
    local cid = p.PlayerData.citizenid
    local amt = math.floor(tonumber(d.amount) or 0)
    if d.action ~= 'refresh' and (amt <= 0 or amt > Config.MaxAmount) then return { ok = false, msg = 'Invalid amount' } end
    if d.action == 'deposit' then
        if not p.Functions.RemoveMoney('cash', amt, 'rox_bank-deposit') then return { ok = false, msg = 'Not enough cash' } end
        p.Functions.AddMoney('bank', amt, 'rox_bank-deposit'); log(cid, 'in', 'Cash deposit', amt, p.PlayerData.money.bank)
    elseif d.action == 'withdraw' then
        if not p.Functions.RemoveMoney('bank', amt, 'rox_bank-withdraw') then return { ok = false, msg = 'Not enough money in your account' } end
        p.Functions.AddMoney('cash', amt, 'rox_bank-withdraw'); log(cid, 'out', 'Cash withdrawal', amt, p.PlayerData.money.bank)
    elseif d.action == 'transfer' then
        local t = findTarget(d.to); if not t then return { ok = false, msg = 'Account not found (the person must be in the city)' } end
        if t.PlayerData.source == src then return { ok = false, msg = 'You cannot transfer to yourself' } end
        local fee = math.floor(amt * Config.TransferFeePct / 100)
        if not p.Functions.RemoveMoney('bank', amt + fee, 'rox_bank-transfer') then return { ok = false, msg = 'Not enough money in your account' } end
        t.Functions.AddMoney('bank', amt, 'rox_bank-transfer')
        local tc = t.PlayerData.charinfo or {}; local pc = p.PlayerData.charinfo or {}
        local note = tostring(d.note or ''):sub(1, 60)
        log(cid, 'out', ('To %s %s%s'):format(tc.firstname or '', tc.lastname or '', note ~= '' and ' · ' .. note or ''), amt + fee, p.PlayerData.money.bank)
        log(t.PlayerData.citizenid, 'in', ('From %s %s%s'):format(pc.firstname or '', pc.lastname or '', note ~= '' and ' · ' .. note or ''), amt, t.PlayerData.money.bank)
        TriggerClientEvent('ox_lib:notify', t.PlayerData.source, { title = 'Bank', description = ('You received $%s'):format(amt), type = 'success' })
    end
    local s = state(p); s.ok = true; return s
end)
