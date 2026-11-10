fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vc2caravan'
description 'VC2 Caravan - Class C motorhome with set-up mode (legs + slide-outs), walk-in interior, furniture and exterior customisation'
version '1.1.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'data/vehicles.meta',
    'data/handling.meta',
    'data/carvariations.meta',
}

data_file 'HANDLING_FILE'            'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE'    'data/vehicles.meta'
data_file 'VEHICLE_VARIATION_FILE'   'data/carvariations.meta'
-- slide-out / leg props (vc2caravan_slideout_side, vc2caravan_slideout_rear, vc2caravan_jack)
data_file 'DLC_ITYP_REQUEST' 'stream/vc2caravan_props.ytyp'

dependency 'oxmysql'
