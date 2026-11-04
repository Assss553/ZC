Config = {}

Config.Model = 'vc2caravan'          -- spawn name of the caravan
Config.Framework = 'auto'            -- 'auto' | 'qb' | 'esx' | 'standalone' (for furniture payments + owner ids)
Config.Interaction = 'auto'          -- 'auto' | 'ox_target' | 'qb-target' | 'key'
Config.Currency = '$'

-- Who may set up the caravan, place furniture and change the look:
-- 'auto' = the VC2 owner when the VC2 script runs, otherwise anyone
-- 'vc2'  = only the owner registered in VC2 (plus vc2.admin)
-- 'none' = anyone
Config.Ownership = 'auto'
Config.AdminAce = 'vc2.admin'

---------------------------------------------------------------- set up / pack up (press Q while parked)
Config.DeployKey = 85                -- Q in a vehicle (INPUT_VEH_RADIO_WHEEL). The radio wheel is blocked in the caravan.
Config.DeployTime = 7000             -- ms for the whole animation
Config.MaxSpeed = 0.5                -- m/s: must be standing still
Config.LowerBody = 0.06              -- the body settles this much (m) when the legs are down

-- Moving parts (separate props attached to the caravan, see ../../model/)
-- Offsets are relative to the vehicle origin: x = right, y = forward, z = up (metres).
-- They match the model; fine-tune them after converting the model if needed.
Config.Parts = {
    slideSide = { model = 'vc2caravan_slideout_side', closed = vector3(-1.225, 0.0, 0.78), open = vector3(-1.885, 0.0, 0.78), rot = vector3(0.0, 0.0, 0.0) },
    slideRear = { model = 'vc2caravan_slideout_rear', closed = vector3(0.0, -3.96, 0.8), open = vector3(0.0, -4.56, 0.8), rot = vector3(0.0, 0.0, 90.0) },
    jack = {
        model = 'vc2caravan_jack', closedZ = 0.90, openZ = 0.56,
        positions = { vector2(-0.95, -3.5), vector2(0.95, -3.5), vector2(-0.95, 1.2), vector2(0.95, 1.2) },
    },
    -- wall screen (the touch panel you look at to customise the caravan)
    screen = { model = 'prop_cs_tablet', fallback = 'prop_cs_tablet', offset = vector3(1.12, 0.6, 1.55), rot = vector3(0.0, 0.0, 90.0) },
}

---------------------------------------------------------------- door + inside
Config.EntryDoor = 3                      -- vehicle door index of door_pside_r (the entry door)
Config.DoorBone = 'door_pside_r'
Config.EnterTeleport = true               -- "Go inside" option (puts you inside next to the door)
Config.EnterOffset = vector3(0.45, -0.75, 0.75)
Config.ExitOffset = vector3(2.1, -0.75, 0.0)
-- Furniture can only be placed inside this box (vehicle offsets, incl. the slide-outs)
Config.InteriorBounds = { minX = -1.9, maxX = 1.15, minY = -4.55, maxY = 1.45, minZ = 0.55, maxZ = 3.2 }
Config.MaxFurniture = 40
-- Furniture menu + placement
Config.Placement = {
    menuKey = 'O',     -- opens the furniture menu (players can rebind it in GTA settings > Key Bindings > FiveM)
    moveStep = 0.01,   -- metres per frame with the arrow keys (hold Shift = 3x)
    rotateStep = 7.5,  -- degrees per mouse-wheel notch
}

---------------------------------------------------------------- exterior
Config.Colors = {
    { label = 'Off White', index = 121, hex = '#e4e2dc' },   { label = 'Frost White', index = 111, hex = '#f2f3f5' }, { label = 'Silver', index = 4, hex = '#b7bbc1' },
    { label = 'Graphite', index = 1, hex = '#3b3d42' },      { label = 'Black', index = 0, hex = '#121316' },
    { label = 'VC2 Orange', index = 38, hex = '#e4501c' },   { label = 'Red', index = 27, hex = '#b3141b' },
    { label = 'Sand', index = 99, hex = '#c8b48a' },         { label = 'Olive', index = 151, hex = '#5c6b3a' },
    { label = 'Sky Blue', index = 70, hex = '#4f8fd6' },     { label = 'Navy', index = 62, hex = '#1f2f5c' },
    { label = 'Forest Green', index = 53, hex = '#1f6b3a' }, { label = 'Yellow', index = 88, hex = '#f2c21b' },
}
Config.Neon = {
    { label = 'Orange', rgb = { 228, 80, 28 } }, { label = 'White', rgb = { 255, 255, 255 } }, { label = 'Blue', rgb = { 40, 120, 255 } },
    { label = 'Green', rgb = { 60, 220, 90 } },  { label = 'Purple', rgb = { 160, 60, 255 } }, { label = 'Red', rgb = { 255, 30, 40 } },
}

---------------------------------------------------------------- furniture catalogue (GTA props)
-- Models that are not found on the server are hidden automatically.
Config.Furniture = {
    { cat = 'Beds',     label = 'Double bed',       model = 'v_res_tre_bed2',        price = 1500 },
    { cat = 'Beds',     label = 'Single bed',       model = 'v_res_msonbed',         price = 900 },
    { cat = 'Beds',     label = 'Simple bed',       model = 'p_lestersbed_s',        price = 700 },
    { cat = 'Seating',  label = 'Sofa',             model = 'prop_couch_01',         price = 1200 },
    { cat = 'Seating',  label = 'Large sofa',       model = 'prop_couch_lg_02',      price = 1800 },
    { cat = 'Seating',  label = 'Small sofa',       model = 'v_res_tre_sofa_s',      price = 800 },
    { cat = 'Seating',  label = 'Chair',            model = 'prop_chair_01a',        price = 150 },
    { cat = 'Seating',  label = 'Office chair',     model = 'prop_off_chair_01',     price = 250 },
    { cat = 'Tables',   label = 'Dining table',     model = 'prop_table_03',         price = 400 },
    { cat = 'Tables',   label = 'Coffee table',     model = 'prop_table_04',         price = 300 },
    { cat = 'Kitchen',  label = 'Fridge',           model = 'prop_fridge_01',        price = 900 },
    { cat = 'Kitchen',  label = 'Microwave',        model = 'prop_micro_01',         price = 200 },
    { cat = 'Kitchen',  label = 'Cooker',           model = 'prop_cooker_03',        price = 700 },
    { cat = 'Kitchen',  label = 'Coffee machine',   model = 'prop_coffee_mac_02',    price = 250 },
    { cat = 'Bathroom', label = 'Toilet',           model = 'prop_toilet_01',        price = 350 },
    { cat = 'Bathroom', label = 'Sink',             model = 'prop_sink_02',          price = 300 },
    { cat = 'Tech',     label = 'Flat TV',          model = 'prop_tv_flat_01',       price = 1100 },
    { cat = 'Tech',     label = 'Small TV',         model = 'prop_tv_flat_02',       price = 700 },
    { cat = 'Tech',     label = 'Laptop',           model = 'prop_laptop_01a',       price = 600 },
    { cat = 'Decor',    label = 'Plant',            model = 'prop_plant_int_01a',    price = 120 },
    { cat = 'Decor',    label = 'Rubber plant',     model = 'v_res_rubberplant',     price = 90 },
    { cat = 'Decor',    label = 'Lamp',             model = 'prop_cs_lamp_01',       price = 140 },
    { cat = 'Storage',  label = 'Wardrobe',         model = 'v_res_tre_wardrobe',    price = 650 },
    { cat = 'Storage',  label = 'Drawers',          model = 'v_res_tre_storageunit', price = 450 },
}
