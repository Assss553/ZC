-- ROX Store | All rights reserved
local cur = nil   -- { item, cfg, left, prop }
local KH = function() return GetResourceState('rox_keyhints') == 'started' end

local function hint()
    if not cur or not KH() then return end
    local c = cur.cfg
    exports.rox_keyhints:Show('consume', { { keys = { 'E' }, label = c.type == 'drink' and 'Drink' or 'Eat' }, { keys = { 'X' }, label = 'Drop' } },
        nil, { info = ('%d%s / %d%s'):format(cur.left, c.unit, c.total, c.unit), progress = cur.left / c.total * 100 })
end

local function finish(drop)
    if not cur then return end
    if cur.prop and DoesEntityExist(cur.prop) then
        if drop then DetachEntity(cur.prop, true, true); SetEntityAsNoLongerNeeded(cur.prop) else DeleteEntity(cur.prop) end
    end
    if KH() then exports.rox_keyhints:Hide('consume') end
    ClearPedSecondaryTask(cache.ped)
    cur = nil
end

local function use(item)
    if cur then return lib.notify({ type = 'error', description = 'You are already holding something' }) end
    local c = Config.Items[item]; if not c then return end
    local total = lib.callback.await('rox_consume:start', false, item)
    if not total then return end
    local p = c.prop
    lib.requestModel(p[1], 5000)
    local pos = GetEntityCoords(cache.ped)
    local obj = CreateObject(joaat(p[1]), pos.x, pos.y, pos.z + 0.2, true, true, false)
    AttachEntityToEntity(obj, cache.ped, GetPedBoneIndex(cache.ped, p[2]), p[3], p[4], p[5], p[6], p[7], p[8], true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(joaat(p[1]))
    cur = { item = item, cfg = c, left = total, prop = obj }
    hint()
    CreateThread(function()
        local busy = false
        while cur do
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)      -- no shooting while holding food
            DisableControlAction(0, 38, true); DisableControlAction(0, 73, true)
            if not busy and IsDisabledControlJustPressed(0, 38) then                 -- E
                busy = true
                local a = Config.Anims[c.type]
                lib.requestAnimDict(a[1])
                TaskPlayAnim(cache.ped, a[1], a[2], 8.0, -8.0, a[3], 49, 0, false, false, false)
                CreateThread(function()
                    Wait(a[3])
                    local left = lib.callback.await('rox_consume:bite', false)
                    if cur then
                        if not left or left <= 0 then finish(false) else cur.left = left; hint() end
                    end
                    Wait(math.max(0, Config.BiteCooldown - a[3])); busy = false
                end)
            end
            if IsDisabledControlJustPressed(0, 73) then TriggerServerEvent('rox_consume:drop'); finish(true) end   -- X
            if IsPedRagdoll(cache.ped) or IsEntityDead(cache.ped) or IsPedSwimming(cache.ped) then TriggerServerEvent('rox_consume:drop'); finish(true) end
            Wait(0)
        end
    end)
end

-- ox_inventory: items.lua -> client = { export = 'rox_consume.use' }
exports('use', function(data) use(data and data.name) end)
AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then finish(false) end end)
