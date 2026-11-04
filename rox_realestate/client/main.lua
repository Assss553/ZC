--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

PropertyList = {}       -- synced from server (personalised)
CurrentHouse = nil      -- { id, label, spawn, door, canFurnish }
ShellObject = nil       -- spawned shell prop for shell interiors

local function deleteShell()
    if ShellObject and DoesEntityExist(ShellObject) then DeleteEntity(ShellObject) end
    ShellObject = nil
end
local blips = {}

---------------------------------------------------------------------
-- Sync + blips
---------------------------------------------------------------------
local function clearBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function addBlip(p, cfg, name)
    local b = AddBlipForCoord(p.door.x, p.door.y, p.door.z)
    SetBlipSprite(b, cfg.sprite)
    SetBlipColour(b, cfg.color)
    SetBlipScale(b, cfg.scale)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(b)
    blips[#blips + 1] = b
end

local function refreshBlips()
    clearBlips()
    for _, p in ipairs(PropertyList) do
        if p.isOwner then
            addBlip(p, Config.Blips.Owned, p.label)
        elseif p.hasKey then
            addBlip(p, Config.Blips.Key, p.label)
        elseif p.status == 'available' and Config.Blips.Available.show then
            addBlip(p, Config.Blips.Available, L('blip_available'))
        elseif p.salePrice and Config.Blips.Market.show then
            addBlip(p, Config.Blips.Market, L('blip_market'))
        end
    end
end

RegisterNetEvent('rox_re:sync', function(list)
    PropertyList = list or {}
    refreshBlips()
    SendNUIMessage({ action = 'sync', properties = PropertyList })
end)

function FindProperty(id)
    for _, p in ipairs(PropertyList) do if p.id == id then return p end end
end

---------------------------------------------------------------------
-- Aim / raycast location picker (used when creating a property)
---------------------------------------------------------------------
function PickLocation(mode)
    local ped = PlayerPedId()
    local result
    Wait(200)
    while true do
        Wait(0)
        DisableControlAction(0, 24, true)  -- attack
        DisableControlAction(0, 25, true)  -- aim
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)
        DisableControlAction(0, 200, true) -- pause menu
        HelpText(L('aim_help'))

        local hit, coords = CameraRaycast(30.0, ped)
        if hit then
            local pc = GetEntityCoords(ped)
            DrawLine(pc.x, pc.y, pc.z, coords.x, coords.y, coords.z, 255, 90, 31, 200)
            DrawMarker(28, coords.x, coords.y, coords.z, 0, 0, 0, 0, 0, 0, 0.12, 0.12, 0.12, 255, 90, 31, 220, false, false, 2, false)
            DrawMarker(25, coords.x, coords.y, coords.z - 0.9, 0, 0, 0, 0, 0, 0, 0.9, 0.9, 0.9, 255, 90, 31, 140, false, false, 2, false)
            DrawText3D(coords.x, coords.y, coords.z + 0.3, ('~o~%.2f  %.2f  %.2f'):format(coords.x, coords.y, coords.z))

            if IsControlJustPressed(0, 38) then -- E
                -- pull the point slightly towards the player so it's not inside the wall
                local dir = vector3(pc.x - coords.x, pc.y - coords.y, 0.0)
                local len = #dir
                if len > 0.01 then dir = dir / len end
                local pos = coords + dir * 0.5
                result = {
                    x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0,
                    h = (GetEntityHeading(ped) + 180.0) % 360.0,
                }
                if mode == 'floor' then
                    -- inside point: stand on the floor where you aimed, facing the way you look
                    local found, gz = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.5, false)
                    result = { x = coords.x + 0.0, y = coords.y + 0.0, z = (found and gz or coords.z) + 1.0, h = GetEntityHeading(ped) }
                end
                PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                break
            end
        end
        if IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 200) then
            PlaySoundFrontend(-1, 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
            break
        end
    end
    if result then return result, StreetAt(result) end
end

---------------------------------------------------------------------
-- Enter / exit
---------------------------------------------------------------------
-- centre of the shell, on its floor (ray straight down inside the model bounds)
function FindShellFloor(obj, hash, p)
    local min, max = GetModelDimensions(hash)
    local cx, cy = p.x + (min.x + max.x) / 2, p.y + (min.y + max.y) / 2
    local t = GetGameTimer() + 1500
    local floorZ
    while GetGameTimer() < t do
        local ray = StartExpensiveSynchronousShapeTestLosProbe(cx, cy, p.z + max.z - 0.3, cx, cy, p.z + min.z - 1.0, 1 + 16, PlayerPedId(), 4)
        local _, hit, coords = GetShapeTestResult(ray)
        if hit == 1 then floorZ = coords.z break end
        Wait(50)
    end
    return vec4(cx, cy, (floorZ or (p.z + min.z + 0.2)) + 1.0, 0.0)
end

function EnterProperty(id)
    local ok, data = ServerCall('enter', id)
    if not ok then
        if data then Notify(data, 'error') end
        return
    end
    local prop = FindProperty(id)
    if data.ipl then RequestIpl(data.ipl) end
    CurrentHouse = {
        id = data.id, label = data.label, spawn = data.spawn, canFurnish = data.canFurnish,
        door = prop and prop.door,
    }
    if data.shell and data.shellPos then
        DoScreenFadeOut(300)
        while not IsScreenFadedOut() do Wait(0) end
        local hash = LoadModel(data.shell)
        if not hash then
            DoScreenFadeIn(300)
            Notify(L('shell_missing', data.shell), 'error')
            ServerCall('exit')
            CurrentHouse = nil
            return
        end
        local p = data.shellPos
        ShellObject = CreateObject(hash, p.x, p.y, p.z, false, false, false)
        FreezeEntityPosition(ShellObject, true)
        SetEntityHeading(ShellObject, 0.0)
        if data.autoEntry then
            -- detected shell without a saved entry: stand in the middle of the floor
            local spawn = FindShellFloor(ShellObject, hash, p)
            data.spawn = spawn
            CurrentHouse.spawn = spawn
            if data.isRealtor then Notify(L('auto_entry', Config.Detect.EntryCommand), 'info') end
        end
        SetModelAsNoLongerNeeded(hash)
    end
    Teleport(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w, data.shell ~= nil)
    SpawnAllFurniture(data.furniture or {})
    if data.canFurnish then Notify(L('furniture_hint'), 'info') end
end

function ExitProperty()
    if not CurrentHouse then return end
    local house = CurrentHouse
    CloseFurnitureMode()
    local _, door = ServerCall('exit')
    door = door or house.door
    DeleteAllFurniture()
    CurrentHouse = nil
    if door then
        DoScreenFadeOut(300)
        while not IsScreenFadedOut() do Wait(0) end
        deleteShell()
        local found, gz = GetGroundZFor_3dCoord(door.x, door.y, door.z + 1.0, false)
        Teleport(door.x, door.y, found and gz + 1.0 or door.z, door.h)
    end
end

RegisterNetEvent('rox_re:forceExit', function() ExitProperty() end)

---------------------------------------------------------------------
-- Door / exit interaction loop
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)

        if CurrentHouse then
            local s = CurrentHouse.spawn
            local dist = #(pc - vector3(s.x, s.y, s.z))
            if dist < 15.0 then
                sleep = 0
                if Config.DrawMarker then
                    DrawMarker(2, s.x, s.y, s.z, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.2, 255, 90, 31, 160, false, true, 2, false)
                end
                if dist < 1.5 and not IsNuiFocused() then
                    HelpText(L('help_exit_only'))
                    if IsControlJustPressed(0, 38) then ExitProperty() end
                end
            end
        else
            local nearest, nd
            for _, p in ipairs(PropertyList) do
                local d = #(pc - vector3(p.door.x, p.door.y, p.door.z))
                if d < 20.0 and (not nd or d < nd) then nearest, nd = p, d end
            end
            if nearest then
                sleep = 0
                local d = nearest.door
                if Config.DrawMarker then
                    local r, g, b = 255, 90, 31
                    if nearest.hasKey then r, g, b = 90, 200, 90 end
                    DrawMarker(2, d.x, d.y, d.z, 0, 0, 0, 0, 0, 0, 0.25, 0.25, 0.2, r, g, b, 170, false, true, 2, false)
                end
                if nd < Config.DoorDistance and not IsNuiFocused() then
                    local view = not nearest.hasKey and (nearest.status == 'available' or nearest.salePrice)
                    HelpText(view and L('help_view', nearest.label) or L('help_enter', nearest.label))
                    if IsControlJustPressed(0, 38) then
                        if view then
                            OpenPropertyCard(nearest)
                        else
                            EnterProperty(nearest.id)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- Keep G free for our use inside houses
-- O (default) anywhere inside your house opens the furniture panel
RegisterKeyMapping('rox_re_furni', 'Real estate: furniture panel (inside your house)', 'keyboard', Config.Furniture.OpenKey)
RegisterCommand('rox_re_furni', function()
    if CurrentHouse and CurrentHouse.canFurnish and not IsNuiFocused() then OpenFurniturePanel() end
end, false)

-- realtor inside a shell: save the entry point where you stand (+ optional label)
RegisterCommand(Config.Detect.EntryCommand, function(_, args)
    if not CurrentHouse then return Notify(L('not_inside'), 'error') end
    local ok, err = ServerCall('saveEntry', table.concat(args or {}, ' '))
    if ok then
        local c, h = GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId())
        CurrentHouse.spawn = vec4(c.x, c.y, c.z, h)
    elseif err then
        Notify(err, 'error')
    end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    DeleteAllFurniture()
    deleteShell()
    SetNuiFocus(false, false)
    if CurrentHouse and CurrentHouse.door then
        local d = CurrentHouse.door
        SetEntityCoords(PlayerPedId(), d.x, d.y, d.z, false, false, false, false)
    end
end)
