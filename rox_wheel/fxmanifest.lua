-- ROX Store | All rights reserved
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX Wheel - weapons & items wheel (tabs, 8 categories, cycle inside a slot) for ox_inventory'
version '1.0.0'
ui_page 'html/index.html'
files { 'html/index.html' }
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
dependencies { 'ox_lib', 'ox_inventory' }
