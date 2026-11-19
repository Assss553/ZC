-- ROX Store | All rights reserved
-- Next-gen trunk: [E] Open Trunk prompt at the rear, lean-in animation, shoulder camera, [X] Close.
-- Uses ox_inventory's trunk inventory (same items / weights / permissions).
local Config = { Key = 38, CloseKey = 73, Distance = 1.6, Camera = true }

local function rearOf(veh)
    local min, max = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, min.y - 0.3, 0.0), min, max
end

local function canUse(veh)
    if veh == 0 or IsPedInAnyVehicle(PlayerPedId(), false) or IsEntityDead(veh) then return false end
    local cls = GetVehicleClass(veh)
    if cls == 8 or cls == 13 or cls == 14 or cls == 15 or cls == 16 or cls == 21 then return false end
    if GetVehicleDoorLockStatus(veh) >= 2 then return false end
    return GetIsDoorValid(veh, 5) or GetIsDoorValid(veh, 2)
end

local function door(veh) return GetIsDoorValid(veh, 5) and 5 or 2 end

local cam
local function startCam(veh)
    if not Config.Camera then return end
    local ped = PlayerPedId()
    local p = GetOffsetFromEntityInWorldCoords(ped, 0.55, -0.9, 0.75)
    local look = rearOf(veh)
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, 0.0, 0.0, 0.0, 55.0, false, 0)
    PointCamAtCoord(cam, look.x, look.y, look.z + 0.35)
    SetCamActive(cam, true); RenderScriptCams(true, true, 600, true, false)
end
local function stopCam()
    if cam then RenderScriptCams(false, true, 600, true, false); DestroyCam(cam, false); cam = nil end
end

local busy = false
local function openTrunk(veh)
    if busy then return end
    busy = true
    local ped = PlayerPedId()
    local rear = rearOf(veh)
    TaskTurnPedToFaceCoord(ped, rear.x, rear.y, rear.z, 600); Wait(600)
    local d = door(veh)
    SetVehicleDoorOpen(veh, d, false, false)
    lib.requestAnimDict('anim@heists@prison_heiststation@cop_reactions')
    TaskPlayAnim(ped, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 4.0, -4.0, -1, 1, 0, false, false, false)
    startCam(veh)
    local ok = exports.ox_inventory:openInventory('trunk', { netid = NetworkGetNetworkIdFromEntity(veh), entityid = veh, door = d })
    if ok == false then stopCam(); ClearPedTasks(ped); SetVehicleDoorShut(veh, d, false); busy = false; return end
    Wait(500)
    CreateThread(function()
        while busy do
            if not LocalPlayer.state.invOpen then
                -- inventory closed: keep standing at the trunk with a CLOSE prompt (like the reference)
                if GetResourceState('rox_interact') == 'started' then exports.rox_interact:Prompt('Close', 'X') end
                if IsControlJustPressed(0, Config.CloseKey) or #(GetEntityCoords(PlayerPedId()) - rearOf(veh)) > 2.5 then break end
                if IsControlJustPressed(0, Config.Key) then
                    exports.ox_inventory:openInventory('trunk', { netid = NetworkGetNetworkIdFromEntity(veh), entityid = veh, door = d })
                    if GetResourceState('rox_interact') == 'started' then exports.rox_interact:Prompt(nil) end
                    Wait(400)
                end
            end
            Wait(0)
        end
        if GetResourceState('rox_interact') == 'started' then exports.rox_interact:Prompt(nil) end
        stopCam(); StopAnimTask(PlayerPedId(), 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 2.0)
        SetVehicleDoorShut(veh, d, false)
        PlaySoundFromEntity(-1, 'Trunk_Close', veh, 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', false, 0)
        busy = false
    end)
end

-- proximity prompt
CreateThread(function()
    local shown = false
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local veh = not busy and lib.getClosestVehicle(GetEntityCoords(ped), 5.0, false)
        local near = false
        if veh and canUse(veh) and #(GetEntityCoords(ped) - rearOf(veh)) < Config.Distance then
            near, sleep = true, 0
            if IsControlJustReleased(0, Config.Key) then openTrunk(veh) end
        end
        if near ~= shown and GetResourceState('rox_interact') == 'started' then
            exports.rox_interact:Prompt(near and 'Open Trunk' or nil, 'E'); shown = near
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then stopCam() end end)
