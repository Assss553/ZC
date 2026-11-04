Config = {}

-- 'auto' | 'qb' | 'esx' | 'standalone'
Config.Framework = 'auto'

-- How players use the kiosk: 'auto' | 'ox_target' | 'qb-target' | 'key'
Config.Interaction = 'auto'
Config.InteractDistance = 1.6   -- distance for the [E] prompt
Config.MaxServerDistance = 8.0  -- server rejects any action if the player is farther than this from the kiosk

Config.Currency = '$'
Config.Payments = { 'bank', 'cash' }   -- allowed payment methods (first = default)
Config.PlateFormat = 'VC2 ####'        -- # = digit, @ = letter (max 8 characters)
Config.QBGarage = 'pillboxgarage'      -- garage the car is assigned to after purchase (QBCore)
Config.Webhook = ''                    -- Discord webhook for purchase logs (optional)

-- Vehicle pictures. The UI tries, in order:
--   1) the vehicle's own `image` (if set below)
--   2) html/images/<model>.png   (drop your own pictures here, great for addon cars)
--   3) Config.ImageUrl with %s replaced by the spawn code (real GTA pictures for base-game cars)
--   4) a drawn silhouette in the selected colour
Config.ImageUrl = 'https://docs.fivem.net/vehicles/%s.webp'

Config.TestDrive = {
    enabled = true,
    duration = 60,      -- seconds
    cooldown = 120,     -- seconds between test drives for the same player
    maxDistance = 600.0 -- test drive ends if the player drives farther than this from the kiosk
}

-- Kiosks (the standalone machine)
Config.Kiosks = {
    {
        label = 'VC2 Showroom - Downtown',
        coords = vector4(-57.35, -1096.85, 25.42, 25.0), -- kiosk position (z = ground)
        model = 'prop_atm_03',   -- in-game prop used as the machine
        spawnProp = true,        -- false = use an object that already exists on the map
        blip = { sprite = 326, color = 47, scale = 0.8 },
        delivery = {             -- parking spots where bought cars are delivered
            vector4(-56.79, -1109.85, 26.43, 71.5),
            vector4(-51.20, -1111.40, 26.43, 71.5),
            vector4(-45.60, -1113.00, 26.43, 71.5),
        },
        testDrive = vector4(-46.99, -1095.47, 26.42, 200.0) -- test drive start point
    },
}

-- Impound NPCs: look at the NPC (target eye) or press E to open the impound terminal.
-- Owners get back their VC2 cars after they were impounded, destroyed,
-- lost after a disconnect / restart, or are still out on the street.
Config.Retrieve = {
    fee = 500,          -- normal retrieval fee
    impoundFee = 2500,  -- fee if the car was impounded (police export / /vc2impound)
    repair = true,      -- true = car comes out fully repaired, false = with its saved body / engine health
}
Config.Garages = {
    {
        label = 'Impound Lot',
        subtitle = 'Vehicle Terminal',
        ped = 's_m_m_security_01',
        coords = vector4(409.09, -1623.37, 28.29, 229.5), -- NPC position (z = ground)
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { sprite = 68, color = 47, scale = 0.75 },
        spawn = {                                          -- where retrieved cars appear
            vector4(401.76, -1647.90, 29.29, 320.0),
            vector4(404.43, -1650.00, 29.29, 320.0),
            vector4(407.16, -1652.20, 29.29, 320.0),
        },
    },
}

-- Admin commands (ACE permission below, e.g. add_ace group.admin vc2.admin allow)
Config.AdminAce = 'vc2.admin'
Config.AdminCommands = {
    own = 'vc2own',         -- /vc2own [playerId]  register the car you are in / next to under your name (or the player's)
    impound = 'vc2impound', -- /vc2impound          send the VC2 car you are in / next to to the impound
}

-- Reads the fuel of a car (shown in the impound terminal). Adjust for your fuel script.
Config.GetFuel = function(vehicle)
    if GetResourceState('LegacyFuel') == 'started' then return exports['LegacyFuel']:GetFuel(vehicle) end
    if GetResourceState('ox_fuel') == 'started' then return Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle) end
    return GetVehicleFuelLevel(vehicle)
end

