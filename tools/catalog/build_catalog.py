# Builds rox_realestate/shared/furniture.lua from the real GTA object list (DurtyFree/gta-v-data-dumps ObjectList.ini)
#   python3 build_catalog.py <ObjectList.ini> <out furniture.lua>   (c) ROX Store
import re, sys
names = sorted(set(l.strip() for l in open(sys.argv[1]) if l.strip()))
S = set(names)
SKIP = ('_dam', '_l1', '_lod', '_slod', 'debris', '_ov', '_decal', '_shadow', '_day', 'screen', '_door', '_lid', '_skinned', '_mesh', 'emon', '_det', 'overlay', 'swag')

CATS = [  # key, en, ar, icon
    ('living', 'Living Room', 'غرفة المعيشة', 'chair'), ('bed', 'Bedroom', 'غرفة النوم', 'bed'), ('table', 'Tables', 'طاولات', 'table'),
    ('chair', 'Chairs & Stools', 'كراسي', 'chair'), ('kitchen', 'Kitchen', 'المطبخ', 'kitchen'), ('bathroom', 'Bathroom', 'الحمام', 'bath'),
    ('light', 'Lighting', 'إضاءة', 'light'), ('electronic', 'Electronics', 'إلكترونيات', 'tv'), ('storage', 'Storage', 'تخزين', 'box'),
    ('decorations', 'Decor & Art', 'ديكور ولوحات', 'plant'), ('plants', 'Plants', 'نباتات', 'plant'), ('office', 'Office', 'مكتب', 'table'),
    ('fun', 'Gym & Fun', 'رياضة وترفيه', 'tv'), ('outdoor', 'Garden', 'الحديقة', 'plant'),
]
# (category, regex on the model name, English base, Arabic base, price)
RULES = [
    ('living', r'^apa_mp_h_stn_sofacorn_\d+$', 'Corner Sofa', 'كنبة زاوية', 3200),
    ('living', r'^apa_mp_h_stn_sofa2seat_\d+$', 'Two Seat Sofa', 'كنبة شخصين', 2200),
    ('living', r'^apa_mp_h_stn_sofa_daybed_\d+$', 'Daybed Sofa', 'كنبة استرخاء', 2600),
    ('living', r'^apa_mp_h_yacht_sofa_\d+$', 'Luxury Sofa', 'كنبة فاخرة', 4200),
    ('living', r'^prop_couch_(lg|sm)_?\d*_?\d+$|^prop_couch_0\d$', 'Couch', 'كنبة', 1300),
    ('living', r'^ex_mp_h_off_sofa_\d+$', 'Office Sofa', 'كنبة مكتب', 2400),
    ('living', r'^bkr_prop_clubhouse_sofa_01a$', 'Leather Club Sofa', 'كنبة جلد', 2000),
    ('living', r'^apa_mp_h_stn_chairarm_\d+$', 'Armchair', 'كرسي مريح', 900),
    ('living', r'^apa_mp_h_yacht_armchair_\d+$', 'Luxury Armchair', 'كرسي فاخر', 1500),
    ('living', r'^(v_res_m_armchair|v_res_d_armchair|v_res_jarmchair|prop_armchair_01|bkr_prop_clubhouse_armchair_01a|v_club_vuarmchair)$', 'Armchair', 'كرسي مريح', 800),
    ('living', r'^apa_mp_h_stn_foot_stool_\d+$', 'Footstool', 'مسند أرجل', 250),
    ('living', r'^apa_mp_h_stn_chairstrip_\d+$', 'Lounge Chair', 'كرسي صالة', 700),
    ('bed', r'^apa_mp_h_bed_(double|wide)_\d+$|^apa_mp_h_bed_with_table_\d+$', 'Double Bed', 'سرير دبل', 3800),
    ('bed', r'^apa_mp_h_yacht_bed_\d+$', 'Luxury Bed', 'سرير فاخر', 5600),
    ('bed', r'^(p_lestersbed_s|p_mbbed_s|v_res_msonbed_s|v_res_mbbed|v_res_d_bed|v_res_tre_bed1|v_res_tre_bed2|v_res_mdbed|ex_prop_exec_bed_01|imp_prop_impexp_sofabed_01a)$', 'Bed', 'سرير', 2200),
    ('bed', r'^apa_mp_h_bed_chestdrawer_\d+$|^apa_mp_h_bed_table_wide_\d+$', 'Bedside Drawer', 'كومودينة', 600),
    ('bed', r'^(v_res_tre_wardrobe|v_res_d_dressingtable|v_res_mbdresser|v_res_tre_bedsidetable|v_res_d_dresser|v_res_mdchest|v_res_tre_chest)$', 'Bedroom Furniture', 'أثاث غرفة نوم', 800),
    ('table', r'^apa_mp_h_din_table_\d+$', 'Dining Table', 'طاولة طعام', 1400),
    ('table', r'^apa_mp_h_tab_coffee_\d+$|^apa_mp_h_yacht_coffee_table_\d+$', 'Coffee Table', 'طاولة قهوة', 650),
    ('table', r'^apa_mp_h_tab_side(lrg|sml)_\d+$|^apa_mp_h_yacht_side_table_\d+$', 'Side Table', 'طاولة جانبية', 380),
    ('table', r'^(prop_table_0\d[a-z]?|prop_ld_farm_table0\d|prop_rub_table_0\d|v_res_m_dinetble|v_res_fh_diningtable|v_res_tre_table2|ba_prop_int_edgy_table_0\d|ex_prop_ex_console_table_01)$', 'Table', 'طاولة', 400),
    ('chair', r'^apa_mp_h_din_chair_\d+$|^apa_mp_h_din_stool_\d+$', 'Dining Chair', 'كرسي طعام', 260),
    ('chair', r'^apa_mp_h_yacht_(barstool|stool|strip_chair)_\d+$|^apa_mp_h_stn_chairstool_\d+$', 'Bar Stool', 'كرسي بار', 300),
    ('chair', r'^(prop_bar_stool_01|bkr_prop_biker_barstool_0\d|prop_chair_0\d[a-z]?|prop_off_chair_0\d[a-z]?|v_corp_offchair|v_res_fh_kitnstool|v_ret_chair|v_club_officechair|bkr_prop_clubhouse_chair_01|prop_rock_chair_01|ba_prop_int_glam_stool)$', 'Chair', 'كرسي', 220),
    ('kitchen', r'^apa_mp_h_kit_kitchen_01_[ab]$', 'Fitted Kitchen', 'مطبخ كامل', 9500),
    ('kitchen', r'^(prop_fridge_01|prop_fridge_03|v_res_fridgemoda|prop_trailr_fridge|prop_bar_fridge_0\d|prop_bar_beerfridge_01)$', 'Fridge', 'ثلاجة', 1400),
    ('kitchen', r'^(prop_microwave_1|prop_micro_0\d|v_res_ovenhobmod|v_res_int_oven|prop_cooker_03|prop_kettle(_01)?|prop_toaster_0\d|prop_coffee_mac_0\d|apa_mp_h_acc_coffeemachine_01|prop_ff_sink_0\d|v_res_m_sinkunit|prop_bar_sink_01|prop_chip_fryer|v_res_mchopboard|prop_kitch_juicer|v_res_tre_mixer|prop_juice_dispenser|prop_dish_rack_01|v_res_cakedome|prop_breadbin_01)$', 'Kitchen Appliance', 'جهاز مطبخ', 300),
    ('bathroom', r'^apa_mp_h_bathtub_01$', 'Bathtub', 'بانيو', 2600),
    ('bathroom', r'^(prop_toilet_0\d|prop_ld_toilet_01|prop_sink_0\d|prop_shower_rack_01|prop_towel_rail_0\d|prop_towel_shelf_01|prop_handdry_01|prop_soap_disp_01|v_res_mbsink|prop_toilet_roll_01|prop_toilet_brush_01|v_res_mbtowelfld|p_shower_towel_s|prop_shower_towel|v_res_mbath)$', 'Bathroom', 'حمام', 350),
    ('light', r'^apa_mp_h_(lit_floorlamp|floorlamp|floor_lamp_int|lit_floorlampnight)_?\w*$|^apa_mp_h_yacht_floor_lamp_\d+$', 'Floor Lamp', 'أباجورة أرضية', 320),
    ('light', r'^apa_mp_h_(lit_lamptable|lit_lamptablenight|table_lamp_int)_\w+$|^apa_mp_h_yacht_table_lamp_\d+$', 'Table Lamp', 'أباجورة طاولة', 160),
    ('light', r'^apa_mp_h_(ceiling_light_0\d|lit_lightpendant_\w+|lampbulb_multiple_a)$', 'Ceiling Light', 'ثريا', 420),
    ('light', r'^(prop_wall_light_0\d[a-z]?|ch_prop_ch_lamp_ceiling_\w+|ch_prop_ch_lamp_wall_01a|ch_prop_ch_lamp_01)$', 'Light', 'إضاءة', 200),
    ('electronic', r'^(prop_tv_flat_0\d[b]?|prop_tv_flat_michael|ex_prop_ex_tv_flat_01|prop_tv_0\d|prop_trev_tv_01|xm_prop_x17_tv_flat_0\d|prop_tv_06)$', 'TV', 'تلفزيون', 1200),
    ('electronic', r'^apa_mp_h_str_avunit(l|m|s)_\w+$', 'TV Unit', 'طاولة تلفزيون', 900),
    ('electronic', r'^(prop_laptop_01a|prop_laptop_lester2|p_laptop_02_s|ex_prop_ex_laptop_01a|prop_pc_0\d[a]?|prop_monitor_0\d[a-d]?|prop_monitor_w_large|prop_keyboard_01a|v_res_pctower|v_res_pcspeaker|prop_console_01|prop_boombox_01|prop_speaker_0\d|prop_hifi_01|prop_radio_01|v_res_fh_speaker|prop_printer_0\d|v_res_mconsolemod|ba_prop_battle_club_speaker_(small|med))$', 'Electronics', 'إلكترونيات', 450),
    ('storage', r'^apa_mp_h_str_(sideboard[lms]|shelffloorm|shelffreel|shelfwallm)_\d+$', 'Sideboard / Shelf', 'بوفيه / رف', 750),
    ('storage', r'^(p_v_43_safe_s|prop_ld_int_safe_01|v_res_tre_smallbookshelf|v_corp_offshelf|prop_cabinet_0\d[a-z]?|v_res_cabinet|prop_tool_cabinet|v_res_fa_chest|ch_prop_ch_laundry_shelving_0\w+|prop_box_wood0\da|v_res_tre_storagebox|v_res_tre_storageunit)$', 'Storage', 'تخزين', 450),
    ('decorations', r'^apa_mp_h_acc_(artwall[lms])_\d+$|^apa_p_h_acc_artwall\w+$|^ch_prop_ch_wallart_0\da$|^h4_prop_h4_painting_01[a-h]$', 'Wall Art', 'لوحة جدارية', 700),
    ('decorations', r'^apa_mp_h_acc_(vase|vase_flowers|candles|bowl_ceramic|dec_head|dec_plate|dec_sculpt|fruitbowl|jar|pot_pouri|scent_sticks|tray|bottle|box_trinket|drink_tray)_?\d*$', 'Decor', 'ديكور', 140),
    ('decorations', r'^apa_mp_h_acc_rugwool[lms]_\d+$', 'Wool Rug', 'سجادة صوف', 520),
    ('decorations', r'^(prop_dart_bd_cab_01|v_res_fh_bedsideclock|prop_big_clock_01|prop_hotel_clock_01|v_ret_gc_clock|prop_acc_guitar_01|prop_el_guitar_0\d|sf_prop_sf_guitars_rack_01a|v_res_fh_guitaramp|sf_prop_sf_piano_01a|m25_2_prop_m52_piano_01a|prop_mr_raspberry_01|prop_cs_dildo_01_off)$', 'Decor', 'ديكور', 400),
    ('plants', r'^apa_mp_h_acc_plant_(palm|tall)_01$', 'Plant', 'نبتة', 260),
    ('plants', r'^prop_plant_int_0\d[a-c]$|^prop_pot_plant_0\d[a-e]$|^prop_pot_plant_6[ab]$|^h4_prop_int_plants_0\w+$|^prop_plant_interior_05a$|^v_res_tre_plant$|^prop_fbibombplant$', 'Plant', 'نبتة', 160),
    ('office', r'^(prop_off_desk_\w+|h4_prop_office_desk_01|v_corp_bk_desk|v_corp_desk|v_corp_offchairfd|prop_office_desk_01|prop_cs_office_chair|prop_filecab_01|prop_whiteboard_01|prop_printer_01|ex_office_swag_\w+_never)$', 'Office', 'مكتب', 900),
    ('fun', r'^(prop_pooltable_0\d|prop_weight_bench_02|prop_weight_rack_0\d|prop_weight_squat|prop_freeweight_0\d|prop_muscle_bench_0\d|prop_beach_ring_01|prop_arcade_0\d|ch_prop_arcade_\w+_01a|prop_jukebox_0\d|m25_2_prop_m52_gymbench_01a|m25_2_prop_m52_gympullup_01a|prop_bball_arcade_01)$', 'Gym & Fun', 'رياضة وترفيه', 1200),
    ('outdoor', r'^(prop_patio_lounger\w*|prop_patio_heater_01|prop_chair_08|prop_table_para_comb_0\d|prop_parasol_0\d[a-z]?|prop_bbq_0\d|prop_bbq_0\d_l1|prop_hottub2|prop_gardnght_01|prop_garden_chimes|prop_garden_dreamcatch_01|prop_wheelbarrow01a|prop_hose_1|prop_trampoline_01|prop_skate_halfpipe_cr|prop_swing_01|prop_pot_plant_05[a-d])$', 'Garden', 'الحديقة', 600),
]
out, seen = [], set()
for cat, rx, en, ar, price in RULES:
    r = re.compile(rx); grp = [n for n in names if r.match(n) and not any(k in n for k in SKIP) and n not in seen]
    for i, n in enumerate(grp):
        seen.add(n)
        num = re.findall(r'(\d+[a-z]?)$', n)
        tag = f' {num[0].upper()}' if num else (f' {i + 1}' if len(grp) > 1 else '')
        p = int(round(price * (0.85 + 0.3 * ((__import__("zlib").crc32(n.encode()) % 100) / 100)) / 10) * 10)
        out.append((n, en + tag, ar + tag, cat, p))
