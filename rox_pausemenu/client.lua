-- ROX Store | All rights reserved
local open = false

local function clock()
    local h, m = GetClockHours(), GetClockMinutes()
    return ('%d:%02d %s'):format((h % 12 == 0) and 12 or h % 12, m, h < 12 and 'am' or 'pm')
end

local function openMenu()
    if open or IsPauseMenuActive() or IsNuiFocused() then return end
    open = true
    local d = lib.callback.await('rox_pausemenu:data', false) or {}
    local c = GetEntityCoords(cache.ped)
    d.server, d.color, d.storeText, d.keys = Config.ServerName, Config.Color, Config.StoreText, Config.Keys
    d.zone = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    d.street = GetStreetNameFromHashKey((GetStreetNameAtCoord(c.x, c.y, c.z)))
    d.waypoint = IsWaypointActive()
    d.time = clock()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = d })
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function closeMenu()
    open = false
    SetNuiFocus(false, false)
end

CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, 200, true)   -- ESC
        DisableControlAction(0, 199, true)   -- P
        if not open and not IsPauseMenuActive() and (IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 199)) then
            openMenu()
        end
    end
end)

-- simple photo studio: free camera + hidden HUD
local function photoStudio()
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', GetGameplayCamCoord(), GetGameplayCamRot(2), 50.0, false, 0)
    SetCamActive(cam, true); RenderScriptCams(true, true, 400, true, false)
    if GetResourceState('rox_hud') == 'started' then pcall(function() exports.rox_hud:SetHidden(true) end) end
    local fov = 50.0
    CreateThread(function()
        while true do
            Wait(0)
            HideHudAndRadarThisFrame(); DisableAllControlActions(0); EnableControlAction(0, 1, true); EnableControlAction(0, 2, true)
            local pos, rot = GetCamCoord(cam), GetCamRot(cam, 2)
            local rx, rz = rot.x - GetDisabledControlNormal(0, 2) * 6.0, rot.z - GetDisabledControlNormal(0, 1) * 6.0
            rx = math.max(-89.0, math.min(89.0, rx))
            local r, p = math.rad(rz), math.rad(rx)
            local fwd = vec3(-math.sin(r) * math.cos(p), math.cos(r) * math.cos(p), math.sin(p))
            local right = vec3(math.cos(r), math.sin(r), 0.0)
            local sp = IsDisabledControlPressed(0, 21) and 0.6 or 0.12
            local mv = vec3(0, 0, 0)
            if IsDisabledControlPressed(0, 32) then mv = mv + fwd end
            if IsDisabledControlPressed(0, 33) then mv = mv - fwd end
            if IsDisabledControlPressed(0, 35) then mv = mv + right end
            if IsDisabledControlPressed(0, 34) then mv = mv - right end
            if IsDisabledControlPressed(0, 38) then mv = mv + vec3(0, 0, 1) end
            if IsDisabledControlPressed(0, 44) then mv = mv - vec3(0, 0, 1) end
            local np = pos + mv * sp
            if #(np - GetEntityCoords(cache.ped)) < 25.0 then pos = np end
            if IsDisabledControlJustPressed(0, 241) then fov = math.max(10.0, fov - 3.0) end
            if IsDisabledControlJustPressed(0, 242) then fov = math.min(90.0, fov + 3.0) end
            SetCamCoord(cam, pos.x, pos.y, pos.z); SetCamRot(cam, rx, 0.0, rz, 2); SetCamFov(cam, fov)
            if IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 177) then break end
        end
        RenderScriptCams(false, true, 400, true, false); DestroyCam(cam, false)
        if GetResourceState('rox_hud') == 'started' then pcall(function() exports.rox_hud:SetHidden(false) end) end
        Wait(300)
    end)
end

RegisterNUICallback('hover', function(_, cb) PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true); cb('ok') end)
RegisterNUICallback('close', function(_, cb) cb('ok'); closeMenu() end)
RegisterNUICallback('action', function(d, cb)
    cb('ok')
    local a = d and d.action
    if a == 'clearwp' then SetWaypointOff(); return end
    closeMenu()
    if a == 'map' then
        if GetResourceState('rox_map') == 'started' then exports.rox_map:open()
        else ActivateFrontendMenu(`FE_MENU_VERSION_MP_PAUSE`, false, -1) end
    elseif a == 'map3d' then
        if GetResourceState('zerodream_3dmap') == 'started' then ExecuteCommand('+3dmap') end
    elseif a == 'settings' then
        if GetResourceState('rox_settings') == 'started' then exports.rox_settings:open() end
    elseif a == 'hud' then ExecuteCommand('hud')
    elseif a == 'keybinds' or a == 'gtasettings' then ActivateFrontendMenu(`FE_MENU_VERSION_LANDING_MENU`, false, -1)
    elseif a == 'store' then
        lib.notify({ description = Config.StoreUrl, duration = 8000 }); lib.setClipboard(Config.StoreUrl)
    elseif a == 'photo' then photoStudio()
    elseif a == 'quit' then TriggerServerEvent('rox_pausemenu:quit') end
end)

exports('open', openMenu)
