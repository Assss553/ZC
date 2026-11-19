# rox_weapons – new weapon models (ROX Store)

These replace the **model only** of existing GTA weapons, so animations, sounds, damage and ox_inventory keep working.

| Weapon | New look |
|---|---|
| WEAPON_SNIPERRIFLE | Lee-Enfield style bolt rifle (wood) |
| WEAPON_REVOLVER | Old revolver (steel + wood grip) |

## Install
1. CodeWalker > Tools > **Import XML** > `codewalker_xml/` (keep the texture folders next to the .ydr.xml).
2. Put the generated `w_sr_sniperrifle.ydr` and `w_pi_revolver.ydr` in `rox_weapons/stream/`.
3. `ensure rox_weapons` in rox.cfg.
4. Icons are already copied to `rox_weaponhud/html/icons` and `ox_inventory/web/images`.

## Check in game (not tested yet)
- Hand position: if the hand is not on the grip, change the grip numbers in the convert command and re-export.
- Orientation: barrel is +X, up is +Z, grip at the origin. If the weapon points backwards in game, re-export with rotation 0,0,180.

## Add more weapons
    python convert_weapon.py <sollumz_addons> <model.fbx|.obj|.blend> <out> <gta_model_name> <length_m> <rx,ry,rz> <grip_from_muzzle,grip_height> <ICON_NAME>
