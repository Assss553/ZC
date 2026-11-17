-- ROX Store | rox_admin | All rights reserved.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX Admin - players, characters, sessions, coords, permissions (Qbox)'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js', 'html/fa/css/*.css', 'html/fa/webfonts/*' }
dependencies { 'qbx_core', 'ox_lib', 'oxmysql' }
