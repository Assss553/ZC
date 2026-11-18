-- ROX Store | All rights reserved. Owner: ROX Store
-- Carry / drag / put in vehicle / take out  (server-validated, consent unless the target is dead or cuffed)
local pairsBy = {}        -- [carrier] = { target = id, mode = 'carry'|'drag' }
local carriedBy = {}      -- [target]  = carrier
local pending = {}        -- [target]  = { from = id, mode = mode, t = time }

local function dist(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return 999 end
    return #(GetEntityCoords(pa) - GetEntityCoords(pb))
end
local function busy(id) return pairsBy[id] or carriedBy[id] end

local function stopPair(carrier)
    local p = pairsBy[carrier]; if not p then return end
    pairsBy[carrier] = nil; carriedBy[p.target] = nil
    TriggerClientEvent('rox_radial:carry:stop', carrier)
    TriggerClientEvent('rox_radial:carry:stop', p.target)
end

RegisterNetEvent('rox_radial:carry:request', function(target, mode)
    local src = source; target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return end
    if mode ~= 'carry' and mode ~= 'drag' and mode ~= 'takeout' then return end
    if dist(src, target) > 5.0 then return TriggerClientEvent('rox_radial:carry:msg', src, 'Too far away', 'error') end
    if mode ~= 'takeout' and (busy(src) or busy(target)) then return TriggerClientEvent('rox_radial:carry:msg', src, 'Already busy', 'error') end
    pending[target] = { from = src, mode = mode, t = os.time() }
    TriggerClientEvent('rox_radial:carry:ask', target, src, mode)
end)

RegisterNetEvent('rox_radial:carry:answer', function(from, ok)
    local target = source; from = tonumber(from)
    local p = pending[target]; pending[target] = nil
    if not p or p.from ~= from or os.time() - p.t > 15 then return end
    if not ok then return TriggerClientEvent('rox_radial:carry:msg', from, 'Request declined', 'error') end
    if dist(from, target) > 5.0 then return end
    if p.mode == 'takeout' then
        return TriggerClientEvent('rox_radial:carry:leaveVehicle', target)
    end
    if busy(from) or busy(target) then return end
    pairsBy[from] = { target = target, mode = p.mode }; carriedBy[target] = from
    TriggerClientEvent('rox_radial:carry:start', from, 'carrier', target, p.mode)
    TriggerClientEvent('rox_radial:carry:start', target, 'carried', from, p.mode)
end)

RegisterNetEvent('rox_radial:carry:stop', function()
    local src = source
    if pairsBy[src] then stopPair(src) elseif carriedBy[src] then stopPair(carriedBy[src]) end
end)

RegisterNetEvent('rox_radial:carry:putin', function(netId, seat)
    local src = source; local p = pairsBy[src]
    if not p or type(netId) ~= 'number' or type(seat) ~= 'number' then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 6.0 then return end
    local target = p.target
    stopPair(src)
    TriggerClientEvent('rox_radial:carry:seat', target, netId, seat)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if pairsBy[src] then stopPair(src) elseif carriedBy[src] then stopPair(carriedBy[src]) end
    pending[src] = nil
end)
