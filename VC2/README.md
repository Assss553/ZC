# VC2 — Car Showroom Kiosk

A standalone self-service machine (like an ATM) where players browse, test drive and buy cars without needing a dealer.

## Features
- Kiosk prop placed on the map with a blip. Use it with `E`, `ox_target` or `qb-target` (detected automatically).
- Modern kiosk UI: boot animation, receipt printer, NFC pad, animated cards.
- **Cars are detected from their spawn codes.** Add `{ model = 'code', price = 1000 }` and the script reads the name, brand, class/category, seats, top speed and stats from the game, so addon cars work too.
- **Real vehicle pictures**, tried in this order:
  1. the vehicle's own `image = 'https://...'`
  2. `html/images/<model>.png` (put your own pictures here, ideal for addon cars)
  3. `Config.ImageUrl` (default: FiveM's vehicle pictures for base-game cars)
  4. a drawn silhouette in the selected colour
- Categories, search, colour picker, bank/cash payment with a not-enough-money warning.
- Timed test drive with a cooldown. You are returned to the kiosk automatically.
- Two-tap purchase confirmation, then a receipt with plate and order number. The car is delivered to a parking spot and marked on the map.
- **QBCore**, **ESX** and **Standalone**.
- Server-side safety: price comes from the config, distance-to-kiosk check, double-click lock, refund if saving fails.
- Optional Discord purchase log.

## Install
1. Copy the `VC2` folder into `resources`.
2. In `server.cfg` (after your framework and oxmysql):
   ```
   ensure oxmysql
   ensure VC2
   ```
3. Edit `config.lua`: kiosk position, delivery spots, cars and prices, colours.

Uses the default tables `player_vehicles` (QBCore) or `owned_vehicles` (ESX), so no extra SQL is needed.

## Notes
- If a spawn code is not found (for example, the addon car isn't streamed), it is skipped and a warning is printed in the F8 console.
- Keys and fuel are handled in `Config.OnVehicleSpawned`. Adjust it for your scripts.
- Open `html/index.html` in a browser to preview the UI with demo data.
