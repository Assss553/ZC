-- ROX Store | rox_phone | All rights reserved.
local function decode(v) if type(v) == 'string' then local ok, r = pcall(json.decode, v); return ok and r or {} end return v or {} end

-- vehicles the current character owns (Qbox player_vehicles)
lib.callback.register('rox_phone:garage', function(src)
    local p = exports.qbx_core:GetPlayer(src); if not p then return {} end
    local rows = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', { p.PlayerData.citizenid }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local mods = decode(r.mods)
        local st = tonumber(r.state) or 0
        out[#out + 1] = { model = r.vehicle or r.hash, plate = (r.plate or ''):gsub('^%s+', ''):gsub('%s+$', ''), garage = r.garage or '',
            state = st == 1 and 'GARAGE' or st == 2 and 'IMPOUND' or 'OUT',
            fuel = math.floor(tonumber(r.fuel) or tonumber(mods.fuelLevel) or 100),
            engine = math.floor((tonumber(r.engine) or tonumber(mods.engineHealth) or 1000) / 10),
            body = math.floor((tonumber(r.body) or tonumber(mods.bodyHealth) or 1000) / 10) }
    end
    return out
end)

lib.callback.register('rox_phone:impound', function(src, plate)
    local p = exports.qbx_core:GetPlayer(src); if not p or type(plate) ~= 'string' then return { ok = false } end
    local row = MySQL.single.await('SELECT state FROM player_vehicles WHERE citizenid = ? AND plate = ?', { p.PlayerData.citizenid, plate })
    if not row or tonumber(row.state) ~= 2 then return { ok = false, msg = 'Vehicle is not impounded' } end
    if not p.Functions.RemoveMoney('bank', Config.ImpoundFee, 'rox_phone-impound') then return { ok = false, msg = 'Not enough money in the bank' } end
    MySQL.update.await('UPDATE player_vehicles SET state = 1 WHERE citizenid = ? AND plate = ?', { p.PlayerData.citizenid, plate })
    return { ok = true, msg = 'Released. Pick it up at your garage.' }
end)

RegisterNetEvent('rox_phone:server:lock', function(netId, lock)
    local src = source; local veh = NetworkGetEntityFromNetworkId(netId); if veh == 0 then return end
    local p = exports.qbx_core:GetPlayer(src); if not p then return end
    local plate = GetVehicleNumberPlateText(veh):gsub('^%s+', ''):gsub('%s+$', '')
    local owns = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND plate = ?', { p.PlayerData.citizenid, plate })
    if owns then SetVehicleDoorsLocked(veh, lock and 2 or 1) end
end)

-- bank transfer to a phone number (receiver must be in the city)
lib.callback.register('rox_phone:transfer', function(src, d)
    local p = exports.qbx_core:GetPlayer(src); if not p or d.action ~= 'transfer' then return { ok = false } end
    local amount = math.floor(tonumber(d.amount) or 0); if amount <= 0 or amount > 10000000 then return { ok = false, msg = 'Invalid amount' } end
    local digits = tostring(d.to or ''):gsub('%D', '')
    local target
    for _, t in pairs(exports.qbx_core:GetQBPlayers()) do
        local ph = tostring((t.PlayerData.charinfo or {}).phone or ''):gsub('%D', '')
        if ph ~= '' and ph == digits then target = t break end
    end
    if not target then return { ok = false, msg = 'No one with that number is in the city' } end
    if target.PlayerData.source == src then return { ok = false, msg = 'You cannot send money to yourself' } end
    if not p.Functions.RemoveMoney('bank', amount, 'rox_phone-transfer') then return { ok = false, msg = 'Not enough money' } end
    target.Functions.AddMoney('bank', amount, 'rox_phone-transfer')
    TriggerClientEvent('ox_lib:notify', target.PlayerData.source, { title = 'ROX Bank', description = ('You received $%s'):format(amount), type = 'success' })
    return { ok = true }
end)
