--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

-- Procedural ROX warehouse design (see shared/decor.lua)
ROXDecor = { entities = {}, lights = {}, spots = {}, polys = {}, fx = {}, flicker = {}, active = false }

local Debug = false

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function makeRng(seed)
    local s = math.floor(seed) % 2147483647
    if s <= 0 then s = s + 2147483646 end
    return function(a, b)
        s = (s * 16807) % 2147483647
        local r = (s - 1) / 2147483646
        if a then return a + r * (b - a) end
        return r
    end
end

local function ray(a, b)
    local h = StartExpensiveSynchronousShapeTestLosProbe(a.x, a.y, a.z, b.x, b.y, b.z, 1, PlayerPedId(), 4)
    local _, hit, c = GetShapeTestResult(h)
    return hit == 1, c
end

-- true when nothing (map or objects) intersects the box
local function boxFree(cx, cy, cz, sx, sy, sz, heading)
    local h = StartShapeTestBox(cx, cy, cz, sx, sy, sz, 0.0, 0.0, heading, 2, 1 + 16, PlayerPedId(), 4)
    local status, hit
    local t = GetGameTimer() + 500
    repeat
        status, hit = GetShapeTestResult(h)
        if status == 1 then Wait(0) end
    until status ~= 1 or GetGameTimer() > t
    return hit ~= 1
end

local existsCache = {}
local function exists(model)
    if existsCache[model] == nil then existsCache[model] = IsModelInCdimage(joaat(model)) and true or false end
    return existsCache[model]
end

