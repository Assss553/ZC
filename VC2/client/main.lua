local FW, Core = 'standalone', nil
local isOpen, mode, currentKiosk, currentGarage = false, nil, nil, nil
local prompting = nil
local testDrive = nil
local props, peds, blips = {}, {}, {}

---------------------------------------------------------------- framework
local function detect()
    if Config.Framework ~= 'auto' then FW = Config.Framework
    elseif GetResourceState('qb-core') == 'started' then FW = 'qb'
    elseif GetResourceState('es_extended') == 'started' then FW = 'esx' end
    if FW == 'qb' then Core = exports['qb-core']:GetCoreObject()
    elseif FW == 'esx' then Core = exports['es_extended']:getSharedObject() end
end

local function notify(msg, kind)
    if FW == 'qb' then Core.Functions.Notify(msg, kind or 'primary')
    elseif FW == 'esx' then Core.ShowNotification(msg)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg)
        EndTextCommandThefeedPostTicker(false, true)
    end
end
RegisterNetEvent('vc2:notify', notify)

local function getProps(veh)
    if FW == 'qb' then return Core.Functions.GetVehicleProperties(veh) end
    if FW == 'esx' then return Core.Game.GetVehicleProperties(veh) end
end

local function setProps(veh, p)
    if type(p) ~= 'table' then return false end
    if FW == 'qb' then Core.Functions.SetVehicleProperties(veh, p) return true end
    if FW == 'esx' then Core.Game.SetVehicleProperties(veh, p) return true end
    return false
end

---------------------------------------------------------------- callbacks
local cbId, cbs = 0, {}
local function serverCallback(name, cb, ...)
    cbId = cbId + 1
    cbs[cbId] = cb
    TriggerServerEvent('vc2:cb:req', name, cbId, ...)
end
RegisterNetEvent('vc2:cb:res', function(id, ...)
    local cb = cbs[id]
    if cb then cbs[id] = nil cb(...) end
end)

---------------------------------------------------------------- helpers
local function loadModel(hash)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

-- spawn code, or '#<hash>' for cars an admin registered without a known spawn code
local function hashOf(model)
    if type(model) == 'number' then return model end
    local n = tostring(model):match('^#(%-?%d+)$')
    return n and tonumber(n) or joaat(model)
end

local function spawnVehicle(model, c, plate, colorIdx, vprops)
    local hash = hashOf(model)
    if not loadModel(hash) then return nil end
    local veh = CreateVehicle(hash, c.x, c.y, c.z, c.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    if not setProps(veh, vprops) then
        local col = Config.Colors[colorIdx or 1]
        if col then SetVehicleColours(veh, col.primary, col.primary) end
    end
    SetVehicleNumberPlateText(veh, plate)
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(veh), true)
    return veh
end

-- spawn a car the player owns and tag it on the server as a VC2 car
local function spawnOwned(model, spots, plate, colorIdx, vprops, health)
    local spot = spots[1]
    for _, c in ipairs(spots) do
        if not IsAnyVehicleNearPoint(c.x, c.y, c.z, 3.0) then spot = c break end
    end
    local veh = spawnVehicle(model, spot, plate, colorIdx, vprops)
    if not veh then
        notify('This vehicle model is not available on the server', 'error')
        return
    end
    if health and not Config.Retrieve.repair then
        SetVehicleBodyHealth(veh, math.max(100.0, health.body or 1000.0))
        SetVehicleEngineHealth(veh, math.max(100.0, health.engine or 1000.0))
    end
    Config.OnVehicleSpawned(veh, plate, false, health and health.fuel or nil)
    TriggerServerEvent('vc2:spawned', NetworkGetNetworkIdFromEntity(veh), plate, getProps(veh))
    SetNewWaypoint(spot.x, spot.y)
    return veh
end

local function nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function setPrompt(text)
    if prompting == text then return end
    prompting = text
    nui('prompt', { show = text ~= nil, text = text })
end

---------------------------------------------------------------- catalogue (read from the game)
local catalog, byModel = nil, {}
local classToCat = {}
for _, c in ipairs(Config.Categories) do
    for _, cl in ipairs(c.classes or {}) do classToCat[cl] = c.id end
end

local function pct(v, max) return math.floor(math.max(5, math.min(100, v / max * 100)) + 0.5) end

local function text(key)
    if not key or key == '' then return nil end
    local t = GetLabelText(key)
    if t == 'NULL' then return nil end
    return t
