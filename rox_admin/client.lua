-- ROX Store | rox_admin | All rights reserved.
local open, me = false, nil
local function call(name, args) return lib.callback.await('rox_admin:call', false, name, args) end

local function loadKeys()
    local raw = GetResourceKvpString('rox_admin_keys')
    return raw and json.decode(raw) or {}
end

local function toggle(state)
    if state == nil then state = not open end
    if state then
        me = call('me')
        if not me or not me.rank then return lib.notify({ type = 'error', description = 'No access' }) end
        me.keys = loadKeys()
    end
    open = state
    SetNuiFocus(state, state)
    SendNUIMessage({ action = 'open', open = state, me = me })
end

RegisterCommand(Config.OpenCommand, function() toggle() end, false)
RegisterKeyMapping(Config.OpenCommand, 'ROX Admin panel', 'keyboard', Config.OpenKey)

RegisterNUICallback('close', function(_, cb) toggle(false) cb(1) end)
RegisterNUICallback('call', function(d, cb) cb(call(d.name, d.args) or false) end)
RegisterNUICallback('myCoords', function(_, cb)
    local p = PlayerPedId(); local c, r = GetEntityCoords(p), GetEntityRotation(p, 2)
    local s = GetStreetNameFromHashKey(GetStreetNameAtCoord(c.x, c.y, c.z))
    cb({ x = c.x, y = c.y, z = c.z, h = GetEntityHeading(p), rx = r.x, ry = r.y, rz = r.z, street = s, zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z)) })
end)
RegisterNUICallback('waypoint', function(d, cb) SetNewWaypoint(d.x + 0.0, d.y + 0.0) cb(1) end)
RegisterNUICallback('saveKeys', function(d, cb) SetResourceKvp('rox_admin_keys', json.encode(d.keys or {})) if me then me.keys = d.keys end cb(1) end)

RegisterNetEvent('rox_admin:client:refreshMe', function() if open then me = call('me'); me.keys = loadKeys(); SendNUIMessage({ action = 'me', me = me }) end end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() TriggerServerEvent('rox_admin:server:charLoaded') end)

RegisterNetEvent('rox_admin:client:tp', function(x, y, z, h)
    local p = PlayerPedId(); local ent = IsPedInAnyVehicle(p, false) and GetVehiclePedIsIn(p, false) or p
    DoScreenFadeOut(250) while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(x, y, z)
    local tries = 0
    SetEntityCoords(ent, x, y, z, false, false, false, false)
    while not HasCollisionLoadedAroundEntity(ent) and tries < 100 do Wait(10) tries += 1 end
    if z < 1.0 then local ok, gz = GetGroundZFor_3dCoord(x, y, 1000.0, false); if ok then SetEntityCoords(ent, x, y, gz, false, false, false, false) end end
    if h then SetEntityHeading(ent, h + 0.0) end
    DoScreenFadeIn(250)
end)

---------------------------------------------------------------- admin shortcuts (custom keybinds)
local KEYS = { F1 = 288, F2 = 289, F3 = 170, F5 = 166, F6 = 167, F7 = 168, F9 = 56, F10 = 57, F11 = 344, HOME = 213, INSERT = 121, DELETE = 178,
    PAGEUP = 10, PAGEDOWN = 11, ['NUM4'] = 108, ['NUM5'] = 110, ['NUM6'] = 107, ['NUM7'] = 117, ['NUM8'] = 111, ['NUM9'] = 118, Z = 20, X = 73, G = 47, H = 74, K = 311, L = 182, U = 303, Y = 246, N = 249, B = 29 }
local noclip = false
local actions = {
    open = function() toggle() end,
    tpm = function()
        local b = GetFirstBlipInfoId(8); if not DoesBlipExist(b) then return lib.notify({ type = 'error', description = 'No waypoint' }) end
        local c = GetBlipInfoIdCoord(b); call('teleport', { x = c.x, y = c.y, z = 0.0 })
    end,
    coords = function()
        local c, h = GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId())
        local s = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h)
        SendNUIMessage({ action = 'clip', text = s }); lib.notify({ description = 'Copied: ' .. s })
    end,
    revive = function() if lib.callback.await('rox_admin:call', false, 'revive', { id = GetPlayerServerId(PlayerId()) }) then lib.notify({ description = 'Revived' }) end end,
    noclip = function()
        if not lib.callback.await('rox_admin:can', false, 'teleport') then return end
        noclip = not noclip
        local p = PlayerPedId(); SetEntityInvincible(p, noclip); SetEntityVisible(p, not noclip, false); SetEntityCollision(p, not noclip, not noclip); FreezeEntityPosition(p, noclip)
    end,
}
CreateThread(function()
    while true do
        local sleep = 500
        if me and me.keys and not open then
            sleep = 0
            for act, key in pairs(me.keys) do
                if act ~= 'open' and key ~= '' and KEYS[key] and IsControlJustPressed(0, KEYS[key]) and actions[act] then actions[act]() end
            end
        end
        if noclip then
            sleep = 0
            local p = PlayerPedId(); local c = GetEntityCoords(p); local f = GetEntityForwardVector(p)
            local sp = IsControlPressed(0, 21) and 3.0 or 0.8
            SetEntityHeading(p, GetGameplayCamRot(2).z)
            if IsControlPressed(0, 32) then c = c + f * sp end
            if IsControlPressed(0, 33) then c = c - f * sp end
            if IsControlPressed(0, 22) then c = c + vector3(0, 0, sp) end
            if IsControlPressed(0, 36) then c = c - vector3(0, 0, sp) end
            SetEntityCoordsNoOffset(p, c.x, c.y, c.z, true, true, true)
        end
        Wait(sleep)
    end
end)
-- load keys for staff on spawn so shortcuts work without opening the panel first
CreateThread(function() Wait(5000) local m = call('me'); if m and m.rank then me = m; me.keys = loadKeys() end end)
