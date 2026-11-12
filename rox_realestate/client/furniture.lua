--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

local Spawned = {}       -- [furnitureId] = entity
CurrentPlacement = nil  -- piece being placed
local panelOpen = false

---------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------
local function spawnPiece(p)
    if Spawned[p.id] then DeleteEntity(Spawned[p.id]); Spawned[p.id] = nil end
    if not p.placed or not p.x then return end
    local hash = LoadModel(p.model)
    if not hash then return end
    local obj = CreateObject(hash, p.x, p.y, p.z, false, false, false)
    SetEntityRotation(obj, p.rx or 0.0, p.ry or 0.0, p.rz or 0.0, 2, true)
    SetEntityCoordsNoOffset(obj, p.x, p.y, p.z, false, false, false)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    Spawned[p.id] = obj
end

function SpawnAllFurniture(list)
    DeleteAllFurniture()
    for _, p in ipairs(list) do spawnPiece(p) end
end

function DeleteAllFurniture()
    for id, obj in pairs(Spawned) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        Spawned[id] = nil
    end
end

RegisterNetEvent('rox_re:furnitureUpdate', function(action, piece)
    if not CurrentHouse then return end
    if action == 'place' then
        spawnPiece(piece)
    elseif action == 'remove' and Spawned[piece.id] then
        DeleteEntity(Spawned[piece.id])
        Spawned[piece.id] = nil
    end
end)

---------------------------------------------------------------------
-- Panel (right side "Your pieces")
---------------------------------------------------------------------
function OpenFurniturePanel()
    if not CurrentHouse or CurrentPlacement then return end
    local res, err = ServerCall('getFurniture', CurrentHouse.id)
    if type(res) ~= 'table' then
        if err then Notify(err, 'error') end
        return
    end
    panelOpen = true
    SendNUIMessage({
        action = 'furniturePanel', propertyId = CurrentHouse.id, label = CurrentHouse.label,
        pieces = res.pieces, max = res.max,
        static = { locale = CurrentLang(), currency = Config.Currency, furniture = FurnitureCatalog,
                   categories = FurnitureCategories, furnitureImage = Config.Furniture.ImageUrl, sellBack = Config.Furniture.SellBack,
                   furnitureImages = ClientRegistry and ClientRegistry.furnitureImages or {} },
    })
    SetNuiFocus(true, true)
end

local function closePanel()
    panelOpen = false
    SendNUIMessage({ action = 'furniturePanelClose' })
    SetNuiFocus(false, false)
end

function CloseFurnitureMode()
    if CurrentPlacement then CurrentPlacement.cancel = true end
    if panelOpen then closePanel() end
end

RegisterNUICallback('furnitureClose', function(_, cb) cb(1); closePanel() end)

---------------------------------------------------------------------
-- Placement with the camera ray
---------------------------------------------------------------------
local function disableControls()
    for _, c in ipairs({ 14, 15, 16, 17, 24, 25, 37, 44, 45, 140, 141, 142, 172, 173, 174, 175, 177, 178, 191, 200, 261, 262 }) do
        DisableControlAction(0, c, true)
    end
end

