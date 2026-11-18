-- ROX Store | rox_atm | All rights reserved.
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX ATM - cash machine UI for every ATM (Qbox)'
version '1.0.0'
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'
ui_page 'html/index.html'
files { 'html/index.html' }
dependencies { 'qbx_core', 'ox_lib', 'ox_target' }
