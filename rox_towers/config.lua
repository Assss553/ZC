--[[ ROX Towers  ·  © ROX Store – All rights reserved. ]]
Config = {}
-- Centre of the towers at street level + heading (the lobby door looks the opposite way of the heading).
-- Stand where the middle of the building should be and type /roxtowers_here (ace rox_towers.admin). Footprint 62 x 52 m.
Config.Origin = vec4(-75.0, -820.0, 326.0, 160.0)
Config.AdminAce = 'rox_towers.admin'
Config.SpawnDistance = 900.0
Config.PropFront = 180.0      -- GTA props look at -Y in model space; set 0.0 if sofas / desks face the wall
Config.Locale = 'ar'

-- Walk-in floors (local z of the floor) and the elevator spot on each floor (in front of the core)
Config.Floors = {
    { key = 'lobby',     label = 'Lobby',       labelAr = 'اللوبي',        z = 0.0 },
    { key = 'office',    label = 'Offices',     labelAr = 'المكاتب',       z = 26.3 },
    { key = 'executive', label = 'Executive',   labelAr = 'دور المدير',    z = 45.8 },
    { key = 'skylounge', label = 'Sky Lounge',  labelAr = 'لاونج السطح',  z = 131.9, elev = 'sky' },
}
Config.Elevator = { x = 0.0, y = -1.4 }          -- local point in front of the core (lobby), the same on every floor except the sky lounge
Config.SkyElevator = { x = -13.0, y = -11.0 }

-- Real GTA props per floor: { models (first available is used), x, y, heading }  (local metres, floor level)
local M = {
    sofa = { 'apa_mp_h_stn_sofacorn_05', 'apa_mp_h_stn_sofacorn_01' }, sofa2 = { 'apa_mp_h_stn_sofa2seat_02' },
    arm = { 'apa_mp_h_stn_chairarm_12', 'apa_mp_h_stn_chairarm_01' }, coffee = { 'apa_mp_h_tab_coffee_07', 'apa_mp_h_tab_coffee_08' },
    side = { 'apa_mp_h_tab_sidelrg_04' }, plant = { 'apa_mp_h_acc_plant_tall_01', 'apa_mp_h_acc_plant_palm_01' },
    lamp = { 'apa_mp_h_floorlamp_c', 'apa_mp_h_lit_floorlamp_06' }, rug = { 'apa_mp_h_acc_rugwoolm_03', 'apa_mp_h_acc_rugwooll_04' },
    art = { 'apa_mp_h_acc_artwalll_01', 'apa_mp_h_acc_artwalll_02' }, desk = { 'h4_prop_office_desk_01', 'prop_table_04' },
    exechair = { 'ex_prop_offchair_exec_01', 'prop_off_chair_01' }, offchair = { 'prop_off_chair_01', 'prop_off_chair_04' },
    monitor = { 'prop_monitor_01a', 'prop_monitor_w_large' }, laptop = { 'ex_prop_ex_laptop_01a' },
    console = { 'ex_prop_ex_console_table_01' }, offsofa = { 'ex_mp_h_off_sofa_01', 'ex_mp_h_off_sofa_02' },
    easy = { 'ex_mp_h_off_easychair_01' }, dining = { 'apa_mp_h_din_table_06', 'apa_mp_h_din_table_04' },
    dinchair = { 'apa_mp_h_din_chair_12', 'apa_mp_h_din_chair_04' }, ysofa = { 'apa_mp_h_yacht_sofa_01', 'apa_mp_h_yacht_sofa_02' },
    yarm = { 'apa_mp_h_yacht_armchair_01' }, ytable = { 'apa_mp_h_yacht_coffee_table_01' }, stool = { 'apa_mp_h_yacht_barstool_01' },
    barfridge = { 'ba_prop_battle_bar_fridge_01', 'prop_bar_fridge_01' }, tv = { 'ex_prop_ex_tv_flat_01', 'prop_tv_flat_01' },
    shelf = { 'apa_mp_h_str_shelffloorm_02' }, sideboard = { 'apa_mp_h_str_sideboardl_06', 'apa_mp_h_str_sideboardm_02' },
    vase = { 'apa_mp_h_acc_vase_flowers_01' }, bookcase = { 'apa_mp_h_str_shelffreel_01' }, counter = { 'prop_ff_counter_01' },
    coffeemac = { 'apa_mp_h_acc_coffeemachine_01' }, pendant = { 'apa_mp_h_lit_lightpendant_05' },
}
Config.Furniture = { lobby = {}, office = {}, executive = {}, skylounge = {} }
local function add(f, m, x, y, h, extra) local t = { m = m, x = x, y = y, h = h or 0.0 }; if extra then for k, v in pairs(extra) do t[k] = v end end; table.insert(Config.Furniture[f], t) end
-- LOBBY: reception, two lounges, plants, art, lamps
add('lobby', M.counter, -2.0, -7.0, 180.0); add('lobby', M.counter, 2.0, -7.0, 180.0); add('lobby', M.exechair, 0.0, -5.8, 180.0)
for _, sx in ipairs({ -1, 1 }) do
    local cx = sx * 15
    add('lobby', M.rug, cx, -13.0, 0.0); add('lobby', M.sofa, cx, -11.0, 180.0); add('lobby', M.arm, cx - 2.6, -14.5, 90.0); add('lobby', M.arm, cx + 2.6, -14.5, 270.0)
    add('lobby', M.coffee, cx, -13.2, 0.0); add('lobby', M.lamp, cx + 3.4, -11.0, 0.0); add('lobby', M.side, cx - 3.4, -11.2, 0.0)
