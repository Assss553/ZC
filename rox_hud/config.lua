--[[ ROX Store | rox_hud V3 | All rights reserved. ]]
Config = {}

Config.Color = '#ff5a1f'           -- accent colour (players can change it in /hud)
Config.SpeedUnit = 'kmh'           -- 'kmh' or 'mph'
Config.MaxSpeed = 300              -- end of the speedometer scale (km/h or mph)

Config.Compass = true              -- compass at the top
Config.PlayerInfo = true           -- ID, job, cash and bank at the top right
Config.HideMinimapOnFoot = true    -- minimap only in vehicles
Config.LowHealthVignette = true    -- red screen edges when health is low
Config.HideDefaultHud = true       -- hide GTA street name / area / vehicle name and the health bars under the minimap

Config.SettingsCommand = 'hud'
Config.MapCommand = 'minimap'      -- /minimap shows / hides the map
Config.MapKey = ''                 -- default key ('' = none, players bind it in settings)     -- /hud opens the HUD settings
Config.SeatbeltCommand = 'seatbelt'
Config.SeatbeltKey = 'B'
Config.Update = 200                -- ms between updates on foot (vehicle: 80)

-- /cash and /bank show the money for a few seconds (hidden the rest of the time)
Config.CashCommand = 'cash'
Config.BankCommand = 'bank'
Config.MoneyShowTime = 6000

-- ESC pause menu (ROX). false = GTA default pause menu
Config.PauseMenu = false   -- false when rox_pausemenu is used
Config.ServerName = 'ROX'
Config.PoliceJobs = { 'police', 'sheriff', 'bcso', 'sasp' }
Config.EmsJobs = { 'ambulance', 'ems' }
-- activities shown in the pause menu: available when enough police are on duty
Config.Activities = {
    { label = 'Store Robbery',  icon = 'store',         police = 2 },
    { label = 'House Robbery',  icon = 'house',         police = 1 },
    { label = 'Fleeca Bank',    icon = 'building-columns', police = 4 },
    { label = 'Jewelry Store',  icon = 'gem',           police = 5 },
}

-- Pause menu map pins (label, world x/y, colour, letter)
Config.MapBlips = {
    { label = 'Pillbox Medical', x = 298.6, y = -584.5, color = '#ff4d6a', icon = 'H' },
    { label = 'Sandy Shores Medical', x = 1839.0, y = 3672.0, color = '#ff4d6a', icon = 'H' },
    { label = 'Mission Row PD', x = 428.2, y = -984.3, color = '#5aa7ff', icon = 'P' },
    { label = 'Sandy Shores PD', x = 1853.0, y = 3686.0, color = '#5aa7ff', icon = 'P' },
    { label = 'Paleto Bay PD', x = -448.0, y = 6012.0, color = '#5aa7ff', icon = 'P' },
    { label = 'Fleeca Bank', x = 149.4, y = -1040.7, color = '#ffc24a', icon = '$' },
    { label = 'Pacific Standard', x = 247.4, y = 222.9, color = '#ffc24a', icon = '$' },
    { label = 'Blaine County Savings', x = -113.2, y = 6470.0, color = '#ffc24a', icon = '$' },
    { label = 'Legion Square', x = 195.2, y = -933.7, color = '#2ee59d', icon = 'L' },
    { label = 'Del Perro Pier', x = -1600.0, y = -1040.0, color = '#2ee59d', icon = 'L' },
}
