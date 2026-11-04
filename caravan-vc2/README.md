# Caravan VC2

An original, realistic Class C motorhome designed for VC2, built for FiveM. The interior is an **empty hollow shell** you can furnish yourself.

![front](model/preview_front.png)

| | |
|---|---|
| ![inside](model/preview_inside_door.png) | ![door](model/preview_dooropen.png) |
| ![mirror](model/preview_mirror.png) | ![rear](model/preview_rear.png) |

## What's in it
- **Hollow shell**: real wall thickness, floor, walls and ceiling. Real openings are cut through the walls: windows, entry door, skylight, rear window, and an open pass-through to the cab.
- **Empty living area**: vinyl plank floor, ceiling lights and LED strips, wheel wells over the rear wheels, and an empty cab-over bunk deck. Nothing else is inside, so you can furnish it.
- **Clear glass everywhere** (no tint): windshield, cab windows, all side windows, door window, skylight, rear window.
- **Mirrors**: two side mirrors with real mirror glass, angled toward the vehicle like real mirrors.
- **Opening doors**: both cab doors and the entry door are separate parts, each with its pivot on the hinge.
- **Cab**: dashboard, instrument cluster, steering wheel and two seats.
- **Realistic wheels**: tyres with a sidewall profile and tread grooves, alloy front rims, steel/alloy **dual rear wheels**, hub caps and lug nuts.
- **Outside**: VC2 livery, awning, storage bays, roof AC units, solar panels, ladder, spare wheel, and lights: headlights, DRLs, fog, tail, marker and LED underglow.
- **Size**: ~8.1 m long, 2.45 m wide, ~3.75 m tall.

## Folders
| Path | Contents |
|---|---|
| `model/vc2_caravan.glb` | The 3D model (glTF binary, ~80k triangles). Open in Blender / ZModeler. |
| `model/preview_*.png` | Renders: outside, inside, open door, mirror. |
| `model/vc2_caravan_builder.html` | Design source (three.js). Open in a browser. Views: `?v=front`, `side`, `rear`, `inside`, `inside_door`, `inside_side`, `window`, `mirror`, `cabin`, `dooropen&door=open`. |
| `fivem/vc2caravan/` | Ready FiveM add-on vehicle resource: `fxmanifest.lua`, `handling.meta`, `vehicles.meta`, `carvariations.meta`, `client.lua`. |

## Realistic driving (`fivem/vc2caravan/data/handling.meta`)
| | Value | Real-world reason |
|---|---|---|
| Weight | 6,000 kg | Typical Class C gross weight |
| Drive | Rear-wheel, 6-speed | Ford E-series style chassis |
| Top speed | ~115-120 km/h | Governed motorhome top speed |
| Acceleration | Slow (drive force 0.15) | 0-100 km/h in ~20 s |
| Brakes | Weak (0.28) | Long braking distance for a heavy vehicle |
| Centre of mass | High (+0.35 m) | Body leans in corners |
| Air drag | High (14) | Tall, flat front |
| Fuel tank | 150 L | |
| Sound | GTA `CAMPER` | |
| Glass | `diffuseTint 0x00FFFFFF` | No window tint |

These are starting values. Drive it in the game and tune it: top speed through `fInitialDriveMaxFlatVel`, weight through `fMass`, braking through `fBrakeForce`.

## Putting it in the game
GTA V needs the model in its own vehicle format: `vc2caravan.yft` + `vc2caravan_hi.yft` + `vc2caravan.ytd`. The `.glb` has to be rigged and exported once in **Blender + [Sollumz](https://github.com/Sollumz/Sollumz)** or in **ZModeler 3**.

1. Import `vc2_caravan.glb`.
2. **Rig it.** The parts already use GTA bone names, so they map straight onto the vehicle skeleton:
   - body: `bodyshell` / `chassis`
   - wheels: `wheel_lf`, `wheel_rf`, `wheel_lr`, `wheel_rr`
   - doors: `door_dside_f`, `door_pside_f`, and the entry door `door_pside_r`
   - glass: `windscreen`, `window_lf`, `window_rf`
   - cab: `steeringw`, `seat_dside_f`, `seat_pside_f`
   - lights: `headlight_l`, `headlight_r`, `taillight_l`, `taillight_r`, `indicator_lf`, `indicator_rf`
3. **Shaders:**
   - Glass: `vehicle_vehglass` with no tint.
   - Mirror glass (`vc2_mirror`): a chrome / reflective vehicle shader.
   - Body: `vehicle_paint` (so it can be repainted).
   - Lights: emissive vehicle light shaders.
4. **Collision**: add a simple collision (bounds) around the body and the cab. Leave the interior hollow so players can walk inside.
5. Export `vc2caravan.yft`, `vc2caravan_hi.yft` and `vc2caravan.ytd` into `fivem/vc2caravan/stream/`.
6. Copy `fivem/vc2caravan` to your server's `resources`, add `ensure vc2caravan` to `server.cfg`, and spawn it with `vc2caravan`.

## Notes
- **Mirrors**: GTA V does not render live mirror reflections on vehicles. In the game the mirror glass reflects the environment the way chrome does. The live reflections in `preview_mirror.png` only exist in the design preview.
- **Walking inside while driving**: GTA has no built-in way to walk inside a moving vehicle. Walking inside works when the caravan is parked. A standing-passenger or "enter interior" system needs a separate script.
