-- ROX Store | All rights reserved
local last = {}
RegisterNetEvent('rox_interact:heal', function(i)
    local src = source
    local h = Config.Heal[tonumber(i) or 0]
    if not h or (last[src] or 0) > GetGameTimer() - 2000 then return end
    last[src] = GetGameTimer()
    if exports.ox_inventory:RemoveItem(src, h.item, 1) then TriggerClientEvent('rox_interact:healed', src, h.health) end
end)
AddEventHandler('playerDropped', function() last[source] = nil end)
