--[[ ROX NYC  ·  © ROX Store – All rights reserved. ]]
Config = {}
-- Centre of the crossroads at street level + heading. The map is 160 x 160 m, put it on a big flat empty area
-- (or stand in the middle of one and type /roxnyc_here — ace rox_nyc.admin; saved on the server).
Config.Origin = vec4(-1500.0, -3000.0, 13.95, 0.0)
Config.AdminAce = 'rox_nyc.admin'
Config.SpawnDistance = 450.0

Config.ParkedCars = true          -- frozen, locked parked cars along the kerbs (local, not networked)
Config.CarModels  = { 'taxi', 'taxi', 'stanier', 'primo', 'washington', 'asterope', 'emperor', 'intruder' }
Config.CarChance  = 0.55
Config.Steam      = true          -- steam out of the manholes (night or day)
Config.Blip       = { sprite = 475, color = 46, scale = 0.8, label = 'ROX NYC' }

-- Real GTA props (names checked against the game object list). First available model of each list is used.
Config.Props = {
    lamp     = { 'prop_streetlight_01', 'prop_streetlight_03', 'prop_streetlight_04' },
    traffic  = { 'prop_traffic_01a', 'prop_traffic_03a', 'prop_traffic_01b' },
    tree     = { 'prop_tree_lficus_02', 'prop_tree_birch_02', 'prop_tree_maple_02', 'prop_tree_lficus_03' },
    hydrant  = { 'prop_fire_hydrant_1', 'prop_fire_hydrant_2' },
    news     = { 'prop_news_disp_02a', 'prop_news_disp_02c', 'prop_news_disp_03a', 'prop_news_disp_02e' },
    bin      = { 'prop_bin_07a', 'prop_bin_07b', 'prop_bin_05a' },
    bench    = { 'prop_bench_01a', 'prop_bench_05', 'prop_bench_06' },
    phone    = { 'prop_phonebox_04', 'prop_phonebox_01a' },
    post     = { 'prop_postbox_01a' },
    hotdog   = { 'prop_hotdogstand_01' },
    bollard  = { 'prop_bollard_02a', 'prop_bollard_01a' },
    dumpster = { 'prop_dumpster_01a', 'prop_dumpster_02a' },
    cone     = { 'prop_roadcone02a', 'prop_mp_cone_01' },
    busstop  = { 'prop_busstop_02', 'prop_busstop_04' },
    sign     = { 'prop_sign_road_01a', 'prop_sign_road_03a' },
}
