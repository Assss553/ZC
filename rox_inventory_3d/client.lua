-- ROX Store | All rights reserved
local open = false
local function push(st, msg) SendNUIMessage({ action = 'state', state = st, msg = msg }) end

local function openInv()
    if open or IsNuiFocused() or IsPauseMenuActive() or LocalPlayer.state.invBusy then return end
    open = true
    local pd = {}
    pcall(function() pd = exports.qbx_core:GetPlayerData() or {} end)
    local ci = pd.charinfo or {}
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', state = lib.callback.await('rox_inv3d:state', false), imagepath = 'nui://ox_inventory/web/images/',
                     layout = Config.Layout, max = Config.MaxWeight,
                     player = { name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):upper(), cid = pd.citizenid, cash = pd.money and pd.money.cash or 0,
                                id = GetPlayerServerId(PlayerId()), job = pd.job and ((pd.job.label or '') .. ' · ' .. (pd.job.grade and pd.job.grade.name or '')) or '' } })
end

RegisterNUICallback('move', function(d, cb) local st, m = lib.callback.await('rox_inv3d:move', false, d.from, d.to, d.split); cb('ok'); push(st, m) end)
RegisterNUICallback('drop', function(d, cb)
    local st, m = lib.callback.await('rox_inv3d:drop', false, d.slot, d.count); cb('ok'); push(st, m)
end)
RegisterNUICallback('give', function(d, cb) local st, m = lib.callback.await('rox_inv3d:give', false, d.slot, d.count); cb('ok'); push(st, m) end)
RegisterNUICallback('use', function(d, cb)
    cb('ok'); open = false; SetNuiFocus(false, false); SendNUIMessage({ action = 'close' })
    exports.ox_inventory:useSlot(tonumber(d.slot))
end)
RegisterNUICallback('close', function(_, cb) cb('ok'); open = false; SetNuiFocus(false, false) end)

local function style()
    if GetResourceState('rox_settings') == 'started' then
        local ok, st = pcall(function() return exports.rox_settings:get() end)
        if ok and st and st.invstyle then return st.invstyle end
    end
    return Config.Default or '3d'
end
local function openPreferred()
    if style() == 'wheel' and GetResourceState('rox_wheel') == 'started' then exports.rox_wheel:Open() else openInv() end
end
exports('Open', openInv)
RegisterNUICallback('switch', function(_, cb)
    cb('ok'); open = false; SetNuiFocus(false, false); SendNUIMessage({ action = 'close' })
    if GetResourceState('rox_wheel') == 'started' then exports.rox_wheel:Open() end
end)
RegisterCommand('inventory3d', openPreferred, false)
RegisterKeyMapping('inventory3d', 'ROX 3D inventory', 'keyboard', Config.Key)