-- Custom car orders: players describe the car they want at the kiosk,
-- workshop owners / admins review it with /vc2orders and build it for them.
Config.Orders = {
    enabled = true,
    maxActive = 2,               -- open orders (pending + ready) per player
    command = 'vc2orders',       -- opens the workshop panel
    managers = {
        ace = 'vc2.admin',       -- add_ace group.admin vc2.admin allow
        jobs = { mechanic = 0 }, -- job name = minimum grade (QBCore / ESX)
    },
    types = { 'Sedan', 'SUV', 'Sports', 'Super', 'Bike', 'Other' },
    maxPrice = 100000000,
}

-- /vc2check : look at (or sit in) a car to see if it was sold by VC2 and who owns it
Config.CheckCommand = 'vc2check'

-- Paint colours (primary = GTA colour index)
Config.Colors = {
    { label = 'Black',  hex = '#15161a', primary = 0 },
    { label = 'White',  hex = '#eceef0', primary = 111 },
    { label = 'Silver', hex = '#a9adb3', primary = 4 },
    { label = 'Red',    hex = '#b3141b', primary = 27 },
    { label = 'Orange', hex = '#e4501c', primary = 38 },
    { label = 'Yellow', hex = '#f2c21b', primary = 88 },
    { label = 'Blue',   hex = '#1f4fae', primary = 64 },
    { label = 'Green',  hex = '#1f6b3a', primary = 53 },
}

-- Categories. A car is placed automatically by its GTA vehicle class
-- (0 Compacts, 1 Sedans, 2 SUVs, 3 Coupes, 4 Muscle, 5 Sports Classics, 6 Sports,
--  7 Super, 8 Motorcycles, 9 Off-road, 12 Vans ...). Unlisted classes go to 'other'.
Config.Categories = {
    { id = 'compacts', label = 'Compacts', classes = { 0 } },
    { id = 'sedans',   label = 'Sedans',   classes = { 1 } },
    { id = 'suvs',     label = 'SUVs',     classes = { 2 } },
    { id = 'coupes',   label = 'Coupes',   classes = { 3 } },
    { id = 'muscle',   label = 'Muscle',   classes = { 4 } },
    { id = 'classics', label = 'Classics', classes = { 5 } },
    { id = 'sports',   label = 'Sports',   classes = { 6 } },
    { id = 'super',    label = 'Super',    classes = { 7 } },
    { id = 'motos',    label = 'Bikes',    classes = { 8 } },
    { id = 'offroad',  label = 'Off-road', classes = { 9 } },
    { id = 'vans',     label = 'Vans',     classes = { 12 } },
    { id = 'other',    label = 'Other',    classes = {} },
}

-- Cars for sale: just the spawn code and the price.
-- Name, brand, class, seats, top speed and stats are read from the game automatically,
-- so addon cars work too. Optional overrides: label, brand, category, image, stats = { speed, accel, brake, handling }
Config.Vehicles = {
    { model = 'asea',      price = 18000 },
    { model = 'tailgater', price = 45000 },
    { model = 'schafter2', price = 62000 },
    { model = 'baller2',   price = 90000 },
    { model = 'granger',   price = 55000 },
    { model = 'dubsta2',   price = 110000 },
    { model = 'elegy2',    price = 150000 },
    { model = 'sultan',    price = 85000 },
    { model = 'comet2',    price = 175000 },
    { model = 'dominator', price = 95000 },
    { model = 'zentorno',  price = 725000 },
    { model = 't20',       price = 850000 },
    { model = 'adder',     price = 1000000 },
    { model = 'bati',      price = 25000 },
    { model = 'akuma',     price = 22000 },
    -- addon example: { model = 'myaddoncar', price = 250000, image = 'https://i.imgur.com/xxxx.png' },
}

-- Runs after a car is spawned (keys / fuel). Adjust it for your own scripts.
-- fuel = saved fuel level for retrieved cars, nil for new cars (full tank)
Config.OnVehicleSpawned = function(vehicle, plate, isTestDrive, fuel)
    fuel = fuel or 100.0
    if GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, fuel)
    elseif GetResourceState('ox_fuel') == 'started' then
        Entity(vehicle).state.fuel = fuel
    else
        SetVehicleFuelLevel(vehicle, fuel)
    end
    if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
end
