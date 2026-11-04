Config = {}

-- Key that opens the menu (players can rebind it in GTA Settings > Key Bindings > FiveM)
Config.Key = 'F1'

-- Accent colour of the menu (any CSS colour)
Config.Color = '#ff5a1f'

-- Title shown in the middle when nothing is hovered
Config.Title = 'ZC MENU'

-- true  = player can keep walking/driving while the menu is open (camera & shooting are blocked)
-- false = the game is frozen while the menu is open
Config.KeepInput = true

-- Small UI sounds (hover tick / select / open)
Config.Sound = true

--[[
    Item fields:
        label       text shown in the middle when hovered
        icon        Font Awesome 6 icon name, e.g. 'car', 'shirt', 'shield-halved'
        type        'client' | 'server' | 'command'
        event       event name (client / server)
        command     command name without '/' (type = 'command')
        args        anything, passed to the event
        items       { ... }  -> makes it a sub menu
        canInteract function() return true end  (optional, hides the item when false)
        keepOpen    true -> don't close the menu after selecting
]]

Config.MenuItems = {
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
            { label = 'Hat',     icon = 'hat-cowboy', type = 'command', command = 'hat' },
            { label = 'Mask',    icon = 'masks-theater', type = 'command', command = 'mask' },
            { label = 'Glasses', icon = 'glasses',    type = 'command', command = 'glasses' },
            { label = 'Shirt',   icon = 'shirt',      type = 'command', command = 'shirt' },
            { label = 'Pants',   icon = 'socks',      type = 'command', command = 'pants' },
            { label = 'Shoes',   icon = 'shoe-prints', type = 'command', command = 'shoes' },
        }
    },
    {
        label = 'Vehicle', icon = 'car',
        canInteract = function() return IsPedInAnyVehicle(PlayerPedId(), false) end,
        items = {
            { label = 'Engine',      icon = 'power-off',       type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'engine' }, keepOpen = true },
            { label = 'Hood',        icon = 'car-side',        type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'door', door = 4 }, keepOpen = true },
            { label = 'Trunk',       icon = 'box-open',        type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'door', door = 5 }, keepOpen = true },
            { label = 'Windows',     icon = 'wind',            type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'windows' }, keepOpen = true },
            { label = 'Shuffle Seat',icon = 'chair',           type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'shuffle' } },
            {
                label = 'Doors', icon = 'door-open',
                items = {
                    { label = 'Front Left',  icon = 'door-open', type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'door', door = 0 }, keepOpen = true },
                    { label = 'Front Right', icon = 'door-open', type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'door', door = 1 }, keepOpen = true },
                    { label = 'Rear Left',   icon = 'door-open', type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'door', door = 2 }, keepOpen = true },
                    { label = 'Rear Right',  icon = 'door-open', type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'door', door = 3 }, keepOpen = true },
                }
            },
        }
    },
    {
        label = 'Flip Vehicle', icon = 'rotate',
        canInteract = function() return not IsPedInAnyVehicle(PlayerPedId(), false) end,
        type = 'client', event = 'zc_radial:client:vehicle', args = { action = 'flip' }
    },
    { label = 'GPS',      icon = 'map-location-dot', type = 'command', command = 'gps' },
    { label = 'Phone',    icon = 'mobile-screen',    type = 'command', command = 'phone' },
    { label = 'Music',    icon = 'music',            type = 'command', command = 'music' },
    { label = 'Keys',     icon = 'key',              type = 'command', command = 'givekeys' },
    { label = 'Settings', icon = 'bars',             type = 'command', command = 'settings' },
}

-- Extra items that only show for a job (QBCore / Qbox / ESX are detected automatically)
Config.JobItems = {
    police = {
        {
            label = 'Police', icon = 'shield-halved',
            items = {
                { label = 'Police Radar', icon = 'satellite-dish', type = 'command', command = 'radar' },
                { label = 'Cuff',         icon = 'handcuffs',      type = 'client', event = 'police:client:CuffPlayer' },
                { label = 'Escort',       icon = 'people-arrows',  type = 'client', event = 'police:client:EscortPlayer' },
                { label = 'Search',       icon = 'magnifying-glass', type = 'client', event = 'police:client:SearchPlayer' },
                { label = 'Put In Vehicle', icon = 'car-side',     type = 'client', event = 'police:client:PutPlayerInVehicle' },
                { label = 'MDT',          icon = 'tablet-screen-button', type = 'command', command = 'mdt' },
                { label = 'Spike Strip',  icon = 'road-spikes',    type = 'command', command = 'spikestrip' },
            }
        },
    },
    ambulance = {
        {
            label = 'EMS', icon = 'kit-medical',
            items = {
                { label = 'Revive', icon = 'heart-pulse', type = 'client', event = 'hospital:client:RevivePlayer' },
                { label = 'Heal',   icon = 'bandage',     type = 'client', event = 'hospital:client:TreatWounds' },
                { label = 'Stretcher', icon = 'bed-pulse', type = 'command', command = 'stretcher' },
            }
        },
    },
}
