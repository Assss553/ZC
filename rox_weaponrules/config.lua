-- ROX Store | All rights reserved
Config = {}
Config.MaxHeavy = 2           -- rifles, shotguns, snipers, MGs, launchers
Config.MaxLight = 2           -- pistols, SMGs, tasers
Config.ShowOnBack = true      -- heavy weapons that are not in your hands are slung on your back (everyone sees it)

-- weapon name -> class. Names not listed are classified by keywords below; melee / throwables are never limited.
Config.Override = {
    WEAPON_MICROSMG = 'light', WEAPON_MINISMG = 'light', WEAPON_MACHINEPISTOL = 'light', WEAPON_SMG = 'light', WEAPON_SMG_MK2 = 'light',
    WEAPON_COMBATPDW = 'light', WEAPON_ASSAULTSMG = 'light', WEAPON_TECPISTOL = 'light',
}
Config.HeavyKeywords = { 'RIFLE', 'CARBINE', 'SHOTGUN', 'SNIPER', 'MG', 'RPG', 'LAUNCHER', 'MINIGUN', 'MUSKET', 'GUSENBERG', 'RAILGUN', 'HOMING', 'FIREWORK' }
Config.LightKeywords = { 'PISTOL', 'REVOLVER', 'SMG', 'STUNGUN', 'FLAREGUN', 'DOUBLEACTION', 'CERAMIC', 'GADGET', 'RAYPISTOL', 'SNSPISTOL' }

-- how the 2 back slots are attached (bone 24818 = upper spine). Tune here if a model sits wrong.
Config.Back = {
    { bone = 24818, pos = vec3(0.08, -0.16, -0.03), rot = vec3(0.0, 165.0, 0.0) },
    { bone = 24818, pos = vec3(0.08, -0.17, 0.05), rot = vec3(0.0, 195.0, 0.0) },
}

function Config.Classify(name)
    if type(name) ~= 'string' or name:sub(1, 7) ~= 'WEAPON_' then return nil end
    if Config.Override[name] then return Config.Override[name] end
    local n = name:sub(8)
    for _, k in ipairs(Config.LightKeywords) do if n:find(k, 1, true) then return 'light' end end
    for _, k in ipairs(Config.HeavyKeywords) do if n:find(k, 1, true) then return 'heavy' end end
    return nil
end
