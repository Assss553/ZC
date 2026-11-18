-- ROX Store | All rights reserved
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX maps - ROX Diner + secret underground gang HQ'
version '0.2.0'
this_is_a_map 'yes'
data_file 'DLC_ITYP_REQUEST' 'stream/rox_diner.ytyp'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'
files { 'stream/rox_diner.ytyp' }
dependencies { 'ox_lib', 'ox_target', 'qbx_core' }
