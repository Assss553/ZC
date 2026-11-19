-- ROX Store | All rights reserved
fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'ROX Store'
description 'ROX Gun Store - categories, weapon showcase, colours, stats, licence check'
version '1.0.0'
ui_page 'html/index.html'
files { 'html/index.html' }
shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client.lua'
server_script 'server.lua'
dependencies { 'ox_lib', 'ox_inventory', 'qbx_core' }
