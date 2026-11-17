Config = {}

-- Tower location (empty lot near Pillbox / downtown). Change to your ymap position.
Config.Tower = vector3(-75.0, -820.0, 326.0)

Config.Blip = { sprite = 475, color = 46, scale = 0.9, label = 'IAA Tower' }

-- Elevator floors: press E at any floor to open the menu
Config.Floors = {
  { label = 'اللوبي - Lobby',            coords = vector4(-70.0, -800.0, 44.2, 340.0) },
  { label = 'المكاتب - Offices (F20)',   coords = vector4(-77.0, -812.0, 120.0, 340.0) },
  { label = 'المختبرات - Labs (F40)',    coords = vector4(-77.0, -812.0, 200.0, 340.0) },
  { label = 'السطح - Roof / IAA Logo',   coords = vector4(-75.0, -820.0, 326.0, 340.0) },
}

Config.Key = 38          -- E
Config.Distance = 1.5
