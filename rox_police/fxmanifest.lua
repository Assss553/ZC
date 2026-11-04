-- ROX Store | All rights reserved. Owner: ROX Store
-- Unauthorized resale or redistribution is not allowed.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rox_police'
author 'ROX Store'
description 'ROX Store - Police iPad: MDT, Prison, Citations, Management, Impound, Unmask'
version '1.0.0'

shared_script 'config.lua'
client_scripts { 'client/main.lua', 'client/jail.lua' }
server_scripts { 'server/bridge.lua', 'server/main.lua' }

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/fa/css/*.css',
    'html/fa/webfonts/*',
}
