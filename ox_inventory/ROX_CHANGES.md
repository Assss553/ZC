# ROX Store theme for ox_inventory

This folder is the **official ox_inventory** by Overextended (GPL-3.0, see LICENSE),
cloned from github.com/overextended/ox_inventory (commit ca61e6d) with a new UI theme by ROX Store.
Only the web UI was changed; all Lua is untouched. Full diff: `ROX_THEME.patch`.

## Layout
| Area | Player slots |
|---|---|
| Primary | 1 |
| Secondary | 2 |
| Quick use | 3, 4, 5 (still the normal hotbar keys 3-5) |
| Gear | 6, 7 |
| Pockets (left grid) | 8+ |

Use / Give / Drop: right-click an item (the old buttons are hidden like the reference layout). Amount: type under Gear.
| Drop Inventory (right) | ground / drop inventory (any other right inventory keeps its own label) |

## Item look
- Rarity background (diagonal lines + colour from the top-left corner): common, uncommon, rare, epic, legendary.
  Set per item in `web/src/helpers/rarity.ts` or per stack with `metadata.rarity = 'rare'`.
- Durability ring under the item (green / grey / yellow), count `x398` top right, slot number badges.
- Tooltip: image, name, rarity dot, weight, description, Actions.

## Rebuild after changes
    cd web
    npm install --legacy-peer-deps
    npx vite build
Item images: the official ones in `web/images` (free-use for ox_inventory, see web/images/readme.md). Add your own PNGs there.

## ROX item images (original, made in Blender)
`web/images/rox_*.png` — plate carrier, oxygen tank, radio, baton, taser, handcuffs, ammo, ID card, package, painkillers,
transparency red / blue / amber. Source: `tools/render_items.py` (edit the models / colours and re-render with `pip install bpy`).
Use them in data/items.lua, e.g. `['rox_vest'] = { label = 'Plate Carrier', weight = 3500 },`

## Ground items (Lua changes: client.lua createDrop + modules/inventory/server.lua)
- A dropped item shows its real model on the ground: weapons lie flat (GTA weapon model), known items use a prop
  (`ROX_DROP_MODELS` in client.lua), anything else uses the normal drop bag.
- Walk close: a floating `[E] ITEM NAME xCOUNT` prompt appears; press E to pick the whole drop up
  (server checks distance + weight: event `ox_inventory:roxPickup`).
