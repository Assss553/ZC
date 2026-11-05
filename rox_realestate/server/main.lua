--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

Properties = {}   -- [id] = property row
Contracts  = {}   -- [id] = contract row (pending + recent)
Inside     = {}   -- [src] = property id

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function now() return os.time() end

local function decode(str, fallback)
    if not str or str == '' then return fallback end
    local ok, v = pcall(json.decode, str)
    return ok and v or fallback
end

local function clampInt(v, min, max)
    v = math.floor(tonumber(v) or -1)
    if v < min or v > max then return nil end
    return v
end

local function sanitizeText(s, maxLen)
    if type(s) ~= 'string' then return nil end
    s = s:gsub('[<>]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if #s == 0 then return nil end
    return s:sub(1, maxLen or 64)
end

local function sanitizeImage(s)
    if type(s) ~= 'string' or s == '' then return nil end
    if s:match('^https://[%w%-%._~:/%?#%[%]@!%$&\'%(%)%*%+,;=%%]+$') or s:match('^img/[%w_%-/%.]+$') then
        return s:sub(1, 255)
    end
    return nil
end

function GetProp(id) return Properties[tonumber(id) or -1] end

function ParsePoint(t)
    if type(t) ~= 'table' then return nil end
    local d = { x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z), h = tonumber(t.h) or 0.0 }
    if not (d.x and d.y and d.z) then return nil end
    return d
end

function IsRealtor(src)
    if IsPlayerAceAllowed(src, Config.Realtor.AcePermission) then return true, 99 end
    local job, grade = Bridge.GetJob(src)
    local min = Config.Realtor.Jobs[job]
    if min and grade >= min then return true, grade end
    return false, 0
end

-- realtor app access per grade (Config.Realtor.Apps)
function HasApp(src, app)
    local ok, grade = IsRealtor(src)
    return ok and grade >= (Config.Realtor.Apps[app] or 0)
end

-- does the player own / rent at least one property
function HasHome(src, identifier)
    identifier = identifier or Bridge.GetIdentifier(src)
    if not identifier then return false end
    for _, prop in pairs(Properties) do
        if prop.owner == identifier then return true end
    end
    return false
end

-- which apps this player sees on the iPad
function AppAccess(src)
    local realtor = IsRealtor(src)
    local apps = { create = HasApp(src, 'create'), manage = HasApp(src, 'manage'), contracts = HasApp(src, 'contracts') }
    apps.estate = Config.Tablet.CitizenEstateApp or HasApp(src, 'estate')
    apps.furniture = (not Config.Tablet.FurnitureNeedsHome) or HasHome(src)
    apps.realtor = realtor
    return apps
end

RegisterCallback('appAccess', function(src) return AppAccess(src) end)

function CanManage(src)
    local ok, grade = IsRealtor(src)
    return ok and grade >= Config.Realtor.ManageGrade
end

-- 'owner' | 'key' | nil
function GetAccess(src, prop, identifier)
    identifier = identifier or Bridge.GetIdentifier(src)
    if not identifier or not prop then return nil end
    if prop.owner == identifier then return 'owner' end
    for _, k in ipairs(prop.keyholders or {}) do
        if k.identifier == identifier then return 'key' end
    end
    return nil
end

local function doorVec(prop) return vector3(prop.door.x, prop.door.y, prop.door.z) end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return vector3(0, 0, 0) end
    return GetEntityCoords(ped)
end

-- NotifyIdentifier(identifier, kind, localeKey, ...) translated in the target's language
function NotifyIdentifier(identifier, kind, key, ...)
    local src = Bridge.GetSourceByIdentifier(identifier)
    if src then Bridge.Notify(src, LP(src, key, ...), kind) end
    return src
end

local function interiorLabel(key)
    local i = Interiors[key]
    if not i then return key end
    return (CurrentLang() == 'ar' and i.labelAr) or i.label
end

local function propImage(prop)
    return prop.image or (Interiors[prop.interior] and Interiors[prop.interior].image)
end

