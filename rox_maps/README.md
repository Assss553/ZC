# ROX maps - ROX Diner + Underground Gang HQ
ROX Store | All rights reserved

## Contents
- `blender/build_restaurant.py`  – builds the whole map in Blender + exports via Sollumz (CodeWalker XML)
- `blender/gen_textures.py`      – generates all textures (original, procedural, 1024px + normal maps)
- `blender/furniture.py`         – detailed furniture + lights: dining chairs, bar stools, booths, round/rect tables,
                                   Chesterfield sofa, office chairs, pendant lamps, wall sconces, LED strips, plants, skirting
- `blender/package.py`           – DDS textures + ytyp/ymap from the exported drawables
- `blender/rox_restaurant.blend` – Blender source file
- `renders/`                     – preview renders (overview.png)

## Lights
Pendants/sconces/LED strips are exported as real GTA drawable lights (16 in the diner, 2 in the HQ).
Collision is auto-simplified to stay under the 32767-vertex bound limit.
- `codewalker_xml/`              – rox_diner_ext / _int / _hq + rox_secret_wall .ydr.xml (+ DDS texture folders), rox_diner.ytyp.xml, rox_diner.ymap.xml
- `client.lua / server.lua / config.lua` – moving secret wall + secret elevator (gang-only, server-validated)

## Secret wall + elevator (how it plays)
1. Gang member uses ox_target **Knock on wall** at the back of the kitchen.
2. The brick wall (`rox_secret_wall`, separate model) swings open on its hinge for **everyone** (GlobalState sync, smooth ease),
   auto-closes after 10s. Non-gang players just see "Just a brick wall...".
3. Behind it: hidden room with steel elevator doors and a red warning light -> **Elevator: Down** -> ride (fade + sounds) -> HQ.
4. In the HQ: **Elevator: Up** at the south wall.
All positions are offsets from `Config.Origin` / `Config.Heading`: if you move the map in CodeWalker, change only those two.

## Convert to game files (CodeWalker, Windows)
1. CodeWalker > Tools > **Import XML** > choose the `codewalker_xml` folder (keep texture folders next to the .ydr.xml).
2. You get `rox_diner_ext.ydr`, `rox_diner_int.ydr`, `rox_diner_hq.ydr`, `rox_diner.ytyp`, `rox_diner.ymap`.
3. Put all of them (incl. `rox_secret_wall.ydr`) in `rox_maps/stream/` (fxmanifest is already set up).
4. Open CodeWalker World near Pacific Standard (Vinewood), move the 3 entities to a free spot
   (default 232, 300, 105.6), then update `Config.SecretWall` and `Config.HQ` in config.lua.

## Rebuild
    python gen_textures.py textures
    python build_restaurant.py <path-to-folder-containing-sollumz> out
    python package.py out/stream
