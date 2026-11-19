-- ROX Store | All rights reserved
local function near(src)
    local p = GetEntityCoords(GetPlayerPed(src))
    for _, c in ipairs(Config.Locations) do if #(p - c) < 12.0 then return true end end
end

lib.callback.register('rox_clothes:wallet', function(src)
    local p = exports.qbx_core:GetPlayer(src); if not p then return {} end
    return { cash = p.PlayerData.money.cash or 0, bank = p.PlayerData.money.bank or 0 }
end)

lib.callback.register('rox_clothes:buy', function(src, catIndex)
    local cat = Config.Categories[tonumber(catIndex) or 0]
    if not cat or not near(src) then return false, 'Not available' end
    local p = exports.qbx_core:GetPlayer(src); if not p then return false end
    for _, acc in ipairs(Config.Payment) do
        if (p.PlayerData.money[acc] or 0) >= cat.price and p.Functions.RemoveMoney(acc, cat.price, 'clothing') then
            if cat.armor then SetPedArmour(GetPlayerPed(src), math.max(GetPedArmour(GetPlayerPed(src)), cat.armor)) end
            return true, nil, { cash = p.PlayerData.money.cash, bank = p.PlayerData.money.bank }
        end
    end
    return false, 'Not enough money'
end)