---------------------------------------------------------------------
-- Client views
---------------------------------------------------------------------
local function propForClient(prop, src, identifier, realtor)
    local access = GetAccess(src, prop, identifier)
    local private = access == 'owner' or realtor
    return {
        id = prop.id, label = prop.label, interior = prop.interior, interiorLabel = interiorLabel(prop.interior),
        image = propImage(prop), ptype = prop.ptype, price = prop.price, rentPrice = prop.rent_price,
        rentDays = prop.rent_days, status = prop.status, ownerName = prop.owner_name,
        realtorName = prop.realtor_name, door = prop.door, street = prop.street, locked = prop.locked,
        salePrice = prop.sale_price, isOwner = access == 'owner', hasKey = access ~= nil,
        keys = access == 'owner' and prop.keyholders or nil,
        rentDue = private and prop.rent_due or nil, overdue = private and prop.overdue or nil,
        rooms = Interiors[prop.interior] and Interiors[prop.interior].rooms or 1,
        inside = realtor and prop.inside or nil,
    }
end

function ContractForClient(c, identifier)
    local prop = Properties[c.property_id]
    return {
        id = c.id, propertyId = c.property_id, ctype = c.ctype, price = c.price, rentPrice = c.rent_price,
        rentDays = c.rent_days, buyerName = c.buyer_name, realtorName = c.realtor_name, status = c.status,
        signature = c.signature, createdAt = c.created_at, signedAt = c.signed_at,
        expiresAt = c.created_at + Config.ContractExpireMinutes * 60,
        dueNow = c.ctype == 'rent' and c.rent_price or c.price,
        label = prop and prop.label or ('#' .. c.property_id), interior = prop and prop.interior,
        interiorLabel = prop and interiorLabel(prop.interior), image = prop and propImage(prop),
        street = prop and prop.street, rooms = prop and Interiors[prop.interior] and Interiors[prop.interior].rooms,
        isMine = identifier ~= nil and c.buyer == identifier,
    }
end

