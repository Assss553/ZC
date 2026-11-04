PropertyList = {}       -- synced from server (personalised)
CurrentHouse = nil      -- { id, label, spawn, door, canFurnish }
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
            addBlip(p, Config.Blips.Available, Config.Locale == 'ar' and 'عقار متاح' or 'Property Available')
        elseif p.salePrice and Config.Blips.Market.show then
            addBlip(p, Config.Blips.Market, Config.Locale == 'ar' and 'عقار للبيع' or 'Property For Sale')
        end
    end
end

RegisterNetEvent('zc_re:sync', function(list)
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
function PickLocation()
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
    Teleport(data.spawn.x, data.spawn.y, data.spawn.z, data.spawn.w)
    SpawnAllFurniture(data.furniture or {})
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
        local found, gz = GetGroundZFor_3dCoord(door.x, door.y, door.z + 1.0, false)
        Teleport(door.x, door.y, found and gz + 1.0 or door.z, door.h)
    end
end

RegisterNetEvent('zc_re:forceExit', function() ExitProperty() end)

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
                    HelpText(L('help_exit'))
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
RegisterKeyMapping('zc_re_furniture', 'Real estate: furniture panel (inside)', 'keyboard', Config.Furniture.OpenKey)
RegisterCommand('zc_re_furniture', function()
    if CurrentHouse and CurrentHouse.canFurnish and not IsNuiFocused() then OpenFurniturePanel() end
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    DeleteAllFurniture()
    SetNuiFocus(false, false)
    if CurrentHouse and CurrentHouse.door then
        local d = CurrentHouse.door
        SetEntityCoords(PlayerPedId(), d.x, d.y, d.z, false, false, false, false)
    end
end)
