-- ROX Store | All rights reserved. Owner: ROX Store
local state = nil            -- { role = 'carrier'|'carried', other = serverId, mode = 'carry'|'drag' }
local KH = function() return GetResourceState('rox_keyhints') == 'started' end
local function msg(t, kind)
    if GetResourceState('ox_lib') == 'started' then exports.ox_lib:notify({ description = t, type = kind or 'inform' })
    else BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(t); EndTextCommandThefeedPostTicker(false, false) end
end
RegisterNetEvent('rox_radial:carry:msg', msg)

local function loadDict(d) RequestAnimDict(d); local t = GetGameTimer() + 3000; while not HasAnimDictLoaded(d) and GetGameTimer() < t do Wait(10) end return HasAnimDictLoaded(d) end

local function closestPlayer(maxD, inVehicle)
    local me, best, bd = GetEntityCoords(PlayerPedId()), nil, maxD
    for _, id in ipairs(GetActivePlayers()) do
        if id ~= PlayerId() then
            local ped = GetPlayerPed(id)
            if (inVehicle == nil) or (IsPedInAnyVehicle(ped, false) == inVehicle) then
                local d = #(GetEntityCoords(ped) - me); if d < bd then best, bd = id, d end
            end
        end
    end
    return best and GetPlayerServerId(best)
end

local function helpless()
    local ped, st = PlayerPedId(), LocalPlayer.state
    return IsEntityDead(ped) or IsPedCuffed(ped) or st.isDead or st.dead or st.isHandcuffed or st.handcuffed or st.inLaststand
end

-- ---------------------------------------------------------------- consent prompt
RegisterNetEvent('rox_radial:carry:ask', function(from, mode)
    if helpless() then return TriggerServerEvent('rox_radial:carry:answer', from, true) end
    local label = ({ carry = 'wants to carry you', drag = 'wants to drag you', takeout = 'wants to take you out of the vehicle' })[mode] or mode
    if KH() then exports.rox_keyhints:Show('carryask', { { keys = { 'Y' }, label = 'Accept' }, { keys = { 'N' }, label = 'Decline' } }, 'Player ' .. from .. ' ' .. label)
    else msg(('Player %s %s · Y accept / N decline'):format(from, label)) end
    local untilT, answer = GetGameTimer() + 10000, false
    while GetGameTimer() < untilT do
        if IsControlJustPressed(0, 246) then answer = true break end      -- Y
        if IsControlJustPressed(0, 249) then break end                    -- N
        Wait(0)
    end
    if KH() then exports.rox_keyhints:Hide('carryask') end
    TriggerServerEvent('rox_radial:carry:answer', from, answer)
end)

-- ---------------------------------------------------------------- start / stop
local ANIM = {
    carry = { carrier = { 'missfinale_c2mcs_1', 'fin_c2_mcs_1_camman', 49 }, carried = { 'nm', 'firemans_carry', 33 },
              bone = 0, off = vec3(0.27, 0.15, 0.63), rot = vec3(0.0, 0.0, 0.0) },
    drag  = { carrier = nil, carried = nil, bone = 11816, off = vec3(0.45, 0.45, 0.0), rot = vec3(0.0, 0.0, 0.0) },
}

local function stopLocal()
    if not state then return end
    local ped = PlayerPedId()
    DetachEntity(ped, true, false); ClearPedTasks(ped)
    if KH() then exports.rox_keyhints:Hide('carry') end
    state = nil
end
RegisterNetEvent('rox_radial:carry:stop', stopLocal)

RegisterNetEvent('rox_radial:carry:start', function(role, other, mode)
    state = { role = role, other = other, mode = mode }
    local A = ANIM[mode]
    if KH() then
        if role == 'carrier' then
            exports.rox_keyhints:Show('carry', { { keys = { 'X' }, label = 'Let go' }, { keys = { '/putin' }, label = 'Put in vehicle' } }, mode == 'carry' and 'Carrying' or 'Dragging')
        else
            exports.rox_keyhints:Show('carry', { { keys = { 'X' }, label = 'Get free' } }, mode == 'carry' and 'Being carried' or 'Being dragged')
        end
    end
    CreateThread(function()
        while state and state.role == role do
            local ped = PlayerPedId()
            local otherPed = GetPlayerPed(GetPlayerFromServerId(other))
            if otherPed == 0 or not DoesEntityExist(otherPed) then TriggerServerEvent('rox_radial:carry:stop'); stopLocal(); break end
            local a = A[role]
            if a and not IsEntityPlayingAnim(ped, a[1], a[2], 3) and loadDict(a[1]) then
                TaskPlayAnim(ped, a[1], a[2], 8.0, -8.0, -1, a[3], 0, false, false, false)
            end
            if role == 'carried' and not IsEntityAttachedToEntity(ped, otherPed) then
                AttachEntityToEntity(ped, otherPed, A.bone == 0 and 0 or GetPedBoneIndex(otherPed, A.bone), A.off.x, A.off.y, A.off.z,
                    A.rot.x, A.rot.y, A.rot.z, false, false, false, false, 2, true)
            end
            if role == 'carrier' then DisableControlAction(0, 21, mode == 'carry'); DisableControlAction(0, 22, true); DisableControlAction(0, 24, true) end
            if role == 'carried' then DisableControlAction(0, 22, true); DisableControlAction(0, 24, true) end
            if IsControlJustPressed(0, 73) then TriggerServerEvent('rox_radial:carry:stop') end       -- X
            Wait(0)
        end
    end)
end)

