--[[ ROX Store | rox_police | All rights reserved. ]]
Config = {}

Config.Color = '#ff5a1f'

-- jobs that can use the MDT / jail / citations
Config.PoliceJobs = { 'police', 'sheriff', 'bcso', 'sasp' }

-- require the officer to be on duty (QBCore / Qbox)
Config.RequireDuty = false

-- commands (also opened from the F1 radial menu)
Config.Commands = { mdt = 'mdt', jail = 'jail', fine = 'fine', paybail = 'paybail', impound = 'impound', unmask = 'unmask', boss = 'policeboss' }

-- distance for the "Nearby" button
Config.NearbyDistance = 6.0

---------------------------------------------------------------------------
-- PRISON
---------------------------------------------------------------------------
Config.Jail = {
    -- true  = use the built-in jail (teleport, timer, keep inside, release)
    -- false = only call Config.OnJail (use your own jail script)
    builtIn = true,
    maxMinutes = 300,
    presets = { 5, 10, 15, 30, 60 },

    types = {
        prison = {
            label = 'Prison', icon = 'building-shield',
            inside  = vector4(1641.6, 2570.4, 45.6, 180.0),
            radius  = 160.0,
            release = vector4(1846.5, 2585.9, 45.7, 270.0),
        },
        cell = {
            label = 'Holding Cell', icon = 'door-closed',
            inside  = vector4(477.8, -1013.6, 26.4, 0.0),   -- MRPD cells
            radius  = 12.0,
            release = vector4(431.5, -981.7, 30.7, 90.0),
        },
    },
}

-- called on the SERVER after someone is jailed (builtIn or not). Put your own jail export here if needed.
Config.OnJail = function(officerSrc, targetSrc, data)
    -- data = { type, minutes, life, charges, bail }
    -- example (qb-policejob): TriggerClientEvent('police:client:SendToJail', targetSrc, data.minutes)
end

---------------------------------------------------------------------------
-- CITATIONS / CHARGES
---------------------------------------------------------------------------
Config.Fine = {
    account = 'bank',      -- money account to take the fine from
    allowUnpaid = true,    -- if the player can't pay, keep it as an unpaid ticket
}

-- fine = money, time = jail minutes (used by the jail panel)
Config.Charges = {
    { cat = 'Traffic', label = 'Speeding',                fine = 500,   time = 0 },
    { cat = 'Traffic', label = 'Reckless Driving',        fine = 1500,  time = 0 },
    { cat = 'Traffic', label = 'Running a Red Light',     fine = 350,   time = 0 },
    { cat = 'Traffic', label = 'Illegal Parking',         fine = 200,   time = 0 },
    { cat = 'Traffic', label = 'Driving Without License', fine = 800,   time = 0 },
    { cat = 'Traffic', label = 'Hit and Run',             fine = 2500,  time = 10 },
    { cat = 'Traffic', label = 'Evading Police',          fine = 3000,  time = 15 },
    { cat = 'Traffic', label = 'No Helmet',               fine = 250,   time = 0 },

    { cat = 'Criminal', label = 'Assault',                fine = 2000,  time = 10 },
    { cat = 'Criminal', label = 'Assault With a Weapon',  fine = 4000,  time = 20 },
    { cat = 'Criminal', label = 'Robbery',                fine = 5000,  time = 25 },
    { cat = 'Criminal', label = 'Armed Robbery',          fine = 8000,  time = 35 },
    { cat = 'Criminal', label = 'Bank Robbery',           fine = 15000, time = 60 },
    { cat = 'Criminal', label = 'Kidnapping',             fine = 10000, time = 40 },
    { cat = 'Criminal', label = 'Attempted Murder',       fine = 20000, time = 60 },
    { cat = 'Criminal', label = 'Murder',                 fine = 30000, time = 120 },
    { cat = 'Criminal', label = 'Grand Theft Auto',       fine = 4000,  time = 15 },
    { cat = 'Criminal', label = 'Drug Possession',        fine = 1500,  time = 5 },
    { cat = 'Criminal', label = 'Drug Trafficking',       fine = 8000,  time = 30 },
    { cat = 'Criminal', label = 'Illegal Weapon',         fine = 5000,  time = 20 },

    { cat = 'Public', label = 'Disturbing the Peace',     fine = 400,   time = 0 },
    { cat = 'Public', label = 'Public Intoxication',      fine = 300,   time = 0 },
    { cat = 'Public', label = 'Trespassing',              fine = 750,   time = 5 },
    { cat = 'Public', label = 'Resisting Arrest',         fine = 1500,  time = 10 },
    { cat = 'Public', label = 'Insulting an Officer',     fine = 1000,  time = 5 },
    { cat = 'Public', label = 'Obstruction of Justice',   fine = 2000,  time = 10 },
    { cat = 'Public', label = 'Impersonating an Officer', fine = 5000,  time = 20 },
}

