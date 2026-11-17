fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'iaa_tower'
description 'IAA Tower - commercial science tower (MLO + teleports + blip)'
version '1.0.0'

this_is_a_map 'yes'

-- Put exported files from Blender/CodeWalker in stream/:
--   iaa_tower.ydr, iaa_tower.ytyp, iaa_tower.ymap, iaa_tower_col.ybn, iaa_logo.ytd
data_file 'DLC_ITYP_REQUEST' 'stream/iaa_tower.ytyp'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'
