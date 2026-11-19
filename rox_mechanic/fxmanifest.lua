-- ROX Store | All rights reserved
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX Mechanic - next-gen auto care (performance parts, repair, stats)'
version '1.0.0'
ui_page 'html/index.html'
files { 'html/index.html' }
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
dependencies { 'ox_lib', 'qbx_core', 'oxmysql' }
