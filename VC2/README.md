# VC2 — Car Showroom Kiosk

A standalone self-service machine (like an ATM) where players browse, test drive and buy cars, order custom builds, and get their cars back from recovery NPCs.

## Features

### Showroom kiosk
- Kiosk prop on the map with a blip. Use it with `E`, `ox_target` or `qb-target` (detected automatically).
- **Cars are detected from their spawn codes.** Add `{ model = 'code', price = 1000 }` and the script reads name, brand, category, seats, top speed and stats from the game. Addon cars work too.
- **Real vehicle pictures**, tried in this order: the vehicle's `image`, then `html/images/<model>.png`, then `Config.ImageUrl`, then a drawn silhouette.
- Categories, search, colour picker, bank/cash payment, timed test drive, two-tap purchase, and a receipt with the plate.

### Custom car orders
1. **Player** (at the kiosk → *Custom order*): writes the base car / idea, type, colour, budget and the specs they want, then sends the order. Their order list shows the live status.
2. **Workshop owner / admin** (`/vc2orders`): sees all orders, reads the specs, enters the spawn code of the car they built plus a price (0 = free) and a note, then presses *Build car*. They can also decline an order.
3. The player is notified. At the kiosk they press **Pay & collect**, and the car is registered to them and delivered.

Managers are set in `Config.Orders.managers`: an ACE permission (`add_ace group.admin vc2.admin allow`) and/or jobs with a minimum grade (for example `mechanic = 0`).

### Ownership & recovery
- Every car bought or built through VC2 is saved in the `vc2_vehicles` table, linked to the owner. It is also saved in the framework garage table (`player_vehicles` / `owned_vehicles`).
- **Recovery NPCs** (`Config.Garages`) list the player's VC2 cars with their status:
  - **Ready**: not in the world (after a disconnect, a server restart, or if it was deleted).
  - **On the street**: still spawned somewhere. Retrieving it removes the old car first, so it is never duplicated.
  - **Destroyed**: burned or exploded.
  - **Impounded**: impounded by police. Uses `impoundFee`.
- Fees are set in `Config.Retrieve`. Saved mods, colours and plate are restored.

### How the server knows a car is from VC2
- Every spawned VC2 car gets the state bag `Entity(veh).state.vc2 = { plate, owner, origin, model }`.
- `/vc2check`: sit in or stand next to a car to see whether VC2 sold it, plus its owner and origin (showroom or custom build).
- Exports for other scripts:
  ```lua
  -- server
  exports.VC2:IsVC2Vehicle(plateOrEntity)  -- true / false
  exports.VC2:GetVC2Vehicle(plate)         -- row from vc2_vehicles or nil
  exports.VC2:ImpoundVehicle(plate)        -- police: removes the car, owner pays the impound fee to recover it
  exports.VC2:ReleaseVehicle(plate)
  -- client
  exports.VC2:IsVC2Vehicle(vehicle)
  ```

## Install
1. Copy `VC2` into `resources`.
2. In `server.cfg` (after your framework):
   ```
   ensure oxmysql
   ensure VC2
   add_ace group.admin vc2.admin allow
   ```
3. Edit `config.lua`: kiosk, delivery spots, recovery NPC position, cars, prices.

`oxmysql` is required in every mode, including standalone. The tables `vc2_vehicles` and `vc2_orders` are created automatically on start (see also `vc2.sql`).

## Notes
- Keys and fuel are handled in `Config.OnVehicleSpawned`.
- Open `html/index.html` in a browser to preview the UI. Add `?mode=garage` or `?mode=manager` to see the other screens.
