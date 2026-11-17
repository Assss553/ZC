--[[ ROX Laundry  ·  © ROX Store – All rights reserved. ]]
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rox_laundry'
author 'ROX Store'
description 'ROX Laundry: walk-in laundromat map + wash / dry / fold minigame'
version '1.0.0'

this_is_a_map 'yes'
data_file 'DLC_ITYP_REQUEST' 'stream/rox_laundry.ytyp'

shared_scripts { 'config.lua', 'shared/props.lua', 'shared/locale.lua' }
server_scripts { 'server/main.lua' }
client_scripts { 'client/main.lua' }

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }
