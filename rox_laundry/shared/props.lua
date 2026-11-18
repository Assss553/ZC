--[[ ROX Laundry  ·  © ROX Store – All rights reserved.
     Real GTA V props inside the laundromat (no custom furniture).
     x / y = building local metres (centre of the shop, front door on -y).
     face  = direction the front of the prop looks at, as a heading (0 = +y / back wall, 180 = street, 90 = -x, 270 = +x).
     m     = model candidates: the first one that exists in your game build is used.
     Change any model name here if you prefer another prop. ]]

local M = {
    washer  = { 'prop_washer_02', 'prop_washer_03', 'prop_washer_01', 'ch_prop_ch_laundry_machine_01a' },
    dryer   = { 'prop_washer_03', 'bkr_prop_prtmachine_dryer', 'prop_washer_01' },
    table   = { 'prop_table_03b', 'prop_table_03', 'prop_table_04', 'prop_table_01' },
    counter = { 'prop_ff_counter_01', 'prop_ff_counter_02', 'prop_table_04' },
    till    = { 'prop_till_01', 'prop_till_02', 'prop_till_03' },
    offchair= { 'prop_off_chair_01', 'prop_off_chair_04', 'v_corp_offchair', 'prop_chair_01a' },
    chair   = { 'apa_mp_h_din_chair_12', 'prop_chair_04a', 'prop_chair_01a' },
    plant   = { 'apa_mp_h_acc_plant_tall_01', 'prop_plant_int_01a', 'prop_plant_int_02a', 'prop_pot_plant_01a' },
    plant2  = { 'apa_mp_h_acc_plant_palm_01', 'prop_plant_int_03a', 'prop_plant_int_02a', 'prop_pot_plant_01a' },
    outplant= { 'prop_pot_plant_04a', 'prop_pot_plant_01a', 'prop_plant_int_04a', 'prop_plant_int_01a' },
    basket  = { 'v_res_tre_laundrybasket', 'v_res_fh_laundrybasket', 'prop_washing_basket_01' },
    trolley = { 'ch_prop_ch_laundry_trolley_01a', 'ch_prop_ch_laundry_trolley_01b' },
    shelf   = { 'ch_prop_ch_laundry_shelving_01a', 'ch_prop_ch_laundry_shelving_01b' },
    soda    = { 'prop_vend_soda_01', 'prop_vend_soda_02' },
    snack   = { 'prop_vend_snak_01' },
    coffee  = { 'prop_vend_coffe_01' },
    bin     = { 'prop_bin_05a', 'prop_bin_07a', 'prop_bin_08a' },
}
LaundryModels = M

LaundryProps = {}
LaundryPoints = {}
local function add(kind, models, x, y, face, extra)
    local p = { kind = kind, m = models, x = x, y = y, face = face or 0.0 }
    if extra then for k, v in pairs(extra) do p[k] = v end end
    LaundryProps[#LaundryProps + 1] = p
    return p
end
local function point(kind, x, y, face, dist)  -- stand in front of the prop, looking at it
    local r = math.rad(face); local fx, fy = -math.sin(r), math.cos(r)
    LaundryPoints[#LaundryPoints + 1] = { id = #LaundryPoints + 1, kind = kind, x = x + fx * (dist or 0.8), y = y + fy * (dist or 0.8), z = 0.6, h = (face + 180.0) % 360.0 }
end

-- west wall: 11 washers looking at the room (+x = heading 270)
for k = 0, 10 do local y = -3.9 + k * 0.74; add('washer', M.washer, -7.55, y, 270.0); point('washer', -7.55, y, 270.0) end
-- back wall: 9 dryers looking at the street
for k = 0, 8 do local x = -6.6 + k * 0.78; add('dryer', M.dryer, x, 4.55, 180.0); point('dryer', x, 4.55, 180.0) end
-- centre island: back to back washers
for k = 0, 6 do
    local x = -4.6 + k * 0.76
    add('washer', M.washer, x, -0.38, 180.0); point('washer', x, -0.38, 180.0)
    add('washer', M.washer, x, 0.38, 0.0); point('washer', x, 0.38, 0.0)
end
-- folding tables + baskets
add('table', M.table, 4.0, -1.0, 0.0, { name = 't1' }); add('table', M.table, 4.0, 1.6, 0.0, { name = 't2' })
add('basket', M.basket, 3.4, -1.0, 20.0, { on = 't1' }); add('basket', M.basket, 4.7, 1.6, -15.0, { on = 't2' })
point('fold', 4.0, -1.0, 180.0, 0.9)
-- cashier
add('counter', M.counter, 6.6, 3.3, 180.0, { name = 'desk' }); add('till', M.till, 6.6, 3.3, 180.0, { on = 'desk' })
add('offchair', M.offchair, 6.6, 4.25, 180.0)
point('cashier', 6.6, 3.3, 180.0, 1.1)
-- vending on the east wall (looking at -x = heading 90)
add('vend', M.soda, 7.5, -2.0, 90.0); add('vend', M.snack, 7.5, -3.0, 90.0); add('vend', M.coffee, 7.5, -4.0, 90.0)
-- waiting chairs by the front windows (looking into the shop) + bins
for k = 0, 5 do add('chair', M.chair, -6.9 + k * 0.75, -4.35, 0.0) end
add('bin', M.bin, -2.0, -4.4, 0.0); add('bin', M.bin, 7.5, 0.4, 90.0)
-- laundry trolleys + shelving (Diamond Casino laundry props)
add('trolley', M.trolley, -5.6, 1.6, 30.0); add('trolley', M.trolley, 1.8, 1.4, -20.0); add('trolley', M.trolley, -1.0, -2.6, 75.0)
add('shelf', M.shelf, 1.6, 4.6, 180.0); add('shelf', M.shelf, 7.5, 1.4, 90.0)
-- plants
add('plant', M.plant, -7.45, -4.55, 30.0); add('plant', M.plant2, 0.6, 4.5, 0.0); add('plant', M.plant, 1.8, -4.45, 60.0); add('plant', M.plant2, 7.45, 4.5, 0.0)
add('plant', M.plant2, -7.45, 4.55, 10.0)
-- outside, both sides of the door
add('outplant', M.outplant, -2.2, -5.9, 0.0); add('outplant', M.outplant, 2.4, -5.9, 0.0)
add('outplant', M.outplant, -6.0, -5.9, 0.0); add('outplant', M.outplant, 6.0, -5.9, 0.0)
