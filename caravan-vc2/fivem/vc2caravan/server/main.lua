local FW, Core = 'standalone', nil
local MODEL = joaat(Config.Model) % 4294967296
local Caravans = {}     -- plate -> { furniture = { {id, model, x, y, z, h} }, exterior = {}, nextId }
local catalog = {}
for _, f in ipairs(Config.Furniture) do catalog[f.model] = f end

---------------------------------------------------------------- framework / db
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
    db('query', [[CREATE TABLE IF NOT EXISTS `vc2_caravans` (
        `plate` VARCHAR(12) NOT NULL PRIMARY KEY,
        `furniture` LONGTEXT DEFAULT NULL,
        `exterior` LONGTEXT DEFAULT NULL,
        `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)]])
    print(('^2[vc2caravan]^7 started (framework: %s)'):format(FW))
end)

local function trim(s) return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')) end

local function identifier(src)
    if FW == 'qb' then local P = Core.Functions.GetPlayer(src) return P and P.PlayerData.citizenid end
    if FW == 'esx' then local P = Core.GetPlayerFromId(src) return P and P.identifier end
    return GetPlayerIdentifierByType(src, 'license')
end

local function pay(src, amount)
    if amount <= 0 or FW == 'standalone' then return true end
    if FW == 'qb' then
        local P = Core.Functions.GetPlayer(src)
        if not P then return false end
        for _, acc in ipairs({ 'bank', 'cash' }) do
            if (P.PlayerData.money[acc] or 0) >= amount then return P.Functions.RemoveMoney(acc, amount, 'vc2-caravan-furniture') end
        end
    elseif FW == 'esx' then
        local P = Core.GetPlayerFromId(src)
        if not P then return false end
        local bank = P.getAccount('bank')
        if bank and bank.money >= amount then P.removeAccountMoney('bank', amount) return true end
        if P.getMoney() >= amount then P.removeMoney(amount) return true end
    end
    return false
end

local function notify(src, msg, kind) TriggerClientEvent('vc2rv:notify', src, msg, kind) end

---------------------------------------------------------------- caravan data
local function load(plate)
    if Caravans[plate] then return Caravans[plate] end
    local row = db('single', 'SELECT furniture, exterior FROM vc2_caravans WHERE plate = ?', { plate })
    local c = { furniture = {}, exterior = {}, nextId = 1 }
    if row then
        c.furniture = row.furniture and json.decode(row.furniture) or {}
        c.exterior = row.exterior and json.decode(row.exterior) or {}
        for _, f in ipairs(c.furniture) do if f.id >= c.nextId then c.nextId = f.id + 1 end end
    end
    Caravans[plate] = c
    return c
end

local function save(plate)
    local c = Caravans[plate]
    db('update', 'INSERT INTO vc2_caravans (plate, furniture, exterior) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE furniture = VALUES(furniture), exterior = VALUES(exterior)',
        { plate, json.encode(c.furniture), json.encode(c.exterior) })
end

local function broadcast(plate)
    local c = Caravans[plate]
    TriggerClientEvent('vc2rv:data', -1, plate, c.furniture, c.exterior)
end

---------------------------------------------------------------- checks
local function caravanFromNet(netId)
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if GetEntityModel(veh) % 4294967296 ~= MODEL then return nil end
    return veh, trim(GetVehicleNumberPlateText(veh))
end

local function nearVeh(src, veh, dist)
    return #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) <= (dist or 12.0)
end

local function canEdit(src, plate)
    if IsPlayerAceAllowed(src, Config.AdminAce) then return true end
    local mode = Config.Ownership
    if mode == 'auto' then mode = GetResourceState('VC2') == 'started' and 'vc2' or 'none' end
    if mode == 'none' then return true end
    if GetResourceState('VC2') ~= 'started' then return false end
    local row = exports.VC2:GetVC2Vehicle(plate)
    return row ~= nil and row.owner == identifier(src)
end

---------------------------------------------------------------- events
RegisterNetEvent('vc2rv:getData', function(plate)
    local src = source
    plate = trim(plate)
    if plate == '' then return end
    local c = load(plate)
    TriggerClientEvent('vc2rv:data', src, plate, c.furniture, c.exterior, canEdit(src, plate))
end)

-- Q while parked: set up / pack up
RegisterNetEvent('vc2rv:toggle', function(netId)
    local src = source
    local veh, plate = caravanFromNet(netId)
    if not veh then return end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(src) then return end
    if GetEntitySpeed(veh) > Config.MaxSpeed + 0.5 then return notify(src, 'Stop the caravan first', 'error') end
    if not canEdit(src, plate) then return notify(src, 'Only the owner can set up this caravan', 'error') end
    local st = Entity(veh).state.vc2rv or {}
    local deployed = not st.deployed
    Entity(veh).state:set('vc2rv', { deployed = deployed, door = false, at = os.time() }, true)
    FreezeEntityPosition(veh, deployed)
    notify(src, deployed and 'Setting up the caravan...' or 'Packing up the caravan...', 'primary')
end)

RegisterNetEvent('vc2rv:door', function(netId, open)
    local src = source
    local veh = caravanFromNet(netId)
    if not veh or not nearVeh(src, veh, 8.0) then return end
    local st = Entity(veh).state.vc2rv or {}
    if not st.deployed then return notify(src, 'Set up the caravan first (Q while parked)', 'error') end
    st.door = open and true or false
    Entity(veh).state:set('vc2rv', st, true)
end)

RegisterNetEvent('vc2rv:addFurniture', function(netId, model, off, h)
    local src = source
    local veh, plate = caravanFromNet(netId)
    if not veh or not nearVeh(src, veh) then return end
    if not canEdit(src, plate) then return notify(src, 'Only the owner can furnish this caravan', 'error') end
    local item = catalog[model]
    if not item or type(off) ~= 'table' then return end
    local b = Config.InteriorBounds
    local x, y, z = tonumber(off.x) or 0, tonumber(off.y) or 0, tonumber(off.z) or 0
    if x < b.minX or x > b.maxX or y < b.minY or y > b.maxY or z < b.minZ - 0.1 or z > b.maxZ then
        return notify(src, 'Furniture must be placed inside the caravan', 'error')
    end
    local c = load(plate)
    if #c.furniture >= Config.MaxFurniture then return notify(src, ('Maximum %d items'):format(Config.MaxFurniture), 'error') end
    if not pay(src, item.price or 0) then return notify(src, 'Not enough money', 'error') end
    c.furniture[#c.furniture + 1] = { id = c.nextId, model = model, x = x, y = y, z = z, h = (tonumber(h) or 0) % 360 }
    c.nextId = c.nextId + 1
    save(plate)
    broadcast(plate)
    notify(src, ('%s placed'):format(item.label), 'success')
end)

RegisterNetEvent('vc2rv:removeFurniture', function(netId, id)
    local src = source
    local veh, plate = caravanFromNet(netId)
    if not veh or not nearVeh(src, veh) or not canEdit(src, plate) then return end
    local c = load(plate)
    for i, f in ipairs(c.furniture) do
        if f.id == tonumber(id) then table.remove(c.furniture, i) break end
    end
    save(plate)
    broadcast(plate)
end)

RegisterNetEvent('vc2rv:setExterior', function(netId, e)
    local src = source
    local veh, plate = caravanFromNet(netId)
    if not veh or not nearVeh(src, veh) or not canEdit(src, plate) or type(e) ~= 'table' then return end
    local n = function(v, max) v = tonumber(v) if v and v >= 0 and v <= max then return math.floor(v) end end
    local clean = {
        primary = n(e.primary, 160), secondary = n(e.secondary, 160), pearl = n(e.pearl, 160), wheel = n(e.wheel, 160),
        livery = n(e.livery, 30),
    }
    if type(e.neon) == 'table' then
        clean.neon = { on = e.neon.on == true, r = n(e.neon.r, 255) or 255, g = n(e.neon.g, 255) or 255, b = n(e.neon.b, 255) or 255 }
    end
    local c = load(plate)
    c.exterior = clean
    save(plate)
    broadcast(plate)
end)
