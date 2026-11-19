-- ROX Store | All rights reserved
Config = {}
Config.Key = 'TAB'            -- hold to open, release to equip (ox_inventory hotbar also uses TAB: change one of them)
Config.ImagePath = 'nui://ox_inventory/web/images/'

-- ITEMS tab: item name -> category index
-- 1 Food, 2 Drinks, 3 Medical, 4 Armour, 5 Equipment, 6 Tools, 7 Documents, 8 Ammo
Config.ItemCats = {
    burger = 1, sandwich = 1, donut = 1, fries = 1, pizza_ham_slice = 1, burger_chicken = 1,
    water = 2, cola = 2, coffee = 2, sprunk = 2,
    bandage = 3, medikit = 3, advancedkit = 3, rox_pills = 3,
    armour = 4, rox_vest = 4,
    phone = 5, radio = 5, rox_radio = 5, parachute = 5, rox_oxygen = 5, binoculars = 5,
    lockpick = 6, WEAPON_CROWBAR = 6, scrapmetal = 6,
    card_id = 7, rox_idcard = 7, card_bank = 7, carkey = 7,
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
