-- ROX Store | All rights reserved
-- ROX Wheel: weapons + items wheel on top of ox_inventory
local isOpen = false
local saved = {}   -- removed clothing: hat / glasses / mask

local function gearState()
    local ped = cache.ped
    local hat = GetPedPropIndex(ped, 0) ~= -1
    local glasses = GetPedPropIndex(ped, 1) ~= -1
    local mask = GetPedDrawableVariation(ped, 1) ~= 0
    local res = 'nui://' .. GetCurrentResourceName() .. '/html/gear/'
    return {
        { name = 'gear_glasses', label = 'Glasses', slot = 'gear:glasses', toggle = true, on = glasses or saved.glasses ~= nil and false, has = glasses or saved.glasses ~= nil, image = res .. 'glasses.png' },
        { name = 'gear_hat', label = 'Hat', slot = 'gear:hat', toggle = true, on = hat, has = hat or saved.hat ~= nil, image = res .. 'hat.png' },
        { name = 'gear_mask', label = 'Mask', slot = 'gear:mask', toggle = true, on = mask, has = mask or saved.mask ~= nil, image = res .. 'mask.png' },
        { name = 'gear_outfit', label = (hat or glasses or mask) and 'Take off all' or 'Put back on', slot = 'gear:all', active = (hat or glasses or mask), image = res .. 'outfit.png' },
    }
end

local function anim(dict, clip, ms)
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, clip, 6.0, -6.0, ms, 49, 0, false, false, false)
    Wait(ms - 300)
end

local function toggleGear(what)
    local ped = cache.ped
    if what == 'hat' then
        if GetPedPropIndex(ped, 0) ~= -1 then
            saved.hat = { GetPedPropIndex(ped, 0), GetPedPropTextureIndex(ped, 0) }
            anim('missheist_agency2ahelmet', 'take_off_helmet_stand', 1200); ClearPedProp(ped, 0)
        elseif saved.hat then
            anim('mp_masks@standard_car@ds@', 'put_on_mask', 800); SetPedPropIndex(ped, 0, saved.hat[1], saved.hat[2], true); saved.hat = nil
        end
    elseif what == 'glasses' then
        if GetPedPropIndex(ped, 1) ~= -1 then
            saved.glasses = { GetPedPropIndex(ped, 1), GetPedPropTextureIndex(ped, 1) }
            anim('clothingspecs', 'take_off', 1200); ClearPedProp(ped, 1)
        elseif saved.glasses then
            anim('clothingspecs', 'put_on', 1200); SetPedPropIndex(ped, 1, saved.glasses[1], saved.glasses[2], true); saved.glasses = nil
        end
    elseif what == 'mask' then
        if GetPedDrawableVariation(ped, 1) ~= 0 then
            saved.mask = { GetPedDrawableVariation(ped, 1), GetPedTextureVariation(ped, 1) }
            anim('mp_masks@standard_car@ds@', 'put_on_mask', 800); SetPedComponentVariation(ped, 1, 0, 0, 0)
        elseif saved.mask then
            anim('mp_masks@standard_car@ds@', 'put_on_mask', 800); SetPedComponentVariation(ped, 1, saved.mask[1], saved.mask[2], 0); saved.mask = nil
        end
    elseif what == 'all' then
        local wearing = GetPedPropIndex(ped, 0) ~= -1 or GetPedPropIndex(ped, 1) ~= -1 or GetPedDrawableVariation(ped, 1) ~= 0
        for _, k in ipairs({ 'hat', 'glasses', 'mask' }) do
            local on = (k == 'hat' and GetPedPropIndex(ped, 0) ~= -1) or (k == 'glasses' and GetPedPropIndex(ped, 1) ~= -1) or (k == 'mask' and GetPedDrawableVariation(ped, 1) ~= 0)
            if wearing == on then toggleGear(k) end
        end
    end
end

