-- ROX Store | All rights reserved
local function near(src)
    local p = GetEntityCoords(GetPlayerPed(src))
    for _, c in ipairs(Config.Locations) do if #(p - c) < 15.0 then return true end end
end
local function pay(src, price)
    local p = exports.qbx_core:GetPlayer(src); if not p then return false end
    for _, acc in ipairs(Config.Payment) do
        if (p.PlayerData.money[acc] or 0) >= price and p.Functions.RemoveMoney(acc, price, 'mechanic') then return true, p end
    end
    return false
end

lib.callback.register('rox_mechanic:wallet', function(src)
    local p = exports.qbx_core:GetPlayer(src); if not p then return {} end
    return { cash = p.PlayerData.money.cash or 0, bank = p.PlayerData.money.bank or 0 }
end)

-- client tells which part + the current level it sees; server prices it and charges
lib.callback.register('rox_mechanic:buy', function(src, partIndex, curLevel)
    local part = Config.Parts[tonumber(partIndex) or 0]
    if not part or not near(src) then return false, 'Not available' end
    local veh = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if veh == 0 then return false, 'You need to be in a vehicle' end
    local price
    if part.repair then price = Config.RepairPrice
    else
        local nextLevel = (tonumber(curLevel) or -1) + 2          -- -1 = stock -> level 1
        price = part.prices[nextLevel]
        if not price then return false, 'Already maxed' end
    end
    local ok, p = pay(src, price)
    if not ok then return false, 'Not enough money' end
    return true, nil, { cash = p.PlayerData.money.cash, bank = p.PlayerData.money.bank }
end)

-- save upgrades on owned vehicles (qbx player_vehicles.mods)
RegisterNetEvent('rox_mechanic:save', function(netId, props)
    local src = source
    if type(props) ~= 'table' or type(props.plate) ~= 'string' or not near(src) then return end
    local p = exports.qbx_core:GetPlayer(src); if not p then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or GetVehiclePedIsIn(GetPlayerPed(src), false) ~= veh then return end
    local plate = props.plate:gsub('^%s*(.-)%s*$', '%1')
    if GetResourceState('oxmysql') ~= 'started' then return end
    MySQL.update('UPDATE player_vehicles SET mods = ? WHERE TRIM(plate) = ? AND citizenid = ?', { json.encode(props), plate, p.PlayerData.citizenid })
end)
