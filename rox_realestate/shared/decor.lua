--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

--[[
    ROX WAREHOUSE DESIGNS
    ---------------------
    A warehouse design is generated inside the interior when someone enters:
    the client measures the room (walls, floor, ceiling) with ray casts, then lays out zones:

        [ENTRY]  clear entrance · fire safety · CCTV
        [OFFICE] desk, monitors, filing, coffee corner        |  [WORKSHOP] workbench, tools, generator, gas
        [RACKS]  pallet racking rows with aisles and a cross aisle
        [DOCK]   pallet stacks, crates, forklift lane, hand trucks, cones

    Every spot is box-tested so nothing is placed inside walls or other props, and the layout is
    seeded with the property id: every player in the same warehouse sees exactly the same design.
    Each role lists several prop models; models that are not in the game are skipped automatically.
]]

DecorProps = {
    rack        = { 'prop_warehseshelf01', 'prop_warehseshelf02', 'prop_warehseshelf03' },
    pallet      = { 'prop_boxpile_07a', 'prop_boxpile_07d', 'prop_boxpile_06a', 'prop_boxpile_06b', 'prop_boxpile_05a',
                    'prop_boxpile_04a', 'prop_boxpile_03a', 'prop_boxpile_02b', 'prop_pallet_pile_01', 'prop_pallet_pile_02',
                    'prop_mb_crate_01a', 'prop_mb_crate_01b' },
    crate       = { 'ex_prop_crate_closed_bc', 'ex_prop_crate_elec_sc', 'ex_prop_crate_wlife_bc', 'ex_prop_crate_art_02_bc',
                    'ex_prop_crate_tob_sc', 'prop_mil_crate_01', 'prop_mil_crate_02', 'prop_box_wood05a', 'prop_box_wood02a',
                    'prop_cratepile_07a' },
    emptyPallet = { 'prop_pallet_02a', 'prop_pallet_01a', 'prop_pallet_03a' },
    handtruck   = { 'prop_sacktruck_02a', 'prop_sacktruck_01', 'prop_pallettruck_01' },
    forklift    = { 'forklift' },                       -- vehicle, spawned frozen and locked

    desk        = { 'prop_office_desk_01', 'prop_tablesmall_01' },
    officeChair = { 'prop_off_chair_04', 'prop_off_chair_01', 'prop_off_chair_05' },
    monitor     = { 'prop_monitor_01b', 'prop_monitor_w_large', 'prop_monitor_02' },
    laptop      = { 'prop_laptop_01a' },
    printer     = { 'prop_printer_01', 'prop_printer_02' },
    filecab     = { 'prop_filecab_01', 'prop_cabinet_01b' },
    cooler      = { 'prop_watercooler', 'prop_watercooler_dark' },
    vending     = { 'prop_vend_coffe_01', 'prop_vend_soda_01', 'prop_vend_snak_01' },
    plant       = { 'prop_plant_int_03a', 'prop_plant_int_02a' },
    bin         = { 'prop_bin_08a', 'prop_bin_07a', 'prop_bin_05a' },
    safe        = { 'p_v_43_safe_s' },
    sofa        = { 'prop_couch_04', 'prop_couch_03' },

    bench       = { 'prop_tool_bench02', 'prop_tool_bench02_ld' },
    toolchest   = { 'prop_toolchest_05', 'prop_toolchest_04', 'prop_toolchest_03', 'prop_tool_chest' },
    generator   = { 'prop_generator_03b', 'prop_generator_01a', 'prop_generator_02a' },
    gas         = { 'prop_gascyl_01a', 'prop_gascyl_02a', 'prop_gascyl_03a' },
    barrel      = { 'prop_barrel_pile_01', 'prop_barrel_02a', 'prop_barrel_01a', 'prop_barrel_03a' },
    ladder      = { 'prop_byard_ladder01' },
    tyres       = { 'prop_rub_tyre_01', 'prop_tyre_rack_01', 'prop_rub_tyre_03' },
    compressor  = { 'prop_compressor_03', 'prop_compressor_02' },
    hoist       = { 'prop_engine_hoist' },
    oil         = { 'prop_oilcan_01a', 'prop_oilcan_02a' },

    extinguisher= { 'prop_fire_exting_1a', 'prop_fire_exting_1b' },
    cone        = { 'prop_roadcone02a', 'prop_mp_cone_01', 'prop_roadcone01a' },
    barrier     = { 'prop_barrier_work05', 'prop_barrier_work06a' },
    cctv        = { 'prop_cctv_cam_01a', 'prop_cctv_cam_05a', 'prop_cctv_cam_04a' },
    worklight   = { 'prop_worklight_03b', 'prop_worklight_04c', 'prop_worklight_02a' },
    lamp        = { 'prop_ind_light_04', 'prop_ind_light_02a', 'prop_ind_light_03c' },

    -- building details (empty detailed design)
    keypad      = { 'prop_ld_keypad_01b', 'prop_ld_keypad_01' },
    elecbox     = { 'prop_elecbox_02a', 'prop_elecbox_03a', 'prop_elecbox_09', 'prop_elecbox_01a' },
    riser       = { 'prop_fire_driser_1a', 'prop_fire_driser_1b' },
    hosereel    = { 'prop_fire_hosereel', 'prop_fire_hosebox_01' },
    firstaid    = { 'prop_ld_health_pack', 'prop_ld_firstaid' },
    walllight   = { 'prop_wall_light_09a', 'prop_wall_light_03a', 'prop_wall_light_05a' },
    alarm       = { 'prop_ld_alarm_01', 'prop_fire_alarm_01' },
    vent        = { 'prop_wall_vent_02', 'prop_wall_vent_01', 'prop_aircon_m_04' },
    bucket      = { 'prop_cs_bucket_s', 'prop_mop_bucket_01a' },
    broom       = { 'prop_tool_broom', 'prop_cs_broom' },
    wetsign     = { 'prop_wetfloor_sign_01', 'prop_sign_wet_floor' },

    -- abandoned gang hideout
    trash       = { 'prop_rub_binbag_01', 'prop_rub_binbag_03', 'prop_rub_binbag_04', 'prop_rub_binbag_05', 'prop_rub_binbag_06',
                    'prop_rub_litter_01', 'prop_rub_litter_03', 'prop_rub_cardpile_01', 'prop_rub_cardpile_03', 'prop_rub_boxpile_01',
                    'prop_rub_boxpile_04', 'prop_rub_pile_01', 'prop_rub_pile_03' },
    planks      = { 'prop_rub_planks_01', 'prop_rub_planks_02', 'prop_rub_planks_03', 'prop_woodpile_04a' },
    mattress    = { 'prop_rub_matress_01', 'prop_rub_matress_02', 'prop_rub_matress_03', 'prop_skid_sleepbag_1' },
    oldCouch    = { 'prop_rub_couch01', 'prop_rub_couch02', 'prop_rub_couch03', 'prop_rub_couch04' },
    oldChair    = { 'prop_rub_chair01', 'prop_rub_chair02', 'prop_old_wood_chair', 'prop_chair_08' },
    crateTable  = { 'prop_box_wood01a', 'prop_box_wood03a', 'prop_cs_cardbox_01', 'prop_table_03b' },
    fireBarrel  = { 'prop_hobo_stove_01', 'prop_barrel_03d', 'prop_barrel_02b' },
    oldTv       = { 'prop_tv_06', 'prop_tv_02', 'prop_tv_04' },
    drugTable   = { 'prop_table_03', 'prop_ld_farm_table02', 'bkr_prop_weed_table_01a' },
    drugs       = { 'bkr_prop_weed_bigbag_01a', 'bkr_prop_weed_bag_01a', 'prop_weed_block_01', 'prop_coke_block_01',
                    'bkr_prop_coke_cutblock_01', 'prop_meth_bag_01', 'bkr_prop_meth_bigbag_04a' },
    cash        = { 'bkr_prop_moneypack_01a', 'prop_cash_pile_01', 'prop_cash_pile_02', 'bkr_prop_money_wrapped_01' },
    scale       = { 'bkr_prop_coke_scale_01', 'bkr_prop_weed_scales_01a' },
    weapons     = { 'prop_gun_case_01', 'prop_box_ammo04a', 'prop_box_ammo03a_set', 'prop_mil_crate_01', 'gr_prop_gr_gunsmithsupl_01a' },
    bottles     = { 'prop_amb_beer_bottle', 'prop_cs_beer_bot_01', 'prop_beer_bottle', 'prop_wine_bot_01', 'prop_vodka_bottle',
                    'prop_ecola_can', 'prop_ld_can_01', 'prop_cs_bs_cup', 'prop_food_bs_juice01' },
    dartboard   = { 'prop_dart_bd_01', 'prop_dart_bd_cab_01' },
    tyre        = { 'prop_rub_tyre_01', 'prop_rub_tyre_02', 'prop_rub_tyre_03' },
    bulb        = { 'prop_construcionlamp_01', 'prop_worklight_01a', 'prop_cs_lamp_wall' },
    radio       = { 'prop_boombox_01', 'prop_ghettoblast_02' },
    bat         = { 'prop_cs_bowie_knife', 'w_me_bat', 'prop_cs_katana_01' },
}

