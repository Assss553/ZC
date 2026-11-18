-- ROX Store | All rights reserved
local DEFAULT = { look = 'rox_realistic', strength = 100, brightness = 0, crosshair = true,
                  cinebars = false, minimap = true, fpsboost = false, shadows = 6 }
local LOOKS = { off = true, rox_realistic = true, rox_cinematic = true, rox_vivid = true, rox_nightpro = true, rox_noir = true }
local PRESETS = {
    standard    = {},
    streamer    = { look = 'rox_cinematic', strength = 80, cinebars = false, minimap = true },
    performance = { look = 'off', fpsboost = true, shadows = 2 },
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
    SetResourceKvp('rox_settings', json.encode(S))
end

local function sanitize(d)
    if type(d) ~= 'table' then return end
    if LOOKS[d.look] then S.look = d.look end
    if type(d.strength) == 'number' then S.strength = clamp(d.strength, 0, 100) end
    if type(d.brightness) == 'number' then S.brightness = clamp(d.brightness, -10, 10) end
    if type(d.shadows) == 'number' then S.shadows = clamp(d.shadows, 1, 10) end
    for _, k in ipairs({ 'crosshair', 'cinebars', 'minimap', 'fpsboost' }) do
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
RegisterNUICallback('close', function(_, cb) isOpen = false; SetNuiFocus(false, false); cb('ok') end)

-- per-frame: crosshair + cinema bars
CreateThread(function()
    load(); apply()
    while true do
        local busy = false
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