-- ---------------------------------------------------------------- vehicle
local function nearestVehicle(maxD)
    local me = GetEntityCoords(PlayerPedId())
    local best, bd = nil, maxD
    for _, v in ipairs(GetGamePool('CVehicle')) do local d = #(GetEntityCoords(v) - me); if d < bd then best, bd = v, d end end
    return best
end

local function putIn()
    if not state or state.role ~= 'carrier' then return msg('You are not carrying or dragging anyone', 'error') end
    local veh = nearestVehicle(5.0); if not veh then return msg('No vehicle nearby', 'error') end
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    for _, s in ipairs({ 1, 2, 0 }) do             -- back seats first, then passenger
        if s <= seats - 2 and IsVehicleSeatFree(veh, s) then
            return TriggerServerEvent('rox_radial:carry:putin', NetworkGetNetworkIdFromEntity(veh), s)
        end
    end
    msg('No free seat', 'error')
end

RegisterNetEvent('rox_radial:carry:seat', function(netId, seat)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 then return end
    local ped = PlayerPedId(); DetachEntity(ped, true, false); ClearPedTasksImmediately(ped)
    TaskWarpPedIntoVehicle(ped, veh, seat)
end)

RegisterNetEvent('rox_radial:carry:leaveVehicle', function()
    local ped = PlayerPedId(); local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then TaskLeaveVehicle(ped, veh, 16) end
end)

local function takeOut()
    local veh = nearestVehicle(5.0); if not veh then return msg('No vehicle nearby', 'error') end
    for s = -1, GetVehicleModelNumberOfSeats(GetEntityModel(veh)) - 2 do
        local p = GetPedInVehicleSeat(veh, s)
        if p ~= 0 and IsPedAPlayer(p) and p ~= PlayerPedId() then
            local id = NetworkGetPlayerIndexFromPed(p)
            return TriggerServerEvent('rox_radial:carry:request', GetPlayerServerId(id), 'takeout')
        end
    end
    msg('Nobody in that vehicle', 'error')
end

-- ---------------------------------------------------------------- radial actions
RegisterNetEvent('rox_radial:client:carry', function(args)
    local a = args and args.action
    if a == 'stop' then return TriggerServerEvent('rox_radial:carry:stop') end
    if a == 'putin' then return putIn() end
    if a == 'takeout' then return takeOut() end
    if a == 'carry' or a == 'drag' then
        if state then return msg('Already busy', 'error') end
        if IsPedInAnyVehicle(PlayerPedId(), false) then return msg('Not possible in a vehicle', 'error') end
        local t = closestPlayer(3.0, false); if not t then return msg('No one close to you', 'error') end
        TriggerServerEvent('rox_radial:carry:request', t, a); msg('Request sent')
    end
end)
RegisterCommand('carry', function() TriggerEvent('rox_radial:client:carry', { action = 'carry' }) end, false)
RegisterCommand('drag', function() TriggerEvent('rox_radial:client:carry', { action = 'drag' }) end, false)

-- ---------------------------------------------------------------- radio (pma-voice)
local radioOn, radioCh = false, 0
RegisterNetEvent('rox_radial:client:radio', function(args)
    if GetResourceState('pma-voice') ~= 'started' then return msg('pma-voice is not running', 'error') end
    local pv = exports['pma-voice']
    if args and args.power then
        radioOn = not radioOn
        pv:setVoiceProperty('radioEnabled', radioOn)
        if not radioOn then pv:setRadioChannel(0); radioCh = 0 end
        return msg(radioOn and 'Radio ON' or 'Radio OFF')
    end
    local ch = tonumber(args and args.channel)
    if not ch or ch < 1 or ch > 10 then return end
    if not radioOn then radioOn = true; pv:setVoiceProperty('radioEnabled', true) end
    pv:setRadioChannel(ch); radioCh = ch
    msg(('Radio channel %d'):format(ch), 'success')
end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then stopLocal() end end)
RegisterCommand('putin', putIn, false)
RegisterCommand('takeout', takeOut, false)
