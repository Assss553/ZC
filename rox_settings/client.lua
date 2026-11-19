-- ROX Store | All rights reserved
local DEFAULT = { look = 'rox_nextgen', strength = 100, brightness = 0, crosshair = true, cinebars = false, idlecam = true,
                  radio = true, scanner = true, wantedmusic = true, sirens = true, flightmusic = true,
                  minimap = true, streetnames = true, fpsboost = false, shadows = 6, lod = 10,
                  accent = '#ff4b12', blur = true, menuscale = 100 }
local ACCENTS = { ['#ff4b12'] = true, ['#ff2d55'] = true, ['#2f9bff'] = true, ['#2fe36a'] = true, ['#a855f7'] = true, ['#ffc400'] = true }
local LOOKS = { off = true, rox_realistic = true, rox_cinematic = true, rox_vivid = true, rox_nightpro = true, rox_noir = true, rox_nextgen = true }
local PRESETS = {
    standard    = {},
    streamer    = { look = 'rox_cinematic', strength = 80, scanner = false, wantedmusic = false },
    performance = { look = 'off', fpsboost = true, shadows = 2, lod = 7 },
    cinema      = { look = 'rox_cinematic', strength = 100, cinebars = true, minimap = false, crosshair = false },
}
local S, isOpen = {}, false

local function load()
    for k, v in pairs(DEFAULT) do S[k] = v end
    local ok, t = pcall(json.decode, GetResourceKvpString('rox_settings') or '')
    if ok and type(t) == 'table' then
        for k, v in pairs(t) do if DEFAULT[k] ~= nil and type(v) == type(DEFAULT[k]) then S[k] = v end end
    end
    if not LOOKS[S.look] then S.look = DEFAULT.look end
end

local function clamp(v, a, b) return math.max(a, math.min(b, math.floor(v + 0.5))) end

local function apply()
    ClearTimecycleModifier(); ClearExtraTimecycleModifier()
    if S.fpsboost then
        SetTimecycleModifier('yell_tunnel_nodirect')           -- vanilla modifier: no direct light = more FPS
    elseif S.look ~= 'off' then
        SetTimecycleModifier(S.look)
        SetTimecycleModifierStrength(S.strength / 100.0)
    end
    if S.brightness ~= 0 then
        SetExtraTimecycleModifier(S.brightness > 0 and 'rox_exp_up' or 'rox_exp_down')
        SetExtraTimecycleModifierStrength(math.abs(S.brightness) / 10.0)
    end
    CascadeShadowsSetCascadeBoundsScale(S.shadows / 6.0)
    DisplayRadar(S.minimap)
    DisableIdleCamera(not S.idlecam)
    SetUserRadioControlEnabled(S.radio)
    SetAudioFlag('PoliceScannerDisabled', not S.scanner)
    SetAudioFlag('WantedMusicDisabled', not S.wantedmusic)
    SetAudioFlag('DisableFlightMusic', not S.flightmusic)
    DistantCopCarSirens(S.sirens)
    SetResourceKvp('rox_settings', json.encode(S))
end

local function sanitize(d)
    if type(d) ~= 'table' then return end
    if LOOKS[d.look] then S.look = d.look end
    if type(d.strength) == 'number' then S.strength = clamp(d.strength, 0, 100) end
    if type(d.brightness) == 'number' then S.brightness = clamp(d.brightness, -10, 10) end
    if type(d.shadows) == 'number' then S.shadows = clamp(d.shadows, 1, 10) end
    if type(d.lod) == 'number' then S.lod = clamp(d.lod, 5, 15) end
    if type(d.menuscale) == 'number' then S.menuscale = clamp(d.menuscale, 80, 120) end
    if ACCENTS[d.accent] then S.accent = d.accent end
    for _, k in ipairs({ 'crosshair', 'cinebars', 'minimap', 'fpsboost', 'idlecam', 'radio', 'scanner', 'wantedmusic',
                         'sirens', 'flightmusic', 'streetnames', 'blur' }) do
        if type(d[k]) == 'boolean' then S[k] = d[k] end
    end
end

local function open()
    if isOpen then return end
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', settings = S })
end
exports('open', open)
exports('get', function() return S end)

RegisterCommand('settings', open, false)
RegisterKeyMapping('settings', 'ROX Settings', 'keyboard', '')

RegisterNUICallback('set', function(d, cb) sanitize(d); apply(); cb(S) end)
RegisterNUICallback('preset', function(d, cb)
    local p = PRESETS[d and d.name]
    if p then
        for k, v in pairs(DEFAULT) do S[k] = v end
        for k, v in pairs(p) do S[k] = v end
        apply()
    end
    cb(S)
end)
RegisterNUICallback('hud', function(_, cb)
    cb('ok'); isOpen = false; SendNUIMessage({ action = 'close' }); SetNuiFocus(false, false)
    if GetResourceState('rox_hud') == 'started' then ExecuteCommand('hud') end
end)
RegisterNUICallback('close', function(_, cb) isOpen = false; SetNuiFocus(false, false); cb('ok') end)

-- per-frame: crosshair + cinema bars
CreateThread(function()
    load(); apply()
    while true do
        local busy = S.lod ~= 10
        if S.lod ~= 10 then OverrideLodscaleThisFrame(S.lod / 10.0) end
        if not S.streetnames then HideHudComponentThisFrame(7); HideHudComponentThisFrame(9); busy = true end
        if not S.crosshair then HideHudComponentThisFrame(14); busy = true end
        if S.cinebars then
            DrawRect(0.5, 0.055, 1.0, 0.11, 0, 0, 0, 255)
            DrawRect(0.5, 0.945, 1.0, 0.11, 0, 0, 0, 255)
            busy = true
        end
        Wait(busy and 0 or 500)
    end
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() then ClearTimecycleModifier(); ClearExtraTimecycleModifier() end
end)
