fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'zc_realestate'
author 'ZC'
description 'Real estate system: realtor iPad, aim-based property creation, contracts, rent, marketplace and furniture'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/locale.lua',
    'shared/interiors.lua',
    'shared/furniture.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/server.lua',
    'server/callbacks.lua',
    'server/database.lua',
    'server/main.lua',
    'server/furniture.lua',
    'server/rent.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/callbacks.lua',
    'client/utils.lua',
    'client/main.lua',
    'client/tablet.lua',
    'client/furniture.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/i18n.js',
    'html/app.js',
    'html/img/*.*',
    'html/img/houses/*.*',
}

dependencies {
    'oxmysql',
}
