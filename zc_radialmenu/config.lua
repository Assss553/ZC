Config = {}

-- Default accent colour (any menu can override it with its own `color`)
Config.Color = '#ff5a1f'

-- true  = player can keep walking/driving while a menu is open (camera & shooting are blocked)
-- false = the game is frozen while a menu is open
Config.KeepInput = true

-- Small UI sounds (hover tick / select / open)
Config.Sound = true

--[[
    Every menu has its own key (players can rebind them in GTA Settings > Key Bindings > FiveM).

    Menu fields:
        key         default key
        title       text in the middle
        color       (optional) accent colour for this menu only
        jobs        (optional) { 'police', 'sheriff' } -> only these jobs can open it
        canOpen     (optional) function() return true end
        items       { ... }

    Item fields:
        label       text shown in the middle when hovered
        icon        Font Awesome 6 icon name, e.g. 'car', 'shirt', 'shield-halved'
        type        'client' | 'server' | 'command' | 'menu'
        event       event name (client / server)
        command     command name without '/' (type = 'command')
        menu        name of another menu to switch to (type = 'menu')
        args        anything, passed to the event
        items       { ... }  -> makes it a sub menu
        canInteract function() return true end  (optional, hides the item when false)
        keepOpen    true -> don't close the menu after selecting
]]

local function inVehicle() return IsPedInAnyVehicle(PlayerPedId(), false) end
local function veh(args, keepOpen)
    return { type = 'client', event = 'zc_radial:client:vehicle', args = args, keepOpen = keepOpen }
end
local function item(label, icon, base)
    base = base or {}
    base.label, base.icon = label, icon
    return base
end

Config.Menus = {}

---------------------------------------------------------------------------
-- F1 : MAIN MENU
---------------------------------------------------------------------------
Config.Menus.main = {
    key = 'F1',
    title = 'ZC MENU',
    items = {
        {
            label = 'Citizen', icon = 'user',
            items = {
                { label = 'Give Number', icon = 'address-book', type = 'command', command = 'givenumber' },
                { label = 'Show ID',     icon = 'id-card',      type = 'command', command = 'showid' },
                { label = 'Carry',       icon = 'people-carry-box', type = 'command', command = 'carry' },
                { label = 'Rob',         icon = 'mask',         type = 'command', command = 'rob' },
            }
        },
        {
            label = 'Emotes', icon = 'person-walking',
            items = {
                { label = 'Emote Menu', icon = 'face-smile', type = 'command', command = 'emotemenu' },
                { label = 'Cancel',     icon = 'ban',        type = 'command', command = 'e c' },
                { label = 'Hands Up',   icon = 'hand',       type = 'command', command = 'e handsup' },
                { label = 'Sit',        icon = 'chair',      type = 'command', command = 'e sit' },
            }
        },
        {
            label = 'Clothing', icon = 'shirt',
            items = {
                { label = 'Hat',     icon = 'hat-cowboy',    type = 'command', command = 'hat' },
                { label = 'Mask',    icon = 'masks-theater', type = 'command', command = 'mask' },
                { label = 'Glasses', icon = 'glasses',       type = 'command', command = 'glasses' },
                { label = 'Shirt',   icon = 'shirt',         type = 'command', command = 'shirt' },
                { label = 'Pants',   icon = 'socks',         type = 'command', command = 'pants' },
                { label = 'Shoes',   icon = 'shoe-prints',   type = 'command', command = 'shoes' },
            }
        },
        -- shortcuts to the other menus
        { label = 'Vehicle', icon = 'car',           type = 'menu', menu = 'vehicle', canInteract = inVehicle },
        { label = 'Police',  icon = 'shield-halved', type = 'menu', menu = 'police' },
        { label = 'EMS',     icon = 'kit-medical',   type = 'menu', menu = 'ambulance' },

        { label = 'Flip Vehicle', icon = 'rotate', type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'flip' },
          canInteract = function() return not inVehicle() end },
        { label = 'GPS',      icon = 'map-location-dot', type = 'command', command = 'gps' },
        { label = 'Phone',    icon = 'mobile-screen',    type = 'command', command = 'phone' },
        { label = 'Music',    icon = 'music',            type = 'command', command = 'music' },
        { label = 'Settings', icon = 'bars',             type = 'command', command = 'settings' },
    }
}

