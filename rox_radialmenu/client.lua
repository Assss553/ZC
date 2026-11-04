--[[ ROX Store | rox_radialmenu | All rights reserved. ]]
local isOpen = false
local lookup = {}
local QBCore, ESX

local function getPlayerData()
    if GetResourceState('qbx_core') == 'started' then
        local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
        if ok and data then return data end
    end
    if GetResourceState('qb-core') == 'started' then
        if not QBCore then
            local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if ok then QBCore = obj end
        end
        if QBCore then return QBCore.Functions.GetPlayerData() end
    end
    if GetResourceState('es_extended') == 'started' then
        if not ESX then
            local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
            if ok then ESX = obj end
        end
        if ESX then return ESX.GetPlayerData() end
    end
    return nil
end

-- context of the player when the menu opens
local ctx = {}

local function readContext()
    local ped = PlayerPedId()
    local data = getPlayerData()
    local job = data and data.job or {}
    local veh = GetVehiclePedIsIn(ped, false)
    ctx = {
        job = job.name,
        jobLabel = job.label or job.name,
        duty = job.onduty ~= false,
        grade = tonumber(type(job.grade) == 'table' and job.grade.level or job.grade) or 0,
        isboss = job.isboss or false,
        vehicle = veh ~= 0,
        vehicleLabel = nil,
    }
    if veh ~= 0 then
        local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
        local label = GetLabelText(name)
        ctx.vehicleLabel = (label ~= 'NULL' and label) or name
    end
end

local function allowed(item)
    if item.jobs then
        local ok = false
        for _, j in ipairs(item.jobs) do
            if j == ctx.job then ok = true break end
        end
        if not ok then return false end
    end
    if item.duty and not ctx.duty then return false end
    if item.minGrade and not ctx.isboss and (ctx.grade or 0) < item.minGrade then return false end
    if item.vehicle ~= nil and item.vehicle ~= ctx.vehicle then return false end
    if item.canInteract then
        local ok, res = pcall(item.canInteract)
        if not (ok and res) then return false end
    end
    return true
end

local function prepare(items, prefix)
    local out = {}
    for _, item in ipairs(items) do
        if allowed(item) then
            local id = prefix .. (#out + 1)
            lookup[id] = item
            local entry = { id = id, label = item.label, icon = item.icon }
            if item.items then
                entry.items = prepare(item.items, id .. '-')
                if #entry.items == 0 then entry = nil end
            end
            if entry then out[#out + 1] = entry end
        end
    end
    return out
end

local function closeMenu()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function blockControls()
    CreateThread(function()
        while isOpen do
            DisableControlAction(0, 1, true)    -- look LR
            DisableControlAction(0, 2, true)    -- look UD
            DisableControlAction(0, 24, true)   -- attack
            DisableControlAction(0, 25, true)   -- aim
            DisableControlAction(0, 37, true)   -- weapon wheel
            DisableControlAction(0, 68, true)   -- veh aim
            DisableControlAction(0, 69, true)   -- veh attack
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 106, true)  -- veh mouse control
            DisableControlAction(0, 140, true)  -- melee
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 199, true)  -- pause (P)
            DisableControlAction(0, 200, true)  -- pause (ESC)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            if IsDisabledControlJustPressed(0, 200) then closeMenu() end
            Wait(0)
        end
    end)
end

local function openMenu()
    if isOpen or IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return end
    readContext()
    lookup = {}
    local items = prepare(Config.Menu, 'i')
    if #items == 0 then return end

    isOpen = true
    SendNUIMessage({
        action = 'open',
        title = Config.Title,
        color = Config.Color,
        keepInput = Config.KeepInput,
        sound = Config.Sound,
        context = ctx,
        items = items,
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(Config.KeepInput)
    SetCursorLocation(0.5, 0.5)
    if Config.KeepInput then blockControls() end
end

RegisterCommand('roxradial', function()
    if isOpen then closeMenu() else openMenu() end
end, false)
RegisterKeyMapping('roxradial', 'Open Radial Menu', 'keyboard', Config.Key)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('select', function(data, cb)
    cb('ok')
    local item = data and lookup[data.id]
    if not item then return end
    if not item.keepOpen then closeMenu() end

    if item.type == 'client' and item.event then
        TriggerEvent(item.event, item.args)
    elseif item.type == 'server' and item.event then
        TriggerServerEvent(item.event, item.args)
    elseif item.type == 'command' and item.command then
        ExecuteCommand(item.command)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then closeMenu() end
end)

exports('IsOpen', function() return isOpen end)
exports('Close', closeMenu)
exports('Open', openMenu)

---------------------------------------------------------------------------
-- Built-in vehicle actions
---------------------------------------------------------------------------
RegisterNetEvent('rox_radial:client:vehicle', function(args)
    args = args or {}
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if args.action == 'flip' then
        local coords = GetEntityCoords(ped)
        local target = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
        if target ~= 0 then
            SetVehicleOnGroundProperly(target)
        end
        return
    end

    if veh == 0 then return end

    if args.action == 'engine' then
        local on = GetIsVehicleEngineRunning(veh)
        SetVehicleEngineOn(veh, not on, false, true)
    elseif args.action == 'door' and args.door then
        if GetVehicleDoorAngleRatio(veh, args.door) > 0.0 then
            SetVehicleDoorShut(veh, args.door, false)
        else
            SetVehicleDoorOpen(veh, args.door, false, false)
        end
    elseif args.action == 'windows' then
        local down = Entity(veh).state.roxWindowsDown
        for i = 0, 3 do
            if down then RollUpWindow(veh, i) else RollDownWindow(veh, i) end
        end
        Entity(veh).state:set('roxWindowsDown', not down, false)
    elseif args.action == 'alldoors' then
        local open = false
        for i = 0, 5 do
            if GetVehicleDoorAngleRatio(veh, i) > 0.0 then open = true break end
        end
        for i = 0, 5 do
            if open then SetVehicleDoorShut(veh, i, false) else SetVehicleDoorOpen(veh, i, false, false) end
        end
    elseif args.action == 'window' and args.window then
        local key = 'roxWin' .. args.window
        local down = Entity(veh).state[key]
        if down then RollUpWindow(veh, args.window) else RollDownWindow(veh, args.window) end
        Entity(veh).state:set(key, not down, false)
    elseif args.action == 'seat' and args.seat then
        if IsVehicleSeatFree(veh, args.seat) then
            SetPedIntoVehicle(ped, veh, args.seat)
        end
    elseif args.action == 'lights' then
        local _, lightsOn, highOn = GetVehicleLightsState(veh)
        SetVehicleLights(veh, (lightsOn == 1 or highOn == 1) and 1 or 3)
    elseif args.action == 'shuffle' then
        if GetPedInVehicleSeat(veh, -1) == ped then
            TaskShuffleToNextVehicleSeat(ped, veh)
        elseif GetPedInVehicleSeat(veh, 0) == ped then
            TaskShuffleToNextVehicleSeat(ped, veh)
        end
    end
end)
