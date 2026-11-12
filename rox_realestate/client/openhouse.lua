--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.

    OPEN HOUSE: real houses of the map that you walk into (no teleport, no loading screen).
    The realtor draws the property zone, marks the doors and the system locks / unlocks them.
]]

OpenHouse = {}

local C = Config.OpenHouse
local active            -- { id, prop, zone, access, canLock, inside }
local doorState = {}    -- [doorHash] = locked (what we last applied)
local hidden = {}       -- model hides we created { x, y, z, model }

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function inPoly(pts, x, y)
    local inside, j = false, #pts
    for i = 1, #pts do
        local a, b = pts[i], pts[j]
        if ((a.y > y) ~= (b.y > y)) and (x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x) then inside = not inside end
        j = i
    end
    return inside
end

function OpenHouse.InZone(zone, c)
    return zone and c.z >= zone.minZ and c.z <= zone.maxZ and inPoly(zone.points, c.x, c.y)
end

local function doorHash(id, i) return joaat(('rox_re_door_%s_%s'):format(id, i)) end

local function hide(r)
    CreateModelHide(r.x + 0.0, r.y + 0.0, r.z + 0.0, 0.8, r.model, true)
    hidden[#hidden + 1] = r
end

local function unhideAll()
    for _, r in ipairs(hidden) do RemoveModelHide(r.x + 0.0, r.y + 0.0, r.z + 0.0, 0.8, r.model, false) end
    hidden = {}
end

local function applyDoors(force)
    if not active then return end
    local prop = FindProperty(active.id)
    if not prop then return end
    local locked = prop.locked and true or false
    for i, d in ipairs(active.zone.doors or {}) do
        local dh = doorHash(active.id, i)
        if doorState[dh] == nil then
            if not IsDoorRegisteredWithSystem(dh) then AddDoorToSystem(dh, d.model, d.x + 0.0, d.y + 0.0, d.z + 0.0, false, false, false) end
        end
        if force or doorState[dh] ~= locked then
            DoorSystemSetDoorState(dh, locked and 1 or 0, false, false)
            doorState[dh] = locked
        end
        -- doors that are plain props (not real door archetypes) are simply frozen while locked
        local obj = GetClosestObjectOfType(d.x + 0.0, d.y + 0.0, d.z + 0.0, 1.2, d.model, false, false, false)
        if obj ~= 0 then FreezeEntityPosition(obj, locked) end
    end
end

local function releaseDoors()
    if not active then return end
    for i, d in ipairs(active.zone.doors or {}) do
        local dh = doorHash(active.id, i)
        if IsDoorRegisteredWithSystem(dh) then RemoveDoorFromSystem(dh) end
        doorState[dh] = nil
        local obj = GetClosestObjectOfType(d.x + 0.0, d.y + 0.0, d.z + 0.0, 1.2, d.model, false, false, false)
        if obj ~= 0 then FreezeEntityPosition(obj, false) end
    end
end

function OpenHouse.Leave()
    if not active then return end
    local id = active.id
    releaseDoors()
    unhideAll()
    active = nil
    if CurrentHouse and CurrentHouse.open then
        CloseFurnitureMode()
        DeleteAllFurniture()
        CurrentHouse = nil
    end
    ServerCall('openLeave', id)
end

local function activate(prop)
    local ok, data = ServerCall('openNear', prop.id)
    if not ok or type(data) ~= 'table' then return end
    if CurrentHouse or ZoneToolOpen then ServerCall('openLeave', prop.id) return end -- entered a shell meanwhile
    active = { id = prop.id, zone = prop.zone, access = data.access, canLock = data.canLock, inside = false }
    local e = prop.zone.entry
    CurrentHouse = {
        id = prop.id, label = prop.label, open = true, canFurnish = false,
        spawn = vec4(e.x + 0.0, e.y + 0.0, e.z + 0.0, (e.h or 0.0) + 0.0), door = prop.door,
    }
    for _, r in ipairs(prop.zone.removed or {}) do hide(r) end
    applyDoors(true)
    SpawnAllFurniture(data.furniture or {})
end

function OpenHouse.Active() return active end

-- property list changed (lock toggled, sold, zone edited, deleted ...)
function OpenHouse.OnSync()
    if not active then return end
    local prop = FindProperty(active.id)
    if not prop or not prop.open or not prop.zone then return OpenHouse.Leave() end
    if json.encode(prop.zone) ~= json.encode(active.zone) or (prop.hasKey and true or false) ~= (active.access and true or false) then
        OpenHouse.Leave() -- re-activated by the proximity loop with fresh data
        return
    end
    applyDoors(false)
end

---------------------------------------------------------------------
-- Proximity: stream the nearest open house (doors, removed doors, furniture)
---------------------------------------------------------------------
CreateThread(function()
    if not C.Enabled then return end
    while true do
        Wait(500)
        local shell = CurrentHouse and not CurrentHouse.open
        if shell then
            if active then releaseDoors(); unhideAll(); active = nil; ServerCall('openLeave') end
        else
            local pc = GetEntityCoords(PlayerPedId())
            local best, bd
            for _, p in ipairs(PropertyList) do
                if p.open and p.zone and p.zone.entry then
                    local e = p.zone.entry
                    local d = #(pc - vector3(e.x + 0.0, e.y + 0.0, e.z + 0.0))
                    if d < C.StreamDistance and (not bd or d < bd) then best, bd = p, d end
                end
            end
            if active and (not best or best.id ~= active.id) then OpenHouse.Leave() end
            if best and not active and not ZoneToolOpen then activate(best) end
            if active and CurrentHouse and CurrentHouse.open then
                local inside = OpenHouse.InZone(active.zone, pc)
                if inside and not active.inside and active.access then Notify(L('furniture_hint'), 'info') end
                active.inside = inside
                CurrentHouse.canFurnish = inside and active.access and true or false
                applyDoors(false) -- door objects stream in late: keep them in the right state
            end
        end
    end
end)

-- door interaction
CreateThread(function()
    if not C.Enabled then return end
    while true do
        local sleep = 400
        if active and not ZoneToolOpen then
            local prop = FindProperty(active.id)
            local pc = GetEntityCoords(PlayerPedId())
            local near, nd, ni
            for i, d in ipairs(active.zone.doors or {}) do
                local dist = #(pc - vector3(d.x + 0.0, d.y + 0.0, d.z + 0.0))
                if dist < C.DoorDistance and (not nd or dist < nd) then near, nd, ni = d, dist, i end
            end
            if near and prop and not IsNuiFocused() then
                sleep = 0
                local canLock = active.access or (active.canLock and not prop.ownerName)
                if Config.DrawMarker then
                    local r, g, b = 235, 70, 60
                    if not prop.locked then r, g, b = 90, 200, 90 end
                    DrawMarker(2, near.x + 0.0, near.y + 0.0, near.z + 1.15, 0, 0, 0, 0, 0, 0, 0.14, 0.14, 0.12, r, g, b, 190, false, true, 2, false)
                end
                if canLock then
                    HelpText(prop.locked and L('help_unlock', prop.label) or L('help_lock', prop.label))
                    if IsControlJustPressed(0, 38) then
                        local ped = PlayerPedId()
                        LoadAnimDict('anim@heists@keycard@')
                        TaskPlayAnim(ped, 'anim@heists@keycard@', 'exit', 8.0, -8.0, 600, 48, 0, false, false, false)
                        PlaySoundFrontend(-1, prop.locked and 'DOOR_BUZZ' or 'Door_Open', prop.locked and 'MP_PLAYER_APARTMENT' or 'DLC_HEIST_FLEECA_SOUNDSET', true)
                        ServerCall('toggleLock', active.id)
                        Wait(350)
                    end
                elseif near.main and (prop.status == 'available' or prop.salePrice) then
                    HelpText(L('help_view', prop.label))
                    if IsControlJustPressed(0, 38) then OpenPropertyCard(prop) end
                elseif prop.locked then
                    HelpText(L('help_knock', prop.label))
                    if IsControlJustPressed(0, 38) then
                        ServerCall('openKnock', active.id)
                        Wait(1500)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

---------------------------------------------------------------------
-- PROPERTY ZONE tool (realtor)
---------------------------------------------------------------------
ZoneToolOpen = false

local function hudLine(y, text)
    SetTextFont(4)
    SetTextScale(0.36, 0.36)
    SetTextColour(255, 255, 255, 235)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.012, y)
end

local function drawZone(pts, baseZ, topZ, r, g, b)
    local n = #pts
    for i = 1, n do
        local a, c = pts[i], pts[i % n + 1]
        DrawLine(a.x, a.y, baseZ, a.x, a.y, topZ, r, g, b, 255)
        if n > 1 and (i < n or n > 2) then
            DrawLine(a.x, a.y, baseZ, c.x, c.y, baseZ, r, g, b, 255)
            DrawLine(a.x, a.y, topZ, c.x, c.y, topZ, r, g, b, 255)
            DrawPoly(a.x, a.y, baseZ, c.x, c.y, baseZ, c.x, c.y, topZ, r, g, b, 45)
            DrawPoly(c.x, c.y, topZ, a.x, a.y, topZ, a.x, a.y, baseZ, r, g, b, 45)
            DrawPoly(c.x, c.y, baseZ, a.x, a.y, baseZ, a.x, a.y, topZ, r, g, b, 45)
            DrawPoly(a.x, a.y, topZ, c.x, c.y, topZ, c.x, c.y, baseZ, r, g, b, 45)
        end
        DrawMarker(28, a.x, a.y, baseZ + 1.0, 0, 0, 0, 0, 0, 0, 0.08, 0.08, 0.08, r, g, b, 230, false, false, 2, false)
    end
end

-- returns zone, location (entry point used as the property "door"), street
function PickZone(existing)
    if ZoneToolOpen then return end
    ZoneToolOpen = true
    OpenHouse.Leave()
    local ped = PlayerPedId()
    local corners, doors, removed = {}, {}, {}
    local height, entry = C.DefaultHeight, nil
    local previewHides = {}
    if type(existing) == 'table' then
        local baseZ = (existing.minZ or 0.0) + 1.0
        for _, p in ipairs(existing.points or {}) do corners[#corners + 1] = { x = p.x + 0.0, y = p.y + 0.0, z = baseZ } end
        for _, d in ipairs(existing.doors or {}) do doors[#doors + 1] = d end
        for _, r in ipairs(existing.removed or {}) do removed[#removed + 1] = r end
        entry = existing.entry
        if existing.maxZ and existing.minZ then height = existing.maxZ - existing.minZ end
    end
    for _, r in ipairs(removed) do CreateModelHide(r.x, r.y, r.z, 0.8, r.model, true); previewHides[#previewHides + 1] = r end

    local function countDoors()
        local m, n = 0, 0
        for _, d in ipairs(doors) do if d.main then m = m + 1 else n = n + 1 end end
        return m, n
    end
    local function toggleDoor(entity, main)
        if not entity or entity == 0 or GetEntityType(entity) ~= 3 then return Notify(L('zone_aim_door'), 'error') end
        local c, model = GetEntityCoords(entity), GetEntityModel(entity)
        for i, d in ipairs(doors) do
            if d.model == model and #(vector3(d.x, d.y, d.z) - c) < 0.5 then
                table.remove(doors, i)
                return Notify(L('zone_door_unset'), 'info')
            end
        end
        if #doors >= C.MaxDoors then return Notify(L('zone_max_doors', C.MaxDoors), 'error') end
        doors[#doors + 1] = { model = model, x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, main = main and true or false }
        PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        Notify(L(main and 'zone_door_main' or 'zone_door_inner'), 'success')
    end

    local result
    Wait(200)
    while true do
        Wait(0)
        for _, k in ipairs({ 24, 25, 37, 14, 15, 16, 17, 140, 141, 142, 257, 263, 264, 200, 199, 44, 47, 74, 73 }) do DisableControlAction(0, k, true) end
        local hit, coords, _, entity = CameraRaycast(40.0, ped)
        local snap = not IsControlPressed(0, 21)
        local pt
        if hit then
            pt = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
            if snap then
                pt.x = math.floor(pt.x / C.Snap + 0.5) * C.Snap
                pt.y = math.floor(pt.y / C.Snap + 0.5) * C.Snap
            end
        end

        local baseZ = 1e9
        for _, c in ipairs(corners) do if c.z < baseZ then baseZ = c.z end end
        if baseZ > 1e8 then baseZ = (pt and pt.z) or GetEntityCoords(ped).z end
        baseZ = baseZ - 1.0
        local topZ = baseZ + height

        -- draw
        drawZone(corners, baseZ, topZ, 255, 90, 31)
        if pt then
            DrawMarker(28, pt.x, pt.y, pt.z, 0, 0, 0, 0, 0, 0, 0.1, 0.1, 0.1, 255, 255, 255, 230, false, false, 2, false)
            if #corners > 0 then
                local l = corners[#corners]
                DrawLine(l.x, l.y, baseZ, pt.x, pt.y, baseZ, 255, 255, 255, 200)
            end
        end
        if entry then DrawMarker(1, entry.x, entry.y, entry.z - 1.0, 0, 0, 0, 0, 0, 0, 0.9, 0.9, 0.4, 90, 200, 90, 160, false, false, 2, false) end
        for _, d in ipairs(doors) do
            local r, g, b = 60, 140, 255
            if d.main then r, g, b = 90, 220, 90 end
            DrawMarker(28, d.x, d.y, d.z + 1.0, 0, 0, 0, 0, 0, 0, 0.16, 0.16, 0.16, r, g, b, 200, false, false, 2, false)
            DrawText3D(d.x, d.y, d.z + 1.35, d.main and '~g~MAIN DOOR' or '~b~INNER DOOR')
        end
        for _, r in ipairs(removed) do DrawText3D(r.x, r.y, r.z + 1.0, '~r~REMOVED') end
        if entity and entity ~= 0 and GetEntityType(entity) == 3 then
            local c = GetEntityCoords(entity)
            DrawText3D(c.x, c.y, c.z + 1.6, ('~o~%s'):format(GetEntityModel(entity)))
        end
        local m, n = countDoors()
        hudLine(0.04, ('~o~PROPERTY ZONE~w~  %d corners · height %.1fm · %d main / %d inner doors%s'):format(#corners, height, m, n, entry and ' · entry set' or ''))
        hudLine(0.068, '~g~CLICK~w~ corner · ~g~SHIFT~w~ no snap · ~g~SCROLL~w~ height · ~b~E~w~ entry · ~b~G~w~ main door · ~b~H~w~ inner door')
        hudLine(0.096, '~r~X~w~ remove door · ~r~DEL~w~ restore door · ~y~BACKSPACE~w~ undo corner · ~g~ENTER~w~ save · ~r~ESC~w~ cancel')

        -- input
        if pt and IsDisabledControlJustPressed(0, 24) then
            if #corners < C.MaxCorners then
                corners[#corners + 1] = pt
                PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            else
                Notify(L('zone_max_corners', C.MaxCorners), 'error')
            end
        end
        if IsDisabledControlJustPressed(0, 15) or IsDisabledControlJustPressed(0, 17) then height = math.min(60.0, height + 0.5) end
        if IsDisabledControlJustPressed(0, 14) or IsDisabledControlJustPressed(0, 16) then height = math.max(2.0, height - 0.5) end
        if IsControlJustPressed(0, 38) then
            local c = GetEntityCoords(ped)
            entry = { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, h = GetEntityHeading(ped) + 0.0 }
            PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            Notify(L('zone_entry_set'), 'success')
        end
        if IsDisabledControlJustPressed(0, 47) then toggleDoor(entity, true) end
        if IsDisabledControlJustPressed(0, 74) then toggleDoor(entity, false) end
        if IsDisabledControlJustPressed(0, 73) then
            if entity and entity ~= 0 and GetEntityType(entity) == 3 and #removed < C.MaxDoors then
                local c, model = GetEntityCoords(entity), GetEntityModel(entity)
                local r = { model = model, x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
                removed[#removed + 1] = r
                CreateModelHide(r.x, r.y, r.z, 0.8, r.model, true)
                previewHides[#previewHides + 1] = r
                for i = #doors, 1, -1 do
                    if doors[i].model == model and #(vector3(doors[i].x, doors[i].y, doors[i].z) - c) < 0.5 then table.remove(doors, i) end
                end
                Notify(L('zone_removed', model), 'error')
            else
                Notify(L('zone_aim_door'), 'error')
            end
        end
        if IsControlJustPressed(0, 178) and #removed > 0 then
            local r = table.remove(removed)
            RemoveModelHide(r.x, r.y, r.z, 0.8, r.model, false)
            Notify(L('zone_restored'), 'info')
        end
        if IsControlJustPressed(0, 177) and not IsDisabledControlPressed(0, 200) and #corners > 0 then
            table.remove(corners)
            PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
        if IsControlJustPressed(0, 191) then
            if #corners < 3 then
                Notify(L('zone_need_corners'), 'error')
            elseif not entry then
                Notify(L('zone_need_entry'), 'error')
            else
                local pts = {}
                for _, c in ipairs(corners) do pts[#pts + 1] = { x = c.x, y = c.y } end
                result = { points = pts, minZ = baseZ, maxZ = topZ, entry = entry, doors = doors, removed = removed }
                break
            end
        end
        if IsDisabledControlJustPressed(0, 200) then
            PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            break
        end
    end
    for _, r in ipairs(previewHides) do RemoveModelHide(r.x, r.y, r.z, 0.8, r.model, false) end
    ZoneToolOpen = false
    if result then
        local e = result.entry
        return result, { x = e.x, y = e.y, z = e.z, h = e.h }, StreetAt(e)
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    releaseDoors()
    unhideAll()
end)