function BuildClientData(src)
    local identifier = Bridge.GetIdentifier(src)
    local realtor = IsRealtor(src)
    local list = {}
    for _, prop in pairs(Properties) do
        list[#list + 1] = propForClient(prop, src, identifier, realtor)
    end
    return list
end

function SyncPlayer(src)
    TriggerClientEvent('rox_re:sync', src, BuildClientData(src))
end

local syncQueued = false
function SyncAll()
    if syncQueued then return end
    syncQueued = true
    SetTimeout(250, function()
        syncQueued = false
        for _, s in ipairs(GetPlayers()) do SyncPlayer(tonumber(s)) end
    end)
end

---------------------------------------------------------------------
-- Boot
---------------------------------------------------------------------
MySQL.ready(function()
    print('^3[ROX Store]^7 ROX Real Estate v1.2 – © ROX Store, all rights reserved')
    DB.Init()
    local count = 0
    for _, row in ipairs(DB.LoadProperties()) do
        count = count + 1
        row.door = decode(row.door, { x = 0, y = 0, z = 0, h = 0 })
        row.keyholders = decode(row.keyholders, {})
        row.inside = decode(row.inside, nil)
        row.locked = row.locked == 1 or row.locked == true
        Properties[row.id] = row
    end
    for _, c in ipairs(DB.LoadContracts()) do Contracts[c.id] = c end
    print(('^2[rox_realestate]^7 loaded %d properties'):format(count))
    if Detect then Detect.Run() end
    SyncAll()
end)

RegisterNetEvent('rox_re:requestSync', function()
    local src = source
    SyncPlayer(src)
    local identifier = Bridge.GetIdentifier(src)
    if identifier then
        for _, p in ipairs(DB.TakePayouts(identifier)) do
            Bridge.AddMoney(src, p.amount, 'realestate-payout')
            Bridge.Notify(src, LP(src, 'payout', FormatMoney(p.amount)), 'success')
        end
        -- show still-pending contracts on login
        for _, c in pairs(Contracts) do
            if c.buyer == identifier and c.status == 'pending' then
                TriggerClientEvent('rox_re:contract', src, ContractForClient(c, identifier))
                break
            end
        end
    end
end)

---------------------------------------------------------------------
-- Tablet bootstrap
---------------------------------------------------------------------
RegisterCallback('bootstrap', function(src)
    local identifier = Bridge.GetIdentifier(src)
    local realtor, grade = IsRealtor(src)
    if not realtor and not Config.Tablet.CitizenAccess then return false, L('not_realtor') end
    local apps = AppAccess(src)
    local contracts = {}
    local rows = apps.contracts and DB.RecentContracts() or DB.ContractsForBuyer(identifier)
    for _, c in ipairs(rows) do contracts[#contracts + 1] = ContractForClient(c, identifier) end
    return {
        name = Bridge.GetName(src), money = Bridge.GetMoney(src), serverId = src,
        isRealtor = realtor, canManage = CanManage(src), grade = grade, apps = apps,
        properties = BuildClientData(src), contracts = contracts,
    }
end)

Bridge.RegisterUsableItem(Config.Tablet.Item, function(src)
    TriggerClientEvent('rox_re:openTablet', src)
end)

---------------------------------------------------------------------
-- Contracts
---------------------------------------------------------------------
local function createContract(prop, buyerSrc, ctype, realtorSrc)
    local c = {
        property_id = prop.id, ctype = ctype, price = prop.price, rent_price = prop.rent_price,
        rent_days = prop.rent_days, buyer = Bridge.GetIdentifier(buyerSrc), buyer_name = Bridge.GetName(buyerSrc),
        realtor = realtorSrc and Bridge.GetIdentifier(realtorSrc) or nil,
        realtor_name = realtorSrc and Bridge.GetName(realtorSrc) or 'Real Estate',
        status = 'pending', created_at = now(),
    }
    c.id = DB.InsertContract(c)
    Contracts[c.id] = c
    prop.status = 'pending'
    DB.SaveProperty(prop)
    TriggerClientEvent('rox_re:contract', buyerSrc, ContractForClient(c, c.buyer))
    return c
end

-- Realtor: create a new property (+ optional contract to a buyer)
RegisterCallback('createProperty', function(src, data)
    if not HasApp(src, 'create') then return false, L('not_realtor') end
    if type(data) ~= 'table' or type(data.door) ~= 'table' then return false, L('invalid_data') end

    local label = sanitizeText(data.label, 48)
    local interior = Interiors[data.interior] and data.interior
    local ptype = (data.ptype == 'rent') and 'rent' or 'sale'
    local price = clampInt(data.price, ptype == 'rent' and 0 or Config.MinPrice, Config.MaxPrice)
    local rentPrice = clampInt(data.rentPrice or 0, 0, Config.MaxPrice)
    local rentDays = clampInt(data.rentDays or Config.Rent.DefaultDays, 1, 60)
    if ptype == 'rent' and (not rentPrice or rentPrice < 1) then return false, L('invalid_data') end
    if not (label and interior and price and rentPrice and rentDays) then return false, L('invalid_data') end

    local door = {
        x = tonumber(data.door.x), y = tonumber(data.door.y), z = tonumber(data.door.z), h = tonumber(data.door.h) or 0.0,
    }
    if not (door.x and door.y and door.z) then return false, L('invalid_data') end
    if #(playerCoords(src) - vector3(door.x, door.y, door.z)) > Config.Realtor.MaxDoorDistance then
        return false, L('too_far_door')
    end

    local inside = nil
    if Interiors[interior].custom then
        inside = ParsePoint(data.inside)
        if not inside then return false, L('invalid_data') end
    end

    local buyerSrc = tonumber(data.buyerId)
    if buyerSrc and buyerSrc > 0 then
        if not GetPlayerName(buyerSrc) or not Bridge.GetIdentifier(buyerSrc) then return false, L('target_offline') end
    else
        buyerSrc = nil
    end

    local prop = {
        label = label, interior = interior, image = sanitizeImage(data.image), ptype = ptype,
        price = price, rent_price = rentPrice, rent_days = rentDays, status = 'available',
        realtor = Bridge.GetIdentifier(src), realtor_name = Bridge.GetName(src), door = door,
        street = sanitizeText(data.street, 120), locked = true, keyholders = {}, overdue = 0, created_at = now(),
        inside = inside,
    }
    prop.id = DB.InsertProperty(prop)
    Properties[prop.id] = prop
    Bridge.Notify(src, LP(src, 'property_created', prop.id), 'success')

    if buyerSrc then
        createContract(prop, buyerSrc, ptype, src)
        Bridge.Notify(src, LP(src, 'contract_sent', Bridge.GetName(buyerSrc)), 'success')
        Bridge.Notify(buyerSrc, LP(buyerSrc, 'contract_received', Bridge.GetName(src)), 'info')
    end
    SyncAll()
    return true, prop.id
end)

-- Realtor: send a contract for an existing available property
RegisterCallback('sendContract', function(src, propId, buyerId, ctype)
    if not HasApp(src, 'manage') then return false, L('not_realtor') end
    local prop = GetProp(propId)
    if not prop or prop.owner then return false, L('not_available') end
    buyerId = tonumber(buyerId)
    if not buyerId or not GetPlayerName(buyerId) then return false, L('target_offline') end
    -- cancel older pending contracts on this property
    for _, c in pairs(Contracts) do
        if c.property_id == prop.id and c.status == 'pending' then c.status = 'cancelled'; DB.UpdateContract(c) end
    end
    createContract(prop, buyerId, ctype == 'rent' and 'rent' or (ctype == 'sale' and 'sale' or prop.ptype), src)
    Bridge.Notify(src, LP(src, 'contract_sent', Bridge.GetName(buyerId)), 'success')
    Bridge.Notify(buyerId, LP(buyerId, 'contract_received', Bridge.GetName(src)), 'info')
    SyncAll()
    return true
end)

-- Citizen: buy / rent an available property directly
RegisterCallback('requestAvailable', function(src, propId)
    if not Config.AllowDirectPurchase then return false, L('no_access') end
    local prop = GetProp(propId)
    if not prop or prop.status ~= 'available' then return false, L('not_available') end
    createContract(prop, src, prop.ptype, nil)
    SyncAll()
    return true
end)

RegisterCallback('getContract', function(src, id)
    local c = Contracts[tonumber(id) or -1]
    if not c then return false end
    if c.buyer ~= Bridge.GetIdentifier(src) and not HasApp(src, 'contracts') then return false end
    return ContractForClient(c, Bridge.GetIdentifier(src))
end)

local function releaseIfPending(prop)
    if prop and not prop.owner and prop.status == 'pending' then
        local stillPending = false
        for _, c in pairs(Contracts) do
            if c.property_id == prop.id and c.status == 'pending' then stillPending = true end
        end
        if not stillPending then prop.status = 'available'; DB.SaveProperty(prop) end
    end
end

RegisterCallback('signContract', function(src, id, signature)
    local c = Contracts[tonumber(id) or -1]
    local identifier = Bridge.GetIdentifier(src)
    if not c or c.status ~= 'pending' or c.buyer ~= identifier then return false, L('invalid_data') end
    signature = sanitizeText(signature, 48)
    if not signature then return false, L('invalid_data') end

    local prop = Properties[c.property_id]
    if not prop or prop.owner then
        c.status = 'cancelled'; DB.UpdateContract(c)
        return false, L('not_available')
    end
    if now() > c.created_at + Config.ContractExpireMinutes * 60 then
        c.status = 'expired'; DB.UpdateContract(c); releaseIfPending(prop); SyncAll()
        return false, L('contract_expired')
    end

    local amount = c.ctype == 'rent' and c.rent_price or c.price
    if not Bridge.RemoveMoney(src, amount, 'realestate-contract') then return false, L('no_money') end

    c.status, c.signature, c.signed_at = 'signed', signature, now()
    DB.UpdateContract(c)

    prop.owner, prop.owner_name = identifier, Bridge.GetName(src)
    prop.ptype = c.ctype
    prop.status = c.ctype == 'rent' and 'rented' or 'owned'
    prop.rent_price, prop.rent_days = c.rent_price, c.rent_days
    prop.rent_due = c.ctype == 'rent' and (now() + c.rent_days * 86400) or nil
    prop.overdue, prop.keyholders, prop.sale_price, prop.locked = 0, {}, nil, true
    DB.SaveProperty(prop)

    -- cancel any other pending contract on the same property
    for _, other in pairs(Contracts) do
        if other.property_id == prop.id and other.status == 'pending' then other.status = 'cancelled'; DB.UpdateContract(other) end
    end

    local commission = 0
    if c.realtor then
        commission = math.floor(amount * Config.Realtor.Commission)
        local rsrc = Bridge.GetSourceByIdentifier(c.realtor)
        if rsrc then
            Bridge.AddMoney(rsrc, commission, 'realestate-commission')
            Bridge.Notify(rsrc, LP(rsrc, 'contract_signed_r', prop.owner_name, prop.label, FormatMoney(commission)), 'success')
        elseif commission > 0 then
            DB.AddPayout(c.realtor, commission, 'commission #' .. c.id)
        end
    end
    pcall(Config.PaySociety, amount - commission, prop.id)

    Bridge.Notify(src, LP(src, 'contract_signed'), 'success')
    SyncAll()
    return true, ContractForClient(c, identifier)
end)

RegisterCallback('declineContract', function(src, id)
    local c = Contracts[tonumber(id) or -1]
    if not c or c.status ~= 'pending' then return false end
    local isBuyer = c.buyer == Bridge.GetIdentifier(src)
    if not isBuyer and not HasApp(src, 'contracts') then return false end
    c.status = isBuyer and 'declined' or 'cancelled'
    DB.UpdateContract(c)
    local prop = Properties[c.property_id]
    releaseIfPending(prop)
    if isBuyer and c.realtor then
        NotifyIdentifier(c.realtor, 'error', 'contract_declined_r', c.buyer_name, prop and prop.label or '')
    end
    Bridge.Notify(src, LP(src, 'contract_declined'), 'info')
    SyncAll()
    return true
end)

-- expire contracts
CreateThread(function()
    while true do
        Wait(60000)
        local t = now()
        for _, c in pairs(Contracts) do
            if c.status == 'pending' and t > c.created_at + Config.ContractExpireMinutes * 60 then
                c.status = 'expired'
                DB.UpdateContract(c)
                releaseIfPending(Properties[c.property_id])
                SyncAll()
            end
        end
    end
end)

---------------------------------------------------------------------
-- Owner actions
---------------------------------------------------------------------
function Evict(prop, reason)
    if prop.owner then NotifyIdentifier(prop.owner, 'error', 'evicted', prop.label) end
    -- kick everybody inside
    for s, pid in pairs(Inside) do
        if pid == prop.id then TriggerClientEvent('rox_re:forceExit', s) end
    end
    prop.owner, prop.owner_name, prop.keyholders, prop.sale_price = nil, nil, {}, nil
    prop.rent_due, prop.overdue, prop.status, prop.locked = nil, 0, 'available', true
    DB.SaveProperty(prop)
    DB.ClearFurniture(prop.id)
    SyncAll()
end

RegisterCallback('toggleLock', function(src, id)
    local prop = GetProp(id)
    if not prop or not GetAccess(src, prop) then return false, L('no_access') end
    prop.locked = not prop.locked
    DB.SaveProperty(prop)
    Bridge.Notify(src, prop.locked and L('door_locked') or L('door_unlocked'), 'info')
    SyncAll()
    return true, prop.locked
end)

RegisterCallback('giveKey', function(src, id, target)
    local prop = GetProp(id)
    if not prop or GetAccess(src, prop) ~= 'owner' then return false, L('no_access') end
    target = tonumber(target)
    if not target or target == src or not GetPlayerName(target) then return false, L('target_offline') end
    if #prop.keyholders >= Config.MaxKeys then return false, L('max_keys') end
    local ident = Bridge.GetIdentifier(target)
    for _, k in ipairs(prop.keyholders) do if k.identifier == ident then return true end end
    prop.keyholders[#prop.keyholders + 1] = { identifier = ident, name = Bridge.GetName(target) }
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'key_given', Bridge.GetName(target)), 'success')
    Bridge.Notify(target, LP(target, 'key_received', prop.label), 'success')
    SyncAll()
    return true
end)

RegisterCallback('removeKey', function(src, id, identifier)
    local prop = GetProp(id)
    if not prop or GetAccess(src, prop) ~= 'owner' then return false, L('no_access') end
    for i, k in ipairs(prop.keyholders) do
        if k.identifier == identifier then table.remove(prop.keyholders, i) break end
    end
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'key_removed'), 'info')
    SyncAll()
    return true
