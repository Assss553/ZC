-- ROX Store | All rights reserved
local trees, cells, spawned = {}, {}, {}

local function cellKey(x, y) return math.floor(x / Config.CellSize) .. ':' .. math.floor(y / Config.CellSize) end

local function despawnAll()
    for i, e in pairs(spawned) do if DoesEntityExist(e) then DeleteEntity(e) end spawned[i] = nil end
end

local function index(list)
    despawnAll(); trees = list or {}; cells = {}
    for i, t in ipairs(trees) do
        local k = cellKey(t.x, t.y); cells[k] = cells[k] or {}; cells[k][#cells[k] + 1] = i
    end
end

local function spawnTree(i, t)
    local m = joaat(t.m)
    if not IsModelInCdimage(m) then return end
    RequestModel(m)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(m) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(m) then return end
    local e = CreateObjectNoOffset(m, t.x, t.y, t.z, false, false, false)
    SetEntityHeading(e, t.h or 0.0); FreezeEntityPosition(e, true); SetEntityLodDist(e, 300)
    SetModelAsNoLongerNeeded(m)
    spawned[i] = e
end

-- streaming loop
CreateThread(function()
    index(lib.callback.await('rox_streets:get', false))
    while true do
        local p = GetEntityCoords(cache.ped)
        local r = math.ceil(Config.StreamDist / Config.CellSize)
        local cx, cy = math.floor(p.x / Config.CellSize), math.floor(p.y / Config.CellSize)
        local want = {}
        for dx = -r, r do for dy = -r, r do
            for _, i in ipairs(cells[(cx + dx) .. ':' .. (cy + dy)] or {}) do
                local t = trees[i]
                if #(vec2(t.x, t.y) - p.xy) < Config.StreamDist then want[i] = true; if not spawned[i] then spawnTree(i, t) end end
            end
        end end
        for i, e in pairs(spawned) do if not want[i] then DeleteEntity(e); spawned[i] = nil end end
        Wait(1000)
    end
end)
RegisterNetEvent('rox_streets:sync', index)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then despawnAll() end end)

-- ---------------------------------------------------------------- generator (admins)
local function validModels(set)
    local out = {}
    for _, n in ipairs(Config.Sets[set] or {}) do if IsModelInCdimage(joaat(n)) then out[#out + 1] = n end end
    return out
end

local function clearAbove(x, y, z, h)
    local ray = StartShapeTestCapsule(x, y, z + 1.0, x, y, z + h, 0.9, 1 + 16, cache.ped, 7)
    local _, hit = GetShapeTestResult(ray)
    while _ == 1 do Wait(0); _, hit = GetShapeTestResult(ray) end
    return hit == 0
end

local function tooClose(list, x, y, d)
    for i = #list, math.max(1, #list - 400), -1 do
        local t = list[i]; if (t.x - x) ^ 2 + (t.y - y) ^ 2 < d * d then return true end
    end
    for _, t in ipairs(trees) do if (t.x - x) ^ 2 + (t.y - y) ^ 2 < d * d then return true end end
    return false
end

local function generate(set, radius)
    local models = validModels(set)
    if #models == 0 then return lib.notify({ type = 'error', description = 'No valid models in set: ' .. set }) end
    local bushes = validModels('bushes')
    local G, out = Config.Generate, {}
    local p = GetEntityCoords(cache.ped)
    lib.notify({ description = ('Scanning roads (%s, %dm)...'):format(set, radius) })
    for n = 1, G.maxNodes do
        local ok, pos, heading = GetNthClosestVehicleNodeWithHeading(p.x, p.y, p.z, n, 1, 3.0, 0)
        if not ok then break end
        if #(pos.xy - p.xy) > radius then break end
        for _, side in ipairs({ 0.0, 180.0 }) do
            local okB, edge = GetRoadBoundaryUsingHeading(pos.x, pos.y, pos.z, (heading + side) % 360)
            if okB then
                local dir = vec2(edge.x - pos.x, edge.y - pos.y)
                local len = #dir
                if len > 1.0 then
                    local t = edge.xy + dir / len * G.edge
                    local okG, gz = GetGroundZFor_3dCoord(t.x, t.y, edge.z + 4.0, false)
                    if okG and math.abs(gz - edge.z) < G.maxSlope and not IsPointOnRoad(t.x, t.y, gz, 0)
                        and not tooClose(out, t.x, t.y, G.spacing) and clearAbove(t.x, t.y, gz, G.clearance) then
                        out[#out + 1] = { m = models[math.random(#models)], x = t.x, y = t.y, z = gz - 0.1, h = math.random(0, 359) }
                        if #bushes > 0 and math.random() < G.bushChance then
                            local f = vec2(-math.sin(math.rad(heading)), math.cos(math.rad(heading))) * (G.spacing / 2)
                            local b = t + f
                            local okb, bz = GetGroundZFor_3dCoord(b.x, b.y, gz + 3.0, false)
                            if okb and not IsPointOnRoad(b.x, b.y, bz, 0) then
                                out[#out + 1] = { m = bushes[math.random(#bushes)], x = b.x, y = b.y, z = bz, h = math.random(0, 359) }
                            end
                        end
                    end
                end
            end
        end
        if n % 50 == 0 then Wait(0) end
    end
    if #out == 0 then return lib.notify({ type = 'error', description = 'No free spots found here' }) end
    TriggerServerEvent('rox_streets:add', out)
end

local function admin() return lib.callback.await('rox_streets:isAdmin', false) end

-- /streetgen [set] [radius]   e.g. /streetgen blossom 300
RegisterCommand('streetgen', function(_, a)
    if not admin() then return end
    generate(a[1] or 'mixed', math.min(tonumber(a[2]) or 250, 1500))
end, false)
RegisterCommand('streetundo', function() if admin() then TriggerServerEvent('rox_streets:undo') end end, false)
RegisterCommand('streetclear', function(_, a)
    if admin() then TriggerServerEvent('rox_streets:clear', GetEntityCoords(cache.ped), tonumber(a[1]) or 50) end
end, false)