end
for _, p in ipairs({ { -26, -18 }, { 26, -18 }, { -26, 16 }, { 26, 16 }, { -6, -20 }, { 6, -20 }, { -8, -1 }, { 8, -1 } }) do add('lobby', M.plant, p[1], p[2], 0.0) end
add('lobby', M.art, -16.0, 22.5, 180.0, { z = 2.2 }); add('lobby', M.art, 16.0, 22.5, 180.0, { z = 2.2 })
-- OFFICES: 4 rows of desks with screens and chairs, meeting table, lounge corner
for i = 0, 4 do for j = 0, 2 do
    local x, y = -16 + i * 4.2, -13 + j * 4.0
    add('office', M.desk, x, y, 0.0, { name = ('d%d%d'):format(i, j) }); add('office', M.monitor, x, y + 0.2, 0.0, { on = ('d%d%d'):format(i, j) })
    add('office', M.offchair, x, y - 1.0, 0.0)
end end
add('office', M.dining, 15.0, -11.0, 90.0); for k = 0, 2 do add('office', M.dinchair, 13.8, -12.8 + k * 1.8, 270.0); add('office', M.dinchair, 16.2, -12.8 + k * 1.8, 90.0) end
add('office', M.offsofa, 15.0, 10.0, 180.0); add('office', M.easy, 12.0, 8.0, 90.0); add('office', M.coffee, 15.0, 8.2, 0.0); add('office', M.tv, 15.0, 12.6, 180.0, { z = 1.2 })
for _, p in ipairs({ { -21, 14 }, { -21, -16 }, { 21, -16 }, { 8, 14 } }) do add('office', M.plant, p[1], p[2], 0.0) end
add('office', M.coffeemac, -18.0, 13.5, 180.0, { z = 0.9 }); add('office', M.sideboard, -18.0, 14.2, 180.0)
-- EXECUTIVE: big desk, exec chair, lounge, bookcase, art
add('executive', M.rug, 0.0, -11.0, 0.0); add('executive', M.desk, 0.0, -12.0, 0.0, { name = 'exd' }); add('executive', M.laptop, 0.0, -12.0, 180.0, { on = 'exd' })
add('executive', M.exechair, 0.0, -13.4, 0.0); add('executive', M.dinchair, -0.8, -10.6, 180.0); add('executive', M.dinchair, 0.8, -10.6, 180.0)
add('executive', M.offsofa, -14.0, -11.0, 90.0); add('executive', M.easy, -10.5, -13.0, 270.0); add('executive', M.coffee, -12.0, -11.0, 0.0)
add('executive', M.bookcase, 14.0, 4.0, 270.0); add('executive', M.sideboard, 14.0, -6.0, 270.0); add('executive', M.vase, 14.0, -6.0, 270.0, { z = 0.85 })
add('executive', M.tv, -18.5, 2.0, 90.0, { z = 1.3 }); add('executive', M.dining, 8.0, 10.0, 0.0); for k = 0, 3 do add('executive', M.dinchair, 6.5 + (k % 2) * 3.0, 9.0 + (k // 2) * 2.0, (k // 2) == 0 and 0.0 or 180.0) end
for _, p in ipairs({ { -20, -16 }, { 20, -16 }, { -20, 14 }, { 20, 14 } }) do add('executive', M.plant, p[1], p[2], 0.0) end
-- SKY LOUNGE (top of the tall tower, centre x = -13): bar, sofas, stools
add('skylounge', M.barfridge, -13.0, 12.6, 180.0); add('skylounge', M.counter, -14.0, 10.6, 180.0); add('skylounge', M.counter, -12.0, 10.6, 180.0)
for k = 0, 3 do add('skylounge', M.stool, -15.6 + k * 1.1, 9.6, 0.0) end
add('skylounge', M.ysofa, -16.0, -4.0, 90.0); add('skylounge', M.ysofa, -10.0, -4.0, 270.0); add('skylounge', M.ytable, -13.0, -4.0, 0.0)
add('skylounge', M.yarm, -13.0, -8.5, 0.0); add('skylounge', M.yarm, -13.0, 0.5, 180.0); add('skylounge', M.rug, -13.0, -4.0, 0.0)
for _, p in ipairs({ { -20.5, -13 }, { -5.5, -13 }, { -20.5, 13 }, { -5.5, 4 } }) do add('skylounge', M.plant, p[1], p[2], 0.0) end