local function pick(role, rnd)
    local list = DecorProps[role] or {}
    local ok = {}
    for _, m in ipairs(list) do if exists(m) then ok[#ok + 1] = m end end
    if #ok == 0 then return nil end
    return ok[math.floor(rnd(1, #ok + 0.999))]
end

---------------------------------------------------------------------
-- room measurement
---------------------------------------------------------------------
local function median3(a, b, c)
    if a > b then a, b = b, a end
    if b > c then b, c = c, b end
    if a > b then a, b = b, a end
    return b
end

local function measure(center)
    local okF, f = ray(center + vector3(0, 0, 1.0), center - vector3(0, 0, 6.0))
    local floorZ = okF and f.z or (center.z - 1.0)
    local mid = vector3(center.x, center.y, floorZ)
    local minX, maxX, minY, maxY
    -- cast from 3 parallel origins and take the median, so one pillar does not shrink the room
    local function wall(o, dx, dy)
        local hit, c = ray(o, o + vector3(dx, dy, 0.0) * 70.0)
        local p = hit and c or (o + vector3(dx, dy, 0.0) * 35.0)
        return dx ~= 0 and p.x or p.y
    end
    for _ = 1, 3 do
        local z = floorZ + 1.6
        local o = vector3(mid.x, mid.y, z)
        local ox, oy = vector3(0, 1.6, 0), vector3(1.6, 0, 0)
        minX = median3(wall(o, -1, 0), wall(o + ox, -1, 0), wall(o - ox, -1, 0))
        maxX = median3(wall(o, 1, 0), wall(o + ox, 1, 0), wall(o - ox, 1, 0))
        minY = median3(wall(o, 0, -1), wall(o + oy, 0, -1), wall(o - oy, 0, -1))
        maxY = median3(wall(o, 0, 1), wall(o + oy, 0, 1), wall(o - oy, 0, 1))
        mid = vector3((minX + maxX) / 2, (minY + maxY) / 2, floorZ)
    end
    local okC, c = ray(vector3(mid.x, mid.y, floorZ + 1.0), vector3(mid.x, mid.y, floorZ + 30.0))
    local ceilZ = okC and c.z or (floorZ + 7.0)
    return { minX = minX, maxX = maxX, minY = minY, maxY = maxY, floorZ = floorZ, ceilZ = ceilZ }
end

---------------------------------------------------------------------
-- builder
---------------------------------------------------------------------
local function Builder(room, entry, seed)
    local B = { room = room, rnd = makeRng(seed), placed = 0, entry = entry }
    local sx, sy = room.maxX - room.minX, room.maxY - room.minY
    B.longX = sx >= sy
    B.L = B.longX and sx or sy          -- length along U (long axis)
    B.W = B.longX and sy or sx          -- width along V
    -- U = 0 at the entrance end
    local eu = B.longX and (entry.x - room.minX) or (entry.y - room.minY)
    B.flip = eu > B.L / 2
    local ev = B.longX and (entry.y - room.minY) or (entry.x - room.minX)
    B.entryV = ev

    function B.toLocal(x, y)
        local u, v
        if B.longX then u, v = x - room.minX, y - room.minY else u, v = y - room.minY, x - room.minX end
        if B.flip then u = B.L - u end
        return u, v
    end

    function B.world(u, v)
        if B.flip then u = B.L - u end
        if B.longX then return room.minX + u, room.minY + v end
        return room.minX + v, room.minY + u
    end

    -- heading so the model's local +Y points along +U (facing the far end) / its long side runs along U
    -- heading (GTA: 0 = +Y, 90 = -X) for a direction given in room space (du along U, dv along V)
    function B.headingToward(du, dv)
        local x0, y0 = B.world(10, 10)
        local x1, y1 = B.world(10 + du, 10 + dv)
        return math.deg(math.atan(-(x1 - x0), y1 - y0)) % 360.0
    end

    -- extra: 0 = face the far end, 180 = face the entrance, 90 = face +V side, -90 = face the V=0 side
    function B.headingU(extra)
        local r = math.rad(extra or 0.0)
        return B.headingToward(math.cos(r), math.sin(r))
    end

    -- floor paint: quad from room-space corners (u, v) list, drawn every frame
    function B.paint(pts, c)
        local w = {}
        for i, p in ipairs(pts) do
            local x, y = B.world(p[1], p[2])
            w[i] = vector3(x, y, room.floorZ + 0.015)
        end
        ROXDecor.polys[#ROXDecor.polys + 1] = { w[1], w[2], w[3], w[4] or w[3], c[1], c[2], c[3], c[4] or 200 }
    end
    function B.line(u0, v0, u1, v1, width, c)
        local du, dv = u1 - u0, v1 - v0
        local len = math.sqrt(du * du + dv * dv)
        if len < 0.01 then return end
        local nu, nv = -dv / len * width / 2, du / len * width / 2
        B.paint({ { u0 + nu, v0 + nv }, { u1 + nu, v1 + nv }, { u1 - nu, v1 - nv }, { u0 - nu, v0 - nv } }, c)
    end
    function B.rect(u0, v0, u1, v1, width, c)
        B.line(u0, v0, u1, v0, width, c); B.line(u1, v0, u1, v1, width, c)
        B.line(u1, v1, u0, v1, width, c); B.line(u0, v1, u0, v0, width, c)
    end

    -- mount a prop flat against a wall. side: 'v0' | 'vW' | 'uL' | 'u0'; at = position along that wall; h = height
    function B.wall(role, side, at, h, opts)
        opts = opts or {}
        local model = opts.model or pick(role, B.rnd)
        if not model then return nil end
        local hash = LoadModel(model)
        if not hash then return nil end
        local mn, mx = GetModelDimensions(hash)
        local depth = math.min(mx.x - mn.x, mx.y - mn.y)
        local u, v, du, dv
        if side == 'v0' then u, v, du, dv = at, depth / 2 + 0.03, 0, 1
        elseif side == 'vW' then u, v, du, dv = at, B.W - depth / 2 - 0.03, 0, -1
        elseif side == 'uL' then u, v, du, dv = B.L - depth / 2 - 0.03, at, -1, 0
        else u, v, du, dv = depth / 2 + 0.03, at, 1, 0 end
        local heading = (B.headingToward(du, dv) + (DecorWallFlip[model] and 180.0 or 0.0)) % 360.0
        return B.place(role, u, v, { model = model, heading = heading, z = room.floorZ + (h or 0.0) - (h and mn.z or 0) , force = opts.force ~= false, wallOk = true })
    end

    -- place a role at (u, v). opts: { heading, alongU = true (long side along U), z = abs z, force, onFloor = true }
    function B.place(role, u, v, opts)
        opts = opts or {}
        local model = opts.model or pick(role, B.rnd)
        if not model then return nil end
        local hash = LoadModel(model)
        if not hash then return nil end
        local mn, mx = GetModelDimensions(hash)
        local size = mx - mn
        local heading = opts.heading or B.headingU(0)
        if opts.alongU then
            -- make the long side of the model run along U
            if size.x > size.y then heading = (heading + 90.0) % 360.0 end
        end
        local wx, wy = B.world(u, v)
        -- keep the spot where players appear free
        if not opts.force and (wx - B.entry.x) ^ 2 + (wy - B.entry.y) ^ 2 < 3.4 ^ 2 then return nil end
        -- footprint centre offset, rotated
        local r = math.rad(heading)
        local ox, oy = (mn.x + mx.x) / 2, (mn.y + mx.y) / 2
        local rx, ry = ox * math.cos(r) - oy * math.sin(r), ox * math.sin(r) + oy * math.cos(r)
        local px, py = wx - rx, wy - ry
        local pz = opts.z or (room.floorZ - mn.z + 0.01)

        -- stay inside the room
        local half = math.max(size.x, size.y) / 2
        local fu = opts.wallOk and 0.05 or 0.35
        if not opts.force then
            if wx - half * 0.7 < room.minX + fu or wx + half * 0.7 > room.maxX - fu or wy - half * 0.7 < room.minY + fu or wy + half * 0.7 > room.maxY - fu then
                if not opts.wallOk then return nil end
            end
            local bz = (opts.z and (opts.z + (mn.z + mx.z) / 2)) or (room.floorZ + size.z / 2 + 0.12)
            if not boxFree(wx, wy, bz, size.x * 0.9, size.y * 0.9, math.max(0.2, size.z * 0.8), heading) then return nil end
        end

        local ent
        if role == 'forklift' then
            ent = CreateVehicle(hash, px, py, room.floorZ + 0.3, heading, false, false)
            SetVehicleDoorsLocked(ent, 2)
            SetEntityInvincible(ent, true)
            SetVehicleOnGroundProperly(ent)
        else
            ent = CreateObject(hash, px, py, pz, false, false, false)
            SetEntityHeading(ent, heading)
        end
        FreezeEntityPosition(ent, true)
        SetModelAsNoLongerNeeded(hash)
        ROXDecor.entities[#ROXDecor.entities + 1] = ent
        ROXDecor.models = ROXDecor.models or {}
        ROXDecor.models[ent] = { model = model, vehicle = role == 'forklift' }
        B.placed = B.placed + 1
        if B.placed % 6 == 0 then Wait(0) end
        return ent, size, model
    end

    return B
end

---------------------------------------------------------------------
-- zones
---------------------------------------------------------------------
local function buildRacks(B, style, u0, u1)
    local rackModel = pick('rack', B.rnd)
    if not rackModel then return end
    local hash = LoadModel(rackModel)
    if not hash then return end
    local mn, mx = GetModelDimensions(hash)
    local len, depth = math.max(mx.x - mn.x, mx.y - mn.y), math.min(mx.x - mn.x, mx.y - mn.y)
    local gap = style.rackGap or 3.2
    local margin = 0.45
    local rows = {}
    if style.racks then
        -- wall row, then back-to-back double rows separated by aisles
        local v = margin + depth / 2
        rows[#rows + 1] = v
        v = v + depth / 2 + gap
        while v + depth * 1.5 + margin < B.W - margin - depth - gap do
            rows[#rows + 1] = v + depth / 2
            rows[#rows + 1] = v + depth * 1.5 + 0.05
            v = v + depth * 2 + gap
        end
        rows[#rows + 1] = B.W - margin - depth / 2
    elseif style.wallRacks then
        rows = { margin + depth / 2, B.W - margin - depth / 2 }
    end
    local crossAt = style.crossAisle and (u0 + (u1 - u0) / 2) or nil
    for _, v in ipairs(rows) do
        local u = u0 + len / 2
        while u + len / 2 <= u1 do
            if crossAt and math.abs(u - crossAt) < len / 2 + 1.2 then
                u = crossAt + 1.4 + len / 2
            else
                B.place('rack', u, v, { model = rackModel, alongU = true })
                u = u + len + 0.08
            end
        end
    end
    -- worklights on the aisle ends and lights over each aisle
    for i = 1, #rows - 1 do
        local av = (rows[i] + rows[i + 1]) / 2
        if rows[i + 1] - rows[i] > depth + 1.0 then
            for lu = u0 + 3.0, u1 - 2.0, 7.0 do ROXDecor.lights[#ROXDecor.lights + 1] = { u = lu, v = av } end
            if B.rnd() > 0.4 then B.place('handtruck', u0 + 0.8, av + B.rnd(-0.4, 0.4), { heading = B.headingU(B.rnd(-25, 25)) }) end
        end
    end
end

local function buildDock(B, style, u0, u1)
    local laneV = B.W / 2
    local step = 2.3
    local density = style.dockDensity or 0.7
    for u = u0 + 1.4, u1 - 1.0, step do
        for v = 1.3, B.W - 1.0, step do
            if math.abs(v - laneV) > 2.4 and B.rnd() < density then
                local role = B.rnd() < 0.62 and 'pallet' or 'crate'
                B.place(role, u + B.rnd(-0.15, 0.15), v + B.rnd(-0.15, 0.15), { heading = B.headingU(B.rnd() < 0.5 and 0 or 90) + B.rnd(-4, 4) })
            end
        end
    end
    -- empty pallets stacked near a wall, forklift on the lane, cones marking the lane
    for i = 0, 2 do B.place('emptyPallet', u1 - 1.2 - i * 1.4, 0.9, { alongU = true, wallOk = true }) end
    B.place('forklift', u0 + (u1 - u0) * 0.45, laneV, { heading = B.headingU(180 + B.rnd(-12, 12)) })
    B.place('handtruck', u0 + (u1 - u0) * 0.7, laneV + 1.3, { heading = B.headingU(B.rnd(0, 360)) })
    for v = laneV - 2.0, laneV + 2.0, 1.3 do B.place('cone', u0 + 0.4, v, {}) end
    B.place('barrier', u0 + 0.6, 1.0, { alongU = false })
    B.place('barrier', u0 + 0.6, B.W - 1.0, { alongU = false })
    for lu = u0 + 2.0, u1 - 1.0, 6.5 do
        ROXDecor.lights[#ROXDecor.lights + 1] = { u = lu, v = laneV - 3.0 }
        ROXDecor.lights[#ROXDecor.lights + 1] = { u = lu, v = laneV + 3.0 }
    end
end

local function buildOffice(B, u0, u1)
    -- office corner on the side away from the entrance door
    local left = B.entryV > B.W / 2
    local function V(d) return left and d or (B.W - d) end
    local face = left and 90.0 or -90.0
    local desk = B.place('desk', u0 + 1.6, V(1.3), { heading = B.headingU(face) })
    if desk then
        local mn, mx = GetModelDimensions(GetEntityModel(desk))
        local top = B.room.floorZ + (mx.z - mn.z)
        B.place('monitor', u0 + 1.3, V(1.05), { heading = B.headingU(face), z = top, force = true })
        B.place('laptop', u0 + 2.0, V(1.25), { heading = B.headingU(face + 15), z = top, force = true })
        B.place('officeChair', u0 + 1.6, V(2.25), { heading = B.headingU(face + 180) })
    end
    B.place('filecab', u0 + 0.5, V(0.45), { heading = B.headingU(face), wallOk = true })
    B.place('filecab', u0 + 1.0, V(0.45), { heading = B.headingU(face), wallOk = true })
    B.place('printer', u0 + 3.1, V(0.6), { heading = B.headingU(face), wallOk = true })
    B.place('safe', u0 + 3.9, V(0.55), { heading = B.headingU(face), wallOk = true })
    B.place('cooler', u1 - 0.6, V(0.45), { heading = B.headingU(face), wallOk = true })
    B.place('vending', u1 - 1.6, V(0.55), { heading = B.headingU(face), wallOk = true })
    B.place('plant', u0 + 0.4, V(2.8), {})
    B.place('bin', u0 + 2.7, V(1.9), {})
    B.place('sofa', u0 + 4.2, V(2.6), { heading = B.headingU(face + 180) })
    ROXDecor.lights[#ROXDecor.lights + 1] = { u = u0 + 2.0, v = V(1.8), warm = true }
end

local function buildWorkshop(B, style, u0, u1)
    local left = B.entryV <= B.W / 2
    local function V(d) return left and d or (B.W - d) end
    local face = left and 90.0 or -90.0
    B.place('bench', u0 + 1.8, V(0.55), { heading = B.headingU(face), alongU = true, wallOk = true })
    B.place('toolchest', u0 + 3.6, V(0.45), { heading = B.headingU(face), wallOk = true })
    B.place('toolchest', u0 + 0.4, V(0.45), { heading = B.headingU(face), wallOk = true })
    B.place('generator', u1 - 0.9, V(0.9), { heading = B.headingU(face) })
    B.place('compressor', u1 - 2.1, V(0.6), { heading = B.headingU(face), wallOk = true })
    B.place('gas', u0 + 4.5, V(0.4), { wallOk = true })
    B.place('gas', u0 + 4.8, V(0.45), { wallOk = true })
    B.place('barrel', u1 - 0.7, V(2.3), {})
    B.place('oil', u0 + 2.6, V(1.4), {})
    B.place('ladder', u0 + 5.4, V(0.25), { heading = B.headingU(face), wallOk = true })
    B.place('worklight', u0 + 3.0, V(1.8), { heading = B.headingU(face + 180) })
    if style.garage then
        B.place('hoist', u0 + 2.4, V(3.4), { heading = B.headingU(B.rnd(0, 360)) })
        B.place('tyres', u1 - 1.0, V(3.6), {})
        B.place('tyres', u1 - 1.0, V(4.6), {})
    end
    ROXDecor.lights[#ROXDecor.lights + 1] = { u = u0 + 2.5, v = V(1.6), warm = true }
end

local function buildGarageFloor(B, u0, u1)
    -- workshop style: open floor with bays, tyre stacks and tool islands
    for u = u0 + 2.0, u1 - 2.0, 6.0 do
        B.place('toolchest', u, B.W / 2 - 2.6, { heading = B.headingU(90) })
        B.place('tyres', u + 1.2, B.W / 2 + 2.6, {})
        B.place('worklight', u + 2.5, B.W / 2, { heading = B.headingU(B.rnd(0, 360)) })
        ROXDecor.lights[#ROXDecor.lights + 1] = { u = u + 1.5, v = B.W / 2 }
    end
end

local function buildSafety(B)
    for u = 3.0, B.L - 2.0, 9.0 do
        B.place('extinguisher', u, 0.25, { wallOk = true })
        B.place('extinguisher', u + 4.5, B.W - 0.25, { wallOk = true })
    end
    -- CCTV in the four corners, under the ceiling, looking at the centre
    local cz = B.room.ceilZ - 0.7
    for _, c in ipairs({ { 0.6, 0.6, 45 }, { 0.6, B.W - 0.6, 135 }, { B.L - 0.6, 0.6, -45 }, { B.L - 0.6, B.W - 0.6, -135 } }) do
        B.place('cctv', c[1], c[2], { heading = B.headingU(c[3]), z = cz, force = true })
    end
    B.place('bin', 1.0, B.W - 0.7, { wallOk = true })
end

---------------------------------------------------------------------
-- empty but detailed: the building itself
---------------------------------------------------------------------
local YELLOW, WHITE, BLACK, RED, GREEN = { 236, 186, 20, 190 }, { 225, 225, 225, 150 }, { 20, 20, 20, 190 }, { 205, 45, 35, 170 }, { 40, 170, 90, 160 }

local function buildMarkings(B, style)
    local m = 0.9
    -- pedestrian walkway around the room (double yellow line)
    B.rect(m, m, B.L - m, B.W - m, 0.10, YELLOW)
    B.rect(m + 0.9, m + 0.9, B.L - m - 0.9, B.W - m - 0.9, 0.06, YELLOW)
    -- entrance hazard band (diagonal yellow / black) and keep-clear box
    local band = 1.2
    for v = m + 0.9, B.W - m - 0.9 - 0.5, 0.5 do
        B.paint({ { band, v }, { band + 0.6, v + 0.25 }, { band + 0.6, v + 0.5 }, { band, v + 0.25 } }, YELLOW)
        B.paint({ { band, v + 0.25 }, { band + 0.6, v + 0.5 }, { band + 0.6, v + 0.75 }, { band, v + 0.5 } }, BLACK)
    end
    local ev = math.max(m + 1.5, math.min(B.W - m - 1.5, B.entryV))
    B.rect(0.2, ev - 1.4, 2.6, ev + 1.4, 0.08, RED)
    B.line(0.4, ev - 1.2, 2.4, ev + 1.2, 0.06, RED); B.line(0.4, ev + 1.2, 2.4, ev - 1.2, 0.06, RED)
    if not style.bays then return end
    -- forklift lane down the middle + storage bays on both sides
    local laneW = math.min(4.0, B.W * 0.28)
    local c = B.W / 2
    B.line(4.5, c - laneW / 2, B.L - m - 0.9, c - laneW / 2, 0.12, YELLOW)
    B.line(4.5, c + laneW / 2, B.L - m - 0.9, c + laneW / 2, 0.12, YELLOW)
    for u = 5.0, B.L - m - 2.0, 3.0 do B.line(u, c - 0.4, u + 1.4, c, 0.10, WHITE); B.line(u + 1.4, c, u, c + 0.4, 0.10, WHITE) end
    local bayD = (B.W - laneW) / 2 - m - 1.3
    if bayD > 1.6 then
        local bayL = math.max(2.4, math.min(3.6, bayD * 0.9))
        for u = 5.0, B.L - m - 1.2 - bayL, bayL + 0.25 do
            B.rect(u, m + 1.15, u + bayL, m + 1.15 + bayD, 0.07, WHITE)
            B.rect(u, B.W - m - 1.15 - bayD, u + bayL, B.W - m - 1.15, 0.07, WHITE)
        end
    end
    -- far wall: green loading box
    B.rect(B.L - m - 4.2, c - laneW / 2 + 0.3, B.L - m - 1.1, c + laneW / 2 - 0.3, 0.10, GREEN)
end

local function buildArchitecture(B)
    -- utilities on the entrance wall and the side walls
    B.wall('keypad', 'u0', B.entryV + 1.2, 1.25)
    B.wall('elecbox', 'v0', 2.0, 0.9)
    B.wall('elecbox', 'v0', 3.1, 0.9)
    B.wall('riser', 'vW', 2.2, 0.0)
    B.wall('hosereel', 'vW', 3.4, 1.0)
    B.wall('firstaid', 'u0', B.entryV - 1.4, 1.35)
    -- every 8 m: wall light high up, extinguisher + alarm by the walkway
    for u = 6.0, B.L - 2.0, 8.0 do
        B.wall('walllight', 'v0', u, B.room.ceilZ - B.room.floorZ - 1.6)
        B.wall('walllight', 'vW', u + 4.0, B.room.ceilZ - B.room.floorZ - 1.6)
        B.wall('extinguisher', 'v0', u + 1.0, 0.0)
        B.wall('extinguisher', 'vW', u + 5.0, 0.0)
        B.wall('alarm', 'v0', u + 1.0, 1.5)
        B.wall('vent', 'vW', u + 2.0, B.room.ceilZ - B.room.floorZ - 2.6)
    end
    -- far wall: ventilation + electrical
    B.wall('vent', 'uL', B.W * 0.3, B.room.ceilZ - B.room.floorZ - 2.4)
    B.wall('vent', 'uL', B.W * 0.7, B.room.ceilZ - B.room.floorZ - 2.4)
    B.wall('elecbox', 'uL', 1.5, 0.9)
    -- cleaning corner + bins + CCTV
    B.place('bucket', 1.2, B.W - 1.2, { wallOk = true })
    B.place('broom', 1.6, B.W - 0.35, { wallOk = true })
    B.place('wetsign', 2.4, B.W - 1.0, { heading = B.headingU(180) })
    B.place('bin', B.L - 1.2, 1.1, { wallOk = true })
    B.place('bin', B.L - 1.2, B.W - 1.1, { wallOk = true })
    local cz = B.room.ceilZ - 0.7
    for _, c in ipairs({ { 0.6, 0.6, 45 }, { 0.6, B.W - 0.6, -45 }, { B.L - 0.6, 0.6, 135 }, { B.L - 0.6, B.W - 0.6, -135 } }) do
        B.place('cctv', c[1], c[2], { heading = B.headingU(c[3]), z = cz, force = true })
    end
end

---------------------------------------------------------------------
-- GANG HIDEOUT: abandoned house dressing
---------------------------------------------------------------------
local function onTop(B, base, role, du, dv, extraHeading)
    if not base then return end
    local mn, mx = GetModelDimensions(GetEntityModel(base))
    local c = GetEntityCoords(base)
    local top = c.z + mx.z
    local bu, bv = B.toLocal(c.x, c.y)
    return B.place(role, bu + (du or 0), bv + (dv or 0), { z = top, force = true, heading = B.headingU(extraHeading or B.rnd(0, 360)) })
end

local function buildHideout(B, style)
    local rnd = B.rnd
    local gang = style.light or { 220, 40, 30 }

    -- 1) junk along every wall: trash bags, boarded planks, mattresses, tyres
    local wallRoles = { { 'trash', 0.42 }, { 'planks', 0.16 }, { 'mattress', 0.14 }, { 'tyre', 0.08 }, { 'oldChair', 0.06 }, { 'trash', 0.14 } }
    local function pickRole()
        local r, acc = rnd(), 0
        for _, w in ipairs(wallRoles) do acc = acc + w[2]; if r <= acc then return w[1] end end
        return 'trash'
    end
    local function wallSpot(side, at)
        if rnd() > 0.72 then return end
        local role = pickRole()
        local u, v, face
        if side == 'v0' then u, v, face = at, 0.7, 90 elseif side == 'vW' then u, v, face = at, B.W - 0.7, -90 else u, v, face = B.L - 0.7, at, 180 end
        B.place(role, u + rnd(-0.3, 0.3), v + rnd(-0.15, 0.15), { heading = B.headingU(face + rnd(-35, 35)), wallOk = true, alongU = role == 'mattress' or role == 'planks' })
    end
    for u = 1.2, B.L - 1.0, 1.7 do wallSpot('v0', u); wallSpot('vW', u + 0.8) end
    for v = 1.2, B.W - 1.0, 1.7 do wallSpot('uL', v) end

    -- 2) the hangout: fire barrel, old couch, chairs, crate table with bottles, old TV, radio
    local hubs = { { B.L * 0.55, B.W * 0.5 }, { B.L * 0.45, B.W * 0.4 }, { B.L * 0.65, B.W * 0.6 }, { B.L * 0.5, B.W * 0.62 }, { B.L * 0.7, B.W * 0.4 } }
    for _, h in ipairs(hubs) do
        local hu, hv = h[1], h[2]
        local barrel = B.place('fireBarrel', hu, hv, {})
        if barrel then
            ROXDecor.flicker[#ROXDecor.flicker + 1] = { u = hu, v = hv, h = 1.3, c = { 255, 120, 30 }, range = 7.0, base = 2.2 }
            B.place('oldCouch', hu, hv - 2.0, { heading = B.headingU(90), alongU = true })
            B.place('oldChair', hu + 1.7, hv + 0.5, { heading = B.headingU(180 + rnd(-30, 30)) })
            B.place('oldChair', hu - 1.7, hv + 0.7, { heading = B.headingU(rnd(-30, 30)) })
            local tbl = B.place('crateTable', hu + 1.1, hv - 1.0, { heading = B.headingU(rnd(0, 90)) })
            for i = 1, 3 do onTop(B, tbl, 'bottles', rnd(-0.2, 0.2), rnd(-0.2, 0.2)) end
            local tvCrate = B.place('crateTable', hu, hv + 2.4, { heading = B.headingU(-90) })
            onTop(B, tvCrate, 'oldTv', 0, 0, -90)
            B.place('radio', hu - 1.0, hv + 2.3, { heading = B.headingU(-90 + rnd(-20, 20)) })
            break
        end
    end

    -- 3) drug corner (far corner) with a gang-coloured light, cash and scales on the table
    local dt = B.place('drugTable', B.L - 1.8, 1.6, { heading = B.headingU(90), alongU = true })
    if dt then
        for _ = 1, 3 do onTop(B, dt, 'drugs', rnd(-0.45, 0.45), rnd(-0.2, 0.2)) end
        onTop(B, dt, 'cash', rnd(-0.3, 0.3), rnd(-0.15, 0.15))
        onTop(B, dt, 'scale', rnd(-0.3, 0.3), rnd(-0.15, 0.15))
        B.place('oldChair', B.L - 1.8, 2.6, { heading = B.headingU(-90) })
        B.place('bulb', B.L - 0.6, 0.8, { heading = B.headingU(135), wallOk = true })
    end
    ROXDecor.lights[#ROXDecor.lights + 1] = { u = B.L - 1.8, v = 1.8, c = gang, h = 2.2 }

    -- 4) weapons corner
    for i = 0, 2 do B.place('weapons', B.L - 1.0 - i * 0.9, B.W - 0.9, { heading = B.headingU(-90 + rnd(-10, 10)), wallOk = true }) end
    B.place('bat', B.L - 3.6, B.W - 0.8, { heading = B.headingU(rnd(0, 360)) })

    -- 5) dartboard + flickering bulb near the entrance
    B.wall('dartboard', 'vW', B.L * 0.3, 1.45)
    ROXDecor.flicker[#ROXDecor.flicker + 1] = { u = 2.2, v = B.W * 0.5, h = 2.4, c = { 255, 225, 170 }, range = 6.0, base = 1.1, broken = true }

    -- 6) litter all over the floor (bottles, cans, cups)
    for _ = 1, math.floor(B.L * B.W / 6) do
        B.place('bottles', rnd(2.5, B.L - 0.8), rnd(0.8, B.W - 0.8), { heading = B.headingU(rnd(0, 360)) })
    end

    -- 7) stains and dirt on the floor
    for _ = 1, math.floor(B.L * B.W / 9) + 6 do
        local u, v, r = rnd(1.0, B.L - 1.0), rnd(1.0, B.W - 1.0), rnd(0.3, 1.2)
        local a = rnd(0, 6.28)
        local pts = {}
        for k = 0, 3 do
            local ang = a + k * 1.5708 + rnd(-0.3, 0.3)
            pts[#pts + 1] = { u + math.cos(ang) * r * rnd(0.6, 1.2), v + math.sin(ang) * r * rnd(0.6, 1.2) }
        end
        local dark = rnd() < 0.2 and { 70, 10, 10, 120 } or { 25, 20, 15, math.floor(rnd(70, 130)) }
        B.paint(pts, dark)
    end

    -- 8) dim gang-coloured mood light in the middle + CCTV (they watch the door)
    ROXDecor.lights[#ROXDecor.lights + 1] = { u = B.L * 0.5, v = B.W * 0.5, c = gang, h = B.room.ceilZ - B.room.floorZ - 0.6 }
    B.place('cctv', 0.6, 0.6, { heading = B.headingU(45), z = B.room.ceilZ - 0.7, force = true })
end

-- even grid of ceiling spot lights + hanging lamp props
local function buildLightGrid(B, style)
    local stepU, stepV = 6.0, math.max(5.0, B.W / math.max(2, math.floor(B.W / 6.0)))
    for u = 3.0, B.L - 2.0, stepU do
        for v = stepV / 2, B.W - 0.5, stepV do
            ROXDecor.spots[#ROXDecor.spots + 1] = { u = u, v = v }
            B.place('lamp', u, v, { z = B.room.ceilZ - 1.4, force = true })
        end
    end
end

---------------------------------------------------------------------
-- public
---------------------------------------------------------------------
function ROXDecor.Clear()
    for _, e in ipairs(ROXDecor.entities) do
        if DoesEntityExist(e) then DeleteEntity(e) end
    end
    for _, f in ipairs(ROXDecor.fx) do StopParticleFxLooped(f, false) end
    ROXDecor.entities, ROXDecor.lights, ROXDecor.spots, ROXDecor.polys, ROXDecor.fx, ROXDecor.flicker, ROXDecor.active = {}, {}, {}, {}, {}, {}, false
end

-- center: vec3/vec4 entry point inside the interior; seed: property id
function ROXDecor.Build(styleKey, center, seed)
    ROXDecor.Clear()
    local style = DecorStyles[styleKey or DecorDefaultStyle]
    if not style or styleKey == 'off' then return 0 end

    local ped = PlayerPedId()
    local interior = GetInteriorFromEntity(ped)
    local t = GetGameTimer() + 4000
    while interior ~= 0 and not IsInteriorReady(interior) and GetGameTimer() < t do Wait(50) end
    Wait(250)

    local room = measure(vector3(center.x, center.y, center.z))
    local B = Builder(room, vector3(center.x, center.y, center.z), seed or 1)
    if style.builder ~= 'hideout' and (B.L < 8.0 or B.W < 6.0) then return 0 end

    if style.builder == 'hideout' then
        if B.L < 5.0 or B.W < 4.0 then return 0 end
        buildHideout(B, style)
        style = setmetatable({ dust = true, lightRange = 8.0, lightIntensity = 1.3 }, { __index = style })
    end

    local entryZone = math.min(4.5, B.L * 0.14)
    local frontZone = (style.office or style.workshop) and math.min(6.5, B.L * 0.2) or 0
    local u0 = entryZone
    local uFrontEnd = u0 + frontZone
    local uDock = (style.dock and B.L > 18) and B.L * 0.76 or B.L - 0.6

    if style.builder == 'hideout' then goto resolve end
    if style.markings then buildMarkings(B, style) end
    if style.architecture then buildArchitecture(B) end
    if style.lightGrid then buildLightGrid(B, style) end
    if style.office then buildOffice(B, u0, uFrontEnd) end
    if style.workshop then buildWorkshop(B, style, u0, uFrontEnd) end
    if style.racks or style.wallRacks then buildRacks(B, style, uFrontEnd + 0.8, uDock - 0.6) end
    if style.garage then buildGarageFloor(B, uFrontEnd + 1.0, uDock - 1.0) end
    if style.dock and B.L > 18 then buildDock(B, style, uDock, B.L - 0.6) end
    if not style.architecture then buildSafety(B) end

    ::resolve::
    -- resolve light positions to world space
    local lights = {}
    for _, l in ipairs(ROXDecor.lights) do
        local x, y = B.world(l.u, l.v)
        local c = l.c or (l.warm and { 255, 214, 170 }) or style.light
        lights[#lights + 1] = { x = x, y = y, z = l.h and (room.floorZ + l.h) or (room.ceilZ - 1.2), r = c[1], g = c[2], b = c[3] }
    end
    local flick = {}
    for _, l in ipairs(ROXDecor.flicker) do
        local x, y = B.world(l.u, l.v)
        flick[#flick + 1] = { x = x, y = y, z = room.floorZ + (l.h or 1.5), r = l.c[1], g = l.c[2], b = l.c[3], range = l.range, base = l.base, broken = l.broken, seed = math.random() * 10 }
    end
    ROXDecor.flicker = flick
    ROXDecor.lights = lights
    local spots = {}
    for _, l in ipairs(ROXDecor.spots) do
        local x, y = B.world(l.u, l.v)
        local c = style.light or { 255, 236, 205 }
        spots[#spots + 1] = { x = x, y = y, z = room.ceilZ - 1.5, r = c[1], g = c[2], b = c[3] }
    end
    ROXDecor.spots = spots
    ROXDecor.spotDist = (room.ceilZ - room.floorZ) + 2.0
    ROXDecor.range, ROXDecor.intensity = style.lightRange or 10.0, style.lightIntensity or 1.4
    -- floating dust in the light beams
    if style.dust then
        RequestNamedPtfxAsset('core')
        local tt = GetGameTimer() + 2000
        while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() < tt do Wait(10) end
        for i = 1, math.min(6, #spots), 2 do
            UseParticleFxAssetNextCall('core')
            local f = StartParticleFxLoopedAtCoord('ent_amb_dust_motes', spots[i].x, spots[i].y, room.floorZ + 2.5, 0.0, 0.0, 0.0, 1.5, false, false, false, false)
            if f and f ~= 0 then ROXDecor.fx[#ROXDecor.fx + 1] = f end
        end
    end
    ROXDecor.active = true
    if Debug then print(('[ROX decor] %s %.1fx%.1f placed %d props, %d lights, %d spots, %d floor marks'):format(styleKey, B.L, B.W, B.placed, #lights, #spots, #ROXDecor.polys)) end
    return B.placed
end

-- lights + floor paint (only while inside a ROX warehouse)
local function poly(a, b, c, r, g, bl, al)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, bl, al)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, bl, al)
end

CreateThread(function()
    while true do
        if ROXDecor.active then
            local pc = GetEntityCoords(PlayerPedId())
            for _, l in ipairs(ROXDecor.lights) do
                if math.abs(l.x - pc.x) < 40.0 and math.abs(l.y - pc.y) < 40.0 then
                    DrawLightWithRange(l.x, l.y, l.z, l.r, l.g, l.b, ROXDecor.range, ROXDecor.intensity)
                end
            end
            local tm = GetGameTimer() / 1000.0
            for _, l in ipairs(ROXDecor.flicker) do
                local k
                if l.broken then
                    -- broken bulb: mostly on, sometimes cuts out
                    local n = math.sin(tm * 13.0 + l.seed) + math.sin(tm * 7.3 + l.seed * 2)
                    k = n > 1.55 and 0.05 or 1.0
                else
                    -- fire: soft random flicker
                    k = 0.75 + 0.15 * math.sin(tm * 9.0 + l.seed) + 0.1 * math.sin(tm * 23.0 + l.seed * 3)
                end
                DrawLightWithRange(l.x, l.y, l.z, l.r, l.g, l.b, l.range, l.base * k)
            end
            for _, l in ipairs(ROXDecor.spots) do
                if math.abs(l.x - pc.x) < 45.0 and math.abs(l.y - pc.y) < 45.0 then
                    DrawSpotLight(l.x, l.y, l.z, 0.0, 0.0, -1.0, l.r, l.g, l.b, ROXDecor.spotDist, 5.0, 0.0, 48.0, 30.0)
                end
            end
            for _, q in ipairs(ROXDecor.polys) do
                if math.abs(q[1].x - pc.x) < 40.0 and math.abs(q[1].y - pc.y) < 40.0 then
                    poly(q[1], q[2], q[3], q[5], q[6], q[7], q[8])
                    poly(q[1], q[3], q[4], q[5], q[6], q[7], q[8])
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Export the warehouse you are standing in as a real map file (CodeWalker .ymap.xml)
-- /roxdecor_export [name]  -> saved on the server in rox_realestate/exports/<name>.ymap.xml
RegisterCommand('roxdecor_export', function(_, args)
    if not ROXDecor.active or #ROXDecor.entities == 0 then return Notify('No ROX warehouse design here', 'error') end
    local list = {}
    for _, e in ipairs(ROXDecor.entities) do
        local meta = ROXDecor.models and ROXDecor.models[e]
        if DoesEntityExist(e) and meta and not meta.vehicle then
            local c = GetEntityCoords(e)
            local qx, qy, qz, qw = GetEntityQuaternion(e)
            list[#list + 1] = { m = meta.model, x = c.x, y = c.y, z = c.z, qx = qx, qy = qy, qz = qz, qw = qw }
        end
    end
    local name = (args and args[1] or ('rox_warehouse_' .. (CurrentHouse and CurrentHouse.id or 0))):gsub('[^%w_%-]', '')
    local ok, res = ServerCall('exportDecor', name, list)
    if ok then Notify(('Saved %s (%d props)'):format(res, #list), 'success') elseif res then Notify(res, 'error') end
end, false)

RegisterCommand('roxdecor_debug', function() Debug = not Debug print('ROX decor debug', Debug) end, false)
