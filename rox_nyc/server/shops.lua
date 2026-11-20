--[[ ROX NYC  ·  © ROX Store – shop purchases (ESX / QBCore / ox_inventory / standalone) ]]
local ESX, QB
CreateThread(function()
    local fw = Config.Framework
    if (fw == 'auto' or fw == 'esx') and GetResourceState('es_extended') == 'started' then ESX = exports['es_extended']:getSharedObject()
    elseif (fw == 'auto' or fw == 'qb') and GetResourceState('qb-core') == 'started' then QB = exports['qb-core']:GetCoreObject() end
end)
local function pay(src, amount)
    if ESX then local p = ESX.GetPlayerFromId(src); if not p or p.getMoney() < amount then return false end p.removeMoney(amount) return true end
    if QB then local p = QB.Functions.GetPlayer(src); return p and p.Functions.RemoveMoney('cash', amount, 'rox-nyc-shop') or false end
    if GetResourceState('ox_inventory') == 'started' then return exports.ox_inventory:RemoveItem(src, 'money', amount) end
    return true
end
local function give(src, item, n)
    if GetResourceState('ox_inventory') == 'started' then return exports.ox_inventory:AddItem(src, item, n) end
    if ESX then local p = ESX.GetPlayerFromId(src); if p then p.addInventoryItem(item, n) end return true end
    if QB then local p = QB.Functions.GetPlayer(src); return p and p.Functions.AddItem(item, n) end
    return true
end
RegisterNetEvent('rox_nyc:buy', function(id, cart)
    local src = source
    local shop
    for _, s in ipairs(NycShops) do if s.id == tonumber(id) then shop = s end end
    if not shop or type(cart) ~= 'table' then return end
    local menu = Config.Shop[shop.kind]; if not menu then return end
    local byItem = {}; for _, it in ipairs(menu.items) do byItem[it.item] = it end
    local total, list = 0, {}
    for item, n in pairs(cart) do
        n = math.floor(tonumber(n) or 0); local it = byItem[item]
        if it and n > 0 and n <= Config.MaxPerItem then total = total + it.price * n; list[#list + 1] = { it, n } end
    end
    if total <= 0 then return end
    if not pay(src, total) then TriggerClientEvent('rox_nyc:notify', src, Config.Locale == 'ar' and '~r~ما عندك فلوس كافية' or '~r~Not enough money') return end
    for _, e in ipairs(list) do give(src, e[1].item, e[2]) end
    TriggerClientEvent('rox_nyc:notify', src, (Config.Locale == 'ar' and '~g~تم الشراء: $' or '~g~Bought for $') .. total)
end)
