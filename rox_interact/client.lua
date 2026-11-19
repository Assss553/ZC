-- ROX Store | All rights reserved
-- 1) Choice list:  local i = exports.rox_interact:Choose({ {label='Tropical Green Paint'}, {label='Stormy Blue Paint', price=40} })
--    (scroll / arrows to move, E to pick, BACKSPACE to cancel) -> returns index or nil
-- 2) Prompt:       exports.rox_interact:Prompt('Open') / exports.rox_interact:Prompt(nil)
-- 3) Keypad:       local ok = exports.rox_interact:Keypad({ length = 4, check = function(code) return code == '6666' end })
-- 4) Quick heal:   hold H to see, 1 / 2 to use (items from Config.Heal)

-- ---------------------------------------------------------------- prompt
exports('Prompt', function(text, key) SendNUIMessage({ action = 'prompt', text = text, key = key or 'E' }) end)

-- ---------------------------------------------------------------- choice list
local choosing = false
exports('Choose', function(options, key)
    if choosing or type(options) ~= 'table' or #options == 0 then return nil end
    choosing = true
    local sel, result = 1, nil
    SendNUIMessage({ action = 'choice', options = options, sel = 0, key = key or 'E' })
    while choosing do
        DisableControlAction(0, 14, true); DisableControlAction(0, 15, true); DisableControlAction(0, 38, true)
        DisableControlAction(0, 172, true); DisableControlAction(0, 173, true); DisableControlAction(0, 24, true)
        local d = 0
        if IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 172) then d = -1 end
        if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 173) then d = 1 end
        if d ~= 0 then
            sel = (sel - 1 + d) % #options + 1
            SendNUIMessage({ action = 'choiceSel', sel = sel - 1 })
            PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
        if IsDisabledControlJustReleased(0, 38) then result = sel; choosing = false end
        if IsControlJustPressed(0, 177) or IsPedRagdoll(PlayerPedId()) then choosing = false end
        Wait(0)
    end
    SendNUIMessage({ action = 'choiceClose' })
    if result then PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
    return result
end)

-- ---------------------------------------------------------------- keypad
local padP
exports('Keypad', function(opts)
    opts = opts or {}
    padP = promise.new()
    local check = opts.check
    SetNuiFocus(true, false)
    SendNUIMessage({ action = 'keypad', length = opts.length or 4, mask = opts.mask, tries = opts.tries })
    RegisterNUICallback('code', function(d, cb)
        if d.cancel then cb({}); SetNuiFocus(false, false); padP:resolve(false); return end
        local ok = (check and check(d.code)) or (opts.code and d.code == tostring(opts.code)) or false
        PlaySoundFrontend(-1, ok and 'Hack_Success' or 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
        cb({ ok = ok })
        if ok then SetTimeout(900, function() SetNuiFocus(false, false); padP:resolve(true) end) end
    end)
    return Citizen.Await(padP)
end)
RegisterNUICallback('beep', function(_, cb) PlaySoundFrontend(-1, 'Click', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true); cb('ok') end)

-- ---------------------------------------------------------------- quick heal
local function countOf(item)
    return GetResourceState('ox_inventory') == 'started' and exports.ox_inventory:Search('count', item) or 0
end
local function healSlots()
    local s = {}
    for _, h in ipairs(Config.Heal) do s[#s + 1] = { image = Config.ImagePath .. h.item .. '.png', count = countOf(h.item), key = tostring(h.key) } end
    return s
end
local healOpen, busy = false, false
RegisterCommand('+roxheal', function()
    healOpen = true
    SendNUIMessage({ action = 'heal', show = true, slots = healSlots() })
    CreateThread(function()
        while healOpen do
            for i, h in ipairs(Config.Heal) do
                DisableControlAction(0, 156 + h.key, true)
                if not busy and IsDisabledControlJustPressed(0, 156 + h.key) and countOf(h.item) > 0 then
                    busy = true
                    CreateThread(function()
                        local a = h.anim
                        lib.requestAnimDict(a[1]); TaskPlayAnim(PlayerPedId(), a[1], a[2], 8.0, -8.0, a[3], 49, 0, false, false, false)
                        Wait(a[3])
                        TriggerServerEvent('rox_interact:heal', i)
                        Wait(300); SendNUIMessage({ action = 'heal', show = healOpen, slots = healSlots() }); busy = false
                    end)
                end
            end
            Wait(0)
        end
    end)
end, false)
RegisterCommand('-roxheal', function() healOpen = false; SendNUIMessage({ action = 'heal', show = false }) end, false)
RegisterKeyMapping('+roxheal', 'Quick heal (hold)', 'keyboard', Config.HealKey)

RegisterNetEvent('rox_interact:healed', function(amount)
    local ped = PlayerPedId()
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
end)

