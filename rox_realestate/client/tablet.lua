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

-- the tablet prop is shared with other ROX iPad apps (rox_police) so switching apps keeps it in the hand
local function sharedProp()
    local h = LocalPlayer.state.roxTabletProp
    if h and DoesEntityExist(h) then return h end
end

local function startTabletAnim()
    if not Config.Tablet.UseProp then return end
    local ped = PlayerPedId()
    local dict, anim = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base'
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    tabletProp = sharedProp()
    if not tabletProp and not IsPedInAnyVehicle(ped, false) then
        local hash = LoadModel('prop_cs_tablet')
        if hash then
            local c = GetEntityCoords(ped)
            tabletProp = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
            AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
            SetModelAsNoLongerNeeded(hash)
            LocalPlayer.state:set('roxTabletProp', tabletProp, false)
        end
    end
    if not IsEntityPlayingAnim(ped, dict, anim, 3) then
        TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, 49, 0, false, false, false)
    end
end

local function stopTabletAnim(keepProp)
    if keepProp then tabletProp = nil return end
    local h = sharedProp() or tabletProp
    if h then DeleteEntity(h) end
    tabletProp = nil
    LocalPlayer.state:set('roxTabletProp', nil, false)
    StopAnimTask(PlayerPedId(), 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 1.0)
end

-- apps from other ROX resources shown on this iPad (rox_police for police jobs)
local function externalApps()
    if GetResourceState('rox_police') ~= 'started' then return {} end
    local ok, apps = pcall(function() return exports.rox_police:IpadApps() end)
    return ok and apps or {}
end

local function updateFocus()
    local focus = tabletOpen or contractOpen
    SetNuiFocus(focus, focus)
end

function OpenTablet(app, handoff)
    if tabletOpen or CurrentPlacement then return end
    local data, err = ServerCall('bootstrap') -- returns the table as first value
    if type(data) ~= 'table' then
        if err then Notify(err, 'error') end
        return
    end
    tabletOpen = true
    startTabletAnim()
    SendNUIMessage({ action = 'open', data = data, static = staticData(), app = app, instant = handoff,
        ext = externalApps(), ipad = LocalPlayer.state.roxIpad })
    updateFocus()
end

function CloseTablet(keepProp)
    tabletOpen = false
    stopTabletAnim(keepProp)
    SendNUIMessage({ action = 'close' })
    updateFocus()
end

RegisterCommand(Config.Tablet.Command, function() OpenTablet() end, false)
RegisterKeyMapping(Config.Tablet.Command, 'Real estate iPad', 'keyboard', Config.Tablet.Key)
RegisterNetEvent('rox_re:openTablet', function(app) OpenTablet(app) end)
exports('OpenTablet', function(app, handoff) CreateThread(function() OpenTablet(app, handoff) end) end)
exports('IsTabletOpen', function() return tabletOpen end)

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

-- open an app that lives in another ROX resource (same iPad, the prop stays in the hand)
RegisterNUICallback('handoff', function(data, cb)
    cb(1)
    if type(data) ~= 'table' or data.res ~= 'rox_police' or GetResourceState('rox_police') ~= 'started' then return end
    CloseTablet(true)
    TriggerEvent('rox_police:client:open', { panel = data.app, page = data.page, handoff = true })
end)

-- wallpaper / size are shared by every ROX iPad app
RegisterNUICallback('ipadSettings', function(data, cb)
    cb(1)
    if type(data) == 'table' then
        LocalPlayer.state:set('roxIpad', { wallpaper = data.wallpaper, scale = tonumber(data.scale) or 1 }, false)
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
