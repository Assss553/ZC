--[[ ROX Store | rox_hud V3 | All rights reserved. ]]
local QB, ESX = nil, nil
local status = { hunger = 100, thirst = 100, stress = 0 }
local belt, voiceMode, radioTalk = false, 2, false

-- player settings (saved on the client with KVP)
local settings = {
    compass = Config.Compass, info = Config.PlayerInfo, mapOnFoot = not Config.HideMinimapOnFoot,
    vignette = Config.LowHealthVignette, alwaysStatus = false, showMap = true, showId = true, showJob = true, scale = 100, unit = Config.SpeedUnit, color = Config.Color, hidden = false,
}
do
    local raw = GetResourceKvpString('rox_hud_settings')
    local ok, t = pcall(json.decode, raw or '')
    if ok and type(t) == 'table' then for k, v in pairs(t) do if settings[k] ~= nil and type(v) == type(settings[k]) then settings[k] = v end end end
end
local function saveSettings() SetResourceKvp('rox_hud_settings', json.encode(settings)) end

CreateThread(function()
    if GetResourceState('qb-core') == 'started' then QB = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then ESX = exports['es_extended']:getSharedObject() end
end)

-- needs / stress (QBCore events, ESX esx_status)
RegisterNetEvent('hud:client:UpdateNeeds', function(h, t) status.hunger, status.thirst = h, t end)
RegisterNetEvent('hud:client:UpdateStress', function(s) status.stress = s end)
AddEventHandler('esx_status:onTick', function(data)
    for _, v in ipairs(data) do
        if v.name == 'hunger' then status.hunger = v.percent elseif v.name == 'thirst' then status.thirst = v.percent elseif v.name == 'stress' then status.stress = v.percent end
    end
end)
-- pma-voice
AddEventHandler('pma-voice:setTalkingMode', function(m) voiceMode = m end)
AddEventHandler('pma-voice:radioActive', function(on) radioTalk = on end)

RegisterCommand(Config.SeatbeltCommand, function()
    if not IsPedInAnyVehicle(PlayerPedId(), false) then return end
    belt = not belt
    PlaySoundFrontend(-1, belt and 'Faster_Click' or 'Faster_Click', 'RESPAWN_ONLINE_SOUNDSET', true)
end, false)
RegisterKeyMapping(Config.SeatbeltCommand, 'Seatbelt', 'keyboard', Config.SeatbeltKey)
exports('IsSeatbeltOn', function() return belt end)

-- exact minimap rectangle on this screen (fractions of the screen)
local function minimapAnchor()
    local safezone = GetSafeZoneSize()
    local aspect = GetAspectRatio(false)
    local resX, resY = GetActiveScreenResolution()
    local xs, ys = 1.0 / resX, 1.0 / resY
    local off = math.abs(safezone - 1.0) * 10
    local w = xs * (resX / (4 * aspect))
    local h = ys * (resY / 5.674)
    local x = xs * (resX * (0.05 * off))
    local bottom = 1.0 - ys * (resY * (0.05 * off))
    return { x = x, y = bottom - h, w = w, h = h }
end

local function sendInit()
    SendNUIMessage({ action = 'init', settings = settings, maxSpeed = Config.MaxSpeed, map = minimapAnchor() })
end

-- hide GTA's own HUD pieces that we replace
CreateThread(function()
    if not Config.HideDefaultHud then return end
    local mm = RequestScaleformMovie('minimap')
    SetRadarBigmapEnabled(true, false) Wait(0) SetRadarBigmapEnabled(false, false)
    while true do
        Wait(0)
        BeginScaleformMovieMethod(mm, 'SETUP_HEALTH_ARMOUR')
        ScaleformMovieMethodAddParamInt(3)
        EndScaleformMovieMethod()
        HideHudComponentThisFrame(6)  -- vehicle name
        HideHudComponentThisFrame(7)  -- area name
        HideHudComponentThisFrame(8)  -- vehicle class
        HideHudComponentThisFrame(9)  -- street name
    end
end)

