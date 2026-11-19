-- ROX Store | All rights reserved
local ox = exports.ox_inventory
local MAXSLOT = Config.Layout.pockets[2]
local busy = {}

local function state(src)
    local items, defs = {}, {}
    for _, it in pairs(ox:GetInventoryItems(src) or {}) do
        if it.slot and it.slot <= MAXSLOT then
            items[#items + 1] = { slot = it.slot, name = it.name, count = it.count, durability = it.metadata and it.metadata.durability,
                                  label = it.metadata and it.metadata.label, rarity = it.metadata and it.metadata.rarity, image = it.metadata and it.metadata.image }
            if not defs[it.name] then
                local d = ox:Items(it.name) or {}
                defs[it.name] = { l = d.label or it.name, w = (d.weight or 0) / 1000, d = d.description or '' }
            end
        end
    end
    return { items = items, defs = defs }
end
lib.callback.register('rox_inv3d:state', function(src) return state(src) end)

local function guard(src)
    if busy[src] and busy[src] > GetGameTimer() then return false end
    busy[src] = GetGameTimer() + 150; return true
end
local function valid(s) s = tonumber(s); return s and s >= 1 and s <= MAXSLOT and math.floor(s) == s and s end

lib.callback.register('rox_inv3d:move', function(src, from, to, split)
    from, to = valid(from), valid(to)
    if not from or not to or from == to or not guard(src) then return state(src) end
    local A, B = ox:GetSlot(src, from), ox:GetSlot(src, to)
    if not A or not A.name then return state(src) end
    if not Config.Fits(to, A.name) or (B and B.name and not Config.Fits(from, B.name)) then return state(src), 'That item does not fit there' end
    if not B or not B.name then
        local n = split and A.count > 1 and math.floor(A.count / 2) or A.count
        if ox:RemoveItem(src, A.name, n, A.metadata, from) then ox:AddItem(src, A.name, n, A.metadata, to) end
    elseif B.name == A.name and B.stack ~= false and json.encode(A.metadata or {}) == json.encode(B.metadata or {}) then
        if ox:RemoveItem(src, A.name, A.count, A.metadata, from) then ox:AddItem(src, A.name, A.count, A.metadata, to) end
    else
        if ox:RemoveItem(src, A.name, A.count, A.metadata, from) then
            if ox:RemoveItem(src, B.name, B.count, B.metadata, to) then
                ox:AddItem(src, A.name, A.count, A.metadata, to); ox:AddItem(src, B.name, B.count, B.metadata, from)
            else ox:AddItem(src, A.name, A.count, A.metadata, from) end
        end
    end
    return state(src)
end)

lib.callback.register('rox_inv3d:drop', function(src, slot, n)
    slot = valid(slot); local A = slot and ox:GetSlot(src, slot)
    if not A or not A.name or not guard(src) then return state(src) end
    n = math.max(1, math.min(A.count, math.floor(tonumber(n) or A.count)))
    if ox:RemoveItem(src, A.name, n, A.metadata, slot) then
        local c = GetEntityCoords(GetPlayerPed(src))
        ox:CustomDrop('Drop', { { A.name, n, A.metadata } }, vec3(c.x, c.y, c.z - 0.95))
    end
    return state(src)
end)

lib.callback.register('rox_inv3d:give', function(src, slot, n)
    slot = valid(slot); local A = slot and ox:GetSlot(src, slot)
    if not A or not A.name or not guard(src) then return state(src) end
    n = math.max(1, math.min(A.count, math.floor(tonumber(n) or A.count)))
    local me, best, bd = GetEntityCoords(GetPlayerPed(src)), nil, 3.0
    for _, id in ipairs(GetPlayers()) do
        id = tonumber(id)
        if id ~= src then local d = #(GetEntityCoords(GetPlayerPed(id)) - me); if d < bd then best, bd = id, d end end
    end
    if not best then return state(src), 'Nobody close to you' end
    if not ox:CanCarryItem(best, A.name, n, A.metadata) then return state(src), 'They cannot carry that' end
    if ox:RemoveItem(src, A.name, n, A.metadata, slot) then ox:AddItem(best, A.name, n, A.metadata) end
    return state(src)
end)
AddEventHandler('playerDropped', function() busy[source] = nil end)
