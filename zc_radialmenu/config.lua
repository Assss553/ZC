Config = {}

-- Key that opens the menu (players can rebind it in GTA Settings > Key Bindings > FiveM)
Config.Key = 'F1'

-- Accent colour (any CSS hex colour)
Config.Color = '#ff5a1f'

-- Title shown in the middle
Config.Title = 'ZC MENU'

-- true  = keep walking/driving while the menu is open (camera & shooting are blocked)
Config.KeepInput = true

-- Small UI sounds (hover tick / select / open)
Config.Sound = true

--[[
    ONE menu on F1 that changes with context:
      * sections with `jobs`      -> only show for those jobs        (police, ems ...)
      * sections with `vehicle`   -> true  = only inside a vehicle
                                     false = only on foot
      * `duty = true`             -> only when on duty (QBCore / Qbox)
      * `canInteract = function() return true end` -> any custom check

    Hover a section and its items fan out around it as an outer ring
    (up to 3 rings deep). Click an item to use it.

    Item fields:
        label, icon         text + Font Awesome 6 (free/solid) icon name
        type                'client' | 'server' | 'command'
        event / command     what to run
        args                passed to the event
        items = { ... }     makes it a section (opens the next ring)
        keepOpen = true     don't close the menu after selecting
]]

local function veh(label, icon, args, keepOpen)
    return { label = label, icon = icon, type = 'client', event = 'zc_radial:client:vehicle', args = args, keepOpen = keepOpen }
end
local function cmd(label, icon, command)
    return { label = label, icon = icon, type = 'command', command = command }
end
local function ev(label, icon, event, args)
    return { label = label, icon = icon, type = 'client', event = event, args = args }
end