# keep a few old hand-picked names that are valid
L = ['--[[', '    ROX Real Estate  ·  © ROX Store – All rights reserved.', '    Furniture shop: %d real GTA V props (names checked against the game object list).' % len(out),
     '    Generated by tools/catalog/build_catalog.py. Add your own entries at the bottom.', ']]', '', 'FurnitureCategories = {',
     "    -- ROX build pieces (rox_houses/stream/rox_build): structure of the empty open houses",
     "    { key = 'walls',  label = 'Walls',           labelAr = 'جدران',         icon = 'building' },",
     "    { key = 'floors', label = 'Floors & Tiles',  labelAr = 'أرضيات وبلاط',  icon = 'box' },",
     "    { key = 'levels', label = 'Stairs & Levels', labelAr = 'درج وأدوار',    icon = 'building' },",
     "    { key = 'doors',  label = 'Doors & Windows', labelAr = 'أبواب وشبابيك', icon = 'door' },"]
L += [f"    {{ key = '{k}', label = '{e}', labelAr = '{a}', icon = '{i}' }}," for k, e, a, i in CATS] + ['}', '', 'FurnitureCatalog = {']
for n, e, a, c, p in out:
    L.append(f"    {{ model = '{n}', label = '{e}', labelAr = '{a}', cat = '{c}', price = {p} }},")
L += ['}', '', 'FurnitureByModel = {}', 'for _, v in ipairs(FurnitureCatalog) do FurnitureByModel[v.model] = v end', '']
open(sys.argv[2], 'w').write('\n'.join(L))
import collections; print(len(out), collections.Counter(o[3] for o in out))
