--[[ ROX Laundry  ·  © ROX Store – All rights reserved. ]]
local MODEL = joaat('rox_laundromat')
local location, building, blip
local busy, open = {}, nil

local function notify(msg)
    BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(msg); EndTextCommandThefeedPostTicker(false, false)
end
RegisterNetEvent('rox_laundry:notify', notify)
RegisterNetEvent('rox_laundry:busy', function(t) busy = {} for k, v in pairs(t or {}) do busy[tonumber(k)] = v end end)

local function world(p)    -- local building point -> world coords + heading
    local h = math.rad(location.w); local c, s = math.cos(h), math.sin(h)
    return vector3(location.x + p.x * c - p.y * s, location.y + p.x * s + p.y * c, location.z + (p.z or 0)), (p.h + location.w) % 360.0
end

local props = {}
local function despawn()
    if building and DoesEntityExist(building) then DeleteEntity(building) end
    building = nil
    for _, e in ipairs(props) do if DoesEntityExist(e) then DeleteEntity(e) end end
    props = {}
end

local function pickModel(list)
    for _, name in ipairs(list) do local h = joaat(name); if IsModelInCdimage(h) and IsModelValid(h) then return h, name end end
end

-- real GTA props (shared/props.lua) standing on the floor or on top of another prop
local function spawnProps()
    local named, missing = {}, {}
    local r = math.rad(location.w); local c, s = math.cos(r), math.sin(r)
    for _, p in ipairs(LaundryProps) do
        local hash = pickModel(p.m)
        if not hash then missing[p.m[1]] = true
        else
            RequestModel(hash); local t = GetGameTimer() + 4000
            while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(0) end
            if HasModelLoaded(hash) then
                local mn, mx = GetModelDimensions(hash)
                local wx, wy = location.x + p.x * c - p.y * s, location.y + p.x * s + p.y * c
                local z = location.z + (p.z or 0.0) - mn.z
                if p.on and named[p.on] then
                    local base = named[p.on]; local _, bmx = GetModelDimensions(GetEntityModel(base))
                    z = GetEntityCoords(base).z + bmx.z - mn.z
                end
                local e = CreateObjectNoOffset(hash, wx, wy, z, false, false, false)
                SetEntityHeading(e, (location.w + p.face + (Config.PropFront or 180.0)) % 360.0)
                FreezeEntityPosition(e, true)
                SetModelAsNoLongerNeeded(hash)
                if p.name then named[p.name] = e end
                props[#props + 1] = e
            end
        end
    end
    for name in pairs(missing) do print(('^3[rox_laundry] no model available for %s (edit shared/props.lua)^7'):format(name)) end
end
local function spawn()
    despawn()
    if not IsModelInCdimage(MODEL) then return print('^1[rox_laundry] rox_laundromat model is not streamed^7') end
    RequestModel(MODEL); local t = GetGameTimer() + 8000
    while not HasModelLoaded(MODEL) and GetGameTimer() < t do Wait(20) end
    building = CreateObjectNoOffset(MODEL, location.x, location.y, location.z, false, false, false)
    SetEntityHeading(building, location.w); FreezeEntityPosition(building, true); SetEntityLodDist(building, 500)
    SetModelAsNoLongerNeeded(MODEL)
    spawnProps()
end

RegisterNetEvent('rox_laundry:location', function(loc)
    location = loc; despawn()
    if blip then RemoveBlip(blip) end
    blip = AddBlipForCoord(loc.x, loc.y, loc.z)
    SetBlipSprite(blip, Config.Blip.sprite); SetBlipColour(blip, Config.Blip.color); SetBlipScale(blip, Config.Blip.scale); SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentSubstringPlayerName(Config.Blip.label); EndTextCommandSetBlipName(blip)
end)
CreateThread(function() Wait(1000) TriggerServerEvent('rox_laundry:hello') end)

-- stream the building in/out
CreateThread(function()
    while true do
        Wait(1000)
        if location then
            local near = #(GetEntityCoords(PlayerPedId()) - location.xyz) < Config.SpawnDistance
            if near and not building then spawn() elseif not near and building then despawn() end
        end
    end
end)

---------------------------------------------------------------------
-- minigame UI
---------------------------------------------------------------------
local anim = {
    washer = { 'mini@repair', 'fixing_a_ped' }, dryer = { 'mini@repair', 'fixing_a_ped' },
    fold = { 'anim@amb@business@coc@coc_unpack_cut_left@', 'coke_cut_v1_coccutter' },
}
local function playAnim(kind)
    local a = anim[kind]; if not a then return end
    RequestAnimDict(a[1]); local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(a[1]) and GetGameTimer() < t do Wait(10) end
    TaskPlayAnim(PlayerPedId(), a[1], a[2], 4.0, -4.0, -1, 1, 0, false, false, false)
end

RegisterNetEvent('rox_laundry:open', function(kind, id, data)
    local p = LaundryPoints[id]; local pos, h = world(p)
    local ped = PlayerPedId()
    SetEntityHeading(ped, h); playAnim(kind)
    open = { kind = kind, id = id }
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', kind = kind, id = id, data = data, lang = Config.Locale })
end)
RegisterNetEvent('rox_laundry:denied', function(msg) notify('~r~' .. msg) end)

local function close()
    SetNuiFocus(false, false); ClearPedTasks(PlayerPedId()); open = nil
end
RegisterNUICallback('finish', function(d, cb) cb(1)
    if open then TriggerServerEvent('rox_laundry:finish', open.id, open.kind, d.score) end
    close()
end)
RegisterNUICallback('cancel', function(_, cb) cb(1) TriggerServerEvent('rox_laundry:cancel') close() end)
RegisterNUICallback('sound', function(d, cb) cb(1)
    local s = ({ coin = { 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET' }, click = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
                 done = { 'Hack_Success', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS' }, error = { 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET' } })[d.name]
    if s then PlaySoundFrontend(-1, s[1], s[2], true) end
end)

---------------------------------------------------------------------
-- interaction
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 800
        if building and not open then
            local pc = GetEntityCoords(PlayerPedId())
            if #(pc - location.xyz) < 20.0 then
                sleep = 0
                local best, bd
                for _, p in ipairs(LaundryPoints) do
                    local w = world(p)
                    local d = #(vector3(pc.x, pc.y, 0) - vector3(w.x, w.y, 0))
                    local score = d + (busy[p.id] and 5 or 0)    -- stacked dryers share a spot: take the free one
                    if d < 0.9 and math.abs(pc.z - (location.z + 1.0)) < 2.0 and (not bd or score < bd) then best, bd = p, score end
                end
                for _, p in ipairs(LaundryPoints) do
                    local w = world(p)
                    if #(pc - w) < 6.0 and p.kind ~= 'cashier' then
                        local r, g, b = 255, 90, 31
                        if busy[p.id] then r, g, b = 220, 40, 40 end
                        DrawMarker(20, w.x, w.y, location.z + 1.15 + (p.z > 1.2 and 0.9 or 0), 0, 0, 0, 0, 180.0, 0, 0.18, 0.18, 0.14, r, g, b, 150, true, true, 2, false)
                    end
                end
                if best then
                    BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(L('use', L(best.kind))); EndTextCommandDisplayHelp(0, false, false, -1)
                    if IsControlJustPressed(0, 38) then
                        if best.kind == 'cashier' then
                            notify(L('cashier_info', Config.Currency .. Config.Prices.wash, Config.Currency .. Config.Prices.dry, Config.Currency .. Config.Reward.money))
                        elseif busy[best.id] then notify('~r~' .. L('busy'))
                        else TriggerServerEvent('rox_laundry:start', best.id) Wait(500) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then despawn() if open then close() end end end)
