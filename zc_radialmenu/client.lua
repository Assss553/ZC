local isOpen = false
local lookup = {}
local QBCore, ESX

local function getJob()
    if GetResourceState('qbx_core') == 'started' then
        local ok, data = pcall(function() return exports.qbx_core:GetPlayerData() end)
        if ok and data and data.job then return data.job.name end
    end
    if GetResourceState('qb-core') == 'started' then
        if not QBCore then
            local ok, obj = pcall(function() return exports['qb-core']:GetCoreObject() end)
            if ok then QBCore = obj end
        end
        if QBCore then
            local data = QBCore.Functions.GetPlayerData()
            if data and data.job then return data.job.name end
        end
    end
    if GetResourceState('es_extended') == 'started' then
        if not ESX then
            local ok, obj = pcall(function() return exports['es_extended']:getSharedObject() end)
            if ok then ESX = obj end
        end
        if ESX then
            local data = ESX.GetPlayerData()
            if data and data.job then return data.job.name end
        end
    end
    return nil
end

local function prepare(items, prefix)
    local out = {}
    for _, item in ipairs(items) do
        local visible = true
        if item.canInteract then
            local ok, res = pcall(item.canInteract)
            visible = ok and res
        end
        if visible then
            local id = prefix .. (#out + 1)
            lookup[id] = item
            local entry = { id = id, label = item.label, icon = item.icon }
            if item.items then entry.items = prepare(item.items, id .. '-') end
            out[#out + 1] = entry
        end
    end
    return out
end

local function buildMenu()
    lookup = {}
    local items = {}
    local job = getJob()
    if job and Config.JobItems[job] then
        for _, v in ipairs(Config.JobItems[job]) do items[#items + 1] = v end
    end
    for _, v in ipairs(Config.MenuItems) do items[#items + 1] = v end
    return prepare(items, 'i')
end

local function closeMenu()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
end

local function openMenu()
    if isOpen or IsPauseMenuActive() then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    isOpen = true
    SendNUIMessage({
        action = 'open',
        title = Config.Title,
        color = Config.Color,
        keepInput = Config.KeepInput,
        sound = Config.Sound,
        items = buildMenu(),
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(Config.KeepInput)
    SetCursorLocation(0.5, 0.5)

    if Config.KeepInput then
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
end

RegisterCommand('zcradial', function()
    if isOpen then closeMenu() else openMenu() end
end, false)
RegisterKeyMapping('zcradial', 'Open Radial Menu', 'keyboard', Config.Key)

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

---------------------------------------------------------------------------
-- Built-in vehicle actions
---------------------------------------------------------------------------
RegisterNetEvent('zc_radial:client:vehicle', function(args)
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
        local down = Entity(veh).state.zcWindowsDown
        for i = 0, 3 do
            if down then RollUpWindow(veh, i) else RollDownWindow(veh, i) end
        end
        Entity(veh).state:set('zcWindowsDown', not down, false)
    elseif args.action == 'shuffle' then
        if GetPedInVehicleSeat(veh, -1) == ped then
            TaskShuffleToNextVehicleSeat(ped, veh)
        elseif GetPedInVehicleSeat(veh, 0) == ped then
            TaskShuffleToNextVehicleSeat(ped, veh)
        end
    end
end)
