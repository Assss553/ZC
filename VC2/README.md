# VC2 — Car Showroom Kiosk

A standalone self-service machine (like an ATM) where players browse, test drive and buy cars, order custom builds, and get their cars back from **My cars** on the kiosk.

## Features

### Showroom kiosk
- **3D kiosk**: the custom VC2 kiosk model (`model/vc2_kiosk.glb`, see `model/README.md` to put it in the game). Until it is streamed, a GTA prop is used automatically. Above every kiosk floats a live **hologram screen**: rotating featured cars with prices, a clock, the kiosk services and a scrolling ticker, plus a glowing frame, light beam, orange glow and floor ring. Settings: `Config.KioskScreen`.
- Kiosk prop on the map with a blip. Use it with `E`, `ox_target` or `qb-target` (detected automatically).
- **Cars are detected from their spawn codes.** Add `{ model = 'code', price = 1000 }` and the script reads name, brand, category, seats, top speed and stats from the game. Addon cars work too.
- **Real vehicle pictures**, tried in this order: the vehicle's `image`, then `html/images/<model>.png`, then `Config.ImageUrl`, then a drawn silhouette.
- Categories, search, colour picker, bank/cash payment, timed test drive, two-tap purchase, and a receipt with the plate.

### Custom car orders
1. **Player** (at the kiosk → *Custom order*): writes the base car / idea, type, colour, budget and the specs they want, then sends the order. Their order list shows the live status.
2. **Workshop owner / admin** (`/vc2orders`): sees all orders, reads the specs, enters the spawn code of the car they built plus a price (0 = free) and a note, then presses *Build car*. They can also decline an order.
3. The player is notified. At the kiosk they press **Pay & collect**, and the car is registered to them and delivered.

Managers are set in `Config.Orders.managers`: an ACE permission (`add_ace group.admin vc2.admin allow`) and/or jobs with a minimum grade (for example `mechanic = 0`).

### My cars (on the kiosk)
- Press **My cars** on the kiosk to see every VC2 car you own: search, favourites (★), a car icon (or real photos with `Config.CarsPhotos = true`), status, plate and **Body / Engine / Fuel** bars.
- Press *Retrieve*, then *Confirm*, and the car is delivered to the kiosk's delivery spot.
- Statuses:
  - **Available**: not in the world (after a disconnect, a server restart, or if it was deleted).
  - **On street**: still spawned. Retrieving it removes the old car first, so it is never duplicated.
  - **Destroyed**: burned or exploded.
  - **Impounded**: costs `impoundFee`.
- Fees and repair-on-retrieve are set in `Config.Retrieve`. Body, engine and fuel are saved every 10 seconds while the owner drives.

### Admin commands (`vc2.admin` ACE only)
- `/vc2place`: places a showroom kiosk where you stand. A see-through preview follows you: arrow keys ← → rotate, `E` places it, `Backspace` cancels.
- `/vc2remove`: removes the placed kiosk closest to you (within 5 m).
- Placed kiosks are saved in the `vc2_places` table and appear for every player instantly and after restarts. Delivery and test-drive spots are picked automatically on the nearest road.
- `/vc2own`: registers the car you are sitting in or standing next to **under your own name** (your framework character ID, or your FiveM license in standalone). Works with any car, including addon cars and cars spawned by admins. From then on you can retrieve it from **My cars** on any VC2 kiosk.
- `/vc2own <playerId>`: registers the car to another player instead.
- `/vc2impound`: sends the VC2 car you are in or next to to the impound.

### How the server knows a car is from VC2
- Every spawned VC2 car gets the state bag `Entity(veh).state.vc2 = { plate, owner, origin, model }`.
- `/vc2check`: sit in or stand next to a car to see whether VC2 sold it, plus its owner and origin (showroom or custom build).
- Exports for other scripts:
  ```lua
  -- server
  exports.VC2:IsVC2Vehicle(plateOrEntity)  -- true / false
  exports.VC2:GetVC2Vehicle(plate)         -- row from vc2_vehicles or nil
  exports.VC2:ImpoundVehicle(plate)        -- police: removes the car, owner pays the impound fee to retrieve it from My cars
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
   (`vc2.admin` is needed for `/vc2own`, `/vc2impound` and, by default, `/vc2orders`.)
3. Edit `config.lua`: kiosk, delivery spots, delivery spots, cars, prices.

`oxmysql` is required in every mode, including standalone. The tables `vc2_vehicles`, `vc2_orders` and `vc2_places` are created automatically on start (see also `vc2.sql`).

## Notes
- Keys and fuel are handled in `Config.OnVehicleSpawned`.
- Open `html/index.html` in a browser to preview the UI. Add `?mode=cars` or `?mode=manager` to see the other screens.
