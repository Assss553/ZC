local FW, Core = 'standalone', nil
local isOpen, mode, currentKiosk = false, nil, nil
local prompting = nil
local testDrive = nil
-- kiosks (from config + placed in-game), synced from the server: key -> { data, entity, blip }
local Places = { kiosk = {} }

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

-- free spots on the nearest road in front of a kiosk (used when no spots are configured)
local function autoSpots(c)
    local h = math.rad(c.w)
    local px, py = c.x - math.sin(h) * 8.0, c.y + math.cos(h) * 8.0
    local ok, pos, head = GetClosestVehicleNodeWithHeading(px, py, c.z, 1, 3.0, 0)
    if not ok or #(pos - c.xyz) > 60.0 then pos, head = vector3(px, py, c.z + 0.5), c.w end
    local rx, ry = math.cos(math.rad(head)) * 3.2, math.sin(math.rad(head)) * 3.2
    return { vector4(pos.x, pos.y, pos.z, head), vector4(pos.x + rx, pos.y + ry, pos.z, head), vector4(pos.x - rx, pos.y - ry, pos.z, head) }
end
local function kioskData(key) return Places.kiosk[key] and Places.kiosk[key].data end
local function deliverySpots(k) return k.delivery or autoSpots(k.coords) end

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
    local k = kioskData(index)
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
                photos = Config.CarsPhotos,
            })
        end)
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
    local k = kioskData(currentKiosk)
    if k then spawnOwned(res.receipt.model, deliverySpots(k), res.receipt.plate, res.receipt.colorIndex) end
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

-------- my cars (retrieve any owned car from the kiosk)
RegisterNUICallback('myCars', function(_, cb)
    cb({})
    buildCatalog()
    serverCallback('vc2:garage', function(res)
        nui('cars', { owned = enrich(res.vehicles), money = res.money })
    end)
end)

