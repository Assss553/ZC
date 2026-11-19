-- ROX Store | All rights reserved
Config = {}
Config.Name = 'ROX AUTO CARE'
Config.Blip = { sprite = 446, color = 48, label = 'Auto Care' }
Config.Locations = { vec3(-337.4, -136.9, 39.0), vec3(731.8, -1088.8, 22.2), vec3(-1155.5, -2007.2, 13.2), vec3(1175.0, 2640.2, 37.8), vec3(110.8, 6626.4, 31.8) }
Config.Payment = { 'cash', 'bank' }
Config.RepairPrice = 250
-- GTA mod types. prices per level (level 1 = first upgrade)
Config.Parts = {
    { label = 'Full Engine',  mod = 11, prices = { 900, 1800, 3200, 5200 },  desc = 'Adjust the torque and top speed. Pair with transmission upgrades to optimize performance.' },
    { label = 'Transmission', mod = 13, prices = { 800, 1600, 2800 },        desc = 'Faster gear changes and better acceleration.' },
    { label = 'Brakes',       mod = 12, prices = { 500, 1000, 1800 },        desc = 'Shorter stopping distance and more control.' },
    { label = 'Suspension',   mod = 15, prices = { 400, 800, 1400, 2200 },   desc = 'Lower the car and improve handling on asphalt.' },
    { label = 'Armor',        mod = 16, prices = { 1200, 2400, 3600, 4800, 6000 }, desc = 'Reinforced body panels. The car takes more damage.' },
    { label = 'Boost',        mod = 18, toggle = true, prices = { 4500 },   desc = 'Turbo: more power from every gear.' },
    { label = 'Repair',       repair = true, desc = 'Fix the engine and body.' },
}
