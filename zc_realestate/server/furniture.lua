local function pieceForClient(row)
    local item = FurnitureByModel[row.model]
    return {
        id = row.id, model = row.model, label = item and item.label or row.model, cat = item and item.cat,
        price = row.price, placed = row.placed == 1 or row.placed == true,
        x = row.x, y = row.y, z = row.z, rx = row.rx or 0, ry = row.ry or 0, rz = row.rz or 0,
    }
end

function GetPlacedFurniture(propertyId)
    local list = {}
    for _, row in ipairs(DB.FurnitureFor(propertyId)) do
        if row.placed == 1 or row.placed == true then list[#list + 1] = pieceForClient(row) end
    end
    return list
end

local function broadcastInside(propertyId, action, payload)
    for s, pid in pairs(Inside) do
        if pid == propertyId then TriggerClientEvent('zc_re:furnitureUpdate', s, action, payload) end
    end
end

local function findPiece(propertyId, fid)
    for _, row in ipairs(DB.FurnitureFor(propertyId)) do
        if row.id == fid then return row end
    end
end

RegisterCallback('getFurniture', function(src, propertyId)
    local prop = GetProp(propertyId)
    if not prop or not GetAccess(src, prop) then return false, L('no_access') end
    local list = {}
    for _, row in ipairs(DB.FurnitureFor(prop.id)) do list[#list + 1] = pieceForClient(row) end
    return { pieces = list, max = Config.Furniture.MaxPieces, money = Bridge.GetMoney(src) }
end)

RegisterCallback('orderFurniture', function(src, propertyId, cart)
    local prop = GetProp(propertyId)
    if not prop or GetAccess(src, prop) ~= 'owner' then return false, L('no_access') end
    if type(cart) ~= 'table' then return false, L('invalid_data') end

    local wanted, total, count = {}, 0, 0
    for _, entry in ipairs(cart) do
        local item = FurnitureByModel[entry.model]
        local qty = math.floor(tonumber(entry.qty) or 0)
        if not item or qty < 1 or qty > Config.Furniture.MaxPieces then return false, L('invalid_data') end
        wanted[#wanted + 1] = { item = item, qty = qty }
        total = total + item.price * qty
        count = count + qty
    end
    if count == 0 then return false, L('invalid_data') end

    local existing = #DB.FurnitureFor(prop.id)
    if existing + count > Config.Furniture.MaxPieces then
        return false, L('max_furniture', Config.Furniture.MaxPieces)
    end
    if not Bridge.RemoveMoney(src, total, 'realestate-furniture') then return false, L('no_money') end

    for _, w in ipairs(wanted) do
        for _ = 1, w.qty do DB.InsertFurniture(prop.id, w.item.model, w.item.price) end
    end
    Bridge.Notify(src, LP(src, 'order_done', count), 'success')
    return true, { money = Bridge.GetMoney(src) }
end)

local function canEditInside(src, propertyId)
    local prop = GetProp(propertyId)
    if not prop or not GetAccess(src, prop) then return nil, L('no_access') end
    if Inside[src] ~= prop.id then return nil, L('not_inside') end
    return prop
end

RegisterCallback('placeFurniture', function(src, propertyId, fid, pos, rot)
    local prop, err = canEditInside(src, propertyId)
    if not prop then return false, err end
    if type(pos) ~= 'table' or type(rot) ~= 'table' then return false, L('invalid_data') end
    local row = findPiece(prop.id, tonumber(fid))
    if not row then return false, L('invalid_data') end

    local x, y, z = tonumber(pos.x), tonumber(pos.y), tonumber(pos.z)
    if not (x and y and z) then return false, L('invalid_data') end
    local spawn, shellPos = GetInteriorSpawn(prop.interior, prop.door, prop.inside)
    local center = shellPos or (spawn and vector3(spawn.x, spawn.y, spawn.z))
    if not center or #(vector3(x, y, z) - center) > Config.Furniture.PlaceRadius then
        return false, L('too_far_place')
    end

    local piece = {
        id = row.id, placed = true, x = x, y = y, z = z,
        rx = tonumber(rot.x) or 0.0, ry = tonumber(rot.y) or 0.0, rz = tonumber(rot.z) or 0.0,
    }
    DB.UpdateFurniture(piece)
    row.placed, row.x, row.y, row.z, row.rx, row.ry, row.rz = 1, piece.x, piece.y, piece.z, piece.rx, piece.ry, piece.rz
    broadcastInside(prop.id, 'place', pieceForClient(row))
    Bridge.Notify(src, LP(src, 'furniture_placed'), 'success')
    return true
end)

RegisterCallback('storeFurniture', function(src, propertyId, fid)
    local prop, err = canEditInside(src, propertyId)
    if not prop then return false, err end
    local row = findPiece(prop.id, tonumber(fid))
    if not row then return false, L('invalid_data') end
    DB.UpdateFurniture({ id = row.id, placed = false })
    broadcastInside(prop.id, 'remove', { id = row.id })
    Bridge.Notify(src, LP(src, 'furniture_stored'), 'info')
    return true
end)

RegisterCallback('sellFurniture', function(src, propertyId, fid)
    local prop = GetProp(propertyId)
    if not prop or GetAccess(src, prop) ~= 'owner' then return false, L('no_access') end
    local row = findPiece(prop.id, tonumber(fid))
    if not row then return false, L('invalid_data') end
    local refund = math.floor((row.price or 0) * Config.Furniture.SellBack)
    DB.DeleteFurniture(row.id)
    Bridge.AddMoney(src, refund, 'realestate-furniture-sell')
    broadcastInside(prop.id, 'remove', { id = row.id })
    Bridge.Notify(src, LP(src, 'furniture_sold', FormatMoney(refund)), 'success')
    return true
end)
