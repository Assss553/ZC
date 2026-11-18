# ROX Real Estate · iPad item (© ROX Store)

Item name: `realestate_ipad` (change it in `config.lua` → `Config.Tablet.Item`).
Picture: `realestate_ipad.png` (100x100) + bigger sizes 128 / 256 / 512.

## ox_inventory
Copy `realestate_ipad.png` to `ox_inventory/web/images/` and add to `ox_inventory/data/items.lua`:
```lua
['realestate_ipad'] = {
    label = 'ROX iPad', weight = 500, stack = false, close = true,
    description = 'iPad العقار ROX',
    client = { image = 'realestate_ipad.png' },
},
```

## qb-core / qbx
Copy `realestate_ipad.png` to `qb-inventory/html/images/` and add to `qb-core/shared/items.lua`:
```lua
realestate_ipad = { name = 'realestate_ipad', label = 'ROX iPad', weight = 500, type = 'item', image = 'realestate_ipad.png', unique = true, useable = true, shouldClose = true, description = 'iPad العقار ROX' },
```

## ESX
Run `esx_item.sql`, then copy the picture to your inventory's image folder.
