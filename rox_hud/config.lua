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

Config.SettingsCommand = 'hud'     -- /hud opens the HUD settings
Config.SeatbeltCommand = 'seatbelt'
Config.SeatbeltKey = 'B'
Config.Update = 200                -- ms between updates on foot (vehicle: 80)
