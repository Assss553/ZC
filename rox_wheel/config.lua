-- ROX Store | All rights reserved
Config = {}
Config.Key = 'TAB'            -- hold to open, release to equip (ox_inventory hotbar also uses TAB: change one of them)
Config.ImagePath = 'nui://ox_inventory/web/images/'

-- ITEMS tab: item name -> category index
-- 1 Food, 2 Drinks, 3 Medical, 4 Armour, 5 Equipment, 6 Tools, 7 Gear (hat/glasses/mask, automatic), 8 Ammo
Config.ItemCats = {
    burger = 1, sandwich = 1, donut = 1, fries = 1, pizza_ham_slice = 1, burger_chicken = 1,
    water = 2, cola = 2, coffee = 2, sprunk = 2,
    bandage = 3, medikit = 3, advancedkit = 3, rox_pills = 3,
    armour = 4, rox_vest = 4,
    phone = 5, radio = 5, rox_radio = 5, parachute = 5, rox_oxygen = 5, binoculars = 5,
    lockpick = 6, WEAPON_CROWBAR = 6, scrapmetal = 6,
    card_id = 5, rox_idcard = 5, card_bank = 5, carkey = 5,
}
-- items whose name starts with 'ammo' go to 8 automatically; everything else not listed is hidden

-- WEAPONS tab: GTA weapon group hash -> category index
-- 1 Melee, 2 Pistols, 3 SMG, 4 Shotguns, 5 Rifles, 6 Snipers, 7 Heavy, 8 Throwables
Config.WeaponGroups = {
    [`GROUP_MELEE`] = 1, [`GROUP_UNARMED`] = 1,
    [`GROUP_PISTOL`] = 2, [`GROUP_STUNGUN`] = 2,
    [`GROUP_SMG`] = 3,
    [`GROUP_SHOTGUN`] = 4,
    [`GROUP_RIFLE`] = 5, [`GROUP_MG`] = 5,
    [`GROUP_SNIPER`] = 6,
    [`GROUP_HEAVY`] = 7,
    [`GROUP_THROWN`] = 8, [`GROUP_PETROLCAN`] = 8, [`GROUP_FIREEXTINGUISHER`] = 8,
}

-- weapon details panel: base stats per class (0-100). Damage is read from the game, the rest comes from here.
-- per-weapon override: Config.WeaponStats.WEAPON_PISTOL = { accuracy = 50, handling = 85, range = 30 }
Config.ClassStats = {
    [1] = { type = 'Melee',      accuracy = 90, handling = 90, range = 5 },
    [2] = { type = 'Sidearm',    accuracy = 48, handling = 82, range = 30 },
    [3] = { type = 'SMG',        accuracy = 45, handling = 75, range = 40 },
    [4] = { type = 'Shotgun',    accuracy = 30, handling = 50, range = 22 },
    [5] = { type = 'Longarm',    accuracy = 62, handling = 55, range = 70 },
    [6] = { type = 'Sniper',     accuracy = 92, handling = 30, range = 98 },
    [7] = { type = 'Heavy',      accuracy = 40, handling = 20, range = 85 },
    [8] = { type = 'Throwable',  accuracy = 35, handling = 70, range = 35 },
}
Config.WeaponStats = {}
