# rox_notify — ROX Store
Custom notifications that replace the default ox_lib / Qbox ones.

`ensure rox_notify` **right after** `ox_lib` (before qbx_core and everything else).

### Required: one line in ox_lib (makes EVERY notification use this design)
Open `ox_lib/resource/interface/client/notify.lua`, and at the very top of `function lib.notify(data)` add:
```lua
if GetResourceState('rox_notify') == 'started' then return exports.rox_notify:Notify(data) end
```
That covers client `lib.notify`, server `lib.notify`, the `ox_lib:notify` event, `QBCore:Notify` and `exports.qbx_core:Notify` (they all end in `lib.notify`).
You can also call `exports.rox_notify:Notify({ title, description, type, duration })` directly.

Test in game: `/testnotify`