local function fuel(veh)
    if GetResourceState('LegacyFuel') == 'started' then local ok, f = pcall(function() return exports.LegacyFuel:GetFuel(veh) end) if ok and f then return f end end
    if GetResourceState('ox_fuel') == 'started' then return Entity(veh).state.fuel or GetVehicleFuelLevel(veh) end
    return GetVehicleFuelLevel(veh)
end

local function playerInfo()
    local out = { id = GetPlayerServerId(PlayerId()), time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()) }
    if QB then
        local d = QB.Functions.GetPlayerData()
        if d and d.money then
            out.cash, out.bank = d.money.cash, d.money.bank
            if d.job then out.job, out.grade, out.duty = d.job.label, d.job.grade and d.job.grade.name, d.job.onduty end
        end
    elseif ESX then
        local d = ESX.GetPlayerData()
        if d then
            for _, a in ipairs(d.accounts or {}) do
                if a.name == 'money' then out.cash = a.money elseif a.name == 'bank' then out.bank = a.money end
            end
            if d.job then out.job, out.grade, out.duty = d.job.label, d.job.grade_label, true end
        end
    end
    return out
end

local DIRS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }
local lastRes = 0

CreateThread(function()
    Wait(1000)
    sendInit()
    while true do
        local ped, pid = PlayerPedId(), PlayerId()
        if QB then
            local d = QB.Functions.GetPlayerData()
            if d and d.metadata then status.hunger, status.thirst, status.stress = d.metadata.hunger or status.hunger, d.metadata.thirst or status.thirst, d.metadata.stress or status.stress end
        end
        local veh = GetVehiclePedIsIn(ped, false)
        local inVeh = veh ~= 0
        if not inVeh then belt = false end
        local radar = settings.showMap and (inVeh or settings.mapOnFoot) and not settings.hidden
        DisplayRadar(radar)

        -- resolution / safe zone changed: re-align with the minimap
        if GetGameTimer() - lastRes > 5000 then lastRes = GetGameTimer(); SendNUIMessage({ action = 'map', map = minimapAnchor() }) end

        local c = GetEntityCoords(ped)
        local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
        local heading = (360.0 - GetGameplayCamRot(0).z) % 360.0
        local data = {
            action = 'tick', hidden = settings.hidden or IsPauseMenuActive() or IsScreenFadedOut(), radar = radar,
            health = math.max(0, GetEntityHealth(ped) - 100), armor = GetPedArmour(ped),
            hunger = status.hunger, thirst = status.thirst, stress = status.stress,
            stamina = 100 - GetPlayerSprintStaminaRemaining(pid),
            oxygen = IsPedSwimmingUnderWater(ped) and GetPlayerUnderwaterTimeRemaining(pid) * 10 or nil,
            talking = NetworkIsPlayerTalking(pid), radio = radioTalk, voice = voiceMode,
            heading = heading, dir = DIRS[math.floor((heading + 22.5) / 45) % 8 + 1],
            street = GetStreetNameFromHashKey(s1), cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or '',
            zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z)),
            info = settings.info and playerInfo() or nil,
        }
        if inVeh then
            local sp = GetEntitySpeed(veh) * (settings.unit == 'mph' and 2.236936 or 3.6)
            local _, lightsOn, highOn = GetVehicleLightsState(veh)
            data.veh = {
                speed = math.floor(sp), rpm = GetVehicleCurrentRpm(veh), gear = GetVehicleCurrentGear(veh), fuel = fuel(veh),
                engine = GetVehicleEngineHealth(veh) / 10, belt = belt, lights = lightsOn == 1 or highOn == 1,
                locked = GetVehicleDoorLockStatus(veh) >= 2, running = GetIsVehicleEngineRunning(veh),
            }
        end
        SendNUIMessage(data)
        Wait(inVeh and 80 or Config.Update)
    end
end)

-- /minimap shows / hides the minimap (bind it in GTA settings > Key Bindings > FiveM)
RegisterCommand(Config.MapCommand, function()
    settings.showMap = not settings.showMap
    saveSettings(); sendInit()
end, false)
RegisterKeyMapping(Config.MapCommand, 'Show / hide minimap', 'keyboard', Config.MapKey)

