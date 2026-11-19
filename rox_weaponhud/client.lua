-- ROX Store | All rights reserved
-- Minimal weapon HUD (top right): clip  reserve  + weapon image. Shows while aiming / shooting / reloading.
local Config = {
    ImagePath = 'nui://ox_inventory/web/images/',
    ShowFor   = 4000,     -- ms the HUD stays after the last shot / aim
    HideGTA   = true,     -- hide GTA's own weapon icon + ammo
}

local lastActive, visible, last = 0, false, {}

local function weaponName(hash)
    if GetResourceState('ox_inventory') == 'started' then
        local w = exports.ox_inventory:getCurrentWeapon()
        if w and w.name then return w.name end
    end
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local armed, hash = GetCurrentPedWeapon(ped, true)
        local sleep = 250
        if armed and hash ~= `WEAPON_UNARMED` then
            sleep = 50
            local now = GetGameTimer()
            if IsPlayerFreeAiming(PlayerId()) or IsPedShooting(ped) or IsPedReloading(ped) or IsControlPressed(0, 25) then lastActive = now end
            local show = now - lastActive < Config.ShowFor
            local _, clip = GetAmmoInClip(ped, hash)
            local total = GetAmmoInPedWeapon(ped, hash)
            local maxClip = GetMaxAmmoInClip(ped, hash, true)
            local melee = GetWeaponDamageType(hash) == 2 or maxClip <= 0
            local name = weaponName(hash)
            local d = { action = 'weapon', show = show, clip = clip, reserve = math.max(0, total - clip), maxClip = maxClip,
                        melee = melee, infinite = total > 9000, reloading = IsPedReloading(ped),
                        image = name and (Config.ImagePath .. name .. '.png') or nil }
            if d.show ~= last.show or d.clip ~= last.clip or d.reserve ~= last.reserve or d.reloading ~= last.reloading or d.image ~= last.image then
                SendNUIMessage(d); last = d
            end
            if Config.HideGTA then HideHudComponentThisFrame(2); HideHudComponentThisFrame(20) end
            if Config.HideGTA then sleep = 0 end
        elseif last.show then
            last = { show = false }; SendNUIMessage({ action = 'weapon', show = false })
        end
        Wait(sleep)
    end
end)
