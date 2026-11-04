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
Config.OnVehicleSpawned = function(vehicle, plate, isTestDrive)
    if GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    elseif GetResourceState('ox_fuel') == 'started' then
        Entity(vehicle).state.fuel = 100.0
    else
        SetVehicleFuelLevel(vehicle, 100.0)
    end
    if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
end