-- server check: the officer must be this close to the player to jail / fine (needs OneSync, 0 = off)
Config.MaxActionDistance = 20.0

---------------------------------------------------------------------------
-- TABLET (iPad)
---------------------------------------------------------------------------
Config.Tablet = {
    command = 'tablet',     -- /tablet opens the iPad home screen
    item = 'tablet',        -- usable item that opens the iPad (QBCore / Qbox / ESX). nil = off
    prop = true,            -- hold a tablet prop + animation while it is open
}

---------------------------------------------------------------------------
-- BOSS MENU (Management app inside the iPad)
---------------------------------------------------------------------------
-- minimum job grade level that can open the Management app (Captain and above).
-- QBCore default police grades: 0 Recruit, 1 Officer, 2 Sergeant, 3 Lieutenant, 4 Chief
-- if you added a "Captain" grade, put its level here. Players with `isboss` always have access.
Config.BossMinGrade = 3

Config.Society = 'police'   -- society / job account name

Config.Certifications = {
    { key = 'firearms', label = 'Firearms',            icon = 'gun' },
    { key = 'pursuit',  label = 'Pursuit Driving',     icon = 'car-burst' },
    { key = 'k9',       label = 'K9 Unit',             icon = 'dog' },
    { key = 'air',      label = 'Air Unit',            icon = 'helicopter' },
    { key = 'swat',     label = 'SWAT',                icon = 'user-ninja' },
    { key = 'detective',label = 'Detective',           icon = 'user-secret' },
    { key = 'traffic',  label = 'Traffic Unit',        icon = 'motorcycle' },
    { key = 'fto',      label = 'Field Training',      icon = 'chalkboard-user' },
}

---------------------------------------------------------------------------
-- IMPOUND / DEPOT (third eye on any vehicle: ox_target / qb-target)
---------------------------------------------------------------------------
Config.Impound = {
    useTarget = true,        -- add "Impound Vehicle" to ox_target / qb-target
    distance = 4.0,
    impoundPrice = 500,      -- price the owner pays at the regular impound
    maxDepotPrice = 50000,
    maxHours = 72,           -- max police hold time
    animation = true,        -- officer writes on a clipboard before the car is taken
}

-- called on the SERVER after a vehicle is impounded. Default handles QBCore / ESX tables.
-- data = { plate, mode = 'impound' | 'depot', price, hours, reason }
Config.OnImpound = nil

---------------------------------------------------------------------------
-- REMOVE MASK / HAT / GLASSES (third eye on a player, or F1)
---------------------------------------------------------------------------
Config.Accessories = {
    { key = 'mask',    label = 'Mask',    icon = 'masks-theater' },
    { key = 'hat',     label = 'Hat',     icon = 'hat-cowboy' },
    { key = 'glasses', label = 'Glasses', icon = 'glasses' },
    { key = 'bag',     label = 'Bag',     icon = 'bag-shopping' },
}
