local FW, Core = 'standalone', nil
local busy, lastTest, pendingProps = {}, {}, {}
local byModel = {}
for _, v in ipairs(Config.Vehicles) do byModel[v.model] = v end
local allowedPay = {}
for _, p in ipairs(Config.Payments) do allowedPay[p] = true end

CreateThread(function()
    if Config.Framework ~= 'auto' then FW = Config.Framework
    elseif GetResourceState('qb-core') == 'started' then FW = 'qb'
    elseif GetResourceState('es_extended') == 'started' then FW = 'esx' end
    if FW == 'qb' then Core = exports['qb-core']:GetCoreObject()
    elseif FW == 'esx' then Core = exports['es_extended']:getSharedObject() end
    print(('^2[VC2]^7 started (framework: %s)'):format(FW))
end)

---------------------------------------------------------------- db
local function db(fn, q, p)
    local pr = promise.new()
    exports.oxmysql[fn](exports.oxmysql, q, p, function(r) pr:resolve(r) end)
    return Citizen.Await(pr)
end

---------------------------------------------------------------- player
local function getPlayer(src)
    if FW == 'qb' then return Core.Functions.GetPlayer(src) end
    if FW == 'esx' then return Core.GetPlayerFromId(src) end
    return true
end

local function getMoney(src)
    local P = getPlayer(src)
    if not P then return { cash = 0, bank = 0 } end
    if FW == 'qb' then
        return { cash = P.PlayerData.money.cash or 0, bank = P.PlayerData.money.bank or 0 }
    elseif FW == 'esx' then
        local bank = P.getAccount('bank')
        return { cash = P.getMoney(), bank = bank and bank.money or 0 }
    end
    return { cash = 9999999, bank = 9999999 }
end

local function removeMoney(src, account, amount)
    local P = getPlayer(src)
    if not P then return false end
    if FW == 'qb' then return P.Functions.RemoveMoney(account, amount, 'vc2-vehicle-purchase') end
    if FW == 'esx' then
        if account == 'cash' then P.removeMoney(amount) else P.removeAccountMoney('bank', amount) end
        return true
    end
    return true
end

local function addMoney(src, account, amount)
    local P = getPlayer(src)
    if not P then return end
    if FW == 'qb' then P.Functions.AddMoney(account, amount, 'vc2-refund')
    elseif FW == 'esx' then
        if account == 'cash' then P.addMoney(amount) else P.addAccountMoney('bank', amount) end
    end
end

local function nearKiosk(src, idx)
    local k = Config.Kiosks[tonumber(idx) or 0]
    if not k then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - k.coords.xyz) <= Config.MaxServerDistance
end

---------------------------------------------------------------- plates
local function randomPlate()
    local s = Config.PlateFormat:gsub('#', function() return tostring(math.random(0, 9)) end)
    s = s:gsub('@', function() return string.char(math.random(65, 90)) end)
    return s:upper()
end

local function plateTaken(plate)
    if FW == 'qb' then return db('scalar', 'SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) ~= nil end
    if FW == 'esx' then return db('scalar', 'SELECT 1 FROM owned_vehicles WHERE plate = ?', { plate }) ~= nil end
    return false
end

local function newPlate()
    for _ = 1, 50 do
        local p = randomPlate()
        if not plateTaken(p) then return p end
    end
end

local function saveVehicle(src, v, plate)
    local P = getPlayer(src)
    local base = json.encode({ model = joaat(v.model), plate = plate })
    if FW == 'qb' then
        return db('insert', 'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { P.PlayerData.license, P.PlayerData.citizenid, v.model, joaat(v.model), base, plate, Config.QBGarage, 0 }) ~= nil
    elseif FW == 'esx' then
        return db('insert', 'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, ?)',
            { P.identifier, plate, base, 'car', 0 }) ~= nil
    end
    return true
end

local function log(src, v, plate, payment)
    if Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = 'VC2 Showroom',
        embeds = { {
            title = 'Vehicle purchased',
            color = 15028252,
            description = ('**Player:** %s (%s)\n**Vehicle:** %s\n**Price:** %s%s\n**Plate:** %s\n**Payment:** %s')
                :format(GetPlayerName(src), src, v.label or v.model, Config.Currency, v.price, plate, payment)
        } }
    }), { ['Content-Type'] = 'application/json' })
end

---------------------------------------------------------------- callbacks
local Callbacks = {}

Callbacks['vc2:money'] = function(src)
    return getMoney(src)
end

Callbacks['vc2:testdrive'] = function(src, model, kiosk)
    if not Config.TestDrive.enabled then return false, 'Test drives are disabled' end
    if not byModel[model] then return false, 'This vehicle is not available' end
    if not nearKiosk(src, kiosk) then return false, 'You must be at the kiosk' end
    local now = os.time()
    local last = lastTest[src]
    if last and now - last < Config.TestDrive.cooldown then
        return false, ('Please wait %d seconds before another test drive'):format(Config.TestDrive.cooldown - (now - last))
    end
    lastTest[src] = now
    return true
end

Callbacks['vc2:buy'] = function(src, model, colorIdx, payment, kiosk)
    local v = byModel[model]
    if not v then return { ok = false, msg = 'This vehicle is not available' } end
    if not allowedPay[payment] then return { ok = false, msg = 'This payment method is not allowed' } end
    if not nearKiosk(src, kiosk) then return { ok = false, msg = 'You must be at the kiosk' } end
    local color = Config.Colors[tonumber(colorIdx) or 1] and tonumber(colorIdx) or 1
    if busy[src] then return { ok = false, msg = 'A transaction is already in progress' } end
    busy[src] = true

    local money = getMoney(src)
    if (money[payment] or 0) < v.price then
        busy[src] = nil
        return { ok = false, msg = 'Not enough money' }
    end
    local plate = newPlate()
    if not plate then busy[src] = nil return { ok = false, msg = 'Could not create a plate, please try again' } end
    if not removeMoney(src, payment, v.price) then busy[src] = nil return { ok = false, msg = 'Not enough money' } end

    local ok, saved = pcall(saveVehicle, src, v, plate)
    if not ok or not saved then
        addMoney(src, payment, v.price)
        busy[src] = nil
        return { ok = false, msg = 'Database error, your money was refunded' }
    end

    local order = GetResourceKvpInt('vc2_order') + 1
    SetResourceKvpInt('vc2_order', order)
    pendingProps[plate] = src
    busy[src] = nil
    log(src, v, plate, payment)

    return {
        ok = true,
        money = getMoney(src),
        receipt = {
            order = order,
            plate = plate,
            model = v.model,
            vehicle = v.label or v.model,
            color = Config.Colors[color].label,
            colorIndex = color,
            price = v.price,
            payment = payment,
        }
    }
end

RegisterNetEvent('vc2:cb:req', function(name, id, ...)
    local src = source
    local fn = Callbacks[name]
    if not fn then return end
    TriggerClientEvent('vc2:cb:res', src, id, fn(src, ...))
end)

RegisterNetEvent('vc2:setProps', function(plate, props)
    local src = source
    if pendingProps[plate] ~= src or type(props) ~= 'table' then return end
    pendingProps[plate] = nil
    props.plate = plate
    local data = json.encode(props)
    if FW == 'qb' then db('update', 'UPDATE player_vehicles SET mods = ? WHERE plate = ?', { data, plate })
    elseif FW == 'esx' then db('update', 'UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', { data, plate }) end
end)

AddEventHandler('playerDropped', function()
    busy[source], lastTest[source] = nil, nil
end)
