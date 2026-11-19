-- ROX Store | All rights reserved
-- exports.rox_keyhints:Show(id, { { keys = {'E'}, label = 'Set up' }, { keys = {'←','→'}, label = 'Rotate' } }, title?)
-- exports.rox_keyhints:Show(id, items, title, { info = '75g / 300g', progress = 25, pos = 'right' })
-- exports.rox_keyhints:Hide(id)
local stack = {}          -- newest on top

local function refresh()
    local top = stack[#stack]
    SendNUIMessage(top and { action = 'show', title = top.title, items = top.items, info = top.opts.info,
        progress = top.opts.progress, pos = top.opts.pos } or { action = 'hide' })
end

local function Hide(id)
    for i = #stack, 1, -1 do if stack[i].id == id then table.remove(stack, i) end end
    refresh()
end

-- opts (optional): { info = '75g / 300g', progress = 0-100, pos = 'right' }
local function Show(id, items, title, opts)
    for i = #stack, 1, -1 do if stack[i].id == id then table.remove(stack, i) end end
    stack[#stack + 1] = { id = id, items = items, title = title, opts = type(opts) == 'table' and opts or {} }
    refresh()
end
exports('Show', Show)
exports('Hide', Hide)

-- eating / drinking / using items: ox_lib progress bars (ox_inventory uses them) -> "X Cancel"
CreateThread(function()
    local shown = false
    while true do
        local active = GetResourceState('ox_lib') == 'started' and select(2, pcall(function() return exports.ox_lib:progressActive() end)) == true
        if active and not shown then
            Show('progress', { { keys = { 'X' }, label = 'Cancel' } }); shown = true
        elseif not active and shown then
            Hide('progress'); shown = false
        end
        Wait(active and 100 or 300)
    end
end)

AddEventHandler('onResourceStop', function(r) if r == GetCurrentResourceName() then SendNUIMessage({ action = 'hide' }) end end)
