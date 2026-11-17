-- ROX Store | rox_notify | All rights reserved.
-- Notify({ title=, description=, type='inform'|'success'|'error'|'warning', duration=ms, icon='bell' })
-- also accepts Notify('text', 'error', 5000) like QBCore.
local Titles = { inform = 'Notification', success = 'Success', error = 'Error', warning = 'Warning' }
local function Notify(data, typ, dur)
    if type(data) ~= 'table' then data = { description = tostring(data), type = typ, duration = dur } end
    local t = data.type or 'inform'
    if t == 'info' or t == 'primary' then t = 'inform' end
    SendNUIMessage({ title = data.title or Titles[t] or 'Notification', text = data.description or data.text or '', type = t,
        duration = data.duration or 5000, icon = type(data.icon) == 'string' and data.icon or nil })
end
exports('Notify', Notify)
RegisterNetEvent('rox_notify:notify', Notify)
-- QBCore:Notify / ox_lib:notify are already handled by qbx_core / ox_lib -> lib.notify -> (patched) here, so no duplicate handlers.
RegisterCommand('testnotify', function() Notify({ title = 'Long message', description = 'A notification with a much longer message, so you can see the lines in the background on the right side of the box.' })
    Notify({ title = 'Success', description = 'Payment received', type = 'success' }) Notify({ description = 'Not enough money', type = 'error' }) end, false)
