-- ROX Store | All rights reserved
Config = {}
Config.AdminAce   = 'rox.streets'   -- add_ace group.admin rox.streets allow
Config.StreamDist = 250.0            -- trees are spawned locally inside this distance
Config.CellSize   = 100.0

-- Tree sets (vanilla GTA V models; models that don't exist in your game build are skipped automatically)
Config.Sets = {
    blossom = { 'prop_tree_jacada_01', 'prop_tree_jacada_02' },                      -- purple/pink jacaranda
    green   = { 'prop_tree_olive_01', 'prop_tree_maple_02', 'prop_tree_maple_03', 'prop_tree_birch_01' },
    palms   = { 'prop_palm_med_01a', 'prop_palm_med_01b', 'prop_palm_sm_01e', 'prop_palm_fan_03_c' },
    mixed   = { 'prop_tree_jacada_01', 'prop_tree_jacada_02', 'prop_tree_olive_01', 'prop_palm_med_01b' },
    bushes  = { 'prop_bush_lrg_04b', 'prop_bush_lrg_04c', 'prop_bush_med_03' },
    decor   = { 'prop_bench_01a', 'prop_bench_05', 'prop_streetlight_01', 'prop_bin_01a', 'prop_planter_01' },
}

Config.Generate = {
    spacing    = 12.0,   -- metres between trees on the same side
    edge       = 2.2,    -- metres from the road edge onto the sidewalk
    maxNodes   = 1500,   -- road nodes scanned per run
    maxSlope   = 2.5,    -- max height difference between road and tree spot
    clearance  = 7.0,    -- free space above the spot (avoids bridges / buildings)
    bushChance = 0.35,   -- chance to also add a bush between two trees
}