local function weaponStats(name, hash, cat, it)
    local base = Config.ClassStats[cat] or {}
    local o = Config.WeaponStats[name] or {}
    local dmg = GetWeaponDamage(hash, 0) or 0
    local comps = it.metadata and it.metadata.components
    return { type = o.type or base.type, damage = o.damage or math.min(100, dmg * (cat == 4 and 0.6 or 1.6)),
             accuracy = o.accuracy or base.accuracy or 50, handling = o.handling or base.handling or 50, range = o.range or base.range or 50,
             mods = comps and #comps or 0, maxMods = o.maxMods or 5 }
end

local function buildData()
    local weapons, items = {}, {}
    for i = 1, 8 do weapons[i] = {}; items[i] = {} end
    weapons[1][1] = { name = 'WEAPON_UNARMED', label = 'Fist', slot = 0, count = 1 }

    local inv = exports.ox_inventory:GetPlayerItems() or {}
    for _, it in pairs(inv) do
        local name = it.name
        local entry = { name = name, label = (it.metadata and it.metadata.label) or it.label or name, slot = it.slot, count = it.count,
                        weight = it.weight, durability = it.metadata and it.metadata.durability,
                        image = it.metadata and it.metadata.imageurl or nil }
        if name:sub(1, 7) == 'WEAPON_' then
            local hash = joaat(name)
            local cat = Config.WeaponGroups[GetWeapontypeGroup(hash)]
            if cat then
                entry.stats = weaponStats(name, hash, cat, it)
                if GetResourceState('rox_weaponhud') == 'started' and not entry.image then
                    entry.image = 'nui://rox_weaponhud/html/icons/' .. name .. '.png'
                end
                entry.ammo = it.metadata and it.metadata.ammo
                if entry.ammo then
                    local ammoType = GetPedAmmoTypeFromWeapon(cache.ped, hash)
                    entry.ammoTotal = 0
                    for _, a in pairs(inv) do
                        if a.name:sub(1, 4) == 'ammo' and joaat(a.name:gsub('ammo%-', 'AMMO_'):upper()) == ammoType then entry.ammoTotal = a.count end
                    end
                end
                local list = weapons[cat]; list[#list + 1] = entry
            elseif Config.ItemCats[name] then
                local list = items[Config.ItemCats[name]]; list[#list + 1] = entry
            end
        else
            local cat = Config.ItemCats[name] or (name:sub(1, 4) == 'ammo' and 8) or nil
            if cat then local list = items[cat]; list[#list + 1] = entry end
        end
    end
    local gear = {}
    for _, g in ipairs(gearState()) do if g.has ~= false then gear[#gear + 1] = g end end
    for _, g in ipairs(gear) do items[7][#items[7] + 1] = g end
    return { weapons = weapons, items = items }
end

local function currentWeaponName()
    local w = GetSelectedPedWeapon(cache.ped)
    if w == `WEAPON_UNARMED` then return 'WEAPON_UNARMED' end
    for _, it in pairs(exports.ox_inventory:GetPlayerItems() or {}) do
        if it.name:sub(1, 7) == 'WEAPON_' and joaat(it.name) == w then return it.name end
    end
end

local function open()
    if isOpen or IsPauseMenuActive() or IsNuiFocused() or IsEntityDead(cache.ped) then return end
    if LocalPlayer.state.invBusy then return end
    isOpen = true
    SetNuiFocus(true, true); SetNuiFocusKeepInput(true)
    SendNUIMessage({ action = 'open', data = buildData(), imagepath = Config.ImagePath, equipped = currentWeaponName() })
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    CreateThread(function()
        while isOpen do
            -- keep walking, block camera + shooting while the wheel is open
            DisableControlAction(0, 1, true); DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true); DisableControlAction(0, 37, true)
            DisableControlAction(0, 14, true); DisableControlAction(0, 15, true); DisableControlAction(0, 16, true); DisableControlAction(0, 17, true)
            DisableControlAction(0, 44, true); DisableControlAction(0, 38, true)                -- Q / E (tab switch in the NUI)
            Wait(0)
        end
    end)
end

local function close()
    if not isOpen then return end
    SendNUIMessage({ action = 'close', confirm = true })
end

RegisterNUICallback('close', function(d, cb)
    cb('ok')
    isOpen = false
    SetNuiFocusKeepInput(false); SetNuiFocus(false, false)
    if type(d and d.slot) == 'string' and d.slot:sub(1, 5) == 'gear:' then
        CreateThread(function() toggleGear(d.slot:sub(6)) end)
        return
    end
    local slot = tonumber(d and d.slot)
    if slot == nil then return end
    if slot == 0 then                                                   -- fist: holster
        TriggerEvent('ox_inventory:disarm', false)
        SendNUIMessage({ action = 'equipToast', label = 'Unarmed', key = Config.Key })
    else
        local it = exports.ox_inventory:GetSlot(slot)
        exports.ox_inventory:useSlot(slot)
        if it then SendNUIMessage({ action = 'equipToast', label = (it.metadata and it.metadata.label) or it.label or it.name, key = Config.Key }) end
    end
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end)
RegisterNUICallback('hover', function(_, cb) PlaySoundFrontend(-1, 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true); cb('ok') end)

RegisterCommand('+roxwheel', open, false)
RegisterCommand('-roxwheel', close, false)
RegisterKeyMapping('+roxwheel', 'ROX weapon / item wheel (hold)', 'keyboard', Config.Key)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() and isOpen then SetNuiFocusKeepInput(false); SetNuiFocus(false, false) end
end)
