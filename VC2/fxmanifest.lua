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
    'html/screen.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png'
}

-- Custom kiosk model (optional): put vc2_kiosk.ydr + vc2_kiosk.ytyp in /stream,
-- uncomment the next line and set Config.Placed.kiosk.model = 'vc2_kiosk'
-- data_file 'DLC_ITYP_REQUEST' 'stream/vc2_kiosk.ytyp'
