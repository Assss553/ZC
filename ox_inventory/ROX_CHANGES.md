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
