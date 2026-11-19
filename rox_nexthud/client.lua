-- ROX Store | All rights reserved
local Config = {
    Imperial     = true,     -- ft / mi like the reference. false = m / km
    MoneyKey     = 'Z',      -- show cash + bank for a few seconds
    MoneyTime    = 5000,
    HideGtaMoney = true,
    ShowCompass  = true,
    ShowMinimapFrame = true,
    -- GenerateDirectionsToCoord result -> text + arrow (verify in game, the ids are community-documented)
    Directions = {
        [0] = { 'Continue', 'straight' }, [1] = { 'Recalculating', 'uturn' }, [2] = { 'Continue', 'straight' },
        [3] = { 'Turn Left', 'left' }, [4] = { 'Turn Right', 'right' }, [5] = { 'Keep Left', 'keepleft' },
        [6] = { 'Keep Right', 'keepright' }, [7] = { 'Turn Left', 'left' }, [8] = { 'Turn Right', 'right' },
    },
}

local function fmt(m, short)
    if Config.Imperial then
        local ft = m * 3.28084
        if ft < 1000 or short then return ('%d ft'):format(math.floor(ft / 5 + 0.5) * 5) end
        return ('%.2f mi'):format(m / 1609.34)
    end
    if m < 1000 or short then return ('%d m'):format(math.floor(m / 5 + 0.5) * 5) end
    return ('%.1f km'):format(m / 1000)
end

local function minimapRect()
    SetScriptGfxAlign(string.byte('L'), string.byte('B'))
    local tlx, tly = GetScriptGfxPosition(-0.0045, 0.002 + (-0.188888))
    local brx, bry = GetScriptGfxPosition(-0.0045 + 0.1638, 0.002)
    ResetScriptGfxAlign()
    local rx, ry = GetActiveScreenResolution()
    return { x = tlx * rx, y = tly * ry, w = (brx - tlx) * rx, h = (bry - tly) * ry }
end

local function hideHealthBars()
    CreateThread(function()
        local mm = RequestScaleformMovie('minimap')
        while not HasScaleformMovieLoaded(mm) do Wait(0) end
        for _ = 1, 10 do
            BeginScaleformMovieMethod(mm, 'SETUP_HEALTH_ARMOUR'); ScaleformMovieMethodAddParamInt(3); EndScaleformMovieMethod()
            Wait(200)
        end
    end)
end

CreateThread(function()
    hideHealthBars()
    local rect = minimapRect()
    local tick = 0
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local radar = IsRadarEnabled() and not IsRadarHidden() and not IsPauseMenuActive()
        tick = tick + 1
        if tick % 20 == 0 then rect = minimapRect() end
        local d = { action = 'tick', compass = Config.ShowCompass and not IsPauseMenuActive() and not IsScreenFadedOut() }
        rect.show = Config.ShowMinimapFrame and radar; d.mm = rect

        local cam = GetGameplayCamRot(2)
        d.heading = (-cam.z) % 360
        local wpBlip = GetFirstBlipInfoId(8)
        if DoesBlipExist(wpBlip) then
            local w = GetBlipInfoIdCoord(wpBlip)
            local p = GetEntityCoords(ped)
            d.wpHeading = math.deg(math.atan(w.x - p.x, w.y - p.y)) % 360
            if veh ~= 0 then
                local _, dir, _, dist = GenerateDirectionsToCoord(w.x, w.y, w.z, true)
                local info = Config.Directions[dir] or Config.Directions[0]
                local total = GetGpsBlipRouteLength()
                if total > 0 and total < 40 then info = { 'Arriving', 'arrive' } end
                d.gps = { text = info[1], icon = info[2], dist = fmt(math.max(0.0, dist), true) }
                if total > 0 then d.dist = fmt(total) end
            end
        end

        if veh ~= 0 then
            local fuel = Entity(veh).state.fuel or GetVehicleFuelLevel(veh)
            local gear = GetVehicleCurrentGear(veh)
            local sp = GetEntitySpeed(veh) * (Config.Imperial and 2.236936 or 3.6)
            local _, lightsOn, high = GetVehicleLightsState(veh)
            d.veh = { engine = math.max(0, math.min(100, GetVehicleEngineHealth(veh) / 10)), fuel = math.max(0, math.min(100, fuel)),
                      speed = sp, unit = Config.Imperial and 'MPH' or 'KMH', rpm = GetVehicleCurrentRpm(veh),
                      gear = (GetEntitySpeedVector(veh, true).y < -0.5 and 'R') or (gear == 0 and 'N') or gear,
                      lights = lightsOn == 1 or high == 1, locked = GetVehicleDoorLockStatus(veh) >= 2,
                      belt = LocalPlayer.state.seatbelt or LocalPlayer.state.seatBelt or LocalPlayer.state.harness or false }
            local cls = GetVehicleClass(veh)
            if cls == 13 then d.veh.speed = nil end   -- bicycles
            local cls = GetVehicleClass(veh)
            if cls == 15 or cls == 16 then d.alt = fmt(GetEntityHeightAboveGround(veh), true) end
        end
        SendNUIMessage(d)
        Wait(veh ~= 0 and 60 or 250)
    end
end)

if Config.HideGtaMoney then
    CreateThread(function()
        while true do HideHudComponentThisFrame(3); HideHudComponentThisFrame(4); HideHudComponentThisFrame(13); Wait(0) end
    end)
end

-- ---------------------------------------------------------------- money
local function moneyNow()
    local ok, pd = pcall(function() return exports.qbx_core:GetPlayerData() end)
    local m = ok and pd and pd.money or {}
    return m.cash or 0, m.bank or 0
end

local function showMoney(showBank)
    local cash, bank = moneyNow()
    SendNUIMessage({ action = 'money', cash = cash, bank = bank, showBank = showBank ~= false, time = Config.MoneyTime })
end

RegisterCommand('+roxmoney', function() showMoney(true) end, false)
RegisterCommand('-roxmoney', function() end, false)
RegisterKeyMapping('+roxmoney', 'Show cash & bank', 'keyboard', Config.MoneyKey)

local function onChange(account, amount, operation, reason)
    if account ~= 'cash' and account ~= 'bank' then return end
    local signed = (operation == 'remove' or operation == 'minus') and -math.abs(amount) or math.abs(amount)
    showMoney(account == 'bank')
    if signed > 0 then SendNUIMessage({ action = 'toast', amount = signed, from = type(reason) == 'string' and reason ~= '' and reason or nil }) end
end
RegisterNetEvent('QBCore:Client:OnMoneyChange', onChange)
RegisterNetEvent('qbx_core:client:onMoneyChange', onChange)

-- other scripts: exports.rox_nexthud:Received(250, 'Donnie')
exports('Received', function(amount, from) SendNUIMessage({ action = 'toast', amount = amount, from = from }); showMoney(true) end)
exports('ShowMoney', showMoney)
