-- ROX Store | All rights reserved
local ITEMS, TINTS = {}, {}
for _, tab in ipairs(Config.Shop) do
    for _, cat in ipairs(tab.cats) do
        for _, it in ipairs(cat.items) do ITEMS[it.name] = { item = it, tab = tab.id } end
    end
end
for _, t in ipairs(Config.Tints) do TINTS[t[1]] = t end

local function nearShop(src)
    local p = GetEntityCoords(GetPlayerPed(src))
    for _, c in ipairs(Config.Locations) do if #(p - c) < 8.0 then return true end end
    return false
end

lib.callback.register('rox_gunstore:wallet', function(src)
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return {} end
    local lic = p.PlayerData.metadata and p.PlayerData.metadata.licences or {}
    return { cash = p.PlayerData.money.cash or 0, bank = p.PlayerData.money.bank or 0, licences = lic }
end)

lib.callback.register('rox_gunstore:buy', function(src, name, tint)
    local e = ITEMS[name]
    if not e or not nearShop(src) then return false, 'Not available' end
    local p = exports.qbx_core:GetPlayer(src)
    if not p then return false end
    local need = Config.LicenseFor[e.tab]
    if need then
        local lic = p.PlayerData.metadata and p.PlayerData.metadata.licences or {}
        if not lic[need] then return false, 'You need a ' .. need .. ' licence' end
    end
    local price, meta = e.item.price, nil
    local t = tint and TINTS[tint]
    if t and name:sub(1, 7) == 'WEAPON_' then price = price + t[3]; meta = { tint = t[1] } end
    local count = e.item.count or 1
    if not exports.ox_inventory:CanCarryItem(src, name, count, meta) then return false, 'You cannot carry that' end
    if GetResourceState('rox_weaponrules') == 'started' and not exports.rox_weaponrules:canCarry(src, name) then
        return false, 'You cannot carry more weapons of that type'
    end
    local paid
    for _, acc in ipairs(Config.Payment) do
        if (p.PlayerData.money[acc] or 0) >= price and p.Functions.RemoveMoney(acc, price, 'gunstore') then paid = acc; break end
    end
    if not paid then return false, 'Not enough money' end
    if not exports.ox_inventory:AddItem(src, name, count, meta) then
        p.Functions.AddMoney(paid, price, 'gunstore-refund')
        return false, 'Inventory full'
    end
    return true, nil, { cash = p.PlayerData.money.cash, bank = p.PlayerData.money.bank }
end)