end

-- name / brand / class of any spawn code, straight from the game
local function modelInfo(model)
    local hash = hashOf(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    local display = GetDisplayNameFromVehicleModel(hash)
    return {
        hash = hash,
        label = text(display) or display or model,
        brand = text(GetMakeNameFromVehicleModel(hash)) or '',
        class = GetVehicleClassFromName(hash),
    }
end

local function buildCatalog()
    if catalog then return catalog end
    catalog = {}
    for _, v in ipairs(Config.Vehicles) do
        local info = modelInfo(v.model)
        if info then
            local hash = info.hash
            local speed = GetVehicleModelEstimatedMaxSpeed(hash)
            local s = v.stats or {}
            local item = {
                model = v.model,
                price = v.price,
                label = v.label or info.label,
                brand = v.brand or info.brand,
                class = info.class,
                category = v.category or classToCat[info.class] or 'other',
                seats = GetVehicleModelNumberOfSeats(hash),
                topSpeed = math.floor(speed * 3.6 + 0.5),
                image = v.image,
                stats = {
                    speed = s.speed or pct(speed, 50.0),
                    accel = s.accel or pct(GetVehicleModelAcceleration(hash), 0.45),
                    brake = s.brake or pct(GetVehicleModelMaxBraking(hash), 1.2),
                    handling = s.handling or pct(GetVehicleModelMaxTraction(hash), 3.2),
                }
            }
            catalog[#catalog + 1] = item
            byModel[v.model] = item
        else
            print(('^3[VC2]^7 vehicle model "%s" was not found - is the addon car streamed?'):format(v.model))
        end
    end
    return catalog
end

local function fullName(model)
    local c = byModel[model] or modelInfo(model)
    if not c then return model end
    return (c.brand ~= '' and c.brand .. ' ' or '') .. c.label
end

-- add game names / pictures info to rows coming from the server
local function enrich(rows)
    for _, r in ipairs(rows or {}) do
        if r.model and r.model ~= '' then
            local c = byModel[r.model] or modelInfo(r.model)
            if c then
                r.label, r.brand, r.class = c.label, c.brand, c.class
                r.image = byModel[r.model] and byModel[r.model].image or nil
            else
                r.label, r.brand = r.model, ''
            end
        end
    end
    return rows or {}
end

---------------------------------------------------------------- UI
local function closeUI()
    if not isOpen then return end
    isOpen, mode = false, nil
    SetNuiFocus(false, false)
    nui('hide')
    ClearPedTasks(PlayerPedId())
end

local function faceAndOpen(coords, scenario, data)
    isOpen = true
    setPrompt(nil)
    local ped = PlayerPedId()
    if coords then
        local p = GetEntityCoords(ped)
        SetEntityHeading(ped, GetHeadingFromVector_2d(coords.x - p.x, coords.y - p.y))
    end
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    SetNuiFocus(true, true)
    data.currency = Config.Currency
    data.colors = Config.Colors
    data.imageUrl = Config.ImageUrl
    data.payments = Config.Payments
    nui('open', data)
end

local function openShop(index)
    if isOpen or testDrive then return end
    local k = Config.Kiosks[index]
    if not k then return end
    currentKiosk = index
    serverCallback('vc2:money', function(money)
        serverCallback('vc2:myOrders', function(orders)
            mode = 'shop'
            faceAndOpen(k.coords, 'PROP_HUMAN_ATM', {
                mode = 'shop',
                kiosk = k.label,
                money = money,
                testDrive = Config.TestDrive.enabled,
                categories = Config.Categories,
                vehicles = buildCatalog(),
                orders = enrich(orders),
                ordersEnabled = Config.Orders.enabled,
                orderTypes = Config.Orders.types,
            })
        end)
    end)
end

local function openGarage(index)
    if isOpen or testDrive then return end
    local g = Config.Garages[index]
    if not g then return end
    currentGarage = index
    buildCatalog()
    serverCallback('vc2:garage', function(res)
        mode = 'impound'
        isOpen = true
        setPrompt(nil)
        SetNuiFocus(true, true)
        nui('impound', {
            title = g.label, subtitle = g.subtitle, money = res.money, currency = Config.Currency,
            colors = Config.Colors, imageUrl = Config.ImageUrl, owned = enrich(res.vehicles),
        })
    end)
end

RegisterNetEvent('vc2:openManager', function()
    if isOpen or testDrive then return end
    buildCatalog()
    serverCallback('vc2:mgrOrders', function(orders)
        if not orders then return end
        mode = 'manager'
        faceAndOpen(nil, nil, { mode = 'manager', kiosk = 'Workshop panel', orders = enrich(orders) })
    end, 'pending')
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({})
end)

local function onPurchase(res)
    if not res or not res.ok then
        nui('error', { msg = res and res.msg or 'Something went wrong, please try again' })
        return
    end
    res.receipt.vehicle = fullName(res.receipt.model)
    nui('receipt', { receipt = res.receipt, money = res.money, orders = res.orders and enrich(res.orders) })
    spawnOwned(res.receipt.model, Config.Kiosks[currentKiosk].delivery, res.receipt.plate, res.receipt.colorIndex)
    notify(('Congratulations! Pick up your %s at the delivery spot'):format(res.receipt.vehicle), 'success')
end

RegisterNUICallback('buy', function(d, cb)
    cb({})
    serverCallback('vc2:buy', onPurchase, d.model, tonumber(d.color) or 1, d.payment, currentKiosk)
end)

-------- custom orders
RegisterNUICallback('orderSubmit', function(d, cb)
    cb({})
    serverCallback('vc2:orderSubmit', function(res)
        if not res.ok then return nui('error', { msg = res.msg }) end
        nui('orders', { orders = enrich(res.orders), msg = ('Order #%d sent! The workshop will build your car.'):format(res.id) })
    end, d, currentKiosk)
end)

RegisterNUICallback('orderCollect', function(d, cb)
    cb({})
    serverCallback('vc2:orderCollect', onPurchase, d.id, d.payment, currentKiosk)
end)

RegisterNUICallback('mgrRefresh', function(d, cb)
    cb({})
    serverCallback('vc2:mgrOrders', function(orders)
        nui('mgr', { orders = enrich(orders) })
    end, d.filter)
end)

RegisterNUICallback('mgrBuild', function(d, cb)
    cb({})
    local model = tostring(d.model or ''):lower():gsub('%s', '')
    if not modelInfo(model) then
        return nui('error', { msg = ('Spawn code "%s" does not exist on this server'):format(model) })
    end
    serverCallback('vc2:mgrBuild', function(res)
        if not res.ok then return nui('error', { msg = res.msg }) end
        serverCallback('vc2:mgrOrders', function(orders)
            nui('mgr', { orders = enrich(orders), msg = ('Order #%s is ready for the customer'):format(d.id) })
        end, d.filter)
    end, d.id, model, d.price, d.note)
end)

RegisterNUICallback('mgrReject', function(d, cb)
    cb({})
    serverCallback('vc2:mgrReject', function(res)
        if not res.ok then return nui('error', { msg = res.msg }) end
        serverCallback('vc2:mgrOrders', function(orders)
            nui('mgr', { orders = enrich(orders), msg = ('Order #%s declined'):format(d.id) })
        end, d.filter)
    end, d.id, d.note)
end)

-------- recovery
RegisterNUICallback('retrieve', function(d, cb)
    cb({})
    serverCallback('vc2:retrieve', function(res)
        if not res.ok then return nui('error', { msg = res.msg }) end
        closeUI()
        local veh = spawnOwned(res.model, Config.Garages[currentGarage].spawn, res.plate, res.color, res.props,
            { body = res.body, engine = res.engine, fuel = res.fuel })
        if veh then notify(('%s is waiting for you in the lot (paid %s%d)'):format(fullName(res.model), Config.Currency, res.fee), 'success') end
    end, d.plate, currentGarage, d.payment)
end)

---------------------------------------------------------------- test drive
local function endTestDrive(reason)
    if not testDrive then return end
    local td = testDrive
    testDrive = nil
    nui('timer', { show = false })
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    if DoesEntityExist(td.veh) then DeleteEntity(td.veh) end
    local ped = PlayerPedId()
    SetEntityCoords(ped, td.back.x, td.back.y, td.back.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, td.heading)
    Wait(300)
    DoScreenFadeIn(500)
    notify(reason or 'Test drive finished', 'primary')
end

local function startTestDrive(model, colorIdx)
    local k = Config.Kiosks[currentKiosk]
    closeUI()
    local ped = PlayerPedId()
    local back, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    local veh = spawnVehicle(model, k.testDrive, ('TEST%04d'):format(math.random(0, 9999)), colorIdx)
    if not veh then
        DoScreenFadeIn(300)
        notify('This model does not exist on the server', 'error')
        return
    end
    Config.OnVehicleSpawned(veh, GetVehicleNumberPlateText(veh), true)
    TaskWarpPedIntoVehicle(ped, veh, -1)
    testDrive = { veh = veh, back = back, heading = heading, kiosk = k.coords.xyz }
    Wait(200)
    DoScreenFadeIn(500)

    local endAt = GetGameTimer() + Config.TestDrive.duration * 1000
    CreateThread(function()
        local outSince = nil
        while testDrive do
            local now = GetGameTimer()
            local left = math.ceil((endAt - now) / 1000)
            nui('timer', { show = true, seconds = math.max(left, 0) })
            local p = PlayerPedId()
            if left <= 0 then endTestDrive() break end
            if not DoesEntityExist(veh) or IsEntityDead(p) or GetEntityHealth(veh) <= 0 then endTestDrive('Test drive finished') break end
            if #(GetEntityCoords(p) - testDrive.kiosk) > Config.TestDrive.maxDistance then endTestDrive('You drove too far from the showroom') break end
            if GetVehiclePedIsIn(p, false) ~= veh then
                outSince = outSince or now
                if now - outSince > 5000 then endTestDrive('You left the vehicle') break end
            else outSince = nil end
            Wait(500)
        end
    end)
end

RegisterNUICallback('testDrive', function(d, cb)
    cb({})
    serverCallback('vc2:testdrive', function(ok, msg)
        if ok then startTestDrive(d.model, tonumber(d.color) or 1)
        else nui('error', { msg = msg }) end
    end, d.model, currentKiosk)
end)

---------------------------------------------------------------- world points (kiosks + recovery NPCs)
local points = {}

local function interactionMode()
    local m = Config.Interaction
    if m == 'auto' then
        if GetResourceState('ox_target') == 'started' then return 'ox_target' end
        if GetResourceState('qb-target') == 'started' then return 'qb-target' end
        return 'key'
    end
    return m
end

local function addBlip(c, b, name)
    if not b then return end
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipColour(blip, b.color)
    SetBlipScale(blip, b.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
end

local function addPoint(id, coords, entity, label, onUse)
    local m = interactionMode()
    points[#points + 1] = { coords = coords.xyz, label = label, onUse = onUse }
    if m == 'ox_target' then
        local opt = { { name = id, icon = 'fas fa-car', label = label, distance = 2.0, onSelect = onUse } }
        if entity then exports.ox_target:addLocalEntity(entity, opt)
        else exports.ox_target:addSphereZone({ coords = coords.xyz, radius = 1.2, options = opt }) end
    elseif m == 'qb-target' then
        local opt = { options = { { icon = 'fas fa-car', label = label, action = onUse } }, distance = 2.0 }
        if entity then exports['qb-target']:AddTargetEntity(entity, opt)
        else exports['qb-target']:AddCircleZone(id, coords.xyz, 1.2, { name = id }, opt) end
    end
end

local function setupWorld()
    for i, k in ipairs(Config.Kiosks) do
        addBlip(k.coords, k.blip, 'VC2 Showroom')
        local obj
        if k.spawnProp then
            local hash = joaat(k.model)
            if loadModel(hash) then
                obj = CreateObject(hash, k.coords.x, k.coords.y, k.coords.z, false, false, false)
                SetEntityHeading(obj, k.coords.w)
                PlaceObjectOnGroundProperly(obj)
                FreezeEntityPosition(obj, true)
                SetEntityInvincible(obj, true)
                SetModelAsNoLongerNeeded(hash)
                props[#props + 1] = obj
            end
        end
        addPoint('vc2_kiosk_' .. i, k.coords, obj, 'Use the showroom kiosk', function() openShop(i) end)
    end

    for i, g in ipairs(Config.Garages) do
        addBlip(g.coords, g.blip, g.label or 'Impound Lot')
        local hash = joaat(g.ped)
        local ped
        if loadModel(hash) then
            ped = CreatePed(4, hash, g.coords.x, g.coords.y, g.coords.z, g.coords.w, false, true)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedCanRagdoll(ped, false)
            if g.scenario then TaskStartScenarioInPlace(ped, g.scenario, 0, true) end
            SetModelAsNoLongerNeeded(hash)
            peds[#peds + 1] = ped
        end
        addPoint('vc2_garage_' .. i, g.coords, ped, 'Open the impound terminal', function() openGarage(i) end)
    end

    if interactionMode() ~= 'key' then return end
    CreateThread(function()
        while true do
            local sleep, near = 750, nil
            if not isOpen and not testDrive then
                local p = GetEntityCoords(PlayerPedId())
                for _, pt in ipairs(points) do
                    local d = #(p - pt.coords)
                    if d < 10.0 then sleep = 250 end
                    if d < Config.InteractDistance + 0.4 then near = pt break end
                end
            end
            if near then
                sleep = 0
                setPrompt(near.label)
                if IsControlJustReleased(0, 38) then near.onUse() end
            else
                setPrompt(nil)
            end
            Wait(sleep)
        end
    end)
end

CreateThread(function()
    detect()
    setupWorld()
end)

---------------------------------------------------------------- health snapshots for the impound terminal
CreateThread(function()
    while true do
        Wait(10000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Entity(veh).state.vc2 then
            local ok, fuel = pcall(Config.GetFuel, veh)
            TriggerServerEvent('vc2:health', NetworkGetNetworkIdFromEntity(veh), GetVehicleBodyHealth(veh), GetVehicleEngineHealth(veh), ok and fuel or nil)
        end
    end
end)

---------------------------------------------------------------- admin commands
local function targetVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local c = GetEntityCoords(ped)
        veh = GetClosestVehicle(c.x, c.y, c.z, 5.0, 0, 70)
    end
    if veh ~= 0 and NetworkGetEntityIsNetworked(veh) then return veh end
end

-- spawn code of any car: from the config, from its display name, or '#<hash>'
local function modelCode(veh)
    local hash = GetEntityModel(veh)
    for _, v in ipairs(Config.Vehicles) do
        if joaat(v.model) == hash then return v.model end
    end
    local dn = GetDisplayNameFromVehicleModel(hash):lower()
    if joaat(dn) == hash then return dn end
    return '#' .. hash
end

RegisterCommand(Config.AdminCommands.own, function(_, args)
    local veh = targetVehicle()
    if not veh then return notify('Sit in or stand next to the vehicle', 'error') end
    serverCallback('vc2:adminOwn', function(res)
        if not res.ok then return notify(res.msg, 'error') end
        notify(('Vehicle %s is now registered to %s. Retrieve it any time from the impound.'):format(res.plate, res.name), 'success')
    end, NetworkGetNetworkIdFromEntity(veh), modelCode(veh), getProps(veh), args[1])
end, false)

RegisterCommand(Config.AdminCommands.impound, function()
    local veh = targetVehicle()
    if not veh then return notify('Sit in or stand next to the vehicle', 'error') end
    serverCallback('vc2:adminImpound', function(res)
        if not res.ok then return notify(res.msg, 'error') end
        notify(('Vehicle %s was sent to the impound'):format(res.plate), 'success')
    end, NetworkGetNetworkIdFromEntity(veh))
end, false)

---------------------------------------------------------------- /vc2check + export
RegisterCommand(Config.CheckCommand, function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local c = GetEntityCoords(ped)
        veh = GetClosestVehicle(c.x, c.y, c.z, 5.0, 0, 70)
    end
    if veh == 0 then return notify('No vehicle nearby', 'error') end
    local netId = NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) or nil
    serverCallback('vc2:check', function(res)
        local r = res and res.row
        if not r then return notify('This vehicle was NOT sold by VC2', 'error') end
        notify(('VC2 vehicle · %s · plate %s · owner %s · %s'):format(fullName(r.model), r.plate, r.owner_name or '?', r.origin == 'custom' and 'custom build' or 'showroom'), 'success')
    end, netId, GetVehicleNumberPlateText(veh))
end, false)

-- exports.VC2:IsVC2Vehicle(vehicle) -> true when the server tagged this car as a VC2 car
exports('IsVC2Vehicle', function(veh)
    return DoesEntityExist(veh) and Entity(veh).state.vc2 ~= nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) ClearPedTasks(PlayerPedId()) end
    if testDrive and DoesEntityExist(testDrive.veh) then
        DeleteEntity(testDrive.veh)
        SetEntityCoords(PlayerPedId(), testDrive.back.x, testDrive.back.y, testDrive.back.z - 1.0, false, false, false, false)
    end
    for _, o in ipairs(props) do if DoesEntityExist(o) then DeleteEntity(o) end end
    for _, p in ipairs(peds) do if DoesEntityExist(p) then DeleteEntity(p) end end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