end)

RegisterCallback('endLease', function(src, id)
    local prop = GetProp(id)
    if not prop or GetAccess(src, prop) ~= 'owner' or prop.status ~= 'rented' then return false, L('no_access') end
    Bridge.Notify(src, LP(src, 'lease_ended'), 'info')
    Evict(prop)
    return true
end)

-- Marketplace
RegisterCallback('listForSale', function(src, id, price)
    if not Config.Marketplace.Enabled then return false end
    local prop = GetProp(id)
    if not prop or GetAccess(src, prop) ~= 'owner' or prop.status ~= 'owned' then return false, L('no_access') end
    price = clampInt(price, Config.MinPrice, Config.MaxPrice)
    if not price then return false, L('invalid_data') end
    prop.sale_price = price
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'listed', FormatMoney(price)), 'success')
    SyncAll()
    return true
end)

RegisterCallback('cancelListing', function(src, id)
    local prop = GetProp(id)
    if not prop or GetAccess(src, prop) ~= 'owner' then return false, L('no_access') end
    prop.sale_price = nil
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'unlisted'), 'info')
    SyncAll()
    return true
end)

RegisterCallback('marketBuy', function(src, id)
    local prop = GetProp(id)
    local identifier = Bridge.GetIdentifier(src)
    if not prop or not prop.sale_price or prop.status ~= 'owned' then return false, L('not_available') end
    if prop.owner == identifier then return false, L('invalid_data') end
    local price = prop.sale_price
    if not Bridge.RemoveMoney(src, price, 'realestate-market') then return false, L('no_money') end

    local payout = math.floor(price * (1 - Config.Marketplace.Tax))
    local seller = prop.owner
    local sellerSrc = Bridge.GetSourceByIdentifier(seller)
    if sellerSrc then
        Bridge.AddMoney(sellerSrc, payout, 'realestate-market')
        Bridge.Notify(sellerSrc, LP(sellerSrc, 'market_sold', prop.label, FormatMoney(payout)), 'success')
    else
        DB.AddPayout(seller, payout, 'market #' .. prop.id)
    end

    for s, pid in pairs(Inside) do
        if pid == prop.id then TriggerClientEvent('rox_re:forceExit', s) end
    end
    prop.owner, prop.owner_name, prop.keyholders, prop.sale_price, prop.locked = identifier, Bridge.GetName(src), {}, nil, true
    prop.price = price
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'market_bought', prop.label), 'success')
    SyncAll()
    return true
