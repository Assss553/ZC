-- ROX Store | All rights reserved
Config = {}
Config.Name          = "ROX TACKLE & SHOT"
Config.ImagePath     = 'nui://ox_inventory/web/images/'   -- 100px item images
Config.HiResPath     = 'nui://rox_weaponhud/html/icons/'  -- side-view weapon icons (rox_weaponhud). Put your own sharper PNGs there to upgrade
Config.Payment       = { 'cash', 'bank' }                   -- tried in this order
Config.LicenseFor    = { longarms = 'weapon' }              -- tab -> qbx licence needed (metadata.licences.<name>), false = none
Config.Blip          = { sprite = 110, color = 1, label = 'Gun Store' }

Config.Locations = {
    vec3(1693.4, 3759.5, 34.7),  vec3(252.3, -50.0, 69.9),   vec3(842.4, -1033.4, 28.2), vec3(-330.2, 6083.8, 31.5),
    vec3(-662.1, -935.3, 21.8),  vec3(-1305.9, -394.5, 36.7), vec3(-1117.5, 2698.6, 18.6), vec3(2567.6, 294.3, 108.7),
    vec3(-3171.9, 1087.8, 20.8), vec3(22.0, -1107.2, 29.8),  vec3(810.2, -2157.3, 29.6),
}

-- GTA weapon tints (index -> name, price). Shown as swatches under the weapon.
Config.Tints = {
    { 0, 'Factory Black', 0, '#2a2b2e' }, { 4, 'Army Tan', 120, '#a8916a' }, { 1, 'Moss Green', 120, '#4b5a3c' },
    { 5, 'Midnight Blue', 150, '#2c3a52' }, { 3, 'Desert Gold', 250, '#c9a24a' }, { 6, 'Steel', 150, '#8c9196' },
}

-- tabs -> categories -> items. stats are 0-100 (shown on the right panel)
Config.Shop = {
    { id = 'sidearms', label = 'SIDEARMS', cats = {
        { label = 'Pistols', items = {
            { name = 'WEAPON_PISTOL',       label = 'Pistol',        type = 'Semi-auto pistol', price = 950,  stats = { 34, 48, 82, 30 } },
            { name = 'WEAPON_COMBATPISTOL', label = 'Combat Pistol', type = 'Duty pistol',      price = 1250, stats = { 38, 52, 80, 32 } },
            { name = 'WEAPON_SNSPISTOL',    label = 'SNS Pistol',    type = 'Pocket pistol',    price = 650,  stats = { 28, 40, 90, 22 } },
            { name = 'WEAPON_HEAVYPISTOL',  label = 'Heavy Pistol',  type = 'Large frame',      price = 1650, stats = { 46, 50, 70, 34 } },
            { name = 'WEAPON_REVOLVER',     label = 'Revolver',      type = 'Double action',    price = 2100, stats = { 70, 55, 52, 40 } },
        } },
    } },
    { id = 'longarms', label = 'LONGARMS', cats = {
        { label = 'Shotguns', items = {
            { name = 'WEAPON_PUMPSHOTGUN',    label = 'Pump Shotgun',    type = 'Pump action shotgun',   price = 1150, stats = { 78, 28, 50, 20 } },
            { name = 'WEAPON_DBSHOTGUN',      label = 'Double Barrel',   type = 'Double barrel shotgun', price = 1450, stats = { 85, 24, 60, 16 } },
            { name = 'WEAPON_SAWNOFFSHOTGUN', label = 'Sawed-Off',       type = 'Short shotgun',         price = 900,  stats = { 74, 20, 72, 12 } },
        } },
        { label = 'Assault Rifles', items = {
            { name = 'WEAPON_CARBINERIFLE',   label = 'Carbine Rifle',   type = 'Carbine rifle',         price = 1450, stats = { 58, 62, 55, 70 } },
            { name = 'WEAPON_ASSAULTRIFLE',   label = 'Assault Rifle',   type = 'Select-fire rifle',     price = 1650, stats = { 62, 55, 52, 66 } },
        } },
        { label = 'Tactical Rifles', items = {
            { name = 'WEAPON_SPECIALCARBINE', label = 'Special Carbine', type = 'Tactical rifle',        price = 2250, stats = { 60, 68, 58, 72 } },
        } },
        { label = 'Sniper Rifles', items = {
            { name = 'WEAPON_SNIPERRIFLE',    label = 'Hunting Rifle',   type = 'Bolt action rifle',     price = 2900, stats = { 90, 92, 30, 98 } },
        } },
    } },
    { id = 'equipment', label = 'AMMO & EQUIPMENT', cats = {
        { label = 'Firearm Ammo', items = {
            { name = 'ammo-9',       label = 'Pistol Ammo x50',        count = 50, price = 24, type = 'Ammunition' },
            { name = 'ammo-shotgun', label = 'Shotgun Ammo x10',       count = 10, price = 15, type = 'Ammunition' },
            { name = 'ammo-rifle',   label = 'Tactical Rifle Ammo x30', count = 30, price = 36, type = 'Ammunition' },
            { name = 'ammo-sniper',  label = 'Sniper Ammo x10',        count = 10, price = 40, type = 'Ammunition' },
        } },
        { label = 'Body Armor', items = {
            { name = 'armour', label = 'Body Armor', price = 275, type = 'Plate carrier' },
        } },
        { label = 'Equipment', items = {
            { name = 'WEAPON_KNIFE',      label = 'Hunting Knife', price = 120, type = 'Melee', stats = { 30, 90, 90, 5 } },
            { name = 'WEAPON_FLASHLIGHT', label = 'Flashlight',    price = 60,  type = 'Melee', stats = { 12, 90, 90, 5 } },
            { name = 'parachute',         label = 'Parachute',     price = 450, type = 'Equipment' },
        } },
    } },
}
