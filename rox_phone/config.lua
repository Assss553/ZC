-- ROX Store | rox_phone | All rights reserved.
Config = {}
Config.Command = 'phone'
Config.Key = 'M'                 -- players can rebind in GTA settings > Key Bindings > FiveM
Config.RequireItem = false       -- set to 'phone' to require the item (ox_inventory)
Config.ImpoundFee = 500
-- props / animations per layout (0 phone, 1 half open, 2 tablet)
Config.Layouts = {
    [0] = { prop = `prop_npc_phone_02`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0),
            dict = 'cellphone@', anim = 'cellphone_text_read_base' },
    [1] = { prop = `prop_cs_tablet`, bone = 28422, pos = vec3(0.0, -0.03, 0.0), rot = vec3(20.0, -90.0, 0.0), scale = 0.75,
            dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', anim = 'base' },
    [2] = { prop = `prop_cs_tablet`, bone = 60309, pos = vec3(0.03, 0.002, -0.0), rot = vec3(10.0, 160.0, 0.0),
            dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', anim = 'base' },
}

-- ---------------- data / apps ----------------
Config.RingSeconds = 30
Config.Services = { police = 'LSPD', ambulance = 'EMS' }          -- job name -> app
Config.ServiceNumbers = { ['911'] = 'police', ['912'] = 'ambulance' }
-- Camera: photos are uploaded with screenshot-basic. Put a Discord webhook (or any screenshot-basic upload URL) here.
Config.PhotoUpload = ''          -- e.g. 'https://discord.com/api/webhooks/...'
Config.PhotoField = 'files[]'    -- 'files[]' for Discord
Config.Crypto = {
    { s = 'BTC', n = 'Bitcoin',     p = 64000, vol = 0.02, col = '#f7931a' },
    { s = 'ROX', n = 'Rox Coin',    p = 120,   vol = 0.05, col = '#ff5a1f' },
    { s = 'ETH', n = 'Ethereum',    p = 3100,  vol = 0.03, col = '#627eea' },
    { s = 'LSC', n = 'Santos Coin', p = 0.8,   vol = 0.08, col = '#16c784' },
}
Config.Gifts = { { e = '🌹', n = 'Rose', price = 1 }, { e = '❤️', n = 'Heart', price = 5 }, { e = '🍩', n = 'Donut', price = 10 }, { e = '🔥', n = 'Fire', price = 25 },
    { e = '🎉', n = 'Party', price = 50 }, { e = '👑', n = 'Crown', price = 100 }, { e = '🚗', n = 'Supercar', price = 500 }, { e = '🚁', n = 'Heli', price = 1000 } }
Config.Places = {
    { label = 'Pillbox Medical', icon = 'hospital', x = 298.6, y = -584.5 },
    { label = 'Mission Row PD', icon = 'shield-halved', x = 428.2, y = -984.3 },
    { label = 'Legion Square', icon = 'tree', x = 195.2, y = -933.7 },
    { label = "Benny's Motorworks", icon = 'wrench', x = -205.7, y = -1307.6 },
    { label = 'Fleeca Bank', icon = 'building-columns', x = 149.4, y = -1040.7 },
    { label = 'Del Perro Pier', icon = 'water', x = -1600.0, y = -1040.0 },
}
