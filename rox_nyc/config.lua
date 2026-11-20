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
    -- restaurant terraces
    rtable   = { 'prop_table_03', 'prop_table_01' },
    rchair   = { 'prop_chair_04a', 'prop_chair_01a', 'prop_chair_08' },
    parasol  = { 'prop_parasol_04', 'prop_parasol_01' },
    heater   = { 'prop_patio_heater_01' },
}

-- GTA props used to furnish the walk-in shops (first available model of each list)
Config.PropFront = 180.0     -- props look at -Y in their model space; try 0.0 if counters face the wall in your build
Config.ShopProps = {
    shelf    = { 'v_ret_247shelves01', 'v_ret_247shelves02', 'v_ret_247shelves03', 'prop_ff_shelves_01' },
    shelf2   = { 'v_ret_247shelves04', 'v_ret_247shelves05', 'v_ret_247shelves02' },
    fridge   = { 'prop_bar_fridge_03', 'prop_bar_fridge_01', 'prop_fridge_01' },
    bigfridge= { 'prop_vend_fridge01', 'v_res_fridgemoda', 'prop_fridge_01' },
    counter  = { 'prop_ff_counter_01', 'prop_ff_counter_02' },
    counter2 = { 'prop_ff_counter_02', 'prop_ff_counter_03', 'prop_ff_counter_01' },
    till     = { 'prop_till_01', 'prop_till_02' },
    cigs     = { 'v_ret_247_cigs' },
    lottery  = { 'v_ret_247_lotterysign', 'v_ret_247_lottery' },
    sweets   = { 'v_ret_247_sweetcount' },
    oven     = { 'prop_pizza_oven_01' },
    pizzabox = { 'prop_pizza_box_02', 'prop_pizza_box_01' },
    coffee   = { 'prop_coffee_mac_02', 'prop_coffee_mac_01' },
    tray     = { 'prop_food_bs_tray_01', 'prop_food_bs_tray_02' },
    table    = { 'prop_table_03', 'prop_table_01' },
    chair    = { 'apa_mp_h_din_chair_12', 'prop_chair_04a', 'prop_chair_01a' },
    stool    = { 'prop_bar_stool_01', 'apa_mp_h_yacht_barstool_01' },
    pump     = { 'prop_bar_pump_01', 'prop_bar_pump_06' },
    plant    = { 'apa_mp_h_acc_plant_tall_01', 'prop_plant_int_01a' },
    display  = { 'prop_display_unit_01', 'prop_display_unit_02' },
    bin      = { 'prop_bin_05a', 'prop_bin_08a' },
}

-- What every shop sells. item = inventory item name (ESX / QB / ox_inventory), price in $.
Config.Shop = {
    deli = { title = 'Deli 24H', items = {
        { item = 'water', label = 'Water', labelAr = 'مويه', price = 3 }, { item = 'sandwich', label = 'Sandwich', labelAr = 'ساندويتش', price = 8 },
        { item = 'chips', label = 'Chips', labelAr = 'شيبس', price = 4 }, { item = 'cola', label = 'Cola', labelAr = 'كولا', price = 4 },
        { item = 'coffee', label = 'Coffee', labelAr = 'قهوة', price = 5 }, { item = 'phone', label = 'Phone', labelAr = 'جوال', price = 450 },
        { item = 'lighter', label = 'Lighter', labelAr = 'ولاعة', price = 3 } } },
    pharmacy = { title = 'Pharmacy', items = {
        { item = 'bandage', label = 'Bandage', labelAr = 'ضماد', price = 25 }, { item = 'painkillers', label = 'Painkillers', labelAr = 'مسكن', price = 40 },
        { item = 'firstaid', label = 'First aid kit', labelAr = 'حقيبة إسعاف', price = 150 }, { item = 'water', label = 'Water', labelAr = 'مويه', price = 3 } } },
    pizza = { title = 'Pizza', items = {
        { item = 'pizza_slice', label = 'Pizza slice', labelAr = 'قطعة بيتزا', price = 6 }, { item = 'pizza', label = 'Whole pizza', labelAr = 'بيتزا كاملة', price = 22 },
        { item = 'cola', label = 'Cola', labelAr = 'كولا', price = 4 }, { item = 'water', label = 'Water', labelAr = 'مويه', price = 3 } } },
    burger = { title = 'Burger', items = {
        { item = 'burger', label = 'Burger', labelAr = 'برقر', price = 12 }, { item = 'fries', label = 'Fries', labelAr = 'بطاطس', price = 5 },
        { item = 'cola', label = 'Cola', labelAr = 'كولا', price = 4 }, { item = 'milkshake', label = 'Milkshake', labelAr = 'ميلك شيك', price = 7 } } },
    cafe = { title = 'Coffee', items = {
        { item = 'coffee', label = 'Coffee', labelAr = 'قهوة', price = 5 }, { item = 'latte', label = 'Latte', labelAr = 'لاتيه', price = 7 },
        { item = 'donut', label = 'Donut', labelAr = 'دونات', price = 4 }, { item = 'croissant', label = 'Croissant', labelAr = 'كرواسون', price = 5 } } },
    bar = { title = 'Bar', items = {
        { item = 'water', label = 'Water', labelAr = 'مويه', price = 3 }, { item = 'cola', label = 'Cola', labelAr = 'كولا', price = 4 },
        { item = 'juice', label = 'Orange juice', labelAr = 'عصير برتقال', price = 5 }, { item = 'mojito', label = 'Mint mojito (no alcohol)', labelAr = 'موهيتو نعناع', price = 9 } } },
}
Config.Framework = 'auto'    -- auto | esx | qb | standalone
Config.MaxPerItem = 10
Config.Locale = 'ar'
