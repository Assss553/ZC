# rox_admin — ROX Store
Admin console for **Qbox** (qbx_core + ox_lib + oxmysql).

## Install
1. Drop `rox_admin` in resources and add `ensure rox_admin` **after** qbx_core.
2. Tables are created automatically on first start (`install.sql`).
3. Make yourself owner, either in `config.lua` → `Config.Staff['license:YOURLICENSE'] = 'owner'`
   or in server.cfg: `add_ace identifier.license:YOURLICENSE rox.owner allow`.
4. In game: `/admin` or **F10** (each admin can rebind it in GTA settings → Key Bindings → FiveM).

## Data sources (real data only)
- Steam: `GetPlayerIdentifierByType(src, 'steam')` (hex, steam64 shown in the UI). Needs `steam_webApiKey` in server.cfg; players without Steam show "no steam".
- Steam name: FiveM player name at join time (the Steam name when Steam is linked).
- Characters: the Qbox `players` table (`citizenid`, `license`, `charinfo`, `job`, `position`, `last_updated`) matched on `license` / `license2`.
- Character creation date: Qbox does not store one, so the panel shows the first time rox_admin saw that character.
- Join/quit sessions, character switches, admin actions, staff, permissions and saved coords live in `rox_admin_*` tables and are never deleted.
- Quit type: `quit` (normal exit), `dropped` (timeout/crash), `kicked`, `server` (restart while online).
- IPs are only stored when `Config.LogIPs = true`, and only ranks with `view_ips` can see them.

## Exports
`exports.rox_admin:GetRank(src)`, `exports.rox_admin:HasPermission(src, 'kick')`
