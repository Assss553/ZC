local FW, Core = 'standalone', nil
local isOpen, currentKiosk, prompting = false, nil, false
local testDrive = nil
local props, blips = {}, {}

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

local function getProps(veh)
    if FW == 'qb' then return Core.Functions.GetVehicleProperties(veh) end
    if FW == 'esx' then return Core.Game.GetVehicleProperties(veh) end
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

local function spawnVehicle(model, c, plate, colorIdx)
    local hash = joaat(model)
    if not loadModel(hash) then return nil end
    local veh = CreateVehicle(hash, c.x, c.y, c.z, c.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    local col = Config.Colors[colorIdx or 1]
    if col then SetVehicleColours(veh, col.primary, col.primary) end
    SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(veh), true)
    return veh
end

local function freeSpot(list)
    for _, c in ipairs(list) do
        if not IsAnyVehicleNearPoint(c.x, c.y, c.z, 3.0) then return c end
    end
    return list[1]
end

local function nui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function setPrompt(state)
    if prompting == state then return end
    prompting = state
    nui('prompt', { show = state })
end

---------------------------------------------------------------- UI
local function closeUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    nui('hide')
    ClearPedTasks(PlayerPedId())
end

local function openUI(index)
    if isOpen or testDrive then return end
    local k = Config.Kiosks[index]
    if not k then return end
    currentKiosk = index
    setPrompt(false)
    serverCallback('vc2:money', function(money)
        isOpen = true
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        SetEntityHeading(ped, GetHeadingFromVector_2d(k.coords.x - p.x, k.coords.y - p.y))
        TaskStartScenarioInPlace(ped, 'PROP_HUMAN_ATM', 0, true)
        SetNuiFocus(true, true)
        nui('open', {
            kiosk = k.label,
            money = money,
            currency = Config.Currency,
            payments = Config.Payments,
            testDrive = Config.TestDrive.enabled,
            categories = Config.Categories,
            colors = Config.Colors,
            vehicles = Config.Vehicles,
        })
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({})
end)

RegisterNUICallback('buy', function(d, cb)
    cb({})
    serverCallback('vc2:buy', function(res)
        if not res or not res.ok then
            nui('error', { msg = res and res.msg or 'صار خطأ، حاول مرة ثانية' })
            return
        end
        nui('receipt', { receipt = res.receipt, money = res.money })
        local k = Config.Kiosks[currentKiosk]
        local spot = freeSpot(k.delivery)
        local veh = spawnVehicle(res.receipt.model, spot, res.receipt.plate, res.receipt.colorIndex)
        if veh then
            Config.OnVehicleSpawned(veh, res.receipt.plate, false)
            local p = getProps(veh)
            if p then TriggerServerEvent('vc2:setProps', res.receipt.plate, p) end
            SetNewWaypoint(spot.x, spot.y)
        end
        notify(('مبروك! استلم سيارتك %s من موقف التسليم'):format(res.receipt.vehicle), 'success')
    end, d.model, tonumber(d.color) or 1, d.payment, currentKiosk)
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
    notify(reason or 'انتهت تجربة القيادة', 'primary')
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
        notify('الموديل غير موجود بالسيرفر', 'error')
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
            if not DoesEntityExist(veh) or IsEntityDead(p) or GetEntityHealth(veh) <= 0 then endTestDrive('انتهت تجربة القيادة') break end
            if #(GetEntityCoords(p) - testDrive.kiosk) > Config.TestDrive.maxDistance then endTestDrive('ابتعدت كثير عن المعرض') break end
            if GetVehiclePedIsIn(p, false) ~= veh then
                outSince = outSince or now
                if now - outSince > 5000 then endTestDrive('نزلت من السيارة') break end
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

---------------------------------------------------------------- kiosks
local function useTarget()
    local m = Config.Interaction
    if m == 'auto' then
        if GetResourceState('ox_target') == 'started' then return 'ox_target' end
        if GetResourceState('qb-target') == 'started' then return 'qb-target' end
        return 'key'
    end
    return m
end

local function setupKiosks()
    local mode = useTarget()
    for i, k in ipairs(Config.Kiosks) do
        if k.blip then
            local b = AddBlipForCoord(k.coords.x, k.coords.y, k.coords.z)
            SetBlipSprite(b, k.blip.sprite)
            SetBlipColour(b, k.blip.color)
            SetBlipScale(b, k.blip.scale)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('VC2 Showroom')
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
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
        if mode == 'ox_target' then
            local opt = { { name = 'vc2_kiosk_' .. i, icon = 'fas fa-car', label = 'جهاز المعرض', distance = 2.0, onSelect = function() openUI(i) end } }
            if obj then exports.ox_target:addLocalEntity(obj, opt)
            else exports.ox_target:addSphereZone({ coords = k.coords.xyz, radius = 1.2, options = opt }) end
        elseif mode == 'qb-target' then
            local opt = { options = { { icon = 'fas fa-car', label = 'جهاز المعرض', action = function() openUI(i) end } }, distance = 2.0 }
            if obj then exports['qb-target']:AddTargetEntity(obj, opt)
            else exports['qb-target']:AddCircleZone('vc2_kiosk_' .. i, k.coords.xyz, 1.2, { name = 'vc2_kiosk_' .. i }, opt) end
        end
    end

    if mode ~= 'key' then return end
    CreateThread(function()
        while true do
            local sleep, near = 750, nil
            if not isOpen and not testDrive then
                local p = GetEntityCoords(PlayerPedId())
                for i, k in ipairs(Config.Kiosks) do
                    local d = #(p - k.coords.xyz)
                    if d < 10.0 then sleep = 250 end
                    if d < Config.InteractDistance then near = i break end
                end
            end
            if near then
                sleep = 0
                setPrompt(true)
                if IsControlJustReleased(0, 38) then openUI(near) end
            else
                setPrompt(false)
            end
            Wait(sleep)
        end
    end)
end

CreateThread(function()
    detect()
    setupKiosks()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then SetNuiFocus(false, false) ClearPedTasks(PlayerPedId()) end
    if testDrive and DoesEntityExist(testDrive.veh) then
        DeleteEntity(testDrive.veh)
        SetEntityCoords(PlayerPedId(), testDrive.back.x, testDrive.back.y, testDrive.back.z - 1.0, false, false, false, false)
    end
    for _, o in ipairs(props) do if DoesEntityExist(o) then DeleteEntity(o) end end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
