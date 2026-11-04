--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

local Callbacks = {}
local lastCall = {}

function RegisterCallback(name, fn)
    Callbacks[name] = fn
end

RegisterNetEvent('rox_re:cb', function(name, reqId, ...)
    local src = source
    local fn = Callbacks[name]
    if type(reqId) ~= 'number' then return end
    if not fn then
        return TriggerClientEvent('rox_re:cbr', src, reqId, false, 'unknown')
    end

    -- anti-spam: max 20 calls per second per player
    local now = GetGameTimer()
    local rl = lastCall[src]
    if not rl or now - rl.t > 1000 then rl = { t = now, n = 0 }; lastCall[src] = rl end
    rl.n = rl.n + 1
    if rl.n > 20 then
        return TriggerClientEvent('rox_re:cbr', src, reqId, false, 'slow down')
    end

    CurrentLangSrc = src
    local ok, a, b = pcall(fn, src, ...)
    CurrentLangSrc = nil
    if not ok then
        print(('^1[rox_realestate] callback %s error:^7 %s'):format(name, a))
        a, b = false, 'error'
    end
    TriggerClientEvent('rox_re:cbr', src, reqId, a, b)
end)

RegisterNetEvent('rox_re:setLang', function(lang)
    if lang == 'en' or lang == 'ar' then PlayerLang[source] = lang end
end)

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
    PlayerLang[source] = nil
end)
