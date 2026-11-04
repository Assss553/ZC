fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'VC2'
description 'VC2 - Car showroom self-service kiosk (QBCore / ESX / Standalone)'
author 'VC2'
version '1.0.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}
