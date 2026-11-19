-- ROX Store | All rights reserved
-- Heavy weapons that are not in your hands are slung on your back (synced to everyone with a state bag)
if not Config.ShowOnBack then return end

local sent = ''
CreateThread(function()
    while true do
        if GetResourceState('ox_inventory') == 'started' then
            local cur = exports.ox_inventory:getCurrentWeapon()
            local list = {}
            for _, it in pairs(exports.ox_inventory:GetPlayerItems() or {}) do
                if Config.Classify(it.name) == 'heavy' and not (cur and cur.slot == it.slot) and #list < #Config.Back then
                    list[#list + 1] = it.name
                end
            end
            table.sort(list)
            local key = table.concat(list, ',')
            if key ~= sent then sent = key; LocalPlayer.state:set('roxBack', list, true) end
        end
        Wait(1000)
    end
end)

-- render for every player near you
local objs = {}   -- [serverId] = { key = '...', ents = {} }

local function clear(id)
    local o = objs[id]; if not o then return end
    for _, e in ipairs(o.ents) do if DoesEntityExist(e) then DeleteEntity(e) end end
    objs[id] = nil
end

local function build(id, ped, list)
    clear(id)
    local o = { key = table.concat(list, ','), ents = {}, ped = ped }
    for i, name in ipairs(list) do
        local slot = Config.Back[i]
        local model = GetWeapontypeModel(joaat(name))
        if slot and model ~= 0 and IsModelInCdimage(model) then
            RequestModel(model)
            local t = GetGameTimer() + 3000
            while not HasModelLoaded(model) and GetGameTimer() < t do Wait(0) end
            if HasModelLoaded(model) then
                local c = GetEntityCoords(ped)
                local e = CreateObject(model, c.x, c.y, c.z - 5.0, false, false, false)
                SetEntityCollision(e, false, false)
                AttachEntityToEntity(e, ped, GetPedBoneIndex(ped, slot.bone), slot.pos.x, slot.pos.y, slot.pos.z,
                    slot.rot.x, slot.rot.y, slot.rot.z, true, true, false, true, 2, true)
                SetModelAsNoLongerNeeded(model)
                o.ents[#o.ents + 1] = e
            end
        end
    end
    objs[id] = o
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local seen = {}
        for _, pl in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(pl)
            local id = GetPlayerServerId(pl)
            if ped ~= 0 and #(GetEntityCoords(ped) - me) < 80.0 then
                seen[id] = true
                local list = Player(id).state.roxBack or {}
                local hidden = IsPedInAnyVehicle(ped, false) or not IsEntityVisible(ped)
                if hidden then list = {} end
                local o = objs[id]
                if not o or o.key ~= table.concat(list, ',') or o.ped ~= ped then build(id, ped, list) end
            end
        end
        for id in pairs(objs) do if not seen[id] then clear(id) end end
        Wait(700)
    end
end)

AddEventHandler('onResourceStop', function(r)
    if r == GetCurrentResourceName() then for id in pairs(objs) do clear(id) end end
end)
