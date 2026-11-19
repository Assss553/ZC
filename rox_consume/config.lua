-- ROX Store | All rights reserved
Config = {}
Config.BiteCooldown = 1500       -- ms between bites
-- total = grams/ml in one item, bite = per press, hunger/thirst = amount for the WHOLE item (0-100)
Config.Items = {
    burger   = { label = 'Burger',   total = 300, bite = 75,  hunger = 45, unit = 'g',  type = 'eat',
                 prop = { 'prop_cs_burger_01', 18905, 0.13, 0.05, 0.02, -50.0, 16.0, 60.0 } },
    sandwich = { label = 'Sandwich', total = 250, bite = 50,  hunger = 35, unit = 'g',  type = 'eat',
                 prop = { 'prop_sandwich_01', 18905, 0.13, 0.05, 0.02, -50.0, 16.0, 60.0 } },
    donut    = { label = 'Donut',    total = 120, bite = 40,  hunger = 15, unit = 'g',  type = 'eat',
                 prop = { 'prop_amb_donut', 18905, 0.13, 0.05, 0.02, -50.0, 16.0, 60.0 } },
    water    = { label = 'Water',    total = 500, bite = 100, thirst = 45, unit = 'ml', type = 'drink',
                 prop = { 'prop_ld_flow_bottle', 28422, 0.0, 0.0, -0.05, 0.0, 0.0, 0.0 } },
    cola     = { label = 'Cola',     total = 330, bite = 66,  thirst = 30, unit = 'ml', type = 'drink',
                 prop = { 'prop_ecola_can', 28422, 0.0, 0.0, 0.0, 0.0, 0.0, 130.0 } },
    coffee   = { label = 'Coffee',   total = 250, bite = 50,  thirst = 20, unit = 'ml', type = 'drink',
                 prop = { 'p_amb_coffeecup_01', 28422, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 } },
}
Config.Anims = {
    eat   = { 'mp_player_inteat@burger', 'mp_player_int_eat_burger', 1800 },
    drink = { 'mp_player_intdrink', 'loop_bottle', 1800 },
}
