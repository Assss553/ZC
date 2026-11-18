-- ROX Store | rox_emotes | All rights reserved.
RegisterNetEvent('rox_emotes:request', function(target, name)
    local src = source; target = tonumber(target); if not target then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(target))) > Config.SharedDistance + 1.0 then return end
    TriggerClientEvent('rox_emotes:requested', target, src, name, GetPlayerName(src))
end)
RegisterNetEvent('rox_emotes:accept', function(from, name)
    local src = source; from = tonumber(from); if not from then return end
    TriggerClientEvent('rox_emotes:playShared', from, src, name, true); TriggerClientEvent('rox_emotes:playShared', src, from, name, false)
end)
