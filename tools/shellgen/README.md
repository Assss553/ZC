# ROX shell generator

**© ROX Store – All rights reserved.**

Generates the ROX house shells as real GTA V assets (`.ydr` with embedded collision and lights, shared `.ytd`, `.ytyp`).

| File | Purpose |
|---|---|
| `tex.py` | Procedural tileable textures (diffuse / normal / specular) written as DXT1 `.dds` with mipmaps |
| `kit.py` | Modelling kit: rooms, walls with door/window openings, casings, baseboards, windows, kitchens, wardrobes, lights, fans; vertex ambient occlusion; collision; CodeWalker XML export |
| `houses.py` | The house designs |
| `build.py` | Runs everything and converts the XML to binary with `cwconv` |
| `cwconv/` | Small .NET console app around CodeWalker.Core (XML ⇄ binary, info, round-trip export) |
| `render.html`, `render.js` | Preview renders of the real mesh + textures (three.js + Playwright) |

## Build
```
# once: .NET 8 SDK, CodeWalker source (github.com/dexyfex/CodeWalker) next to cwconv.csproj's ProjectReference, pip install numpy pillow
dotnet build -c Release cwconv           # -> <work>/cwconv/bin/Release/net8.0/cwconv.dll
python3 tex.py   <work>/tex              # textures
python3 build.py <work>                  # <work>/out/*.ydr, rox_shells_txd.ytd, rox_shells.ytyp
node render.js <work> <work>/img rox_shell_apartment "rox_shell_garage:inside:x=7&y=-3.5&yaw=60"
```
Copy `<work>/out/*` to `rox_houses/stream/rox_shells/`.

## Adding a house
Add a function in `houses.py` (see the existing ones), append it to `ALL`, rebuild. Coordinates are metres, origin at the
middle of the house on the floor, +Z up. `s.entry_door(...)` also defines the entry point written to `houses.json`.
