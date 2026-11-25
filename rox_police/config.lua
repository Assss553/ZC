--[[ ROX Police HQ  ·  © ROX Store – All rights reserved. ]]
Config = {}
-- Centre of the building at street level + heading. Stand there and type /roxpolice_here (ace rox_police.admin).
-- Footprint 49 x 35 m, entrance on the local -Y side.
Config.Origin = vec4(-600.0, -320.0, 34.9, 0.0)
Config.AdminAce = 'rox_police.admin'
Config.SpawnDistance = 400.0
Config.PropFront = 180.0      -- set 0.0 if the chairs / desks face the wall in your build
Config.Locale = 'ar'
Config.Models = { 'rox_police_hq' }

-- stairs teleport: inside (west end of the corridor) <-> roof helipad
Config.Floors = {
    { key = 'ground', label = 'Station', labelAr = 'المركز', z = 0.0, ex = -22.5, ey = -3.0 },
    { key = 'roof',   label = 'Roof helipad', labelAr = 'مهبط الهليكوبتر', z = 4.6, ex = 0.0, ey = 4.0 },
}

-- heading: 0 = looks to local -Y (towards the entrance), 90 = +X, 180 = +Y, 270 = -X
local M = {
    chair = { 'v_corp_offchair', 'prop_off_chair_01' }, exec = { 'ex_prop_offchair_exec_01', 'prop_off_chair_01' }, fold = { 'prop_off_chair_04', 'prop_cs_folding_chair_01' },
    desk = { 'h4_prop_office_desk_01', 'prop_table_04' }, monitor = { 'prop_monitor_01a' }, laptop = { 'ex_prop_ex_laptop_01a' },
    bench = { 'v_ilev_ph_bench', 'prop_wait_bench_01' }, plant = { 'apa_mp_h_acc_plant_tall_01', 'prop_plant_int_02a' },
    flagus = { 'prop_flag_us' }, flagls = { 'prop_flag_lsservices', 'prop_flag_us' }, tv = { 'prop_tv_flat_michael', 'prop_tv_flat_01' },
    conf = { 'v_corp_conftable' }, lect = { 'v_ilev_cd_lampal' }, cam = { 'prop_tv_cam_02', 'prop_pap_camera_01' },
    locker = { 'p_cs_locker_01_s', 'p_cs_locker_01' }, cooler = { 'prop_watercooler' }, weapons = { 'v_ilev_gc_weapons' },
    toilet = { 'prop_ld_toilet_01', 'prop_toilet_01' }, sink = { 'prop_sink_06' }, files = { 'prop_fbibombfile' }, boxes = { 'prop_cs_cardbox_01' },
    sofa = { 'ex_mp_h_off_sofa_01', 'apa_mp_h_stn_sofacorn_05' }, coffee = { 'apa_mp_h_tab_coffee_07' }, cctv = { 'prop_cctv_cam_01a' },
    bin = { 'prop_bin_08open' }, idboard = { 'prop_police_id_board' }, shelf = { 'apa_mp_h_str_shelffloorm_02' }, bed = { 'v_res_msonbed', 'v_res_mbbed' },
}
Config.Furniture = { ground = {}, roof = {} }
local function add(m, x, y, h, extra) local t = { m = m, x = x, y = y, h = h or 0.0 }; if extra then for k, v in pairs(extra) do t[k] = v end end; table.insert(Config.Furniture.ground, t) end

-- LOBBY: officers behind the counter, waiting benches, flags, plants
add(M.chair, -1.5, -7.4, 0.0); add(M.chair, 1.5, -7.4, 0.0)
add(M.monitor, -1.5, -8.6, 0.0, { z = 1.16 }); add(M.monitor, 1.5, -8.6, 0.0, { z = 1.16 })
add(M.bench, -6.0, -12.5, 90.0); add(M.bench, -6.0, -15.0, 90.0); add(M.bench, 6.0, -12.5, 270.0); add(M.bench, 6.0, -15.0, 270.0)
add(M.flagus, -4.5, -5.8, 180.0); add(M.flagls, 4.5, -5.8, 180.0)
for _, p in ipairs({ { -7.2, -16.2 }, { 7.2, -16.2 }, { -7.2, -6.0 }, { 7.2, -6.0 } }) do add(M.plant, p[1], p[2], 0.0) end
add(M.cooler, 7.3, -10.0, 270.0); add(M.cctv, 7.6, -5.4, 225.0, { z = 3.6 })

