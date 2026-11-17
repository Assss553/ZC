--[[ ROX Store | rox_hud | All rights reserved. ]]
local QB, ESX, status = nil, nil, { hunger = 100, thirst = 100, stress = 0 }
local belt, voiceMode = false, 2

CreateThread(function()
    if GetResourceState('qb-core') == 'started' then QB = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then ESX = exports['es_extended']:getSharedObject() end
end)

-- QBCore / Qbox metadata
RegisterNetEvent('hud:client:UpdateNeeds', function(h, t) status.hunger, status.thirst = h, t end)
RegisterNetEvent('hud:client:UpdateStress', function(s) status.stress = s end)
-- ESX esx_status
AddEventHandler('esx_status:onTick', function(data)
    for _, v in ipairs(data) do
        if v.name == 'hunger' then status.hunger = v.percent elseif v.name == 'thirst' then status.thirst = v.percent end
    end
end)
-- pma-voice range
AddEventHandler('pma-voice:setTalkingMode', function(m) voiceMode = m end)

RegisterCommand(Config.SeatbeltCommand, function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    belt = not belt
    SendNUIMessage({ action = 'belt', on = belt })
end, false)
RegisterKeyMapping(Config.SeatbeltCommand, 'Seatbelt', 'keyboard', Config.SeatbeltKey)

local function fuel(veh)
    if GetResourceState('LegacyFuel') == 'started' then local ok, f = pcall(function() return exports.LegacyFuel:GetFuel(veh) end) if ok then return f end end
    if GetResourceState('ox_fuel') == 'started' then return Entity(veh).state.fuel or GetVehicleFuelLevel(veh) end
    return GetVehicleFuelLevel(veh)
end

local DIRS = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }

CreateThread(function()
    Wait(1000)
    SendNUIMessage({ action = 'init', color = Config.Color, unit = Config.SpeedUnit, compass = Config.Compass })
    while true do
        local ped, pid = PlayerPedId(), PlayerId()
        if QB then local d = QB.Functions.GetPlayerData(); if d and d.metadata then status.hunger, status.thirst, status.stress = d.metadata.hunger or status.hunger, d.metadata.thirst or status.thirst, d.metadata.stress or status.stress end end
        local veh = GetVehiclePedIsIn(ped, false)
        local inVeh = veh ~= 0
        if not inVeh then belt = false end
        DisplayRadar(inVeh or not Config.HideMinimapOnFoot)
        local c = GetEntityCoords(ped)
        local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
        local heading = (360.0 - GetGameplayCamRot(0).z) % 360.0
        local data = {
            action = 'tick', hidden = IsPauseMenuActive() or IsScreenFadedOut(),
            health = math.max(0, GetEntityHealth(ped) - 100), armor = GetPedArmour(ped),
            hunger = status.hunger, thirst = status.thirst, stress = status.stress,
            stamina = 100 - GetPlayerSprintStaminaRemaining(pid),
            oxygen = IsPedSwimmingUnderWater(ped) and GetPlayerUnderwaterTimeRemaining(pid) * 10 or nil,
            talking = NetworkIsPlayerTalking(pid), voice = voiceMode,
            heading = heading, dir = DIRS[math.floor((heading + 22.5) / 45) % 8 + 1],
            street = GetStreetNameFromHashKey(s1), cross = s2 ~= 0 and GetStreetNameFromHashKey(s2) or '',
            zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z)),
            veh = nil,
        }
        if inVeh then
            local sp = GetEntitySpeed(veh) * (Config.SpeedUnit == 'mph' and 2.236936 or 3.6)
            data.veh = { speed = math.floor(sp), rpm = GetVehicleCurrentRpm(veh), gear = GetVehicleCurrentGear(veh), fuel = fuel(veh),
                engine = GetVehicleEngineHealth(veh) / 10, belt = belt, lights = select(2, GetVehicleLightsState(veh)) == 1, locked = GetVehicleDoorLockStatus(veh) >= 2, maxGear = GetVehicleHighGear(veh) }
        end
        SendNUIMessage(data)
        Wait(inVeh and 80 or Config.Update)
    end
end)
