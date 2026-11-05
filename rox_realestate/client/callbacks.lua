--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

local pending, nextId = {}, 0

-- Synchronous server call: local ok, data = ServerCall('name', ...)
function ServerCall(name, ...)
    nextId = nextId + 1
    local id = nextId
    local p = promise.new()
    pending[id] = p
    TriggerServerEvent('rox_re:cb', name, id, ...)
    SetTimeout(15000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ n = 2, false, 'timeout' })
        end
    end)
    local r = Citizen.Await(p)
    return table.unpack(r, 1, r.n)
end

RegisterNetEvent('rox_re:cbr', function(id, ...)
    local p = pending[id]
    if p then
        pending[id] = nil
        p:resolve(table.pack(...))
    end
end)
