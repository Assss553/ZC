fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vc2caravan'
description 'VC2 Caravan - Class C motorhome (add-on vehicle)'
version '1.0.0'

files {
    'data/vehicles.meta',
    'data/handling.meta',
    'data/carvariations.meta',
}

data_file 'HANDLING_FILE'            'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE'    'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE'   'data/carvariations.meta'

client_script 'client.lua'
