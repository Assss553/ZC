-- ROX Store | rox_bank | All rights reserved.
Config = {}
Config.MaxAmount = 5000000
Config.TransferFeePct = 0          -- % fee on transfers
-- bank counters (ox_target sphere)
Config.Banks = {
    { name = 'Fleeca · Legion Square', coords = vec3(149.4, -1040.7, 29.4) },
    { name = 'Fleeca · Alta',          coords = vec3(313.8, -278.9, 54.2) },
    { name = 'Fleeca · Burton',        coords = vec3(-351.5, -49.5, 49.0) },
    { name = 'Fleeca · Del Perro',     coords = vec3(-1212.9, -330.8, 37.8) },
    { name = 'Fleeca · Great Ocean',   coords = vec3(-2962.6, 482.6, 15.7) },
    { name = 'Fleeca · Route 68',      coords = vec3(1175.0, 2706.6, 38.1) },
    { name = 'Pacific Standard',       coords = vec3(247.4, 222.9, 106.3) },
    { name = 'Blaine County Savings',  coords = vec3(-113.2, 6470.0, 31.6) },
}
Config.Blip = { sprite = 108, color = 2, scale = 0.75 }

-- ---------------- loans ----------------
Config.Loans = {
    enabled = true,
    min = 1000, max = 100000,
    terms = { 4, 8, 12 },        -- number of weekly payments the player can choose
    rate = 8,                    -- % total interest
    intervalHours = 24 * 7,      -- time between payments (real hours)
    autoCollect = true,          -- take the payment from bank automatically when due
    lateFeePct = 5,              -- added to the loan if a payment fails
}
