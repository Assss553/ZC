# VC2 kiosk model

`vc2_kiosk.glb` is the 3D model of the VC2 kiosk: about 11.5k triangles, real-world size (0.86 m wide, 1.86 m tall), origin at the ground centre. Previews: `preview_front.png`, `preview_side.png`, `preview_closeup.png`.

The hologram screen floating above the kiosk is **not** part of the model. The script draws it in the game.

GTA V / FiveM only loads models in its own format (`.ydr` + `.ytyp`), so the `.glb` has to be converted once in Blender. It takes about 10 minutes.

## What you need
- [Blender](https://www.blender.org/) 4.x
- The [Sollumz](https://github.com/Sollumz/Sollumz) add-on (the standard GTA V / FiveM exporter for Blender)

## Steps
1. **Import**: Blender → *File → Import → glTF 2.0* → `vc2_kiosk.glb`.
2. **Convert to a drawable**: select every kiosk mesh. In the Sollumz panel choose *Convert to Drawable* (shader **default** for all materials).
3. **Glowing parts**: set these materials to the **emissive** shader:
   - `vc2_led`
   - `vc2_logo`
   - `vc2_screen`
4. **Texture name (important)**: name the screen texture **`vc2_screen_tex`**. The script replaces this texture at runtime, so the kiosk's own display shows the live VC2 screen.
5. **Collision**: with the drawable selected, use Sollumz *Create Bound → Composite* and add a simple **box** around the kiosk (about 0.86 × 0.62 × 1.86 m).
6. **Name**: rename the drawable to `vc2_kiosk`.
7. **Export**:
   - Sollumz *Export* → `vc2_kiosk.ydr` (textures embedded or as `vc2_kiosk.ytd`).
   - In Sollumz *Archetypes*, create a `.ytyp` with one archetype named `vc2_kiosk` (type: base, LOD distance 100) and export `vc2_kiosk.ytyp`.
8. **Install**:
   - Create the folder `VC2/stream/` and put `vc2_kiosk.ydr` (plus `.ytd`) and `vc2_kiosk.ytyp` in it.
   - In `fxmanifest.lua`, uncomment: `data_file 'DLC_ITYP_REQUEST' 'stream/vc2_kiosk.ytyp'`
9. Restart the server.

`Config.KioskModel` is already `'vc2_kiosk'`, so the script uses the new model automatically. Until the model is streamed, it falls back to `Config.KioskFallbackModel` (`prop_atm_03`).

## Facing direction
The model is exported so its front should face the direction you look when placing it with `/vc2place`. If it comes out backwards in the game:
- rotate it 180° in Blender (Z axis) and export again, or
- set `Config.KioskScreen.flip = true` for the hologram.