-- /hud settings
RegisterCommand(Config.SettingsCommand, function()
    SendNUIMessage({ action = 'settings', settings = settings })
    SetNuiFocus(true, true)
end, false)

RegisterNUICallback('saveSettings', function(d, cb)
    cb('ok')
    if type(d) ~= 'table' then return end
    for _, k in ipairs({ 'compass', 'info', 'mapOnFoot', 'vignette', 'hidden', 'alwaysStatus', 'showMap', 'showId', 'showJob' }) do
        if type(d[k]) == 'boolean' then settings[k] = d[k] end
    end
    if type(d.scale) == 'number' then settings.scale = math.max(60, math.min(140, math.floor(d.scale))) end
    if d.unit == 'kmh' or d.unit == 'mph' then settings.unit = d.unit end
    if type(d.color) == 'string' and d.color:match('^#%x%x%x%x%x%x$') then settings.color = d.color end
    saveSettings()
    sendInit()
end)

RegisterNUICallback('closeSettings', function(_, cb) cb('ok') SetNuiFocus(false, false) end)

-- /cash and /bank
RegisterCommand(Config.CashCommand, function() SendNUIMessage({ action = 'money', which = 'cash', time = Config.MoneyShowTime }) end, false)
RegisterCommand(Config.BankCommand, function() SendNUIMessage({ action = 'money', which = 'bank', time = Config.MoneyShowTime }) end, false)

-- ESC pause menu
local pauseOpen = false
local function openPause()
    if pauseOpen then return end
    pauseOpen = true
    TriggerServerEvent('rox_hud:server:pause')
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local s1 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local wp; local b = GetFirstBlipInfoId(8); if DoesBlipExist(b) then local w = GetBlipInfoIdCoord(b); wp = { x = w.x, y = w.y } end
    SendNUIMessage({ action = 'pause', open = true, info = playerInfo(), activities = Config.Activities, server = Config.ServerName, blips = Config.MapBlips,
        coords = { x = c.x, y = c.y, h = GetEntityHeading(ped) }, waypoint = wp,
        location = GetLabelText(GetNameOfZone(c.x, c.y, c.z)) .. ' - ' .. GetStreetNameFromHashKey(s1) })
    CreateThread(function()
        while pauseOpen do Wait(500) local p = GetEntityCoords(PlayerPedId()); SendNUIMessage({ action = 'pauseCoords', coords = { x = p.x, y = p.y, h = GetEntityHeading(PlayerPedId()) } }) end
    end)
    SetNuiFocus(true, true)
end
local function closePause()
    pauseOpen = false
    SendNUIMessage({ action = 'pause', open = false })
    SetNuiFocus(false, false)
end
RegisterNetEvent('rox_hud:client:pause', function(d) if pauseOpen then SendNUIMessage({ action = 'pauseData', data = d }) end end)

if Config.PauseMenu then
    CreateThread(function()
        while true do
            Wait(0)
            DisableControlAction(0, 200, true) -- ESC
            DisableControlAction(0, 199, true) -- P
            if not pauseOpen and not IsPauseMenuActive() and (IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 199)) then
                openPause()
            end
        end
    end)
end

RegisterNUICallback('waypoint', function(d, cb) if d.x and d.y then SetNewWaypoint(d.x + 0.0, d.y + 0.0) end cb(1) end)

RegisterNUICallback('pause', function(d, cb)
    cb('ok')
    local a = type(d) == 'table' and d.action
    closePause()
    if a == 'map' then ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1)
    elseif a == 'settings' then ActivateFrontendMenu(`FE_MENU_VERSION_LANDING_MENU`, false, -1)
    elseif a == 'hud' then SendNUIMessage({ action = 'settings', settings = settings }) SetNuiFocus(true, true)
    elseif a == 'quit' then TriggerServerEvent('rox_hud:server:quit') end
end)

-- other scripts can hide the HUD (cutscenes, iPads ...)
exports('SetHidden', function(state) settings.hidden = state == true end)