---------------------------------------------------------------------------
-- F6 : POLICE MENU  (police jobs only)
---------------------------------------------------------------------------
Config.Menus.police = {
    key = 'F6',
    title = 'POLICE',
    jobs = { 'police', 'sheriff', 'bcso', 'sasp' },
    -- color = '#2f7bff',   -- uncomment for a blue police menu
    items = {
        { label = 'Police Radar', icon = 'satellite-dish',   type = 'command', command = 'radar' },
        { label = 'Cuff',         icon = 'handcuffs',        type = 'client', event = 'police:client:CuffPlayer' },
        { label = 'Escort',       icon = 'people-arrows',    type = 'client', event = 'police:client:EscortPlayer' },
        { label = 'Search',       icon = 'magnifying-glass', type = 'client', event = 'police:client:SearchPlayer' },
        {
            label = 'Vehicle', icon = 'car-side',
            items = {
                { label = 'Put In Vehicle',  icon = 'right-to-bracket', type = 'client', event = 'police:client:PutPlayerInVehicle' },
                { label = 'Take Out',        icon = 'right-from-bracket', type = 'client', event = 'police:client:SetPlayerOutVehicle' },
                { label = 'Impound',         icon = 'truck-pickup',     type = 'client', event = 'police:client:ImpoundVehicle' },
                { label = 'Plate Check',     icon = 'rectangle-list',   type = 'command', command = 'plate' },
            }
        },
        {
            label = 'Objects', icon = 'road-barrier',
            items = {
                { label = 'Cone',        icon = 'traffic-light', type = 'client', event = 'police:client:spawnCone' },
                { label = 'Barrier',     icon = 'road-barrier',  type = 'client', event = 'police:client:spawnBarrier' },
                { label = 'Spike Strip', icon = 'road-spikes',   type = 'command', command = 'spikestrip' },
                { label = 'Remove',      icon = 'trash',         type = 'client', event = 'police:client:deleteObject' },
            }
        },
        { label = 'Fine',   icon = 'file-invoice-dollar',  type = 'command', command = 'fine' },
        { label = 'Jail',   icon = 'building-shield',      type = 'command', command = 'jail' },
        { label = 'MDT',    icon = 'tablet-screen-button', type = 'command', command = 'mdt' },
        { label = 'Duty',   icon = 'user-shield',          type = 'command', command = 'duty' },
        { label = 'Backup', icon = 'tower-broadcast',      type = 'command', command = '10-78' },
    }
}

---------------------------------------------------------------------------
-- F6 : EMS MENU  (same key as police, opens for ambulance job)
---------------------------------------------------------------------------
Config.Menus.ambulance = {
    key = 'F6',
    title = 'EMS',
    jobs = { 'ambulance', 'ems' },
    items = {
        { label = 'Revive',    icon = 'heart-pulse', type = 'client', event = 'hospital:client:RevivePlayer' },
        { label = 'Heal',      icon = 'bandage',     type = 'client', event = 'hospital:client:TreatWounds' },
        { label = 'Stretcher', icon = 'bed-pulse',   type = 'command', command = 'stretcher' },
        { label = 'Escort',    icon = 'people-arrows', type = 'client', event = 'police:client:EscortPlayer' },
        { label = 'Duty',      icon = 'user-doctor', type = 'command', command = 'duty' },
    }
}

---------------------------------------------------------------------------
-- F3 : VEHICLE MENU  (only inside a vehicle)
---------------------------------------------------------------------------
Config.Menus.vehicle = {
    key = 'F3',
    title = 'VEHICLE',
    canOpen = inVehicle,
    items = {
        item('Engine',  'power-off', veh({ action = 'engine' }, true)),
        item('Hood',    'car-side',  veh({ action = 'door', door = 4 }, true)),
        item('Trunk',   'box-open',  veh({ action = 'door', door = 5 }, true)),
        {
            label = 'Doors', icon = 'door-open',
            items = {
                item('Front Left',  'door-open', veh({ action = 'door', door = 0 }, true)),
                item('Front Right', 'door-open', veh({ action = 'door', door = 1 }, true)),
                item('Rear Left',   'door-open', veh({ action = 'door', door = 2 }, true)),
                item('Rear Right',  'door-open', veh({ action = 'door', door = 3 }, true)),
                item('All Doors',   'car',       veh({ action = 'alldoors' }, true)),
            }
        },
        {
            label = 'Windows', icon = 'wind',
            items = {
                item('Front Left',  'wind', veh({ action = 'window', window = 0 }, true)),
                item('Front Right', 'wind', veh({ action = 'window', window = 1 }, true)),
                item('Rear Left',   'wind', veh({ action = 'window', window = 2 }, true)),
                item('Rear Right',  'wind', veh({ action = 'window', window = 3 }, true)),
                item('All Windows', 'wind', veh({ action = 'windows' }, true)),
            }
        },
        {
            label = 'Seats', icon = 'chair',
            items = {
                item('Driver',      'gauge-high', veh({ action = 'seat', seat = -1 })),
                item('Passenger',   'user',  veh({ action = 'seat', seat = 0 })),
                item('Rear Left',   'user',  veh({ action = 'seat', seat = 1 })),
                item('Rear Right',  'user',  veh({ action = 'seat', seat = 2 })),
            }
        },
        item('Lights',  'lightbulb',    veh({ action = 'lights' }, true)),
        item('Lock',    'lock',         { type = 'command', command = 'lock' }),
        item('Keys',    'key',          { type = 'command', command = 'givekeys' }),
    }
}