-- wall props whose front is their local -Y (mounted rotated 180°). Adjust if a model faces the wall.
DecorWallFlip = {
    prop_ld_keypad_01 = true, prop_ld_keypad_01b = true,
}

-- styles the owner can pick from the iPad (property page)
DecorStyles = {
    -- ===================== GANG HIDEOUT (abandoned house) =====================
    -- light = gang colour of the hideout lights
    hideout_red    = { category = 'hideout', builder = 'hideout', order = 10, label = 'Abandoned · Blood Red', labelAr = 'مهجور · أحمر', light = { 220, 40, 30 } },
    hideout_purple = { category = 'hideout', builder = 'hideout', order = 11, label = 'Abandoned · Purple',    labelAr = 'مهجور · بنفسجي', light = { 150, 40, 220 } },
    hideout_yellow = { category = 'hideout', builder = 'hideout', order = 12, label = 'Abandoned · Yellow',    labelAr = 'مهجور · أصفر', light = { 240, 190, 20 } },
    hideout_green  = { category = 'hideout', builder = 'hideout', order = 13, label = 'Abandoned · Green',     labelAr = 'مهجور · أخضر', light = { 40, 200, 70 } },
    hideout_blue   = { category = 'hideout', builder = 'hideout', order = 14, label = 'Abandoned · Blue',      labelAr = 'مهجور · أزرق', light = { 40, 110, 240 } },

    -- ===================== WAREHOUSE =====================
    -- DEFAULT: empty warehouse, fully detailed building (no stock, no furniture)
    empty = {
        label = 'ROX Empty · Detailed', labelAr = 'ROX فاضي · بالتفاصيل', order = 0,
        architecture = true, markings = true, bays = true, lightGrid = true, dust = true,
        light = { 255, 240, 220 }, lightRange = 12.0, lightIntensity = 1.2,
    },
    logistics = {
        label = 'Logistics Hub', labelAr = 'مركز لوجستي',
        racks = true, rackGap = 3.2, crossAisle = true, dock = true, dockDensity = 0.7, office = true, workshop = true,
        architecture = true, markings = true, lightGrid = false, order = 1,
        light = { 255, 236, 205 }, lightRange = 11.0, lightIntensity = 1.6,
    },
    storage = {
        label = 'Dense Storage', labelAr = 'تخزين كثيف',
        racks = true, rackGap = 2.6, crossAisle = true, dock = true, dockDensity = 0.95, office = true, workshop = false,
        architecture = true, markings = true, order = 2,
        light = { 230, 240, 255 }, lightRange = 10.0, lightIntensity = 1.4,
    },
    workshop = {
        label = 'Workshop Garage', labelAr = 'ورشة وكراج',
        racks = false, wallRacks = true, dock = false, office = true, workshop = true, garage = true,
        architecture = true, markings = true, bays = true, lightGrid = true, order = 3,
        light = { 255, 222, 180 }, lightRange = 12.0, lightIntensity = 1.8,
    },
    off = { label = 'Bare (no details)', labelAr = 'بدون أي إضافات', order = 99, category = 'any' },
}

for _, st in pairs(DecorStyles) do st.category = st.category or 'warehouse' end

DecorDefaults = { warehouse = 'empty', hideout = 'hideout_red' }
DecorDefaultStyle = 'empty'

-- interior.decor = true (warehouse) or a category name ('hideout')
function DecorCategory(interiorKey)
    local i = Interiors[interiorKey]
    if not i or not i.decor then return nil end
    return i.decor == true and 'warehouse' or i.decor
end

function DecorDefaultFor(interiorKey)
    return DecorDefaults[DecorCategory(interiorKey) or 'warehouse'] or DecorDefaultStyle
end

-- style chosen for a property, falling back to the category default
function DecorStyleFor(interiorKey, chosen)
    local cat = DecorCategory(interiorKey)
    if not cat then return nil end
    local st = chosen and DecorStyles[chosen]
    if st and (st.category == cat or st.category == 'any') then return chosen end
    return DecorDefaultFor(interiorKey)
end

function DecorStylesForUI()
    local out = {}
    for key, s in pairs(DecorStyles) do out[#out + 1] = { key = key, label = s.label, labelAr = s.labelAr, order = s.order or 9, category = s.category, color = s.builder == 'hideout' and s.light or nil } end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end
