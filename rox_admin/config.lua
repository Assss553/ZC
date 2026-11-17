-- ROX Store | rox_admin | All rights reserved.
Config = {}

Config.OpenCommand = 'admin'
Config.OpenKey = 'F10'          -- default; every admin can rebind it in GTA keybinds
Config.Locale = 'ar'            -- 'ar' (RTL) or 'en' default UI language
Config.RefreshMs = 3000         -- live refresh while the panel is open
Config.LogIPs = false           -- store player IPs in join logs (only if your rules allow it)
Config.Webhook = ''             -- optional Discord webhook for join/quit

-- Bootstrap staff: identifiers that are always given a rank (license:, license2:, steam:, discord:)
-- Owners add the rest from the panel (saved in the database).
Config.Staff = {
    -- ['license:xxxxxxxxxxxxxxxx'] = 'owner',
}
-- ACE fallback: add_ace identifier.license:xxx rox.owner allow
Config.AceRanks = { 'owner', 'admin', 'supervisor', 'moderator' }

Config.Ranks = {
    { name = 'owner',      label = 'Owner',      level = 4 },
    { name = 'admin',      label = 'Admin',      level = 3 },
    { name = 'supervisor', label = 'Supervisor', level = 2 },
    { name = 'moderator',  label = 'Moderator',  level = 1 },
}

-- every permission + which ranks get it by default (Owner can change these in the panel)
Config.Permissions = {
    view_players    = { 'owner', 'admin', 'supervisor', 'moderator' },
    view_characters = { 'owner', 'admin', 'supervisor' },
    view_logs       = { 'owner', 'admin', 'supervisor', 'moderator' },
    view_ips        = { 'owner' },
    view_actions    = { 'owner', 'admin', 'supervisor' },
    coords          = { 'owner', 'admin', 'supervisor', 'moderator' },
    coords_save     = { 'owner', 'admin', 'supervisor' },
    teleport        = { 'owner', 'admin', 'supervisor' },
    ['goto']        = { 'owner', 'admin', 'supervisor', 'moderator' },
    bring           = { 'owner', 'admin', 'supervisor' },
    freeze          = { 'owner', 'admin', 'supervisor', 'moderator' },
    revive          = { 'owner', 'admin' },
    kick            = { 'owner', 'admin', 'supervisor' },
    set_job         = { 'owner', 'admin' },
    give_money      = { 'owner' },
    manage_staff    = { 'owner' },
    manage_perms    = { 'owner' },
}

-- admin shortcuts that can be bound from the Keybinds tab
Config.Keybinds = {
    { action = 'open',     label = 'Open panel',        default = 'F10' },
    { action = 'noclip',   label = 'Noclip',            default = '' },
    { action = 'tpm',      label = 'Teleport to marker', default = '' },
    { action = 'coords',   label = 'Copy my coords',    default = '' },
    { action = 'revive',   label = 'Revive self',       default = '' },
}
