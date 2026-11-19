-- ROX Store | All rights reserved
-- Weapon carry limit: max 2 heavy + 2 light (server enforced through ox_inventory hooks)
local LIMIT = { heavy = Config.MaxHeavy, light = Config.MaxLight }

local function counts(src)
    local c = { heavy = 0, light = 0 }
    for _, it in pairs(exports.ox_inventory:GetInventoryItems(src) or {}) do
        local cls = Config.Classify(it.name)
        if cls then c[cls] = c[cls] + (it.count or 1) end
    end
    return c
end

local function deny(src, cls)
    TriggerClientEvent('ox_lib:notify', src, { type = 'error',
        description = ('You can only carry %d %s weapons'):format(LIMIT[cls], cls) })
end

--- can `src` take one more `name`? (`giveBack` = a weapon of the same class leaves in the same move)
local function canCarry(src, name, giveBack)
    local cls = Config.Classify(name)
    if not cls then return true end
    if giveBack and Config.Classify(giveBack) == cls then return true end
    return counts(src)[cls] < LIMIT[cls]
end
exports('canCarry', canCarry)

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
    local ox = exports.ox_inventory

    -- moving a weapon INTO a player inventory from anywhere else (drop, stash, trunk, other player...)
    ox:registerHook('swapItems', function(p)
        if p.toType ~= 'player' or p.fromType == 'player' and p.fromInventory == p.toInventory then return true end
        local item = p.fromSlot; if type(item) ~= 'table' then return true end
        local target = tonumber(p.toInventory) or p.source
        local back = type(p.toSlot) == 'table' and p.action == 'swap' and p.toSlot.name or nil
        if not canCarry(target, item.name, back) then deny(p.source, Config.Classify(item.name)); return false end
        return true
    end)

    ox:registerHook('buyItem', function(p)
        if not canCarry(p.source, p.itemName) then deny(p.source, Config.Classify(p.itemName)); return false end
        return true
    end)

    ox:registerHook('craftItem', function(p)
        local name = p.recipe and p.recipe.name
        if name and not canCarry(p.source, name) then deny(p.source, Config.Classify(name)); return false end
        return true
    end)
end)
