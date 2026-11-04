fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'zc_police'
description 'ZC - Police tablet: MDT, Prison Management, Citations'
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
