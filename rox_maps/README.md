# ROX maps - ROX Diner + Underground Gang HQ
ROX Store | All rights reserved

## Contents
- `blender/build_restaurant.py`  – builds the whole map in Blender + exports via Sollumz (CodeWalker XML)
- `blender/gen_textures.py`      – generates all textures (original, procedural, 1024px + normal maps)
- `blender/rox_restaurant.blend` – Blender source file
- `codewalker_xml/`              – rox_diner_ext / _int / _hq .ydr.xml (+ DDS texture folders), rox_diner.ytyp.xml, rox_diner.ymap.xml
- `client.lua / server.lua / config.lua` – secret wall (ox_target), gang-only, fade + teleport

## Convert to game files (CodeWalker, Windows)
1. CodeWalker > Tools > **Import XML** > choose the `codewalker_xml` folder (keep texture folders next to the .ydr.xml).
2. You get `rox_diner_ext.ydr`, `rox_diner_int.ydr`, `rox_diner_hq.ydr`, `rox_diner.ytyp`, `rox_diner.ymap`.
3. Put them in `rox_maps/stream/` and add to fxmanifest: `this_is_a_map 'yes'` and `data_file 'DLC_ITYP_REQUEST' 'stream/rox_diner.ytyp'`.
4. Open CodeWalker World near Pacific Standard (Vinewood), move the 3 entities to a free spot
   (default 232, 300, 105.6), then update `Config.SecretWall` and `Config.HQ` in config.lua.

## Rebuild
    python gen_textures.py textures
    python build_restaurant.py <path-to-folder-containing-sollumz> out
