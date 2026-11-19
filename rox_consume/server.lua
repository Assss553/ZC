-- ROX Store | All rights reserved
local active = {}   -- [src] = { item, left, last }

lib.callback.register('rox_consume:start', function(src, item)
    local c = Config.Items[item]
    if not c or active[src] then return false end
    if not exports.ox_inventory:RemoveItem(src, item, 1) then return false end
    active[src] = { item = item, left = c.total, last = 0 }
    return c.total
end)

lib.callback.register('rox_consume:bite', function(src)
    local a = active[src]; if not a then return false end
    local now = GetGameTimer()
    if now - a.last < Config.BiteCooldown - 200 then return a.left end
    a.last = now
    local c = Config.Items[a.item]
    local amount = math.min(c.bite, a.left)
    a.left = a.left - amount
    local p = exports.qbx_core:GetPlayer(src)
    if p then
        local frac = amount / c.total
        for _, k in ipairs({ 'hunger', 'thirst' }) do
            if c[k] then
                local cur = p.PlayerData.metadata[k] or 0
                local new = math.min(100, cur + c[k] * frac)
                p.Functions.SetMetaData(k, new)
            end
        end
        TriggerClientEvent('hud:client:UpdateNeeds', src, p.PlayerData.metadata.hunger, p.PlayerData.metadata.thirst)
    end
    if a.left <= 0 then active[src] = nil end
    return a.left
end)

RegisterNetEvent('rox_consume:drop', function() active[source] = nil end)
AddEventHandler('playerDropped', function() active[source] = nil end)
