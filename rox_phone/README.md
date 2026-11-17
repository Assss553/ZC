# rox_phone — ROX Store (v0.6)
Qbox + ox_lib + oxmysql + pma-voice. Optional: screenshot-basic (camera).
`ensure rox_phone` after qbx_core and pma-voice. Tables are created automatically.

Open: **M** or `/phone`. ESC closes. In the game there is NO demo data: everything comes from the database / other players.

| App | Real data |
|---|---|
| Phone | Contacts (saved per character), call log, real voice calls between players via pma-voice, 911 / 912 ring on-duty LSPD / EMS |
| Messages | Messages between phone numbers (works offline, delivered live when online), photos, GPS location, money, contact cards |
| Banking | Real cash/bank, transfers by phone number, phone transaction history |
| Garage | `player_vehicles` of your character, track, lock/unlock, pay impound |
| LSPD / EMS | Real on-duty count, go on/off duty (Qbox duty), do-not-disturb, alerts with GPS to on-duty units |
| Twitter | Posts and likes from all players |
| Pic-it | Accounts (hashed passwords), posts, likes, comments |
| Clips | Posts, likes, LIVE rooms with real viewers, chat, hearts, gifts paid from bank, earnings wallet |
| Crypto | Holdings per character, buy/sell with bank, send by phone number or wallet code, prices move every minute (`Config.Crypto`) |
| Camera / Photos | Photos via screenshot-basic uploaded to `Config.PhotoUpload` (e.g. Discord webhook). Video is not available yet. |
| Notes, Settings, home layout, first-time setup | Saved per character |
| Maps | `Config.Places` with real coordinates (sets GPS) |

Removed in game (no backend yet): Mail, DOJ, Racing, Houses, Crew, Pigeon, Vibe, Drop, Music.
