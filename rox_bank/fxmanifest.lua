-- ROX Store | rox_bank | All rights reserved.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX Bank - bank branches UI (Qbox)'
version '1.0.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/fa/css/*.css', 'html/fa/webfonts/*' }
dependencies { 'qbx_core', 'ox_lib', 'oxmysql', 'ox_target' }
