-- ROX Store | All rights reserved
Config = {}
Config.Key = 'F2'                -- opens the 3D inventory (ox_inventory keeps its own TAB/F2 bind: change one of them)
Config.MaxWeight = 60            -- shown on the weight bar (kg). Real limit = ox_inventory player weight
-- player slot layout (ox_inventory slot numbers)
Config.Layout = { hot = { 1, 2, 3, 4, 5 }, primary = 6, secondary = 7, vest = 8, bag = 9, head = 10, pockets = { 11, 35 } }
Config.Equip = {
    vest = { armour = true, rox_vest = true },
    bag = { parachute = true, rox_oxygen = true, duffel_bag = true },
    head = { helmet = true, cap = true, mask = true },
}
Config.Heavy = { 'RIFLE', 'CARBINE', 'SHOTGUN', 'SNIPER', 'MG', 'RPG', 'LAUNCHER', 'MINIGUN', 'MUSKET', 'GUSENBERG' }
function Config.SlotKind(slot)
    local L = Config.Layout
    if slot == L.primary then return 'primary' elseif slot == L.secondary then return 'secondary'
    elseif slot == L.vest then return 'vest' elseif slot == L.bag then return 'bag' elseif slot == L.head then return 'head' end
end
function Config.Fits(slot, name)
    local k = Config.SlotKind(slot)
    if not k then return true end
    if k == 'vest' or k == 'bag' or k == 'head' then return Config.Equip[k][name] == true end
    if name:sub(1, 7) ~= 'WEAPON_' then return false end
    local heavy = false
    for _, w in ipairs(Config.Heavy) do if name:find(w, 8, true) then heavy = true end end
    return (k == 'primary') == heavy
end
