--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

function Notify(msg, kind)
    SendNUIMessage({ action = 'notify', msg = msg, kind = kind or 'info' })
end

RegisterNetEvent('rox_re:notify', Notify)

function HelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

-- Ray from the gameplay camera. Returns hit(bool), coords, normal, entity
function CameraRaycast(distance, ignore, flags)
    local camPos = GetGameplayCamCoord()
    local dir = rotToDir(GetGameplayCamRot(2))
    local dest = camPos + dir * (distance or 15.0)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, flags or -1, ignore or PlayerPedId(), 4)
    local _, hit, coords, normal, entity = GetShapeTestResult(handle)
    return hit == 1, coords, normal, entity
end

function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

function StreetAt(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local a, b = GetStreetNameFromHashKey(s1), s2 ~= 0 and GetStreetNameFromHashKey(s2) or nil
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    local street = a
    if b and b ~= '' then street = street .. ' / ' .. b end
    if zone and zone ~= 'NULL' then street = street .. ', ' .. zone end
    return street
end

function Teleport(x, y, z, h, exact)
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, exact and z or z - 0.98, false, false, false, false)
    SetEntityHeading(ped, h or 0.0)
    local t = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
    Wait(300)
    DoScreenFadeIn(500)
end

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end