RegisterNUICallback('retrieve', function(d, cb)
    cb({})
    serverCallback('vc2:retrieve', function(res)
        if not res.ok then return nui('error', { msg = res.msg }) end
        local k = kioskData(currentKiosk)
        if not k then return end
        local veh = spawnOwned(res.model, deliverySpots(k), res.plate, res.color, res.props,
            { body = res.body, engine = res.engine, fuel = res.fuel })
        nui('cars', { owned = enrich(res.vehicles), money = res.money,
            msg = veh and ('%s is waiting for you at the delivery spot (paid %s%d)'):format(fullName(res.model), Config.Currency, res.fee) or nil })
    end, d.plate, currentKiosk, d.payment)
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
    local k = kioskData(currentKiosk)
    if not k then return end
    closeUI()
    local ped = PlayerPedId()
    local back, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    local veh = spawnVehicle(model, k.testDrive or autoSpots(k.coords)[1], ('TEST%04d'):format(math.random(0, 9999)), colorIdx)
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

---------------------------------------------------------------- world (kiosks)
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
    return blip
end

-- custom VC2 model when it is streamed, otherwise the GTA fallback prop
local function kioskModel(d)
    local m = d.model or Config.KioskModel
    if IsModelInCdimage(joaat(m)) then return m, m == Config.KioskModel end
    return Config.KioskFallbackModel, false
end

local function makeProp(model, c)
    local hash = joaat(model)
    if not loadModel(hash) then return nil end
    local obj = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(obj, c.w)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function addTarget(id, p, label, onUse)
    local m = interactionMode()
    if m == 'ox_target' then
        local opt = { { name = id, icon = 'fas fa-car', label = label, distance = 2.0, onSelect = onUse } }
        if p.entity then exports.ox_target:addLocalEntity(p.entity, opt)
        else p.zone = exports.ox_target:addSphereZone({ coords = p.data.coords.xyz, radius = 1.2, options = opt }) end
    elseif m == 'qb-target' then
        local opt = { options = { { icon = 'fas fa-car', label = label, action = onUse } }, distance = 2.0 }
        if p.entity then exports['qb-target']:AddTargetEntity(p.entity, opt)
        else exports['qb-target']:AddCircleZone(id, p.data.coords.xyz, 1.2, { name = id }, opt) p.zone = id end
    end
end

local function removePlace(key)
    local p = Places.kiosk[key]
    if not p then return end
    local m = interactionMode()
    if m == 'ox_target' then
        if p.entity then pcall(function() exports.ox_target:removeLocalEntity(p.entity) end) end
        if p.zone then pcall(function() exports.ox_target:removeZone(p.zone) end) end
    elseif m == 'qb-target' then
        if p.entity then pcall(function() exports['qb-target']:RemoveTargetEntity(p.entity) end) end
        if p.zone then pcall(function() exports['qb-target']:RemoveZone(p.zone) end) end
    end
    if p.entity and DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
    if p.blip then RemoveBlip(p.blip) end
    Places.kiosk[key] = nil
end

local function v4(t) return vector4(t.x + 0.0, t.y + 0.0, t.z + 0.0, (t.w or 0) + 0.0) end
local function fromNet(d)
    d.coords = v4(d.coords)
    if d.delivery then for i, c in ipairs(d.delivery) do d.delivery[i] = v4(c) end end
    if d.testDrive then d.testDrive = v4(d.testDrive) end
    return d
end

local function addPlace(key, d)
    removePlace(key)
    d = fromNet(d)
    local p = { data = d, label = 'Use the showroom kiosk', onUse = function() openShop(key) end }
    p.blip = addBlip(d.coords, d.blip, d.label or 'VC2 Showroom')
    if d.spawnProp ~= false then
        local model, custom = kioskModel(d)
        p.entity, p.custom = makeProp(model, d.coords), custom
    end
    addTarget('vc2_kiosk_' .. key, p, p.label, p.onUse)
    Places.kiosk[key] = p
end

RegisterNetEvent('vc2:places', function(kiosks)
    for key in pairs(Places.kiosk) do removePlace(key) end
    for key, d in pairs(kiosks or {}) do addPlace(key, d) end
end)
RegisterNetEvent('vc2:placeAdd', addPlace)
RegisterNetEvent('vc2:placeRemove', removePlace)

-- [E] prompt (only when no target script is used)
CreateThread(function()
    while true do
        local sleep, near = 750, nil
        if interactionMode() == 'key' and not isOpen and not testDrive then
            local pc = GetEntityCoords(PlayerPedId())
            for _, p in pairs(Places.kiosk) do
                local d = #(pc - p.data.coords.xyz)
                if d < 10.0 then sleep = 250 end
                if d < Config.InteractDistance + 0.4 then near = p break end
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

---------------------------------------------------------------- 3D hologram screen (live VC2 display drawn in the world)
CreateThread(function()
    local S = Config.KioskScreen
    if not S or not S.enabled then return end
    local dui = CreateDui(('nui://%s/html/screen.html'):format(GetCurrentResourceName()), 1280, 724)
    while not IsDuiAvailable(dui) do Wait(100) end
    local txd = CreateRuntimeTxd('vc2_screen')
    CreateRuntimeTextureFromDuiHandle(txd, 'screen', GetDuiHandle(dui))
    -- the custom model's own display (texture vc2_screen_tex in vc2_kiosk.ytd) shows the same live screen
    AddReplaceTexture(Config.KioskModel, 'vc2_screen_tex', 'vc2_screen', 'screen')
    AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then DestroyDui(dui) end end)

    -- feed the screen with featured cars from the catalogue
    CreateThread(function()
        Wait(1500)
        local feat = {}
        for _, v in ipairs(buildCatalog()) do
            feat[#feat + 1] = { model = v.model, label = v.label, brand = v.brand, price = v.price, image = v.image, class = v.class, speed = v.topSpeed }
        end
        table.sort(feat, function(a, b) return a.price > b.price end)
        while #feat > (S.featured or 6) do table.remove(feat) end
        SendDuiMessage(dui, json.encode({ type = 'feed', cars = feat, currency = Config.Currency, imageUrl = Config.ImageUrl, orders = Config.Orders.enabled }))
    end)

    local function tri(a, b, c, ua, ub, uc)
        DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 255, 255, 255, 255, 'vc2_screen', 'screen',
            ua[1], ua[2], 1.0, ub[1], ub[2], 1.0, uc[1], uc[2], 1.0)
    end
    local function line(a, b, al) DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 255, 110, 50, al) end
    local up = vector3(0.0, 0.0, 1.0)
    while true do
        local pc, any = GetEntityCoords(PlayerPedId()), false
        local t = GetGameTimer()
        for _, p in pairs(Places.kiosk) do
            local c = p.data.coords
            if #(pc - c.xyz) < S.drawDistance then
                any = true
                local base = (p.entity and DoesEntityExist(p.entity)) and GetEntityCoords(p.entity) or c.xyz
                local h = math.rad(c.w)
                local right, fwd = vector3(math.cos(h), math.sin(h), 0.0), vector3(-math.sin(h), math.cos(h), 0.0)
                local off = p.custom and S.offset or (S.fallbackOffset or S.offset)
                local bob = (S.bob or 0) * math.sin(t / 900.0)
                local ctr = base + right * off.x + fwd * off.y + up * (off.z + bob)
                local hw, hh = right * (S.width / 2), up * (S.height / 2)
                -- A = left as seen from the front, B = right as seen from the front
                local At, Ab, Bt, Bb = ctr + hw + hh, ctr + hw - hh, ctr - hw + hh, ctr - hw - hh
                if not S.flip then
                    tri(At, Bt, Bb, { 0, 0 }, { 1, 0 }, { 1, 1 }) tri(At, Bb, Ab, { 0, 0 }, { 1, 1 }, { 0, 1 })
                    tri(Bt, At, Ab, { 0, 0 }, { 1, 0 }, { 1, 1 }) tri(Bt, Ab, Bb, { 0, 0 }, { 1, 1 }, { 0, 1 })
                else
                    tri(At, Bb, Bt, { 1, 0 }, { 0, 1 }, { 0, 0 }) tri(At, Ab, Bb, { 1, 0 }, { 1, 1 }, { 0, 1 })
                    tri(Bt, Ab, At, { 1, 0 }, { 0, 1 }, { 0, 0 }) tri(Bt, Bb, Ab, { 1, 0 }, { 1, 1 }, { 0, 1 })
                end
                -- hologram frame: glowing outline + corner brackets slightly in front of the screen
                local pulse = math.floor(150 + 80 * math.sin(t / 400.0))
                local o, cx, cy = fwd * 0.004, hw * 0.12, hh * 0.2
                line(At + o, Bt + o, 120) line(Ab + o, Bb + o, 120) line(At + o, Ab + o, 120) line(Bt + o, Bb + o, 120)
                for _, k in ipairs({ { At, -1, -1 }, { Bt, 1, -1 }, { Ab, -1, 1 }, { Bb, 1, 1 } }) do
                    local q = k[1] + o + fwd * 0.002
                    line(q, q + cx * k[2], pulse) line(q, q + cy * k[3], pulse)
                end
                if S.beam then
                    local top = base + up * 1.7
                    local bottom = ctr - hh
                    DrawMarker(1, top.x, top.y, top.z, 0, 0, 0, 0, 0, 0, 0.12, 0.12, math.max(0.05, bottom.z - top.z), 255, 110, 50, 45, false, false, 2, false, nil, nil, false)
                end
                if S.glow then
                    local l = ctr + fwd * 0.6
                    DrawLightWithRange(l.x, l.y, l.z, 228, 80, 28, 3.5, 1.4)
                    DrawMarker(25, c.x, c.y, c.z + 0.03, 0, 0, 0, 0, 0, 0, 1.6, 1.6, 1.0, 228, 80, 28, 90, false, false, 2, false, nil, nil, false)
                    DrawMarker(25, c.x, c.y, c.z + 0.035, 0, 0, 0, 0, 0, 0, 1.15, 1.15, 1.0, 255, 140, 80, math.floor(40 + 35 * math.sin(t / 300.0)), false, false, 2, false, nil, nil, false)
                end
            end
        end
        Wait(any and 0 or 1000)
    end
end)

