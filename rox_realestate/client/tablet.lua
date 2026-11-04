--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

local tabletOpen = false
local tabletProp
local contractOpen = false

ClientRegistry = nil   -- detected interiors + pictures (from the server)

RegisterNetEvent('rox_re:registry', function(reg)
    ClientRegistry = reg
    SendNUIMessage({ action = 'registry', static = { interiors = UIInteriors(), furnitureImages = reg.furnitureImages } })
end)

-- interior list with a client-side check that each shell is really streamed
function UIInteriors()
    local list = (ClientRegistry and ClientRegistry.interiors) or InteriorsForUI()
    local out = {}
    for _, i in ipairs(list) do
        local copy = {}
        for k, v in pairs(i) do copy[k] = v end
        if i.shell then copy.available = IsModelInCdimage(joaat(i.shell)) and true or false end
        if copy.available ~= false or not i.auto then out[#out + 1] = copy end -- hide detected-but-missing
    end
    return out
end

local function staticData()
    return {
        locale = CurrentLang(), defaultLocale = Config.Locale, currency = Config.Currency, interiors = UIInteriors(),
        furnitureImages = ClientRegistry and ClientRegistry.furnitureImages or {},
        wallpaper = Config.Tablet.DefaultWallpaper,
        furniture = FurnitureCatalog, categories = FurnitureCategories,
        maxFurniture = Config.Furniture.MaxPieces, furnitureImage = Config.Furniture.ImageUrl,
        map = Config.Map, rentDays = Config.Rent.DefaultDays, directPurchase = Config.AllowDirectPurchase,
        marketplace = Config.Marketplace.Enabled, marketTax = Config.Marketplace.Tax,
        sellBack = Config.Furniture.SellBack, maxKeys = Config.MaxKeys, maxOverdue = Config.Rent.MaxOverdue,
        contractMinutes = Config.ContractExpireMinutes, visit = Config.AllowVisitAvailable,
    }
end

local function startTabletAnim()
    if not Config.Tablet.UseProp then return end
    local ped = PlayerPedId()
    local dict, anim = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    local hash = LoadModel('prop_cs_tablet')
    if hash and not tabletProp then
        local c = GetEntityCoords(ped)
        tabletProp = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
        AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(hash)
    end
    TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function stopTabletAnim()
    if tabletProp then
        DeleteEntity(tabletProp)
        tabletProp = nil
    end
    StopAnimTask(PlayerPedId(), 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
end

local function updateFocus()
    local focus = tabletOpen or contractOpen
    SetNuiFocus(focus, focus)
end

function OpenTablet(app)
    if tabletOpen or CurrentPlacement then return end
    local data, err = ServerCall('bootstrap') -- returns the table as first value
    if type(data) ~= 'table' then
        if err then Notify(err, 'error') end
        return
    end
    tabletOpen = true
    startTabletAnim()
    SendNUIMessage({ action = 'open', data = data, static = staticData(), app = app })
    updateFocus()
end

function CloseTablet()
    tabletOpen = false
    stopTabletAnim()
    SendNUIMessage({ action = 'close' })
    updateFocus()
end

RegisterCommand(Config.Tablet.Command, function() OpenTablet() end, false)
RegisterKeyMapping(Config.Tablet.Command, 'Real estate iPad', 'keyboard', Config.Tablet.Key)
RegisterNetEvent('rox_re:openTablet', function() OpenTablet() end)

-- Property card at a door (available / for sale)
function OpenPropertyCard(prop)
    contractOpen = true
    SendNUIMessage({ action = 'propertyCard', property = prop, static = staticData() })
    updateFocus()
end

RegisterNetEvent('rox_re:contract', function(contract)
    contractOpen = true
    SendNUIMessage({ action = 'contract', contract = contract, static = staticData() })
    updateFocus()
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
end)

---------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb)
    cb(1)
    CloseTablet()
end)

-- language chosen in the iPad settings (also sent once when the UI loads)
RegisterNUICallback('setLang', function(data, cb)
    cb(1)
    if data.lang == 'en' or data.lang == 'ar' then
        ClientLang = data.lang
        TriggerServerEvent('rox_re:setLang', data.lang)
    end
end)

RegisterNUICallback('closeOverlay', function(_, cb)
    cb(1)
    contractOpen = false
    updateFocus()
end)

-- generic bridge: { name = 'callbackName', args = {...} }
RegisterNUICallback('call', function(data, cb)
    CreateThread(function()
        local args = data.args or {}
        local a, b = ServerCall(data.name, table.unpack(args, 1, data.argc or #args))
        if type(a) == 'table' then
            cb({ ok = true, data = a })          -- callbacks that return a single table
        else
            cb({ ok = a and true or false, data = b })
        end
    end)
end)

RegisterNUICallback('pickLocation', function(data, cb)
    cb(1)
    CreateThread(function()
        SendNUIMessage({ action = 'hide' })
        SetNuiFocus(false, false)
        stopTabletAnim()
        local loc, street = PickLocation(data and data.mode)
        startTabletAnim()
        SendNUIMessage({ action = 'locationPicked', location = loc, street = street })
        updateFocus()
    end)
end)

RegisterNUICallback('waypoint', function(data, cb)
    cb(1)
    if data.x and data.y then
        SetNewWaypoint(data.x + 0.0, data.y + 0.0)
        Notify(L('waypoint_set'), 'success')
    end
end)

RegisterNUICallback('visit', function(data, cb)
    cb(1)
    contractOpen = false
    CloseTablet()
    CreateThread(function() EnterProperty(tonumber(data.id)) end)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then stopTabletAnim() end
end)
