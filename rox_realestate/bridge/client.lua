--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

-- Re-sync the property list once the character is loaded
local function loaded()
    SetTimeout(1500, function()
        if ClientLang then TriggerServerEvent('rox_re:setLang', ClientLang) end
        TriggerServerEvent('rox_re:requestSync')
    end)
end

RegisterNetEvent('esx:playerLoaded', loaded)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', loaded)
RegisterNetEvent('qbx_core:client:playerLoaded', loaded)

-- job changes can unlock / lock the realtor apps
RegisterNetEvent('esx:setJob', function() TriggerServerEvent('rox_re:requestSync') end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function() TriggerServerEvent('rox_re:requestSync') end)

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then loaded() end
end)
