# rox_phone — ROX Store (v0.5, early in-game build)
Qbox + ox_lib + oxmysql. `ensure rox_phone` after qbx_core.

- Open: **M** or `/phone` (rebind in GTA settings > Key Bindings > FiveM). ESC closes.
- Phone prop + animation in hand. Phone (small phone), Half (tablet held small), Tablet (tablet) change the prop and animation.
- Real data: name, phone number (charinfo.phone), job, cash/bank.
- Garage: reads your vehicles from `player_vehicles` (citizenid). Track (GPS to your car if it exists in the world), lock/unlock (only your own car, within 40m), pay impound (`Config.ImpoundFee`, state 2 -> 1).
- Bank: Send money to a phone number (receiver must be in the city).
- Everything else (messages, Twitter, Pic-it, Clips, crypto, LSPD/EMS alerts) is still demo data inside the phone and is not saved on the server yet.
