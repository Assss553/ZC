# rox_consume — bite by bite eating & drinking
ROX Store | All rights reserved

Use a food/drink item -> it appears in your hand -> **E** = one bite/sip (75g / 300g counter), **X** = drop it.
Server removes the item once, then tracks the grams left and gives hunger/thirst per bite (anti-cheat, rate limited).

## ox_inventory (data/items.lua) — point the items at this export
```lua
['burger'] = { label = 'Burger', weight = 300, client = { export = 'rox_consume.use' } },
['water']  = { label = 'Water',  weight = 500, client = { export = 'rox_consume.use' } },
-- sandwich, donut, cola, coffee the same way (see config.lua)
```
Needs `rox_keyhints` for the E / X box. Start order: ox_lib, ox_inventory, qbx_core, rox_keyhints, rox_consume.
