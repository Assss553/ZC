-- ROX Store | rox_atm | All rights reserved.
local Open = {}   -- [src] = vector3 where the ATM was opened
local function notify(src, msg, typ) TriggerClientEvent('ox_lib:notify', src, { title = 'ATM', description = msg, type = typ }) end
local function balances(p) return { cash = p.PlayerData.money.cash or 0, bank = p.PlayerData.money.bank or 0 } end

lib.callback.register('rox_atm:open', function(src, coords)
    local p = exports.qbx_core:GetPlayer(src); if not p then return nil end
    local ped = GetPlayerPed(src)
    if not coords or #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z)) > Config.ServerDistance then return nil end
    Open[src] = GetEntityCoords(ped)
    local ci = p.PlayerData.charinfo or {}
    local b = balances(p)
    b.name = ((ci.firstname or '') .. ' ' .. (ci.lastname or ''))
    return b
end)

lib.callback.register('rox_atm:tx', function(src, kind, amount)
    local p = exports.qbx_core:GetPlayer(src)
    local at = Open[src]
    if not p or not at or #(GetEntityCoords(GetPlayerPed(src)) - at) > Config.ServerDistance then return { ok = false, msg = 'Too far from ATM' } end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > Config.MaxPerTransaction then return { ok = false, msg = 'Invalid amount' } end
    local from, to = 'bank', 'cash'
    if kind == 'deposit' then from, to = 'cash', 'bank' elseif kind ~= 'withdraw' then return { ok = false } end
    if (p.PlayerData.money[from] or 0) < amount then return { ok = false, msg = 'Not enough ' .. from } end
    if not p.Functions.RemoveMoney(from, amount, 'atm-' .. kind) then return { ok = false, msg = 'Failed' } end
    p.Functions.AddMoney(to, amount, 'atm-' .. kind)
    notify(src, (kind == 'withdraw' and 'Withdrew $' or 'Deposited $') .. amount, 'success')
    local b = balances(p); b.ok = true
    return b
end)
AddEventHandler('playerDropped', function() Open[source] = nil end)