Config.Menu = {
    -------------------------------------------------------------------
    -- VEHICLE  (only when you are inside a vehicle)
    -------------------------------------------------------------------
    {
        label = 'Vehicle', icon = 'car', vehicle = true,
        items = {
            veh('Engine', 'power-off', { action = 'engine' }, true),
            {
                label = 'Doors', icon = 'door-open',
                items = {
                    veh('Front Left',  'door-open', { action = 'door', door = 0 }, true),
                    veh('Front Right', 'door-open', { action = 'door', door = 1 }, true),
                    veh('Rear Left',   'door-open', { action = 'door', door = 2 }, true),
                    veh('Rear Right',  'door-open', { action = 'door', door = 3 }, true),
                    veh('Hood',        'car-side',  { action = 'door', door = 4 }, true),
                    veh('Trunk',       'box-open',  { action = 'door', door = 5 }, true),
                    veh('All Doors',   'car',       { action = 'alldoors' }, true),
                }
            },
            {
                label = 'Windows', icon = 'wind',
                items = {
                    veh('Front Left',  'wind', { action = 'window', window = 0 }, true),
                    veh('Front Right', 'wind', { action = 'window', window = 1 }, true),
                    veh('Rear Left',   'wind', { action = 'window', window = 2 }, true),
                    veh('Rear Right',  'wind', { action = 'window', window = 3 }, true),
                    veh('All',         'wind', { action = 'windows' }, true),
                }
            },
            {
                label = 'Seats', icon = 'chair',
                items = {
                    veh('Driver',     'gauge-high', { action = 'seat', seat = -1 }),
                    veh('Passenger',  'user',       { action = 'seat', seat = 0 }),
                    veh('Rear Left',  'user',       { action = 'seat', seat = 1 }),
                    veh('Rear Right', 'user',       { action = 'seat', seat = 2 }),
                }
            },
            veh('Lights', 'lightbulb', { action = 'lights' }, true),
            cmd('Lock', 'lock', 'lock'),
            cmd('Give Keys', 'key', 'givekeys'),
        }
    },

    -------------------------------------------------------------------
    -- POLICE  (only for police jobs)
    -------------------------------------------------------------------
    {
        label = 'Police', icon = 'shield-halved',
        jobs = { 'police', 'sheriff', 'bcso', 'sasp' },
        items = {
            {
                label = 'Citizen', icon = 'person',
                items = {
                    ev('Cuff',   'handcuffs',        'police:client:CuffPlayer'),
                    ev('Escort', 'people-arrows',    'police:client:EscortPlayer'),
                    ev('Search', 'magnifying-glass', 'police:client:SearchPlayer'),
                    ev('Put In Vehicle', 'right-to-bracket',   'police:client:PutPlayerInVehicle'),
                    ev('Take Out',       'right-from-bracket', 'police:client:SetPlayerOutVehicle'),
                }
            },
            {
                label = 'Objects', icon = 'road-barrier',
                items = {
                    ev('Cone',    'traffic-light', 'police:client:spawnCone'),
                    ev('Barrier', 'road-barrier',  'police:client:spawnBarrier'),
                    cmd('Spikes', 'road-spikes',   'spikestrip'),
                    ev('Remove',  'trash',         'police:client:deleteObject'),
                }
            },
            {
                label = 'Vehicle', icon = 'car-side',
                items = {
                    ev('Impound', 'truck-pickup', 'police:client:ImpoundVehicle'),
                    cmd('Plate Check', 'rectangle-list', 'plate'),
                    cmd('Radar', 'satellite-dish', 'radar'),
                }
            },
            -- zc_police panels
            ev('MDT',       'tablet-screen-button', 'zc_police:client:open', { panel = 'mdt' }),
            ev('Prison',    'building-shield',      'zc_police:client:open', { panel = 'jail' }),
            ev('Citations', 'file-invoice-dollar',  'zc_police:client:open', { panel = 'fine' }),
            cmd('Backup', 'tower-broadcast',      '10-78'),
            cmd('Duty',   'user-shield',          'duty'),
        }
    },

    -------------------------------------------------------------------
    -- EMS  (only for ambulance jobs)
    -------------------------------------------------------------------
    {
        label = 'EMS', icon = 'kit-medical',
        jobs = { 'ambulance', 'ems' },
        items = {
            ev('Revive', 'heart-pulse',   'hospital:client:RevivePlayer'),
            ev('Heal',   'bandage',       'hospital:client:TreatWounds'),
            ev('Escort', 'people-arrows', 'police:client:EscortPlayer'),
            cmd('Stretcher', 'bed-pulse', 'stretcher'),
            cmd('Duty', 'user-doctor', 'duty'),
        }
    },

    -------------------------------------------------------------------
    -- EVERYONE
    -------------------------------------------------------------------
    {
        label = 'Citizen', icon = 'user',
        items = {
            cmd('Show ID',     'id-card',          'showid'),
            cmd('Give Number', 'address-book',     'givenumber'),
            cmd('Carry',       'people-carry-box', 'carry'),
            cmd('Rob',         'mask',             'rob'),
        }
    },
    {
        label = 'Emotes', icon = 'person-walking',
        items = {
            cmd('Emote Menu', 'face-smile', 'emotemenu'),
            cmd('Hands Up',   'hand',       'e handsup'),
            cmd('Sit',        'chair',      'e sit'),
            cmd('Cancel',     'ban',        'e c'),
        }
    },
    {
        label = 'Clothing', icon = 'shirt',
        items = {
            cmd('Hat',     'hat-cowboy',    'hat'),
            cmd('Mask',    'masks-theater', 'mask'),
            cmd('Glasses', 'glasses',       'glasses'),
            cmd('Shirt',   'shirt',         'shirt'),
            cmd('Pants',   'socks',         'pants'),
            cmd('Shoes',   'shoe-prints',   'shoes'),
        }
    },
    { label = 'Flip Vehicle', icon = 'rotate', vehicle = false,   -- on foot only
      type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'flip' } },
    cmd('GPS',      'map-location-dot', 'gps'),
    cmd('Phone',    'mobile-screen',    'phone'),
    cmd('Settings', 'gear',             'settings'),
}
