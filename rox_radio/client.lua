-- ROX Store | All rights reserved
-- Vehicle radio strip: hold the GTA radio key (Q on keyboard, d-pad left) or the mapped key.
-- Mouse wheel / arrows = change station, X = turn off, release = keep.
local Key = 'Q'
local open, list, idx = false, {}, 1

local function stations()
    local t = { { id = 'OFF', off = true } }
    for i = 0, GetNumUnlockedRadioStations() - 1 do
        local id = GetRadioStationName(i)
        local label = GetLabelText(id)
        if label == 'NULL' or label == '' then label = id:gsub('RADIO_%d+_', ''):gsub('_', ' ') end
        t[#t + 1] = { id = id, label = label }
    end
    return t
end

local function current()
    local name = GetPlayerRadioStationName()
    if not name or name == '' or GetPlayerRadioStationIndex() == 255 then return 1 end
    for i, s in ipairs(list) do if s.id == name then return i end end
    return 1
end

local function send(action)
    SendNUIMessage({ action = action, list = list, index = idx - 1, volume = GetProfileSetting(306) / 10.0, source = 'vehicle',
                     track = list[idx] and not list[idx].off and 'Live' or '' })
end

local function apply()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return end
    if list[idx].off then SetVehRadioStation(veh, 'OFF') else SetVehicleRadioEnabled(veh, true); SetVehRadioStation(veh, list[idx].id) end
    PlaySoundFrontend(-1, 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function openRadio()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if open or veh == 0 or not (GetPedInVehicleSeat(veh, -1) == ped or GetPedInVehicleSeat(veh, 0) == ped) then return end
    open = true; list = stations(); idx = current(); send('open')
    CreateThread(function()
        while open do
            HudWeaponWheelIgnoreSelection(); DisableControlAction(0, 85, true); DisableControlAction(0, 81, true); DisableControlAction(0, 82, true)
            DisableControlAction(0, 14, true); DisableControlAction(0, 15, true); DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)
            local d = 0
            if IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 175) then d = 1 end
            if IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 174) then d = -1 end
            if d ~= 0 then idx = (idx - 1 + d) % #list + 1; apply(); send('update') end
            if IsControlJustPressed(0, 73) then idx = 1; apply(); send('update') end
            if GetVehiclePedIsIn(PlayerPedId(), false) == 0 then open = false end
            Wait(0)
        end
        SendNUIMessage({ action = 'close' })
    end)
end

-- hide GTA's radio wheel
CreateThread(function()
    while true do
        if IsPedInAnyVehicle(PlayerPedId(), false) then HideHudComponentThisFrame(16); DisableControlAction(0, 85, true); Wait(0) else Wait(500) end
    end
end)

RegisterCommand('+roxradio', openRadio, false)
RegisterCommand('-roxradio', function() open = false end, false)
RegisterKeyMapping('+roxradio', 'Vehicle radio (hold)', 'keyboard', Key)
