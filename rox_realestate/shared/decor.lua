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
}

-- styles the owner can pick from the iPad (property page)
DecorStyles = {
    logistics = {
        label = 'Logistics Hub', labelAr = 'مركز لوجستي',
        racks = true, rackGap = 3.2, crossAisle = true, dock = true, dockDensity = 0.7, office = true, workshop = true,
        light = { 255, 236, 205 }, lightRange = 11.0, lightIntensity = 1.6,
    },
    storage = {
        label = 'Dense Storage', labelAr = 'تخزين كثيف',
        racks = true, rackGap = 2.6, crossAisle = true, dock = true, dockDensity = 0.95, office = true, workshop = false,
        light = { 230, 240, 255 }, lightRange = 10.0, lightIntensity = 1.4,
    },
    workshop = {
        label = 'Workshop Garage', labelAr = 'ورشة وكراج',
        racks = false, wallRacks = true, dock = false, office = true, workshop = true, garage = true,
        light = { 255, 222, 180 }, lightRange = 12.0, lightIntensity = 1.8,
    },
    off = { label = 'Empty', labelAr = 'فاضي' },
}

DecorDefaultStyle = 'logistics'

function DecorStylesForUI()
    local out = {}
    for key, s in pairs(DecorStyles) do out[#out + 1] = { key = key, label = s.label, labelAr = s.labelAr } end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end
