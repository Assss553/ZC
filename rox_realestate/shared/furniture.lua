--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

-- Furniture shop catalog. model = GTA prop name, price = cost per piece.
FurnitureCategories = {
    -- ROX build pieces (rox_houses/stream/rox_build): build the inside of the empty open houses
    { key = 'walls',       label = 'Walls',            labelAr = 'جدران',          icon = 'building' },
    { key = 'floors',      label = 'Floors & Tiles',   labelAr = 'أرضيات وبلاط',   icon = 'box' },
    { key = 'levels',      label = 'Stairs & Levels',  labelAr = 'درج وأدوار',     icon = 'building' },
    { key = 'doors',       label = 'Doors & Windows',  labelAr = 'أبواب وشبابيك',  icon = 'door' },
    { key = 'bathroom',    label = 'Bathroom',    labelAr = 'الحمام',      icon = 'bath' },
    { key = 'bed',         label = 'Bed',         labelAr = 'غرف النوم',   icon = 'bed' },
    { key = 'chair',       label = 'Chair & Sofa',labelAr = 'كراسي وكنب',  icon = 'chair' },
    { key = 'table',       label = 'Tables',      labelAr = 'طاولات',      icon = 'table' },
    { key = 'decorations', label = 'Decorations', labelAr = 'ديكورات',     icon = 'plant' },
    { key = 'electronic',  label = 'Electronic',  labelAr = 'إلكترونيات',  icon = 'tv' },
    { key = 'kitchen',     label = 'Kitchen',     labelAr = 'المطبخ',      icon = 'kitchen' },
    { key = 'light',       label = 'Light',       labelAr = 'إضاءة',       icon = 'light' },
    { key = 'storage',     label = 'Storage',     labelAr = 'تخزين',       icon = 'box' },
}

