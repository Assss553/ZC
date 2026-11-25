--[[ ROX Towers  ·  © ROX Store – All rights reserved. ]]
Config = {}
-- Centre of the towers at street level + heading (the lobby door looks the opposite way of the heading).
-- Stand where the middle of the building should be and type /roxtowers_here (ace rox_towers.admin). Footprint 62 x 52 m.
Config.Origin = vec4(-75.0, -820.0, 326.0, 160.0)
Config.AdminAce = 'rox_towers.admin'
Config.SpawnDistance = 900.0
Config.PropFront = 180.0      -- GTA props look at -Y in model space; set 0.0 if sofas / desks face the wall
Config.Locale = 'ar'

-- Floors, room furniture and doors come from data/interior.json (generated with the models by tools/shellgen/towers_int.py).
Config.StreamRadius = 70.0          -- floors are spawned only when you are inside the tower footprint (+ this margin)
Config.FloorWindow = 9.0            -- ... and within this height of the floor
Config.KeycardAce = 'rox_towers.keycard'
Config.KeycardJobs = { police = true, sheriff = true, lspd = true, bcso = true }   -- QBCore / ESX job names that open security doors
Config.DoorModels = {               -- first model whose width fits the opening is used
    std   = { 'v_ilev_ph_gendoor004', 'v_ilev_ph_gendoor005', 'v_ilev_fib_door1' },
    glass = { 'v_ilev_fib_door2', 'v_ilev_fib_door1', 'v_ilev_ph_gendoor004' },
    sec   = { 'v_ilev_arm_secdoor', 'v_ilev_ph_gendoor006', 'v_ilev_ph_gendoor004' },
}
Config.StairsPoint = { x = 6.0, y = 13.2 }     -- emergency stairs on every mid floor

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
Config.Furniture = { skylounge = {} }   -- extra furniture (sky lounge lives in the exterior piece)
local function add(f, m, x, y, h, extra) local t = { m = m, x = x, y = y, h = h or 0.0 }; if extra then for k, v in pairs(extra) do t[k] = v end end; table.insert(Config.Furniture[f], t) end
-- SKY LOUNGE (top of the tall tower, centre x = -13): bar, sofas, stools
add('skylounge', M.barfridge, -13.0, 12.6, 180.0); add('skylounge', M.counter, -14.0, 10.6, 180.0); add('skylounge', M.counter, -12.0, 10.6, 180.0)
for k = 0, 3 do add('skylounge', M.stool, -15.6 + k * 1.1, 9.6, 0.0) end
add('skylounge', M.ysofa, -16.0, -4.0, 90.0); add('skylounge', M.ysofa, -10.0, -4.0, 270.0); add('skylounge', M.ytable, -13.0, -4.0, 0.0)
add('skylounge', M.yarm, -13.0, -8.5, 0.0); add('skylounge', M.yarm, -13.0, 0.5, 180.0); add('skylounge', M.rug, -13.0, -4.0, 0.0)
for _, p in ipairs({ { -20.5, -13 }, { -5.5, -13 }, { -20.5, 13 }, { -5.5, 4 } }) do add('skylounge', M.plant, p[1], p[2], 0.0) end
