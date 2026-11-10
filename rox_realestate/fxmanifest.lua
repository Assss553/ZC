--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rox_realestate'
-- © ROX Store – All rights reserved
author 'ROX Store'
description 'Real estate system: realtor iPad, aim-based property creation, contracts, rent, marketplace and furniture'
version '1.2.0'

-- shells / maps dropped in stream/houses are streamed automatically
this_is_a_map 'yes'
data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'

shared_scripts {
    'config.lua',
    'shared/locale.lua',
    'shared/interiors.lua',
    'shared/furniture.lua',
    'shared/decor.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/callbacks.lua',
    'server/database.lua',
    'server/main.lua',
    'server/furniture.lua',
    'server/rent.lua',
    'server/detect.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/callbacks.lua',
    'client/utils.lua',
    'client/main.lua',
    'client/tablet.lua',
    'client/furniture.lua',
    'client/decor.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/i18n.js',
    'html/app.js',
    'html/img/*.*',
    'html/img/houses/*.*',
    'html/img/furniture/*.*',
    'html/img/icons/*.*',
    'html/img/wallpapers/*.*',
}

dependencies {
    'oxmysql',
}