end)

---------------------------------------------------------------------
-- Realtor management
---------------------------------------------------------------------
RegisterCallback('updateProperty', function(src, id, data)
    if not HasApp(src, 'manage') then return false, L('not_realtor') end
    local prop = GetProp(id)
    if not prop or type(data) ~= 'table' then return false, L('invalid_data') end
    prop.label = sanitizeText(data.label, 48) or prop.label
    if data.price then prop.price = clampInt(data.price, 0, Config.MaxPrice) or prop.price end
    if data.rentPrice then prop.rent_price = clampInt(data.rentPrice, 0, Config.MaxPrice) or prop.rent_price end
    if data.rentDays then prop.rent_days = clampInt(data.rentDays, 1, 60) or prop.rent_days end
    if not prop.owner and (data.ptype == 'sale' or data.ptype == 'rent') then prop.ptype = data.ptype end
    if data.interior and Interiors[data.interior] and not prop.owner then prop.interior = data.interior end
    if data.image ~= nil then prop.image = sanitizeImage(data.image) end
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'property_updated'), 'success')
    SyncAll()
    return true
end)

RegisterCallback('setInside', function(src, id, inside)
    if not HasApp(src, 'manage') then return false, L('not_realtor') end
    local prop = GetProp(id)
    local d = ParsePoint(inside)
    if not prop or not d then return false, L('invalid_data') end
    if #(playerCoords(src) - vector3(d.x, d.y, d.z)) > Config.Realtor.MaxDoorDistance then return false, L('too_far_door') end
    prop.inside = d
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'property_updated'), 'success')
    SyncAll()
    return true
