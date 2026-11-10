--[[
    ROX Houses (upload folder)  ·  © ROX Store – All rights reserved.
    Drop your house / shell / MLO map files in stream/ and their pictures in images/.
    rox_realestate detects them automatically (iPad > Create Property > Interior).
]]
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'rox_houses'
author 'ROX Store'
description 'ROX Real Estate upload folder: house map files + pictures'
version '1.0.0'

this_is_a_map 'yes'

-- shells need their archetypes (.ytyp) registered
data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'

-- pictures shown in the iPad (nui://rox_houses/images/<name>.png)
files {
    'images/*.*',
    'houses.json',
}
