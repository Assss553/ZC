-- ROX Store | rox_phone | All rights reserved.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX Phone - foldable phone (Qbox)'
version '0.5.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/*.js', 'html/img/*.webp', 'html/fa/css/*.css', 'html/fa/webfonts/*' }
dependencies { 'qbx_core', 'ox_lib', 'oxmysql' }
