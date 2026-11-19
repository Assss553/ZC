-- ROX Store | All rights reserved
local open = false

CreateThread(function()
    for _, c in ipairs(Config.Locations) do
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, Config.Blip.sprite); SetBlipColour(b, Config.Blip.color); SetBlipScale(b, 0.75); SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.Blip.label); EndTextCommandSetBlipName(b)
    end
end)

local function openShop()
    if open then return end
    local w = lib.callback.await('rox_gunstore:wallet', false) or {}
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', name = Config.Name, shop = Config.Shop, tints = Config.Tints, wallet = w,
                     img = Config.ImagePath, hires = Config.HiResPath, license = Config.LicenseFor })
end

-- proximity prompt
CreateThread(function()
    local shown = false
    while true do
        local sleep, near = 800, false
        local p = GetEntityCoords(cache.ped)
        for _, c in ipairs(Config.Locations) do
            local d = #(p - c)
            if d < 15.0 then sleep = 0 end
            if d < 2.0 then near = true end
        end
        if near and not open then
            if not shown then
                shown = true
                if GetResourceState('rox_keyhints') == 'started' then exports.rox_keyhints:Show('gunstore', { { keys = { 'E' }, label = 'Browse weapons' } }) end
            end
            if IsControlJustReleased(0, 38) then openShop() end
        elseif shown then
            shown = false
            if GetResourceState('rox_keyhints') == 'started' then exports.rox_keyhints:Hide('gunstore') end
        end
        Wait(sleep)
    end
end)

RegisterNUICallback('buy', function(d, cb)
    local ok, err, wallet = lib.callback.await('rox_gunstore:buy', false, d.name, d.tint)
    if ok then PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true) else PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
    cb({ ok = ok, err = err, wallet = wallet })
end)
RegisterNUICallback('nav', function(_, cb) PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true); cb('ok') end)
RegisterNUICallback('close', function(_, cb) open = false; SetNuiFocus(false, false); cb('ok') end)