FurnitureCatalog = {
    -- Bathroom
    { model = 'prop_sink_02',            label = 'Bathroom Sink (Rounded)',   cat = 'bathroom', price = 280 },
    { model = 'prop_sink_04',            label = 'Bathroom Sink (Pedestal)',  cat = 'bathroom', price = 250 },
    { model = 'prop_sink_06',            label = 'Bathroom Sink (Wall)',      cat = 'bathroom', price = 400 },
    { model = 'prop_sink_05',            label = 'Metal Sink',                cat = 'bathroom', price = 300 },
    { model = 'prop_toilet_01',          label = 'Toilet',                    cat = 'bathroom', price = 350 },
    { model = 'prop_toilet_02',          label = 'Toilet (Modern)',           cat = 'bathroom', price = 450 },
    { model = 'prop_shower_rack_01',     label = 'Shower Rack',               cat = 'bathroom', price = 80 },
    { model = 'prop_towel_rail_02',      label = 'Towel Rail',                cat = 'bathroom', price = 60 },
    { model = 'prop_handdry_01',         label = 'Hand Dryer',                cat = 'bathroom', price = 120 },
    { model = 'prop_soap_disp_01',       label = 'Soap Dispenser',            cat = 'bathroom', price = 50 },

    -- Bed
    { model = 'p_lestersbed_s',          label = 'Double Bed (Classic)',      cat = 'bed', price = 900 },
    { model = 'p_mbbed_s',               label = 'Master Bed',                cat = 'bed', price = 2500 },
    { model = 'v_res_msonbed_s',         label = 'Single Bed',                cat = 'bed', price = 700 },
    { model = 'apa_mp_h_bed_double_08',  label = 'Modern Double Bed',         cat = 'bed', price = 3200 },
    { model = 'apa_mp_h_bed_double_09',  label = 'Modern Double Bed (Dark)',  cat = 'bed', price = 3200 },
    { model = 'apa_mp_h_bed_wide_05',    label = 'Wide Bed',                  cat = 'bed', price = 3800 },
    { model = 'apa_mp_h_yacht_bed_01',   label = 'Luxury Bed',                cat = 'bed', price = 5200 },

    -- Chairs & Sofas
    { model = 'prop_couch_01',           label = 'Leather Couch',             cat = 'chair', price = 1200 },
    { model = 'prop_couch_03',           label = 'Fabric Couch',              cat = 'chair', price = 950 },
    { model = 'prop_couch_lg_02',        label = 'Large Couch',               cat = 'chair', price = 1600 },
    { model = 'apa_mp_h_stn_sofacorn_01',label = 'Corner Sofa',               cat = 'chair', price = 2600 },
    { model = 'apa_mp_h_stn_sofa2seat_02',label= 'Two Seat Sofa',             cat = 'chair', price = 1800 },
    { model = 'apa_mp_h_stn_chairarm_01',label = 'Armchair',                  cat = 'chair', price = 750 },
    { model = 'apa_mp_h_stn_chairarm_12',label = 'Armchair (Modern)',         cat = 'chair', price = 850 },
    { model = 'apa_mp_h_din_chair_04',   label = 'Dining Chair',              cat = 'chair', price = 220 },
    { model = 'apa_mp_h_din_chair_12',   label = 'Dining Chair (Modern)',     cat = 'chair', price = 260 },
    { model = 'prop_off_chair_01',       label = 'Office Chair',              cat = 'chair', price = 300 },
    { model = 'prop_bar_stool_01',       label = 'Bar Stool',                 cat = 'chair', price = 140 },
    { model = 'prop_armchair_01',        label = 'Old Armchair',              cat = 'chair', price = 400 },

    -- Tables
    { model = 'apa_mp_h_din_table_04',   label = 'Dining Table',              cat = 'table', price = 1100 },
    { model = 'apa_mp_h_din_table_06',   label = 'Dining Table (Glass)',      cat = 'table', price = 1400 },
    { model = 'apa_mp_h_tab_coffee_07',  label = 'Coffee Table',              cat = 'table', price = 500 },
    { model = 'apa_mp_h_tab_coffee_08',  label = 'Coffee Table (Wood)',       cat = 'table', price = 550 },
    { model = 'apa_mp_h_tab_sidelrg_04', label = 'Side Table',                cat = 'table', price = 320 },
    { model = 'prop_table_03',           label = 'Simple Table',              cat = 'table', price = 200 },
    { model = 'prop_ld_farm_table01',    label = 'Farm Table',                cat = 'table', price = 380 },

    -- Decorations
    { model = 'prop_plant_int_01a',      label = 'Indoor Plant',              cat = 'decorations', price = 120 },
    { model = 'prop_plant_int_02a',      label = 'Indoor Plant (Tall)',       cat = 'decorations', price = 160 },
    { model = 'prop_plant_int_03a',      label = 'Indoor Plant (Bush)',       cat = 'decorations', price = 140 },
    { model = 'apa_mp_h_acc_vase_01',    label = 'Vase',                      cat = 'decorations', price = 90 },
    { model = 'apa_mp_h_acc_rugwoolm_03',label = 'Wool Rug',                  cat = 'decorations', price = 450 },
    { model = 'apa_mp_h_acc_artwalll_01',label = 'Wall Art',                  cat = 'decorations', price = 700 },
    { model = 'apa_mp_h_acc_plant_tall_01',label = 'Tall Plant',              cat = 'decorations', price = 220 },
    { model = 'prop_pooltable_02',       label = 'Pool Table',                cat = 'decorations', price = 2800 },
    { model = 'prop_dart_bd_cab_01',     label = 'Dart Board',                cat = 'decorations', price = 260 },

    -- Electronic
    { model = 'prop_tv_flat_01',         label = 'Flat TV (Large)',           cat = 'electronic', price = 1500 },
    { model = 'prop_tv_flat_02',         label = 'Flat TV',                   cat = 'electronic', price = 900 },
    { model = 'prop_tv_flat_michael',    label = 'Flat TV (Wall)',            cat = 'electronic', price = 1300 },
    { model = 'prop_tv_03',              label = 'Old TV',                    cat = 'electronic', price = 300 },
    { model = 'prop_laptop_01a',         label = 'Laptop',                    cat = 'electronic', price = 800 },
    { model = 'prop_pc_01a',             label = 'Computer',                  cat = 'electronic', price = 1000 },
    { model = 'prop_monitor_w_large',    label = 'Large Monitor',             cat = 'electronic', price = 450 },
    { model = 'prop_speaker_06',         label = 'Speaker',                   cat = 'electronic', price = 350 },
    { model = 'prop_boombox_01',         label = 'Boombox',                   cat = 'electronic', price = 200 },
    { model = 'prop_console_01',         label = 'Game Console',              cat = 'electronic', price = 500 },

    -- Kitchen
    { model = 'prop_fridge_01',          label = 'Fridge',                    cat = 'kitchen', price = 900 },
    { model = 'prop_fridge_03',          label = 'Fridge (Steel)',            cat = 'kitchen', price = 1200 },
    { model = 'prop_cooker_03',          label = 'Cooker',                    cat = 'kitchen', price = 800 },
    { model = 'prop_micro_01',           label = 'Microwave',                 cat = 'kitchen', price = 180 },
    { model = 'prop_micro_02',           label = 'Microwave (Steel)',         cat = 'kitchen', price = 220 },
    { model = 'prop_kettle',             label = 'Kettle',                    cat = 'kitchen', price = 40 },
    { model = 'prop_toaster_01',         label = 'Toaster',                   cat = 'kitchen', price = 45 },
    { model = 'prop_coffee_mac_02',      label = 'Coffee Machine',            cat = 'kitchen', price = 260 },
    { model = 'prop_ff_sink_02',         label = 'Kitchen Sink',              cat = 'kitchen', price = 380 },

    -- Light
    { model = 'apa_mp_h_floorlamp_a',    label = 'Floor Lamp',                cat = 'light', price = 180 },
    { model = 'apa_mp_h_floorlamp_b',    label = 'Floor Lamp (Arc)',          cat = 'light', price = 220 },
    { model = 'apa_mp_h_lit_lamptable_02',label = 'Table Lamp',               cat = 'light', price = 90 },
    { model = 'apa_mp_h_lit_floorlamp_06',label = 'Floor Lamp (Modern)',      cat = 'light', price = 260 },
    { model = 'prop_wall_light_05a',     label = 'Wall Light',                cat = 'light', price = 70 },

    -- Storage
    { model = 'v_res_tre_wardrobe',      label = 'Wardrobe',                  cat = 'storage', price = 700 },
    { model = 'apa_mp_h_str_shelffloorm_02',label = 'Shelf',                  cat = 'storage', price = 420 },
    { model = 'apa_mp_h_str_sideboardl_06',label = 'Sideboard',               cat = 'storage', price = 650 },
    { model = 'prop_cabinet_01b',        label = 'Cabinet',                   cat = 'storage', price = 300 },
    { model = 'prop_tool_chest',         label = 'Tool Chest',                cat = 'storage', price = 350 },
    { model = 'p_v_43_safe_s',           label = 'Safe',                      cat = 'storage', price = 1500 },
}

FurnitureByModel = {}
for _, v in ipairs(FurnitureCatalog) do FurnitureByModel[v.model] = v end
