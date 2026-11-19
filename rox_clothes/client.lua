-- ROX Store | All rights reserved
local open, cam, original = false, nil, nil

CreateThread(function()
    for _, c in ipairs(Config.Locations) do
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, Config.Blip.sprite); SetBlipColour(b, Config.Blip.color); SetBlipScale(b, 0.7); SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.Blip.label); EndTextCommandSetBlipName(b)
    end
end)

local function snapshot(ped)
    local s = { comp = {}, prop = {} }
    for i = 0, 11 do s.comp[i] = { GetPedDrawableVariation(ped, i), GetPedTextureVariation(ped, i) } end
    for _, i in ipairs({ 0, 1, 2, 6, 7 }) do s.prop[i] = { GetPedPropIndex(ped, i), GetPedPropTextureIndex(ped, i) } end
    return s
end
local function restore(ped, s)
    for i, v in pairs(s.comp) do SetPedComponentVariation(ped, i, v[1], v[2], 0) end
    for i, v in pairs(s.prop) do if v[1] == -1 then ClearPedProp(ped, i) else SetPedPropIndex(ped, i, v[1], v[2], true) end end
end

local CAM = { head = { 0.0, 0.85, 0.65, 0.65, 35.0 }, body = { 0.0, 1.6, 0.2, 0.2, 45.0 }, legs = { 0.0, 1.6, -0.45, -0.45, 45.0 }, feet = { 0.0, 1.2, -0.85, -0.85, 40.0 } }
local function camTo(kind)
    local ped = PlayerPedId(); local c = CAM[kind] or CAM.body
    local p = GetOffsetFromEntityInWorldCoords(ped, c[1], c[2], c[3])
    local t = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, c[4])
    local new = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', p.x, p.y, p.z, 0.0, 0.0, 0.0, c[5], false, 0)
    PointCamAtCoord(new, t.x, t.y, t.z)
    if cam then SetCamActiveWithInterp(new, cam, 450, 1, 1); Wait(10); DestroyCam(cam, false) else SetCamActive(new, true); RenderScriptCams(true, true, 500, true, false) end
    cam = new
end

local function count(cat)
    local ped = PlayerPedId()
    if cat.kind == 'prop' then return GetNumberOfPedPropDrawableVariations(ped, cat.id) end
    return GetNumberOfPedDrawableVariations(ped, cat.id)
end
local function textures(cat, d)
    local ped = PlayerPedId()
    if cat.kind == 'prop' then return d < 0 and 0 or GetNumberOfPedPropTextureVariations(ped, cat.id, d) end
    return GetNumberOfPedTextureVariations(ped, cat.id, d)
end
local function current(cat)
    local ped = PlayerPedId()
    if cat.kind == 'prop' then return GetPedPropIndex(ped, cat.id), math.max(0, GetPedPropTextureIndex(ped, cat.id)) end
    return GetPedDrawableVariation(ped, cat.id), GetPedTextureVariation(ped, cat.id)
end
local function apply(cat, d, t)
    local ped = PlayerPedId()
    if cat.kind == 'prop' then if d < 0 then ClearPedProp(ped, cat.id) else SetPedPropIndex(ped, cat.id, d, t, true) end
    else SetPedComponentVariation(ped, cat.id, d, t, 0) end
end

local function info(ci)
    local cat = Config.Categories[ci]
    local d, t = current(cat)
    return { cat = ci, drawable = d, texture = t, total = count(cat), textures = textures(cat, d), price = cat.price, label = cat.label, min = cat.kind == 'prop' and -1 or 0 }
end

local function openShop()
    if open then return end
    open = true
    local ped = PlayerPedId()
    original = snapshot(ped)
    FreezeEntityPosition(ped, true)
    TaskStandStill(ped, -1)
    local cats = {}
    for i, c in ipairs(Config.Categories) do cats[i] = { label = c.label, price = c.price } end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', name = Config.Name, cats = cats, wallet = lib.callback.await('rox_clothes:wallet', false), item = info(1) })
    camTo(Config.Categories[1].cam)
end

local function closeShop(keep)
    if not open then return end
    open = false
    local ped = PlayerPedId()
    if not keep and original then restore(ped, original) end
    FreezeEntityPosition(ped, false); ClearPedTasks(ped)
    RenderScriptCams(false, true, 500, true, false); if cam then DestroyCam(cam, false); cam = nil end
    SetNuiFocus(false, false)
    -- save the look in the appearance resource if present
    if keep and GetResourceState('illenium-appearance') == 'started' then
        local ok, app = pcall(function() return exports['illenium-appearance']:getPedAppearance(ped) end)
        if ok and app then TriggerServerEvent('illenium-appearance:server:saveAppearance', app) end
    end
end

RegisterNUICallback('cat', function(d, cb)
    local ci = tonumber(d.cat) or 1; camTo(Config.Categories[ci].cam); cb(info(ci))
end)
RegisterNUICallback('set', function(d, cb)
    local cat = Config.Categories[tonumber(d.cat) or 1]
    local total = count(cat); local min = cat.kind == 'prop' and -1 or 0
    local dr = math.max(min, math.min(total - 1, math.floor(tonumber(d.drawable) or 0)))
    local tx = math.max(0, math.min(math.max(0, textures(cat, dr) - 1), math.floor(tonumber(d.texture) or 0)))
    apply(cat, dr, tx); cb(info(tonumber(d.cat) or 1))
end)
RegisterNUICallback('rotate', function(d, cb) local ped = PlayerPedId(); SetEntityHeading(ped, GetEntityHeading(ped) + (tonumber(d.dir) or 0) * 15.0); cb('ok') end)
RegisterNUICallback('buy', function(d, cb)
    local ok, err, wallet = lib.callback.await('rox_clothes:buy', false, d.cat)
    if ok then original = snapshot(PlayerPedId()); PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true) end
    cb({ ok = ok, err = err, wallet = wallet })
end)
RegisterNUICallback('close', function(d, cb) cb('ok'); closeShop(d and d.keep) end)
RegisterNUICallback('nav', function(_, cb) PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true); cb('ok') end)

CreateThread(function()
    local shown = false
    while true do
        local sleep, nearby = 700, false
        local p = GetEntityCoords(PlayerPedId())
        for _, c in ipairs(Config.Locations) do local dd = #(p - c); if dd < 12 then sleep = 0 end; if dd < 2.0 then nearby = true end end
        if nearby and not open then
            if not shown and GetResourceState('rox_interact') == 'started' then exports.rox_interact:Prompt('Browse clothes', 'E'); shown = true end
            if IsControlJustReleased(0, 38) then
                if GetResourceState('rox_interact') == 'started' then exports.rox_interact:Prompt(nil) end
                shown = false; openShop()
            end
        elseif shown then shown = false; if GetResourceState('rox_interact') == 'started' then exports.rox_interact:Prompt(nil) end end
        Wait(sleep)
    end
end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then closeShop(false) end end)
