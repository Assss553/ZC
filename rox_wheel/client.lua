-- ROX Store | All rights reserved
-- ROX Wheel: weapons + items wheel on top of ox_inventory
local isOpen = false

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
    local slot = tonumber(d and d.slot)
    if slot == nil then return end
    if slot == 0 then                                                   -- fist: holster
        TriggerEvent('ox_inventory:disarm', false)
    else
        exports.ox_inventory:useSlot(slot)
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
