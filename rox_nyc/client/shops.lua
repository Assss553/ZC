--[[ ROX NYC  ·  © ROX Store – walk-in shops: GTA props inside + buy menu ]]
local SP = Config.ShopProps
NycShopPoints = {}     -- { id, x, y (local), kind } cashier points

-- shop frame: u along the front wall (left -> right seen from inside), v = depth from the front wall inwards
local function frame(s)
    local f = s.doors[1][3]
    local L, D, map, out
    if f == 'N' then L, D = s.ix1 - s.ix0, s.iy1 - s.iy0; map = function(u, v) return s.ix1 - u, s.iy1 - v end; out = 0.0
    elseif f == 'S' then L, D = s.ix1 - s.ix0, s.iy1 - s.iy0; map = function(u, v) return s.ix0 + u, s.iy0 + v end; out = 180.0
    elseif f == 'E' then L, D = s.iy1 - s.iy0, s.ix1 - s.ix0; map = function(u, v) return s.ix1 - v, s.iy0 + u end; out = 270.0
    else L, D = s.iy1 - s.iy0, s.ix1 - s.ix0; map = function(u, v) return s.ix0 + v, s.iy1 - u end; out = 90.0 end
    return L, D, map, out           -- out = heading of "looking towards the front / street"
end

-- doors are in the middle of the front: keep that lane free
function NycFurnish(spawn, onTop)
    for _, s in ipairs(NycShops) do
        local L, D, map, front = frame(s)
        local back = (front + 180.0) % 360.0
        local function P(list, u, v, head, z) local x, y = map(u, v); return spawn(list, x, y, (z or 0.0) + 0.01, head) end
        local function point(u, v) local x, y = map(u, v); NycShopPoints[#NycShopPoints + 1] = { id = s.id, x = x, y = y, kind = s.kind, label = s.label } end
        local big = L > 15
        if s.kind == 'deli' or s.kind == 'pharmacy' then
            for u = 1.0, L - 1.0, 1.05 do P(SP.bigfridge, u, D - 0.45, front) end                     -- fridges along the back wall
            local rows = big and { D * 0.35, D * 0.52, D * 0.69 } or { D * 0.5 }
            for _, v in ipairs(rows) do                                                          -- shelf aisles
                for u = (big and 5.0 or 2.2), L - (big and 2.0 or 1.6), 1.25 do P(SP.shelf, u, v, front); P(SP.shelf2, u, v + 0.65, back) end
            end
            local cu = L - 2.2
            local c = P(SP.counter, cu, 2.2, front)                                               -- counter next to the door, facing the door
            if c then onTop(SP.till, c, 0.0); end
            P(SP.cigs, cu, 3.4, front, 1.2); P(SP.sweets, cu - 1.5, 2.0, front); P(SP.lottery, cu + 1.2, 2.2, front)
            point(cu, 1.1)
            P(SP.plant, 0.7, 0.8, 0.0); P(SP.bin, 0.8, 1.6, 0.0)
        elseif s.kind == 'pizza' or s.kind == 'burger' or s.kind == 'cafe' then
            local c = P(SP.counter2, L * 0.5, D - 2.4, front)
            if c then onTop(SP.till, c, 0.0); onTop(s.kind == 'cafe' and SP.coffee or (s.kind == 'pizza' and SP.pizzabox or SP.tray), c, 0.6) end
            if s.kind == 'pizza' then P(SP.oven, L * 0.5, D - 0.7, front) end
            P(SP.fridge, 0.6, D - 1.0, 90.0 + front - 90.0); P(SP.display, L - 0.7, D - 1.2, front)
            for k = 0, 1 do                                                                     -- 2 tables with 2 chairs each
                local u = k == 0 and 1.5 or L - 1.5
                P(SP.table, u, 2.6, 0.0); P(SP.chair, u - 0.7, 2.6, front + 90.0); P(SP.chair, u + 0.7, 2.6, front - 90.0)
                P(SP.table, u, 4.6, 0.0); P(SP.chair, u - 0.7, 4.6, front + 90.0); P(SP.chair, u + 0.7, 4.6, front - 90.0)
            end
            P(SP.plant, 0.6, 0.6, 0.0)
            point(L * 0.5, D - 3.5)
        elseif s.kind == 'bar' then
            local bv = big and D * 0.65 or D - 2.4
            for u = (big and 3.0 or 1.0), L - (big and 3.0 or 1.0), 1.5 do
                local c = P(SP.counter2, u, bv, front)
                if c and math.floor(u) % 3 == 0 then onTop(SP.pump, c, 0.0) end
                P(SP.stool, u, bv - 1.0, back)
            end
            for u = (big and 3.0 or 1.0), L - (big and 3.0 or 1.0), 1.1 do P(SP.fridge, u, D - 0.45, front) end
            if big then
                for u = 3.0, L - 3.0, 3.5 do P(SP.table, u, 3.0, 0.0); P(SP.chair, u - 0.7, 3.0, front + 90.0); P(SP.chair, u + 0.7, 3.0, front - 90.0) end
            end
            point(L * 0.5, bv - 1.3)
        end
    end
end

---------------------------------------------------------------------
-- buy menu
---------------------------------------------------------------------
local menuOpen = false
local function openMenu(p)
    local shop = Config.Shop[p.kind]; if not shop then return end
    menuOpen = true; SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', id = p.id, title = p.label or shop.title, kind = p.kind, items = shop.items, lang = Config.Locale, max = Config.MaxPerItem })
end
RegisterNUICallback('close', function(_, cb) cb(1) menuOpen = false SetNuiFocus(false, false) end)
RegisterNUICallback('buy', function(d, cb)
    cb(1); menuOpen = false; SetNuiFocus(false, false)
    TriggerServerEvent('rox_nyc:buy', d.id, d.cart)
end)
RegisterNetEvent('rox_nyc:notify', function(msg)
    BeginTextCommandThefeedPost('STRING'); AddTextComponentSubstringPlayerName(msg); EndTextCommandThefeedPostTicker(false, false)
end)

CreateThread(function()
    while true do
        local sleep = 700
        if NycWorld and not menuOpen and #NycShopPoints > 0 then
            local pc = GetEntityCoords(PlayerPedId())
            for _, p in ipairs(NycShopPoints) do
                local w = NycWorld(p.x, p.y, 0.0)
                local d = #(vector3(pc.x, pc.y, 0) - vector3(w.x, w.y, 0))
                if d < 8.0 and math.abs(pc.z - w.z - 1.0) < 2.5 then
                    sleep = 0
                    DrawMarker(29, w.x, w.y, w.z + 1.0, 0, 0, 0, 0, 0, 0, 0.35, 0.35, 0.35, 255, 90, 31, 170, true, true, 2, false)
                    if d < 1.3 then
                        BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(Config.Locale == 'ar' and '~INPUT_CONTEXT~ شراء من ' .. p.label or '~INPUT_CONTEXT~ Buy at ' .. p.label); EndTextCommandDisplayHelp(0, false, false, -1)
                        if IsControlJustPressed(0, 38) then openMenu(p) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
