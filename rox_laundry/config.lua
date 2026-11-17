--[[ ROX Laundry  ·  © ROX Store – All rights reserved. ]]
Config = {}

Config.Locale    = 'ar'          -- 'ar' | 'en'
Config.Framework = 'auto'        -- 'auto' | 'esx' | 'qb' | 'standalone'
Config.Currency  = '$'

-- Centre of the building at street level + heading (the shop front looks the opposite way of the heading).
-- Easiest: stand on the pavement where the front door should be, look at where the shop should stand and type
-- /roxlaundry_here (ace rox_laundry.admin). It is saved on the server, no restart needed.
-- The building is 16.6 x 10.6 m: pick a flat empty lot.
Config.Location  = vec4(-1197.10, -1162.40, 7.70, 15.0)
Config.AdminAce  = 'rox_laundry.admin'
Config.SpawnDistance = 250.0

Config.Prices = { wash = 4, dry = 3, fold = 0 }
Config.Reward = {
    money = 25,                   -- paid after folding (scaled by quality 0..1)
    item  = false,                -- e.g. 'clean_tshirt' (needs ox_inventory / qb / esx items)
    requireItem = false,          -- e.g. 'dirty_tshirt' taken when the wash starts
}
Config.Times = { wash = 22, dry = 16 }   -- seconds of the drum animation (server checks them too)
Config.Blip = { sprite = 366, color = 47, scale = 0.8, label = 'ROX Laundry' }

-- The GTA props in shared/props.lua look at -Y in their own model space (like vending machines).
-- If machines appear turned the wrong way in your build, try 0.0 here.
Config.PropFront = 180.0