local function startPlacement(piece)
    if not CurrentHouse then return end
    local hash = LoadModel(piece.model)
    if not hash then return Notify('Invalid model: ' .. piece.model, 'error') end

    local ped = PlayerPedId()
    local existing = Spawned[piece.id]
    if existing then SetEntityVisible(existing, false, false); SetEntityCollision(existing, false, false) end

    local pc = GetEntityCoords(ped)
    local ghost = CreateObject(hash, pc.x, pc.y, pc.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityCollision(ghost, false, false)
    SetEntityAlpha(ghost, 190, false)
    FreezeEntityPosition(ghost, true)

    CurrentPlacement = piece
    local heading = piece.placed and piece.rz or GetEntityHeading(ped)
    local zOff, snap, lastPos = 0.0, true, nil
    local build = tostring(piece.model):find('^rox_b_') ~= nil   -- ROX build piece: grid snap, 15° steps, no drop to the ground
    if build then heading = math.floor(heading / 15.0 + 0.5) * 15.0 end
    local lastRot = 0
    local result -- 'place' | 'cancel' | 'store'

    SendNUIMessage({ action = 'placeHint', show = true, edit = piece.placed and true or false, label = piece.label })

    while true do
        Wait(0)
        disableControls()
        if piece.cancel then result = 'cancel' break end

        local fast = not IsControlPressed(0, 21) -- hold shift = precise
        local rotStep = fast and 2.5 or 0.5
        local zStep = fast and 0.01 or 0.0025

        if build and fast then
            -- walls / floors: turn in clean 15° steps so pieces line up
            if GetGameTimer() - lastRot > 140 then
                if IsDisabledControlPressed(0, 14) or IsDisabledControlPressed(0, 175) then heading = heading - 15.0; lastRot = GetGameTimer() end
                if IsDisabledControlPressed(0, 15) or IsDisabledControlPressed(0, 174) then heading = heading + 15.0; lastRot = GetGameTimer() end
            end
            zStep = 0.02
        else
            if IsDisabledControlPressed(0, 14) or IsDisabledControlPressed(0, 175) then heading = heading - rotStep * (IsDisabledControlPressed(0, 14) and 4 or 1) end
            if IsDisabledControlPressed(0, 15) or IsDisabledControlPressed(0, 174) then heading = heading + rotStep * (IsDisabledControlPressed(0, 15) and 4 or 1) end
        end
        if IsDisabledControlPressed(0, 172) then zOff = zOff + zStep end
        if IsDisabledControlPressed(0, 173) then zOff = zOff - zStep end
        if IsControlJustPressed(0, 47) then snap = not snap; zOff = 0.0 end -- G

        local hit, coords = CameraRaycast(12.0, ped, 1 + 16)
        if hit then lastPos = coords end
        if lastPos then
            local px, py = lastPos.x, lastPos.y
            if build and snap then px, py = math.floor(px / 0.25 + 0.5) * 0.25, math.floor(py / 0.25 + 0.5) * 0.25 end
            SetEntityCoordsNoOffset(ghost, px, py, lastPos.z + zOff, false, false, false)
            SetEntityRotation(ghost, 0.0, 0.0, heading, 2, true)
            if snap and zOff == 0.0 and not build then PlaceObjectOnGroundProperly(ghost) end
            local c = GetEntityCoords(ghost)
            DrawMarker(25, c.x, c.y, c.z + 0.02, 0, 0, 0, 0, 0, 0, 0.7, 0.7, 0.7, 255, 90, 31, 120, false, false, 2, false)
        end

        if IsDisabledControlJustPressed(0, 191) or IsControlJustPressed(0, 38) then
            if lastPos then result = 'place' break end
        end
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 25) then result = 'cancel' break end
        if piece.placed and IsDisabledControlJustPressed(0, 178) then result = 'store' break end
    end

    SendNUIMessage({ action = 'placeHint', show = false })
    local coords, rot = GetEntityCoords(ghost), GetEntityRotation(ghost, 2)
    DeleteEntity(ghost)
    CurrentPlacement = nil

    if not CurrentHouse then return end
    if result == 'place' then
        local ok, err = ServerCall('placeFurniture', CurrentHouse.id, piece.id,
            { x = coords.x, y = coords.y, z = coords.z }, { x = rot.x, y = rot.y, z = rot.z })
        if not ok then
            if err then Notify(err, 'error') end
            if existing and DoesEntityExist(existing) then SetEntityVisible(existing, true, false); SetEntityCollision(existing, true, true) end
        end
    elseif result == 'store' then
        ServerCall('storeFurniture', CurrentHouse.id, piece.id)
    elseif existing and DoesEntityExist(existing) then
        SetEntityVisible(existing, true, false)
        SetEntityCollision(existing, true, true)
    end

    if not piece.cancel then
        Wait(250)
        if CurrentHouse then OpenFurniturePanel() end
    end
end

RegisterNUICallback('furniturePlace', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or not data.id then return end
    panelOpen = false
    SendNUIMessage({ action = 'furniturePanelClose' })
    SetNuiFocus(false, false)
    CreateThread(function()
        startPlacement({
            id = data.id, model = data.model, label = data.label, placed = data.placed,
            rz = tonumber(data.rz) or 0.0,
        })
    end)
end)

RegisterNUICallback('furnitureStore', function(data, cb)
    CreateThread(function()
        local ok, err = ServerCall('storeFurniture', CurrentHouse and CurrentHouse.id, data.id)
        cb({ ok = ok, err = err })
    end)
end)

RegisterNUICallback('furnitureSell', function(data, cb)
    CreateThread(function()
        local ok, err = ServerCall('sellFurniture', CurrentHouse and CurrentHouse.id, data.id)
        cb({ ok = ok, err = err })
    end)
end)

RegisterNUICallback('furnitureRefresh', function(_, cb)
    CreateThread(function()
        local res = CurrentHouse and ServerCall('getFurniture', CurrentHouse.id)
        cb(type(res) == 'table' and res or { pieces = {} })
    end)
end)
