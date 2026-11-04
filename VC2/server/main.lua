local FW, Core = 'standalone', nil
local busy, lastTest, pendingSpawn = {}, {}, {}
local active = {}   -- plate -> entity handle of the VC2 car currently in the world
local byModel = {}
for _, v in ipairs(Config.Vehicles) do byModel[v.model] = v end
local allowedPay = {}
for _, p in ipairs(Config.Payments) do allowedPay[p] = true end
local orderTypes = {}
for _, t in ipairs(Config.Orders.types) do orderTypes[t] = true end

local function modelHash(m)
    local n = tostring(m):match('^#(%-?%d+)$')
    return n and tonumber(n) or joaat(m)
end

---------------------------------------------------------------- db
local function db(fn, q, p)
    local pr = promise.new()
    exports.oxmysql[fn](exports.oxmysql, q, p or {}, function(r) pr:resolve(r) end)
    return Citizen.Await(pr)
end

CreateThread(function()
    if Config.Framework ~= 'auto' then FW = Config.Framework
    elseif GetResourceState('qb-core') == 'started' then FW = 'qb'
    elseif GetResourceState('es_extended') == 'started' then FW = 'esx' end
    if FW == 'qb' then Core = exports['qb-core']:GetCoreObject()
    elseif FW == 'esx' then Core = exports['es_extended']:getSharedObject() end

    db('query', [[CREATE TABLE IF NOT EXISTS `vc2_vehicles` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `plate` VARCHAR(12) NOT NULL UNIQUE,
        `owner` VARCHAR(64) NOT NULL,
        `owner_name` VARCHAR(64) DEFAULT NULL,
        `model` VARCHAR(64) NOT NULL,
        `color` INT DEFAULT 1,
        `props` LONGTEXT DEFAULT NULL,
        `origin` VARCHAR(16) DEFAULT 'showroom',
        `price` INT DEFAULT 0,
        `impounded` TINYINT DEFAULT 0,
        `body` FLOAT DEFAULT 1000,
        `engine` FLOAT DEFAULT 1000,
        `fuel` FLOAT DEFAULT 100,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX (`owner`))]])
    -- upgrade tables created by older VC2 versions
    for col, def in pairs({ body = 'FLOAT DEFAULT 1000', engine = 'FLOAT DEFAULT 1000', fuel = 'FLOAT DEFAULT 100' }) do
        local has = db('scalar', "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'vc2_vehicles' AND COLUMN_NAME = ?", { col })
        if has == 0 then db('query', ('ALTER TABLE `vc2_vehicles` ADD COLUMN `%s` %s'):format(col, def)) end
    end
    db('query', [[CREATE TABLE IF NOT EXISTS `vc2_orders` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `owner` VARCHAR(64) NOT NULL,
        `owner_name` VARCHAR(64) DEFAULT NULL,
        `base` VARCHAR(64) DEFAULT NULL,
        `type` VARCHAR(16) DEFAULT NULL,
        `color` INT DEFAULT 1,
        `budget` INT DEFAULT 0,
        `specs` TEXT,
        `status` VARCHAR(16) DEFAULT 'pending',
        `model` VARCHAR(64) DEFAULT NULL,
        `price` INT DEFAULT NULL,
        `note` VARCHAR(255) DEFAULT NULL,
        `handled_by` VARCHAR(64) DEFAULT NULL,
        `plate` VARCHAR(12) DEFAULT NULL,
        `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX (`owner`))]])
    print(('^2[VC2]^7 started (framework: %s)'):format(FW))
end)

---------------------------------------------------------------- player
local function getPlayer(src)
    if FW == 'qb' then return Core.Functions.GetPlayer(src) end
    if FW == 'esx' then return Core.GetPlayerFromId(src) end
    return true
end

local function identifier(src)
    local P = getPlayer(src)
    if not P then return nil end
    if FW == 'qb' then return P.PlayerData.citizenid end
    if FW == 'esx' then return P.identifier end
    return GetPlayerIdentifierByType(src, 'license')
end

local function playerName(src)
    local P = getPlayer(src)
    if FW == 'qb' and P then
        local c = P.PlayerData.charinfo or {}
        if c.firstname then return c.firstname .. ' ' .. (c.lastname or '') end
    elseif FW == 'esx' and P then
        return P.getName()
    end
    return GetPlayerName(src)
end

local function sourceOf(ident)
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        if identifier(s) == ident then return s end
    end
end

local function notify(src, msg, kind)
    TriggerClientEvent('vc2:notify', src, msg, kind)
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
    if amount <= 0 then return true end
    local P = getPlayer(src)
    if not P then return false end
    if (getMoney(src)[account] or 0) < amount then return false end
    if FW == 'qb' then return P.Functions.RemoveMoney(account, amount, 'vc2') end
    if FW == 'esx' then
        if account == 'cash' then P.removeMoney(amount) else P.removeAccountMoney('bank', amount) end
    end
    return true
end

local function addMoney(src, account, amount)
    if amount <= 0 then return end
    local P = getPlayer(src)
    if not P then return end
    if FW == 'qb' then P.Functions.AddMoney(account, amount, 'vc2-refund')
    elseif FW == 'esx' then
        if account == 'cash' then P.addMoney(amount) else P.addAccountMoney('bank', amount) end
    end
end

-- pay with the chosen account, fall back to the other one
local function charge(src, preferred, amount)
    if amount <= 0 then return preferred end
    if removeMoney(src, preferred, amount) then return preferred end
    for _, p in ipairs(Config.Payments) do
        if p ~= preferred and removeMoney(src, p, amount) then return p end
    end
end

local function isManager(src)
    local m = Config.Orders.managers
    if m.ace and IsPlayerAceAllowed(src, m.ace) then return true end
    local P = getPlayer(src)
    if FW == 'qb' and P then
        local j = P.PlayerData.job
        local min = j and m.jobs[j.name]
        return min ~= nil and (j.grade.level or 0) >= min
    elseif FW == 'esx' and P then
        local j = P.job
        local min = j and m.jobs[j.name]
        return min ~= nil and (j.grade or 0) >= min
    end
    return false
end

local function near(src, point, idx)
    local p = point[tonumber(idx) or 0]
    if not p then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - p.coords.xyz) <= Config.MaxServerDistance
end

---------------------------------------------------------------- plates & saving
local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function randomPlate()
    local s = Config.PlateFormat:gsub('#', function() return tostring(math.random(0, 9)) end)
    s = s:gsub('@', function() return string.char(math.random(65, 90)) end)
    return s:upper()
end

local function plateTaken(plate)
    if db('scalar', 'SELECT 1 FROM vc2_vehicles WHERE plate = ?', { plate }) then return true end
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

-- stores the car in the framework garage table AND in vc2_vehicles (the VC2 ownership record)
local function saveVehicle(src, model, plate, color, price, origin)
    local P = getPlayer(src)
    local base = json.encode({ model = modelHash(model), plate = plate })
    local ok = true
    if FW == 'qb' then
        ok = db('insert', 'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { P.PlayerData.license, P.PlayerData.citizenid, model, modelHash(model), base, plate, Config.QBGarage, 0 }) ~= nil
    elseif FW == 'esx' then
        ok = db('insert', 'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, ?)',
            { P.identifier, plate, base, 'car', 0 }) ~= nil
    end
    if not ok then return false end
    return db('insert', 'INSERT INTO vc2_vehicles (plate, owner, owner_name, model, color, origin, price) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { plate, identifier(src), playerName(src), model, color, origin, price }) ~= nil
end

local function log(src, title, text)
    if Config.Webhook == '' then return end
    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = 'VC2 Showroom',
        embeds = { { title = title, color = 15028252, description = ('**Player:** %s (%s)\n%s'):format(GetPlayerName(src), src, text) } }
    }), { ['Content-Type'] = 'application/json' })
end

local function nextOrderNumber()
    local n = GetResourceKvpInt('vc2_order') + 1
    SetResourceKvpInt('vc2_order', n)
    return n
end

local function colorIndex(c)
    c = tonumber(c) or 1
    return Config.Colors[c] and c or 1
end

---------------------------------------------------------------- vehicle state
local function activeEntity(plate)
    local ent = active[plate]
    if ent and DoesEntityExist(ent) then return ent end
    active[plate] = nil
end

local function vehicleStatus(row)
    if row.impounded == 1 or row.impounded == true then return 'impounded' end
    local ent = activeEntity(row.plate)
    if ent then
        if GetEntityHealth(ent) <= 0 or GetVehicleEngineHealth(ent) <= 0 then return 'destroyed' end
        return 'out'
    end
    return 'stored'
end

AddEventHandler('entityRemoved', function(ent)
    local ok, st = pcall(function() return Entity(ent).state.vc2 end)
    if ok and st and st.plate and active[st.plate] == ent then active[st.plate] = nil end
end)

-- client tells us it spawned an owned VC2 car; we tag it so the whole server knows it is ours
RegisterNetEvent('vc2:spawned', function(netId, plate, props)
    local src = source
    if pendingSpawn[plate] ~= src then return end
    pendingSpawn[plate] = nil
    local ent
    for _ = 1, 50 do
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then break end
        Wait(100)
    end
    if not ent or ent == 0 or trim(GetVehicleNumberPlateText(ent)) ~= trim(plate) then return end
    local row = db('single', 'SELECT owner, origin, model FROM vc2_vehicles WHERE plate = ?', { plate })
    if not row then return end
    local old = activeEntity(plate)
    if old and old ~= ent then DeleteEntity(old) end
    active[plate] = ent
    Entity(ent).state:set('vc2', { plate = plate, owner = row.owner, origin = row.origin, model = row.model }, true)
    if type(props) == 'table' then
        props.plate = plate
        local data = json.encode(props)
        db('update', 'UPDATE vc2_vehicles SET props = ? WHERE plate = ?', { data, plate })
        if FW == 'qb' then db('update', 'UPDATE player_vehicles SET mods = ? WHERE plate = ?', { data, plate })
        elseif FW == 'esx' then db('update', 'UPDATE owned_vehicles SET vehicle = ? WHERE plate = ?', { data, plate }) end
    end
end)

---------------------------------------------------------------- callbacks
local Callbacks = {}

Callbacks['vc2:money'] = function(src)
    return getMoney(src)
end

Callbacks['vc2:testdrive'] = function(src, model, kiosk)
    if not Config.TestDrive.enabled then return false, 'Test drives are disabled' end
    if not byModel[model] then return false, 'This vehicle is not available' end
    if not near(src, Config.Kiosks, kiosk) then return false, 'You must be at the kiosk' end
    local now = os.time()
    local last = lastTest[src]
    if last and now - last < Config.TestDrive.cooldown then
        return false, ('Please wait %d seconds before another test drive'):format(Config.TestDrive.cooldown - (now - last))
    end
    lastTest[src] = now
    return true
end

-- shared purchase routine (showroom car or custom order)
local function purchase(src, model, color, payment, price, origin)
    if busy[src] then return { ok = false, msg = 'A transaction is already in progress' } end
    busy[src] = true
    local plate = newPlate()
    if not plate then busy[src] = nil return { ok = false, msg = 'Could not create a plate, please try again' } end
    local paid = charge(src, payment, price)
    if not paid then busy[src] = nil return { ok = false, msg = 'Not enough money' } end
    local ok, saved = pcall(saveVehicle, src, model, plate, color, price, origin)
    if not ok or not saved then
        addMoney(src, paid, price)
        busy[src] = nil
        return { ok = false, msg = 'Database error, your money was refunded' }
    end
    pendingSpawn[plate] = src
    busy[src] = nil
    return {
        ok = true,
        money = getMoney(src),
        receipt = {
            order = nextOrderNumber(), plate = plate, model = model, vehicle = model,
            color = Config.Colors[color].label, colorIndex = color, price = price, payment = paid,
        }
    }
end

Callbacks['vc2:buy'] = function(src, model, colorIdx, payment, kiosk)
    local v = byModel[model]
    if not v then return { ok = false, msg = 'This vehicle is not available' } end
    if not allowedPay[payment] then return { ok = false, msg = 'This payment method is not allowed' } end
    if not near(src, Config.Kiosks, kiosk) then return { ok = false, msg = 'You must be at the kiosk' } end
    if (getMoney(src)[payment] or 0) < v.price then return { ok = false, msg = 'Not enough money' } end
    local res = purchase(src, model, colorIndex(colorIdx), payment, v.price, 'showroom')
    if res.ok then log(src, 'Vehicle purchased', ('**Vehicle:** %s\n**Price:** %s%s\n**Plate:** %s'):format(model, Config.Currency, v.price, res.receipt.plate)) end
    return res
end

-------- custom orders (player)
local function myOrders(src)
    return db('query', 'SELECT id, base, type, color, budget, specs, status, model, price, note, plate, UNIX_TIMESTAMP(created_at) AS created FROM vc2_orders WHERE owner = ? ORDER BY id DESC LIMIT 20', { identifier(src) }) or {}
end

Callbacks['vc2:myOrders'] = function(src)
    return myOrders(src)
end

Callbacks['vc2:orderSubmit'] = function(src, d, kiosk)
    if not Config.Orders.enabled then return { ok = false, msg = 'Custom orders are disabled' } end
    if type(d) ~= 'table' then return { ok = false, msg = 'Invalid order' } end
    if not near(src, Config.Kiosks, kiosk) then return { ok = false, msg = 'You must be at the kiosk' } end
    local base, specs = trim(d.base):sub(1, 60), trim(d.specs):sub(1, 500)
    local budget = math.floor(tonumber(d.budget) or 0)
    if #specs < 10 then return { ok = false, msg = 'Describe the car you want (at least 10 characters)' } end
    if not orderTypes[d.type] then return { ok = false, msg = 'Pick a vehicle type' } end
    if budget < 0 or budget > Config.Orders.maxPrice then return { ok = false, msg = 'Invalid budget' } end
    local ident = identifier(src)
    local open = db('scalar', "SELECT COUNT(*) FROM vc2_orders WHERE owner = ? AND status IN ('pending','ready')", { ident }) or 0
    if open >= Config.Orders.maxActive then return { ok = false, msg = ('You can only have %d open orders'):format(Config.Orders.maxActive) } end
    local id = db('insert', 'INSERT INTO vc2_orders (owner, owner_name, base, type, color, budget, specs) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { ident, playerName(src), base, d.type, colorIndex(d.color), budget, specs })
    if not id then return { ok = false, msg = 'Database error' } end
    for _, p in ipairs(GetPlayers()) do
        local s = tonumber(p)
        if isManager(s) then notify(s, ('New custom car order #%d from %s (/%s)'):format(id, playerName(src), Config.Orders.command), 'primary') end
    end
    log(src, 'Custom order #' .. id, ('**Type:** %s\n**Base:** %s\n**Budget:** %s%s\n**Specs:** %s'):format(d.type, base, Config.Currency, budget, specs))
    return { ok = true, id = id, orders = myOrders(src) }
end

Callbacks['vc2:orderCollect'] = function(src, id, payment, kiosk)
    if not allowedPay[payment] then return { ok = false, msg = 'This payment method is not allowed' } end
    if not near(src, Config.Kiosks, kiosk) then return { ok = false, msg = 'You must be at the kiosk' } end
    local o = db('single', 'SELECT * FROM vc2_orders WHERE id = ? AND owner = ?', { tonumber(id), identifier(src) })
    if not o or o.status ~= 'ready' then return { ok = false, msg = 'This order is not ready' } end
    -- lock the order first so it cannot be collected twice
    local changed = db('update', "UPDATE vc2_orders SET status = 'collecting' WHERE id = ? AND status = 'ready'", { o.id })
    if changed ~= 1 then return { ok = false, msg = 'This order is not ready' } end
    local res = purchase(src, o.model, colorIndex(o.color), payment, o.price or 0, 'custom')
    if not res.ok then
        db('update', "UPDATE vc2_orders SET status = 'ready' WHERE id = ?", { o.id })
        return res
    end
    db('update', "UPDATE vc2_orders SET status = 'delivered', plate = ? WHERE id = ?", { res.receipt.plate, o.id })
    res.receipt.order = o.id
    res.orders = myOrders(src)
    log(src, 'Custom order collected #' .. o.id, ('**Vehicle:** %s\n**Price:** %s%s\n**Plate:** %s'):format(o.model, Config.Currency, o.price or 0, res.receipt.plate))
    return res
end

-------- custom orders (workshop / admin)
Callbacks['vc2:mgrOrders'] = function(src, filter)
    if not isManager(src) then return nil end
    local where = ({ pending = "WHERE status = 'pending'", ready = "WHERE status = 'ready'", done = "WHERE status IN ('delivered','rejected')" })[filter] or ''
    return db('query', 'SELECT id, owner_name, base, type, color, budget, specs, status, model, price, note, handled_by, plate, UNIX_TIMESTAMP(created_at) AS created FROM vc2_orders ' .. where .. ' ORDER BY id DESC LIMIT 100') or {}
end

Callbacks['vc2:mgrBuild'] = function(src, id, model, price, note)
    if not isManager(src) then return { ok = false, msg = 'No permission' } end
    model = trim(model):lower()
    price = math.floor(tonumber(price) or -1)
    if not model:match('^[%w_%-]+$') or #model > 32 then return { ok = false, msg = 'Invalid spawn code' } end
    if price < 0 or price > Config.Orders.maxPrice then return { ok = false, msg = 'Invalid price' } end
    local o = db('single', 'SELECT owner, status FROM vc2_orders WHERE id = ?', { tonumber(id) })
    if not o or (o.status ~= 'pending' and o.status ~= 'ready') then return { ok = false, msg = 'This order cannot be changed' } end
    db('update', "UPDATE vc2_orders SET status = 'ready', model = ?, price = ?, note = ?, handled_by = ? WHERE id = ?",
        { model, price, trim(note):sub(1, 255), playerName(src), tonumber(id) })
    local owner = sourceOf(o.owner)
    if owner then notify(owner, ('Your custom car (order #%d) is ready! Pay and collect it at the VC2 kiosk.'):format(id), 'success') end
    log(src, 'Custom order built #' .. id, ('**Spawn code:** %s\n**Price:** %s%s'):format(model, Config.Currency, price))
    return { ok = true }
end

Callbacks['vc2:mgrReject'] = function(src, id, note)
    if not isManager(src) then return { ok = false, msg = 'No permission' } end
    local o = db('single', 'SELECT owner, status FROM vc2_orders WHERE id = ?', { tonumber(id) })
    if not o or (o.status ~= 'pending' and o.status ~= 'ready') then return { ok = false, msg = 'This order cannot be changed' } end
    db('update', "UPDATE vc2_orders SET status = 'rejected', note = ?, handled_by = ? WHERE id = ?", { trim(note):sub(1, 255), playerName(src), tonumber(id) })
    local owner = sourceOf(o.owner)
    if owner then notify(owner, ('Your custom car order #%d was declined.'):format(id), 'error') end
    return { ok = true }
end

-------- recovery (NPC garages)
local function feeFor(status)
    return status == 'impounded' and Config.Retrieve.impoundFee or Config.Retrieve.fee
end

local function pct(v, max) return math.floor(math.max(0, math.min(100, (tonumber(v) or 0) / max * 100)) + 0.5) end

local function myVehicles(src)
    local rows = db('query', 'SELECT plate, model, color, origin, impounded, body, engine, fuel FROM vc2_vehicles WHERE owner = ? ORDER BY id DESC', { identifier(src) }) or {}
    for _, r in ipairs(rows) do
        r.status = vehicleStatus(r)
        r.fee = feeFor(r.status)
        local ent = activeEntity(r.plate)
        if ent then r.body, r.engine = GetVehicleBodyHealth(ent), GetVehicleEngineHealth(ent) end
        r.body, r.engine, r.fuel = pct(r.body, 1000), pct(r.engine, 1000), pct(r.fuel, 100)
        r.impounded = nil
    end
    return rows
end

Callbacks['vc2:garage'] = function(src)
    return { vehicles = myVehicles(src), money = getMoney(src) }
end

Callbacks['vc2:retrieve'] = function(src, plate, garage, payment)
    if not near(src, Config.Garages, garage) then return { ok = false, msg = 'You must be at the recovery desk' } end
    if busy[src] then return { ok = false, msg = 'A transaction is already in progress' } end
    local row = db('single', 'SELECT * FROM vc2_vehicles WHERE plate = ? AND owner = ?', { plate, identifier(src) })
    if not row then return { ok = false, msg = 'This is not your vehicle' } end
    busy[src] = true
    local fee = feeFor(vehicleStatus(row))
    local paid = charge(src, allowedPay[payment] and payment or Config.Payments[1], fee)
    if not paid then busy[src] = nil return { ok = false, msg = ('You need %s%d to retrieve this vehicle'):format(Config.Currency, fee) } end
    local old = activeEntity(plate)
    if old then DeleteEntity(old) active[plate] = nil end
    db('update', 'UPDATE vc2_vehicles SET impounded = 0 WHERE plate = ?', { plate })
    if FW == 'qb' then db('update', 'UPDATE player_vehicles SET state = 0 WHERE plate = ?', { plate }) end
    pendingSpawn[plate] = src
    busy[src] = nil
    return {
        ok = true, model = row.model, plate = plate, color = row.color,
        props = row.props and json.decode(row.props) or nil,
        body = row.body, engine = row.engine, fuel = row.fuel,
        vehicles = myVehicles(src), money = getMoney(src), fee = fee
    }
end

-------- /vc2check
Callbacks['vc2:check'] = function(src, netId, plate)
    local ent = netId and NetworkGetEntityFromNetworkId(netId)
    local st = ent and ent ~= 0 and Entity(ent).state.vc2
    plate = st and st.plate or trim(plate)
    local row = db('single', 'SELECT plate, owner_name, model, origin, UNIX_TIMESTAMP(created_at) AS created FROM vc2_vehicles WHERE plate = ?', { plate })
    return { row = row, tagged = st ~= nil }
end

-------- health snapshots (shown in the impound terminal)
local lastHealth = {}
RegisterNetEvent('vc2:health', function(netId, body, engine, fuel)
    local src = source
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local st = Entity(ent).state.vc2
    if not st or active[st.plate] ~= ent or GetPedInVehicleSeat(ent, -1) ~= GetPlayerPed(src) then return end
    local now = os.time()
    if (lastHealth[st.plate] or 0) > now - 8 then return end
    lastHealth[st.plate] = now
    local c = function(v, max) return math.max(0.0, math.min(max, tonumber(v) or max)) end
    db('update', 'UPDATE vc2_vehicles SET body = ?, engine = ?, fuel = ? WHERE plate = ?', { c(body, 1000.0), c(engine, 1000.0), c(fuel, 100.0), st.plate })
end)

-------- admin
local function isAdmin(src) return IsPlayerAceAllowed(src, Config.AdminAce) end

local function vehicleFromNet(netId)
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 2 then return ent end
end

-- register an existing car (any car) under a player's name
Callbacks['vc2:adminOwn'] = function(src, netId, model, props, target)
    if not isAdmin(src) then return { ok = false, msg = 'Admins only' } end
    local ent = vehicleFromNet(netId)
    if not ent then return { ok = false, msg = 'Vehicle not found (it must be a networked car)' } end
    target = tonumber(target) or src
    if not GetPlayerName(target) or not identifier(target) then return { ok = false, msg = 'Player not found' } end
    model = tostring(model or '')
    if not model:match('^#?[%w_%-]+$') or (modelHash(model) % 4294967296) ~= (GetEntityModel(ent) % 4294967296) then return { ok = false, msg = 'Could not read the vehicle model' } end
    local plate = trim(GetVehicleNumberPlateText(ent))
    if plate == '' then return { ok = false, msg = 'This vehicle has no plate' } end
    local ident, name, P = identifier(target), playerName(target), getPlayer(target)
    local data = type(props) == 'table' and json.encode(props) or json.encode({ model = modelHash(model), plate = plate })

    if db('scalar', 'SELECT 1 FROM vc2_vehicles WHERE plate = ?', { plate }) then
        db('update', "UPDATE vc2_vehicles SET owner = ?, owner_name = ?, model = ?, props = ?, origin = 'admin', impounded = 0 WHERE plate = ?", { ident, name, model, data, plate })
    else
        db('insert', "INSERT INTO vc2_vehicles (plate, owner, owner_name, model, props, origin) VALUES (?, ?, ?, ?, ?, 'admin')", { plate, ident, name, model, data })
    end
    if FW == 'qb' then
        if db('scalar', 'SELECT 1 FROM player_vehicles WHERE plate = ?', { plate }) then
            db('update', 'UPDATE player_vehicles SET license = ?, citizenid = ?, mods = ? WHERE plate = ?', { P.PlayerData.license, ident, data, plate })
        else
            db('insert', 'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                { P.PlayerData.license, ident, model, modelHash(model), data, plate, Config.QBGarage, 0 })
        end
    elseif FW == 'esx' then
        if db('scalar', 'SELECT 1 FROM owned_vehicles WHERE plate = ?', { plate }) then
            db('update', 'UPDATE owned_vehicles SET owner = ?, vehicle = ? WHERE plate = ?', { ident, data, plate })
        else
            db('insert', 'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, ?)', { ident, plate, data, 'car', 0 })
        end
    end
    local old = activeEntity(plate)
    if old and old ~= ent then DeleteEntity(old) end
    active[plate] = ent
    Entity(ent).state:set('vc2', { plate = plate, owner = ident, origin = 'admin', model = model }, true)
    if target ~= src then notify(target, ('An admin registered the vehicle %s under your name'):format(plate), 'success') end
    log(src, 'Vehicle registered by admin', ('**Plate:** %s\n**Model:** %s\n**New owner:** %s (%s)'):format(plate, model, name, ident))
    return { ok = true, plate = plate, name = name }
end

Callbacks['vc2:adminImpound'] = function(src, netId)
    if not isAdmin(src) then return { ok = false, msg = 'Admins only' } end
    local ent = vehicleFromNet(netId)
    if not ent then return { ok = false, msg = 'Vehicle not found' } end
    local plate = trim(GetVehicleNumberPlateText(ent))
    if not db('scalar', 'SELECT 1 FROM vc2_vehicles WHERE plate = ?', { plate }) then return { ok = false, msg = 'This is not a VC2 vehicle' } end
    db('update', 'UPDATE vc2_vehicles SET impounded = 1, body = ?, engine = ? WHERE plate = ?', { GetVehicleBodyHealth(ent), GetVehicleEngineHealth(ent), plate })
    DeleteEntity(ent)
    active[plate] = nil
    return { ok = true, plate = plate }
end

RegisterNetEvent('vc2:cb:req', function(name, id, ...)
    local src = source
    local fn = Callbacks[name]
    if not fn then return end
    TriggerClientEvent('vc2:cb:res', src, id, fn(src, ...))
end)

RegisterCommand(Config.Orders.command, function(src)
    if src == 0 then return end
    if not isManager(src) then return notify(src, 'You are not allowed to manage custom orders', 'error') end
    TriggerClientEvent('vc2:openManager', src)
end, false)

AddEventHandler('playerDropped', function()
    busy[source], lastTest[source] = nil, nil
end)

---------------------------------------------------------------- exports (use these from other scripts)
-- exports.VC2:IsVC2Vehicle(plateOrEntity) -> true if this car was sold by VC2
exports('IsVC2Vehicle', function(v)
    if type(v) == 'number' and DoesEntityExist(v) then
        if Entity(v).state.vc2 then return true end
        v = GetVehicleNumberPlateText(v)
    end
    return db('scalar', 'SELECT 1 FROM vc2_vehicles WHERE plate = ?', { trim(v) }) ~= nil
end)
-- exports.VC2:GetVC2Vehicle(plate) -> { plate, owner, owner_name, model, origin, ... } or nil
exports('GetVC2Vehicle', function(plate)
    return db('single', 'SELECT * FROM vc2_vehicles WHERE plate = ?', { trim(plate) })
end)
-- police: exports.VC2:ImpoundVehicle(plate) -> owner must pay the impound fee at a recovery NPC
exports('ImpoundVehicle', function(plate)
    plate = trim(plate)
    local ent = activeEntity(plate)
    if ent then DeleteEntity(ent) active[plate] = nil end
    return db('update', 'UPDATE vc2_vehicles SET impounded = 1 WHERE plate = ?', { plate }) == 1
end)
exports('ReleaseVehicle', function(plate)
    return db('update', 'UPDATE vc2_vehicles SET impounded = 0 WHERE plate = ?', { trim(plate) }) == 1
end)
