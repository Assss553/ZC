--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

-- Periodic rent collection
local function period(prop) return (prop.rent_days or Config.Rent.DefaultDays) * 86400 end

local function processRent()
    local t = os.time()
    local changed = false
    for _, prop in pairs(Properties) do
        if prop.status == 'rented' and prop.owner and prop.rent_due and t >= prop.rent_due then
            local src = Bridge.GetSourceByIdentifier(prop.owner)
            local paid = false
            if Config.Rent.AutoPay and src and (prop.overdue or 0) == 0 then
                paid = Bridge.RemoveMoney(src, prop.rent_price, 'realestate-rent')
                if paid then
                    Bridge.Notify(src, LP(src, 'rent_auto', prop.label, FormatMoney(prop.rent_price)), 'info')
                    pcall(Config.PaySociety, prop.rent_price, prop.id)
                end
            end
            if not paid then
                prop.overdue = (prop.overdue or 0) + 1
                if src then Bridge.Notify(src, LP(src, 'rent_overdue', prop.label), 'error') end
            end
            prop.rent_due = prop.rent_due + period(prop)
            changed = true
            if prop.overdue > Config.Rent.MaxOverdue then
                Evict(prop)
            else
                DB.SaveProperty(prop)
            end
        end
    end
    if changed then SyncAll() end
end

CreateThread(function()
    Wait(30000)
    while true do
        pcall(processRent)
        Wait(Config.Rent.CheckMinutes * 60000)
    end
end)

-- Pay overdue rent (or pay the next period in advance)
RegisterCallback('payRent', function(src, id)
    local prop = GetProp(id)
    if not prop or GetAccess(src, prop) ~= 'owner' or prop.status ~= 'rented' then return false, L('no_access') end
    local periods = math.max(prop.overdue or 0, 1)
    local amount = prop.rent_price * periods
    if not Bridge.RemoveMoney(src, amount, 'realestate-rent') then return false, L('no_money') end
    if (prop.overdue or 0) > 0 then
        prop.overdue = 0
    else
        prop.rent_due = (prop.rent_due or os.time()) + period(prop)
    end
    pcall(Config.PaySociety, amount, prop.id)
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'rent_paid', FormatMoney(amount)), 'success')
    SyncAll()
    return true
end)
