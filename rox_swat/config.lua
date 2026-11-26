--[[ ROX SWAT TEAM HQ  ·  © ROX Store – All rights reserved. ]]
Config = {}
-- Centre of the hatch at street level + heading (cars drive in along the local Y axis).
-- Pick a FLAT spot with nothing underground (no tunnels / interiors), stand on it and type /roxswat_here (ace rox_swat.admin).
-- The plaza is 20 x 38 m (with ramps). Under it: level 1 (11 m down) and level 2 (18 m down), each ~86 x 86 m.
Config.Origin = vec4(-2100.0, 3050.0, 32.8, 60.0)
Config.AdminAce = 'rox_swat.admin'
Config.Locale = 'ar'
Config.SpawnDistance = 350.0
Config.PropFront = 180.0          -- set 0.0 if chairs / desks face the wall

-- who can open the hatch, use the lift and the security doors
Config.AccessAce = 'rox_swat.access'
Config.Jobs = { police = true, swat = true, sheriff = true, lspd = true, bcso = true }

-- timings (seconds)
Config.PillarTime = 3.5
Config.DoorTime = 3.0
Config.LiftTime = 9.0
Config.AutoClose = 25            -- seconds the hatch stays open with nobody on the lift

Config.DoorModels = {
    std   = { 'v_ilev_ph_gendoor004', 'v_ilev_ph_gendoor005', 'v_ilev_fib_door1' },
    glass = { 'v_ilev_fib_door2', 'v_ilev_fib_door1', 'v_ilev_ph_gendoor004' },
    sec   = { 'v_ilev_arm_secdoor', 'v_ilev_ph_gendoor006', 'v_ilev_ph_gendoor004' },
    cell  = { 'v_ilev_ph_cellgate', 'v_ilev_ph_cellgate02' },
}

-- secret doors (bookcase + emblem panel in the commander office): who may open them
Config.SecretAce = 'rox_swat.secret'
Config.SecretJobs = { swat = 3, police = 4 }      -- job name = minimum grade (QBCore grade.level / ESX grade)
Config.SecretTime = 2.5

-- SWAT vehicles parked in the garage as decoration (local, locked, frozen; set false if you park real ones)
Config.ShowcaseVehicles = false