---------------------------------------------------------------- admin placement (/vc2place)
local placing = false
local function startPlacing()
    if placing or isOpen then return end
    local model = kioskModel({})
    local hash = joaat(model)
    if not loadModel(hash) then return notify('Model ' .. model .. ' could not be loaded', 'error') end
    placing = true
    local ped = PlayerPedId()
    local ghost = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(ghost, 160, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityInvincible(ghost, true)
    local rot = GetEntityHeading(ped) + 180.0
    nui('prompt', { show = true, text = 'Arrows ← → rotate · E place · Backspace cancel' })
    CreateThread(function()
        while placing do
            Wait(0)
            local p, h = GetEntityCoords(ped), math.rad(GetEntityHeading(ped))
            local x, y = p.x - math.sin(h) * 1.6, p.y + math.cos(h) * 1.6
            local found, gz = GetGroundZFor_3dCoord(x, y, p.z + 1.0, false)
            local z = found and gz or p.z - 1.0
            if IsControlPressed(0, 174) then rot = rot + 1.5 end
            if IsControlPressed(0, 175) then rot = rot - 1.5 end
            SetEntityCoordsNoOffset(ghost, x, y, z, false, false, false)
            SetEntityHeading(ghost, rot)
            DisableControlAction(0, 174, true) DisableControlAction(0, 175, true) DisableControlAction(0, 177, true)
            DrawMarker(25, x, y, z + 0.03, 0, 0, 0, 0, 0, 0, 1.4, 1.4, 1.0, 228, 80, 28, 140, false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 38) then
                placing = false
                serverCallback('vc2:place', function(res)
                    if res.ok then notify(('Kiosk placed and saved (#%d)'):format(res.id), 'success')
                    else notify(res.msg, 'error') end
                end, x, y, z, rot % 360.0)
            elseif IsDisabledControlJustReleased(0, 177) then
                placing = false
                notify('Placement cancelled', 'error')
            end
        end
        DeleteEntity(ghost)
        SetModelAsNoLongerNeeded(hash)
        nui('prompt', { show = false })
        prompting = nil
    end)
end

RegisterCommand(Config.AdminCommands.place, function() startPlacing() end, false)

RegisterCommand(Config.AdminCommands.remove, function()
    local pc, best, bd = GetEntityCoords(PlayerPedId()), nil, 5.0
    for key, p in pairs(Places.kiosk) do
        local d = #(pc - p.data.coords.xyz)
        if d < bd then best, bd = key, d end
    end
    if not best then return notify('No kiosk within 5 m', 'error') end
    serverCallback('vc2:unplace', function(res)
        if res.ok then notify('Kiosk removed', 'success') else notify(res.msg, 'error') end
    end, best)
end, false)

CreateThread(function()
    detect()
    TriggerEvent('chat:addSuggestion', '/' .. Config.AdminCommands.place, 'VC2: place a showroom kiosk where you stand (admin)')
    TriggerEvent('chat:addSuggestion', '/' .. Config.AdminCommands.remove, 'VC2: remove the closest placed kiosk (admin)')
    TriggerEvent('chat:addSuggestion', '/' .. Config.AdminCommands.own, 'VC2: register this vehicle to you or a player (admin)', { { name = 'id', help = 'player id (optional)' } })
    TriggerEvent('chat:addSuggestion', '/' .. Config.AdminCommands.impound, 'VC2: send this VC2 vehicle to the impound (admin)')
    TriggerServerEvent('vc2:requestPlaces')
end)

---------------------------------------------------------------- health snapshots for My cars
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
        notify(('Vehicle %s is now registered to %s. Retrieve it any time from My cars at a VC2 kiosk.'):format(res.plate, res.name), 'success')
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
    for _, p in pairs(Places.kiosk) do
        if p.entity and DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
        if p.blip then RemoveBlip(p.blip) end
    end
end)
