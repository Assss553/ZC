--[[ ROX Store | rox_police | All rights reserved. ]]
local jail = nil   -- { type, remaining, life, total, charges, bail }

local function tp(v)
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    Wait(450)
    RequestCollisionAtCoord(v.x, v.y, v.z)
    SetEntityCoords(ped, v.x, v.y, v.z, false, false, false, false)
    SetEntityHeading(ped, v.w or 0.0)
    Wait(300)
    DoScreenFadeIn(500)
end

RegisterNetEvent('rox_police:client:jailed', function(data)
    local t = Config.Jail.types[data.type] or Config.Jail.types.prison
    local first = jail == nil
    jail = data
    jail.cfg = t
    if first then
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) Wait(800) end
        RemoveAllPedWeapons(ped, true)
        tp(t.inside)
    end
    SendNUIMessage({ action = 'jailHud', show = true, data = { remaining = jail.remaining, life = jail.life, total = jail.total, label = t.label, bail = jail.bail, paybail = Config.Commands.paybail } })
end)

RegisterNetEvent('rox_police:client:released', function(typeKey)
    local t = (jail and jail.cfg) or Config.Jail.types[typeKey] or Config.Jail.types.prison
    jail = nil
    SendNUIMessage({ action = 'jailHud', show = false })
    tp(t.release)
end)

-- keep the prisoner inside + local countdown
CreateThread(function()
    while true do
        if jail then
            local ped = PlayerPedId()
            local c = jail.cfg.inside
            if #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) > jail.cfg.radius then
                tp(c)
            end
            if not jail.life and jail.remaining > 0 then jail.remaining = jail.remaining - 1 end
            DisableControlAction(0, 24, true)
            Wait(1000)
        else
            Wait(2000)
        end
    end
end)

-- ask the server if we are still in prison after (re)joining
local function checkIn() TriggerServerEvent('rox_police:server:checkIn') end
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() Wait(2000) checkIn() end)
RegisterNetEvent('qbx_core:client:playerLoaded', function() Wait(2000) checkIn() end)
RegisterNetEvent('esx:playerLoaded', function() Wait(2000) checkIn() end)
AddEventHandler('onClientResourceStart', function(r) if r == GetCurrentResourceName() then Wait(1500) checkIn() end end)