-- BRIEFING: lectern + flags at the west wall, 4 rows x 6 chairs facing west, screen
add(M.lect, -21.2, -11.6, 270.0); add(M.flagus, -23.3, -13.4, 270.0); add(M.flagls, -23.3, -7.4, 270.0)
add(M.tv, -23.8, -11.0, 270.0, { z = 2.0 })
for r = 0, 3 do for c = 0, 5 do add(M.fold, -18.0 + r * 1.6, -14.5 + c * 1.3, 270.0) end end
add(M.cam, -11.0, -11.0, 270.0)

-- BULLPEN: 3 x 3 desks with screens and chairs, files, plants
for i = 0, 2 do for j = 0, 2 do
    local x, y = 11.5 + i * 4.2, -14.5 + j * 3.4
    add(M.desk, x, y, 0.0, { name = ('b%d%d'):format(i, j) }); add(M.monitor, x, y + 0.2, 0.0, { on = ('b%d%d'):format(i, j) }); add(M.chair, x, y - 1.0, 0.0)
end end
add(M.files, 23.4, -12.0, 270.0); add(M.files, 23.4, -11.0, 270.0); add(M.tv, 23.8, -8.0, 270.0, { z = 1.6 }); add(M.plant, 23.0, -16.2, 0.0)

-- OFFICES (west): desk, exec chair, guest chairs, shelf, plant
for _, y in ipairs({ 3.5, 12.5 }) do
    add(M.desk, -18.0, y, 90.0, { name = 'o' .. y }); add(M.laptop, -18.0, y, 270.0, { on = 'o' .. y })
    add(M.exec, -19.1, y, 90.0); add(M.chair, -16.6, y - 0.7, 270.0); add(M.chair, -16.6, y + 0.7, 270.0)
    add(M.shelf, -13.0, y, 270.0); add(M.plant, -23.2, y + 3.5, 0.0)
end

-- BOOKING / MUGSHOT: camera on tripod facing the height chart, booking desk
add(M.cam, -7.5, 3.6, 270.0); add(M.idboard, -11.4, 3.6, 90.0, { z = 0.0 })
add(M.desk, -6.0, 6.5, 180.0, { name = 'bk' }); add(M.monitor, -6.0, 6.3, 180.0, { on = 'bk' }); add(M.chair, -6.0, 7.4, 180.0)

-- INTERROGATION: table + 3 chairs, camera in the corner
add(M.conf, -8.0, 13.0, 0.0); add(M.chair, -8.0, 14.4, 180.0); add(M.chair, -8.6, 11.6, 0.0); add(M.chair, -7.4, 11.6, 0.0)
add(M.cctv, -4.6, 16.6, 135.0, { z = 3.4 })

-- CELLS: bed + toilet in every cell (east of the bars), desk for the guard
for k = 0, 3 do
    local y0 = -0.9 + k * 4.475
    add(M.toilet, 7.0, y0 + 3.6, 90.0)
end
add(M.desk, -1.5, 2.0, 90.0, { name = 'cg' }); add(M.monitor, -1.5, 2.0, 90.0, { on = 'cg' }); add(M.chair, -2.4, 2.0, 90.0)

-- LOCKERS: two rows of lockers, benches, weapons rack
for k = 0, 7 do add(M.locker, 11.0 + k * 0.62, 7.4, 180.0); add(M.locker, 11.0 + k * 0.62, -0.4, 0.0) end
add(M.bench, 14.0, 3.5, 0.0); add(M.weapons, 23.6, 3.5, 270.0)

-- CHIEF OFFICE: big desk, exec chair, sofa, flags, plants
add(M.desk, 18.0, 13.5, 180.0, { name = 'ch' }); add(M.laptop, 18.0, 13.5, 0.0, { on = 'ch' })
add(M.exec, 18.0, 14.6, 180.0); add(M.chair, 17.3, 12.2, 0.0); add(M.chair, 18.7, 12.2, 0.0)
add(M.flagus, 16.2, 16.4, 180.0); add(M.flagls, 19.8, 16.4, 180.0)
add(M.sofa, 11.2, 12.0, 90.0); add(M.coffee, 12.8, 12.0, 0.0); add(M.plant, 23.2, 9.0, 0.0); add(M.plant, 10.8, 16.4, 0.0)
