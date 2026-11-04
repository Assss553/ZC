local isOpen = false
local pending, reqSeq = {}, 0

-- request to the server, returns the result (yields)
function ServerRequest(action, data)
    reqSeq = reqSeq + 1
    local id = reqSeq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('zc_police:server:req', id, action, data or {})
    SetTimeout(10000, function()
        if pending[id] then pending[id] = nil; p:resolve({ ok = false, msg = 'Server timeout' }) end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('zc_police:client:res', function(id, res)
    local p = pending[id]
    if p then pending[id] = nil; p:resolve(res) end
end)

local function canOpen()
    reqSeq = reqSeq + 1
    local id = reqSeq
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('zc_police:server:canOpen', id)
    SetTimeout(5000, function() if pending[id] then pending[id] = nil; p:resolve({ ok = false }) end end)
    return Citizen.Await(p).ok
end

local function close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function open(panel, opts)
    if isOpen then
        SendNUIMessage({ action = 'open', panel = panel, opts = opts or {} })
        return
    end
    if not canOpen() then
        SendNUIMessage({ action = 'toast', kind = 'error', msg = 'Police only' })
        return
    end
    local init = ServerRequest('init')
    isOpen = true
    SendNUIMessage({ action = 'open', panel = panel, opts = opts or {}, init = init, color = Config.Color })
    SetNuiFocus(true, true)
end

RegisterNetEvent('zc_police:client:open', function(args)
    local panel = type(args) == 'table' and args.panel or args or 'mdt'
    CreateThread(function() open(panel, type(args) == 'table' and args or {}) end)
end)

RegisterCommand(Config.Commands.mdt,  function() open('mdt') end, false)
RegisterCommand(Config.Commands.jail, function(_, a) open('jail', { id = tonumber(a[1]) }) end, false)
RegisterCommand(Config.Commands.fine, function(_, a) open('fine', { id = tonumber(a[1]) }) end, false)

RegisterNetEvent('zc_police:client:notify', function(msg, kind)
    SendNUIMessage({ action = 'toast', msg = msg, kind = kind })
end)

local function nearby()
    local me = PlayerPedId()
    local my = GetEntityCoords(me)
    local list, ids = {}, {}
    for _, pl in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pl)
        if ped ~= me then
            local d = #(GetEntityCoords(ped) - my)
            if d <= Config.NearbyDistance then
                local sid = GetPlayerServerId(pl)
                list[#list + 1] = { id = sid, dist = math.floor(d * 10) / 10 }
                ids[#ids + 1] = sid
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    if #ids == 0 then return {} end
    local names = ServerRequest('names', { ids = ids }) or {}
    local byId = {}
    for _, n in ipairs(names) do byId[n.id] = n end
    for _, e in ipairs(list) do
        e.name = byId[e.id] and byId[e.id].name or ('Player ' .. e.id)
        e.cid = byId[e.id] and byId[e.id].cid
    end
    return list
end

local function closestPlate()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then
        local c = GetEntityCoords(ped)
        veh = GetClosestVehicle(c.x, c.y, c.z, 8.0, 0, 70)
    end
    if veh == 0 then return nil end
    local plate = GetVehicleNumberPlateText(veh):gsub('^%s*(.-)%s*$', '%1')
    return { plate = plate, model = GetLabelText(GetDisplayNameFromVehicleModel(GetEntityModel(veh))) }
end

RegisterNUICallback('close', function(_, cb) close(); cb('ok') end)

RegisterNUICallback('req', function(data, cb)
    local action = data.action
    if action == 'nearby' then return cb(nearby()) end
    if action == 'closestPlate' then return cb(closestPlate() or {}) end
    CreateThread(function() cb(ServerRequest(action, data.data)) end)
end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then close() end end)