end)

RegisterCallback('setDoor', function(src, id, door, street)
    if not HasApp(src, 'manage') then return false, L('not_realtor') end
    local prop = GetProp(id)
    if not prop or type(door) ~= 'table' then return false, L('invalid_data') end
    local d = { x = tonumber(door.x), y = tonumber(door.y), z = tonumber(door.z), h = tonumber(door.h) or 0.0 }
    if not (d.x and d.y and d.z) then return false, L('invalid_data') end
    if #(playerCoords(src) - vector3(d.x, d.y, d.z)) > Config.Realtor.MaxDoorDistance then return false, L('too_far_door') end
    prop.door = d
    prop.street = sanitizeText(street, 120) or prop.street
    DB.SaveProperty(prop)
    Bridge.Notify(src, LP(src, 'property_updated'), 'success')
    SyncAll()
    return true
end)

RegisterCallback('evictProperty', function(src, id)
    if not CanManage(src) then return false, L('no_access') end
    local prop = GetProp(id)
    if not prop then return false end
    Evict(prop)
    Bridge.Notify(src, LP(src, 'property_evicted'), 'success')
    return true
end)

RegisterCallback('deleteProperty', function(src, id)
    if not CanManage(src) then return false, L('no_access') end
    local prop = GetProp(id)
    if not prop then return false end
    for s, pid in pairs(Inside) do
        if pid == prop.id then TriggerClientEvent('rox_re:forceExit', s) end
    end
    if prop.owner then NotifyIdentifier(prop.owner, 'error', 'evicted', prop.label) end
    DB.DeleteProperty(prop.id)
    Properties[prop.id] = nil
    for _, c in pairs(Contracts) do
        if c.property_id == prop.id and c.status == 'pending' then c.status = 'cancelled' end
    end
    Bridge.Notify(src, LP(src, 'property_deleted'), 'success')
    SyncAll()
    return true
end)

