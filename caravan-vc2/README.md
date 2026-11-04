# Caravan VC2

An original Class C motorhome designed for VC2: white body with a graphite / orange VC2 livery, a rounded cab-over bunk, and a generic van front with the VC2 grille badge.

![front](model/preview_front.png)

## Files (`model/`)
| File | What it is |
|---|---|
| `vc2_caravan.glb` | The 3D model (glTF binary, ~42k triangles, real size, origin at the centre on the ground). Opens in Blender, 3ds Max, ZModeler, etc. |
| `preview_*.png` | Renders: front, side, rear, top and night. |
| `vc2_caravan_builder.html` | Source of the design (three.js). Open it in a browser to view it; add `?v=side`, `?v=rear`, `?v=top` or `&night=1`. |

## Size
- Length ~8.1 m, width 2.45 m, height ~3.75 m (with the roof units).
- Single front wheels, dual rear wheels.

## Parts
- **Living box**: rounded cab-over bunk with a window and LED strip, 3 side windows, entry door with window, step, grab handle and porch light.
- **Outside**: roll-out awning, storage bays on both sides, vents, amber marker lights, orange LED underglow.
- **Roof**: 2 AC units, roof vent, solar panels, antenna. Rear ladder and spare wheel.
- **Cab**: original van front with the VC2 grille and badge, headlights with orange DRLs, fog lights, bumper with orange trim, mirrors.
- **Rear**: tail lights with LED strips.

Materials are named (`vc2_paint`, `vc2_glass`, `vc2_tyre`, `vc2_rim`, `vc2_led`, `vc2_tail`, `vc2_livery_r/l` ...). Wheels are separate objects (`wheel_front_*`, `wheel_rear_*`), so they can be rigged for a game vehicle.
