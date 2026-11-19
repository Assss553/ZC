-- ROX Store | All rights reserved
-- Living world: wind that moves trees & grass, weather-matched cloud layers, heavier wet rain, rain/fog grading.
-- Works on top of any weather sync (it never changes the weather itself, only reacts to it).
local Config = {
    Wind      = { min = 0.15, max = 1.0, storm = 3.0, change = 25 },   -- wind speed (m/s-ish), seconds between gusts
    Clouds    = true,
    RainBoost = 1.35,       -- multiplier on rain intensity while raining
    Grade     = true,       -- timecycle grading for rain & fog (rox_rain / rox_fog in timecycle_world.xml)
    TimeOfDay = true,       -- golden hour (06-08 / 18-20) and cleaner night (21-05) when the weather is dry
    Shadows   = true,       -- sharper, longer shadows + shadows from more entities
}

local W = { clear = { 'EXTRASUNNY', 'CLEAR', 'NEUTRAL' }, cloud = { 'CLOUDS', 'SMOG', 'OVERCAST' }, rain = { 'RAIN', 'CLEARING' }, storm = { 'THUNDER' }, fog = { 'FOGGY' }, snow = { 'SNOW', 'SNOWLIGHT', 'BLIZZARD', 'XMAS' } }
local HATS = { clear = { 'Wispy', 'Cirrus', 'Puffs' }, cloud = { 'Altostratus', 'Cloudy 01', 'Stratoscumulus' }, rain = { 'Rain', 'Stormy 01' }, storm = { 'Stormy 01', 'Shower' }, fog = { 'Altostratus', 'Contrails' }, snow = { 'Snowy 01', 'Cloudy 01' } }

local function group(hash)
    for g, list in pairs(W) do for _, n in ipairs(list) do if hash == joaat(n) then return g end end end
    return 'clear'
end

local function lerp(a, b, t) return a + (b - a) * t end

CreateThread(function()
    local wind, target, dir, tdir, nextGust = 0.3, 0.3, 0.0, 0.0, 0
    local lastGroup, lastHat = nil, nil
    local grade = nil
    while true do
        local now = GetGameTimer()
        local g = group(GetPrevWeatherTypeHashName())
        local nextG = group(GetNextWeatherTypeHashName())
        local _, _, pct = GetWeatherTypeTransition()
        if pct and pct > 0.5 then g = nextG end

        -- wind: smooth gusts. trees, grass, flags, water ripples follow SetWind*
        if now > nextGust then
            local top = (g == 'storm' and Config.Wind.storm) or (g == 'rain' and Config.Wind.max * 1.6) or Config.Wind.max
            target = Config.Wind.min + math.random() * (top - Config.Wind.min)
            tdir = (dir + math.random(-60, 60)) % 360
            nextGust = now + (Config.Wind.change * 1000) * (0.5 + math.random())
        end
        wind = lerp(wind, target, 0.02); dir = lerp(dir, tdir, 0.01)
        SetWind(1.0); SetWindSpeed(wind); SetWindDirection(math.rad(dir))

        -- clouds that match the weather
        if Config.Clouds and g ~= lastGroup then
            local list = HATS[g]; local hat = list[math.random(#list)]
            if hat ~= lastHat then
                if lastHat then UnloadCloudHat(lastHat, 0.0) end
                LoadCloudHat(hat, 25.0); lastHat = hat
            end
            SetCloudsAlpha(g == 'clear' and 0.55 or 1.0)
        end

        -- rain: heavier + wet roads
        if g == 'rain' or g == 'storm' then
            local base = g == 'storm' and 1.0 or 0.6
            SetRainLevel(math.min(1.0, base * Config.RainBoost))
        else
            SetRainLevel(-1.0)
        end

        -- grading
        if Config.Grade then
            local want = (g == 'rain' or g == 'storm') and 'rox_rain' or (g == 'fog' and 'rox_fog') or nil
            if not want and Config.TimeOfDay then
                local h = GetClockHours()
                if (h >= 6 and h < 8) or (h >= 18 and h < 20) then want = 'rox_golden' elseif h >= 21 or h < 5 then want = 'rox_night' end
            end
            -- rox_settings uses the extra modifier for its brightness boost: don't fight it
            if GetResourceState('rox_settings') == 'started' then
                local ok, st = pcall(function() return exports.rox_settings:get() end)
                if ok and st and st.brightness and st.brightness ~= 0 then want = nil end
            end
            if want ~= grade then
                if want then SetExtraTimecycleModifier(want); SetExtraTimecycleModifierStrength(0.8)
                elseif grade then ClearExtraTimecycleModifier() end
                grade = want
            end
        end
        lastGroup = g
        Wait(100)
    end
end)

-- shadows
if Config.Shadows then
    CreateThread(function()
        while true do
            CascadeShadowsEnableEntityTracker(true)
            CascadeShadowsSetDynamicDepthMode(true)
            CascadeShadowsSetEntityTrackerScale(1.6)
            CascadeShadowsSetDynamicDepthValue(0.6)
            Wait(5000)
        end
    end)
end

-- lightning flashes feel stronger in storms
CreateThread(function()
    while true do
        Wait(15000 + math.random(0, 25000))
        if group(GetPrevWeatherTypeHashName()) == 'storm' then ForceLightningFlash() end
    end
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() then SetWind(0.0); SetRainLevel(-1.0); ClearExtraTimecycleModifier() end
end)