---------------------------------------------------------------------
-- Enter / exit (each property = its own routing bucket)
---------------------------------------------------------------------
RegisterCallback('enter', function(src, id)
    local prop = GetProp(id)
    if not prop then return false end
    if #(playerCoords(src) - doorVec(prop)) > 6.0 then return false, L('too_far_door') end

    local access = GetAccess(src, prop)
    local allowed = access ~= nil or not prop.locked and prop.owner ~= nil
    if not allowed and Config.Realtor.CanEnterAll and IsRealtor(src) then allowed = true end
    if not allowed and Config.AllowVisitAvailable and not prop.owner then allowed = true end
    if not allowed then
        -- knock
        for s, pid in pairs(Inside) do
            if pid == prop.id then Bridge.Notify(s, LP(s, 'knock', prop.label), 'info') end
        end
        return false, L('locked')
    end

    local interior = Interiors[prop.interior]
    if not interior then return false, L('invalid_data') end

    local spawn, shellPos, auto = GetInteriorSpawn(prop.interior, prop.door, prop.inside)
    if not spawn then return false, L('invalid_data') end
    Inside[src] = prop.id
    local bucket = Config.BucketOffset + prop.id
    SetPlayerRoutingBucket(src, bucket)
    SetRoutingBucketPopulationEnabled(bucket, false)

    return true, {
        id = prop.id, label = prop.label, spawn = spawn, ipl = interior.ipl,
        shell = interior.shell, shellPos = shellPos, autoEntry = auto, interior = prop.interior,
        isRealtor = IsRealtor(src),
        furniture = GetPlacedFurniture(prop.id), canFurnish = access ~= nil,
    }
end)

RegisterCallback('exit', function(src)
    local id = Inside[src]
    Inside[src] = nil
    SetPlayerRoutingBucket(src, 0)
    local prop = GetProp(id)
    if not prop then return true, nil end
    return true, prop.door
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = Inside[src]
    if id then
        local prop = GetProp(id)
        local ped = GetPlayerPed(src)
        -- put the ped back at the door so the framework saves a valid position
        if prop and ped and ped ~= 0 then SetEntityCoords(ped, prop.door.x, prop.door.y, prop.door.z, false, false, false, false) end
        Inside[src] = nil
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    -- clients teleport themselves back to the door in their own onResourceStop
    for s in pairs(Inside) do SetPlayerRoutingBucket(s, 0) end
end)
