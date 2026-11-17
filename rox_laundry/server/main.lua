--[[ ROX Laundry  ·  © ROX Store – All rights reserved. ]]
local ESX, QB
CreateThread(function()
    local fw = Config.Framework
    if (fw == 'auto' or fw == 'esx') and GetResourceState('es_extended') == 'started' then ESX = exports['es_extended']:getSharedObject()
    elseif (fw == 'auto' or fw == 'qb') and (GetResourceState('qb-core') == 'started') then QB = exports['qb-core']:GetCoreObject() end
end)

local function money(src, amount)        -- remove (amount > 0) or add (amount < 0); standalone = free
    if amount == 0 then return true end
    if ESX then
        local p = ESX.GetPlayerFromId(src); if not p then return false end
        if amount > 0 then if p.getMoney() < amount then return false end p.removeMoney(amount) else p.addMoney(-amount) end
        return true
    elseif QB then
        local p = QB.Functions.GetPlayer(src); if not p then return false end
        if amount > 0 then return p.Functions.RemoveMoney('cash', amount, 'rox-laundry') else p.Functions.AddMoney('cash', -amount, 'rox-laundry') end
        return true
    end
    return true
end

local function item(src, name, count)    -- count > 0 add, < 0 remove
    if not name then return true end
    if GetResourceState('ox_inventory') == 'started' then
        if count > 0 then return exports.ox_inventory:AddItem(src, name, count) end
        return exports.ox_inventory:RemoveItem(src, name, -count)
    elseif ESX then
        local p = ESX.GetPlayerFromId(src); if not p then return false end
        if count > 0 then p.addInventoryItem(name, count) return true end
        local it = p.getInventoryItem(name); if not it or it.count < -count then return false end
        p.removeInventoryItem(name, -count) return true
    elseif QB then
        local p = QB.Functions.GetPlayer(src); if not p then return false end
        if count > 0 then return p.Functions.AddItem(name, count) end
        return p.Functions.RemoveItem(name, -count)
    end
    return true
end

-- per player: { stage = 'idle'|'washing'|'washed'|'drying'|'dried', machine, t, quality }
local state, inUse = {}, {}
local function S(src) state[src] = state[src] or { stage = 'idle' } return state[src] end

local location = Config.Location
CreateThread(function()
    local saved = GetResourceKvpString('rox_laundry_location')
    if saved then local d = json.decode(saved); if d then location = vec4(d.x, d.y, d.z, d.w) end end
    TriggerClientEvent('rox_laundry:location', -1, location)
end)
RegisterNetEvent('rox_laundry:hello', function() TriggerClientEvent('rox_laundry:location', source, location); TriggerClientEvent('rox_laundry:busy', source, inUse) end)

RegisterCommand('roxlaundry_here', function(src)
    if src ~= 0 and not IsPlayerAceAllowed(src, Config.AdminAce) then return end
    local ped = GetPlayerPed(src); local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    -- the player stands at the front door looking at the shop: put the building behind him
    local r = math.rad(h); local fx, fy = -math.sin(r), math.cos(r)
    location = vec4(c.x + fx * 6.5, c.y + fy * 6.5, c.z - 1.0, h)   -- building centre is 6.5 m behind the door
    SetResourceKvp('rox_laundry_location', json.encode({ x = location.x, y = location.y, z = location.z, w = location.w }))
    TriggerClientEvent('rox_laundry:location', -1, location)
    TriggerClientEvent('rox_laundry:notify', src, L('placed'))
end, false)

local function point(id) return LaundryPoints[tonumber(id) or -1] end
local function setBusy(id, v) inUse[id] = v; TriggerClientEvent('rox_laundry:busy', -1, inUse) end

RegisterNetEvent('rox_laundry:start', function(id)
    local src, p, st = source, point(id), S(source)
    if not p then return end
    local ok, err = false, nil
    if inUse[p.id] and inUse[p.id] ~= src then err = L('busy')
    elseif p.kind == 'washer' then
        if st.stage ~= 'idle' then err = L('have_load')
        elseif Config.Reward.requireItem and not item(src, Config.Reward.requireItem, -1) then err = L('no_item')
        elseif not money(src, Config.Prices.wash) then err = L('no_money') else ok = true end
    elseif p.kind == 'dryer' then
        if st.stage ~= 'washed' then err = L('need_wash') elseif not money(src, Config.Prices.dry) then err = L('no_money') else ok = true end
    elseif p.kind == 'fold' then
        if st.stage ~= 'dried' then err = L('need_dry') else ok = true end
    end
    if not ok then TriggerClientEvent('rox_laundry:denied', src, err or L('cancelled')) return end
    if p.kind ~= 'fold' then setBusy(p.id, src) end
    st.machine, st.t = p.id, os.time()
    TriggerClientEvent('rox_laundry:open', src, p.kind, p.id, { prices = Config.Prices, times = Config.Times, currency = Config.Currency, quality = st.quality })
end)

RegisterNetEvent('rox_laundry:finish', function(id, kind, score)
    local src, st = source, S(source)
    local p = point(id); score = math.max(0.0, math.min(1.0, tonumber(score) or 0))
    if not p or st.machine ~= p.id or p.kind ~= kind then return end
    local need = (kind == 'washer' and Config.Times.wash) or (kind == 'dryer' and Config.Times.dry) or 3
    if os.time() - (st.t or 0) < need - 2 then TriggerClientEvent('rox_laundry:denied', src, L('too_fast')) setBusy(p.id, nil) return end
    setBusy(p.id, nil)
    if kind == 'washer' then st.stage, st.quality = 'washed', score * 0.5
    elseif kind == 'dryer' then st.stage, st.quality = 'dried', (st.quality or 0) + score * 0.3
    elseif kind == 'fold' then
        local q = math.min(1.0, (st.quality or 0) + score * 0.2)
        local pay = math.floor(Config.Reward.money * (0.4 + 0.6 * q) + 0.5)
        money(src, -pay); if Config.Reward.item then item(src, Config.Reward.item, 1) end
        state[src] = { stage = 'idle' }
        TriggerClientEvent('rox_laundry:notify', src, L('done', Config.Currency .. pay))
        return
    end
    st.machine = nil
end)

RegisterNetEvent('rox_laundry:cancel', function()
    local src = source; local st = S(src)
    if st.machine and inUse[st.machine] == src then setBusy(st.machine, nil) end
    st.machine = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, who in pairs(inUse) do if who == src then inUse[id] = nil end end
    state[src] = nil
    TriggerClientEvent('rox_laundry:busy', -1, inUse)
end)
