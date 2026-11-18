-- ROX Store | All rights reserved
local FILE = 'data/trees.json'
local trees = json.decode(LoadResourceFile(GetCurrentResourceName(), FILE) or '[]') or {}
local history = {}

local function save()
    SaveResourceFile(GetCurrentResourceName(), FILE, json.encode(trees), -1)
end

-- also write a CodeWalker ymap XML so the trees can be baked into a real map later
local function exportYmap()
    local out = { '<?xml version="1.0" encoding="UTF-8"?>', '<CMapData>', ' <name>rox_streets</name><parent/><flags value="0"/><contentFlags value="1"/>', ' <entities>' }
    for _, t in ipairs(trees) do
        local h = math.rad(t.h or 0) / 2
        out[#out + 1] = ('  <Item type="CEntityDef"><archetypeName>%s</archetypeName><flags value="1572865"/><guid value="0"/>'
            .. '<position x="%.3f" y="%.3f" z="%.3f"/><rotation x="0" y="0" z="%.5f" w="%.5f"/><scaleXY value="1"/><scaleZ value="1"/>'
            .. '<parentIndex value="-1"/><lodDist value="200"/><childLodDist value="0"/><lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>'
            .. '<numChildren value="0"/><priorityLevel>PRI_REQUIRED</priorityLevel><extensions/><ambientOcclusionMultiplier value="255"/>'
            .. '<artificialAmbientOcclusion value="255"/><tintValue value="0"/></Item>'):format(t.m, t.x, t.y, t.z, -math.sin(h), math.cos(h))
    end
    out[#out + 1] = ' </entities>'
    out[#out + 1] = '</CMapData>'
    SaveResourceFile(GetCurrentResourceName(), 'data/rox_streets.ymap.xml', table.concat(out, '\n'), -1)
end

local function isAdmin(src) return src == 0 or IsPlayerAceAllowed(src, Config.AdminAce) end

lib.callback.register('rox_streets:get', function() return trees end)
lib.callback.register('rox_streets:isAdmin', function(src) return isAdmin(src) end)

RegisterNetEvent('rox_streets:add', function(list)
    local src = source
    if not isAdmin(src) or type(list) ~= 'table' or #list > 5000 then return end
    local batch = {}
    for _, t in ipairs(list) do
        if type(t) == 'table' and type(t.m) == 'string' and #t.m < 64 and tonumber(t.x) and tonumber(t.y) and tonumber(t.z) then
            local e = { m = t.m, x = t.x + 0.0, y = t.y + 0.0, z = t.z + 0.0, h = tonumber(t.h) or 0.0 }
            trees[#trees + 1] = e; batch[#batch + 1] = e
        end
    end
    history[#history + 1] = #batch
    save(); exportYmap()
    TriggerClientEvent('rox_streets:sync', -1, trees)
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = ('Planted %d (total %d)'):format(#batch, #trees) })
end)

RegisterNetEvent('rox_streets:undo', function()
    local src = source
    if not isAdmin(src) then return end
    local n = table.remove(history) or 0
    for _ = 1, n do table.remove(trees) end
    save(); exportYmap(); TriggerClientEvent('rox_streets:sync', -1, trees)
    TriggerClientEvent('ox_lib:notify', src, { description = ('Removed last batch (%d)'):format(n) })
end)

RegisterNetEvent('rox_streets:remove', function(c)
    local src = source
    if not isAdmin(src) or type(c) ~= 'vector3' then return end
    local best, bd = nil, 3.0
    for i, t in ipairs(trees) do local d = #(vec3(t.x, t.y, t.z) - c); if d < bd then best, bd = i, d end end
    if not best then return end
    table.remove(trees, best); history = {}
    save(); exportYmap(); TriggerClientEvent('rox_streets:sync', -1, trees)
end)

RegisterNetEvent('rox_streets:clear', function(c, r)
    local src = source
    if not isAdmin(src) or type(c) ~= 'vector3' and type(c) ~= 'table' then return end
    r = math.min(tonumber(r) or 50, 2000)
    local keep, removed = {}, 0
    for _, t in ipairs(trees) do
        if #(vec3(t.x, t.y, t.z) - vec3(c.x, c.y, c.z)) > r then keep[#keep + 1] = t else removed = removed + 1 end
    end
    trees = keep; history = {}
    save(); exportYmap(); TriggerClientEvent('rox_streets:sync', -1, trees)
    TriggerClientEvent('ox_lib:notify', src, { description = ('Removed %d trees'):format(removed) })
end)
