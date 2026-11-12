--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

Config = {}

-- 'auto' | 'esx' | 'qb' | 'standalone'
Config.Framework = 'auto'

-- Default language: 'en' (primary) | 'ar' (alternative).
-- Every player can switch language from the iPad Settings app.
Config.Locale = 'en'

Config.Currency = '$'

-- Account used for every payment (bank / money / cash)
Config.PayAccount = 'bank'

---------------------------------------------------------------------
-- iPad / Tablet
---------------------------------------------------------------------
Config.Tablet = {
    DefaultWallpaper = 'img/wallpapers/street.jpg',
    Command   = 'ipad',          -- /ipad  يفتح الايباد
    Key       = 'F6',            -- default key (players can change it in GTA settings)
    Item      = 'realestate_ipad', -- usable item (set to false to disable)
    UseProp   = true,            -- hold a tablet prop + animation
    CitizenAccess = true,        -- false = only realtors can open the iPad at all
}

---------------------------------------------------------------------
-- Realtor (العقاري)
---------------------------------------------------------------------
Config.Realtor = {
    -- job name = minimum grade that can open the realtor apps
    Jobs = {
        realestate = 0,
        realtor    = 0,
    },
    ManageGrade     = 2,     -- grade needed to delete / evict properties
    -- Minimum grade for each realtor app. The app is hidden from the iPad dock below that grade
    -- (and the server refuses the action too). Grades are checked against the job's grade in Config.Realtor.Jobs.
    Apps = {
        create    = 0,  -- Create Property
        manage    = 1,  -- Manage Properties (edit, change door, send contract)
        contracts = 0,  -- See every contract of the agency
    },
    AcePermission   = 'rox_realestate.realtor', -- players with this ace are realtors too (admins)
    Commission      = 0.10,  -- 10% of each deal goes to the realtor who made the contract
    MaxDoorDistance = 25.0,  -- realtor must be this close to the door he aimed at
    CanEnterAll     = true,  -- realtors can enter any property (inspection)
}

-- Optional: send the rest of the deal money to a society account.
-- Example ESX: TriggerEvent('esx_addonaccount:getSharedAccount', 'society_realestate', function(a) a.addMoney(amount) end)
-- Example QB : exports['qb-management']:AddMoney('realestate', amount)
Config.PaySociety = function(amount, propertyId)
end

---------------------------------------------------------------------
-- Contracts / buying
---------------------------------------------------------------------
Config.ContractExpireMinutes = 30     -- pending contract expires after
Config.AllowDirectPurchase   = true   -- citizens can buy "Available" properties from the iPad without a realtor
Config.AllowVisitAvailable   = true   -- citizens can visit (preview) available properties
Config.MinPrice  = 1000
Config.MaxPrice  = 50000000
Config.MaxKeys   = 5

---------------------------------------------------------------------
-- Rent (الإيجار)
---------------------------------------------------------------------
Config.Rent = {
    DefaultDays   = 7,    -- rent period in days
    CheckMinutes  = 10,   -- how often the server checks due rents
    AutoPay       = true, -- take rent automatically when the tenant is online
    MaxOverdue    = 3,    -- evicted after this many unpaid periods
}

---------------------------------------------------------------------
-- Marketplace (owners selling their property to other players)
---------------------------------------------------------------------
Config.Marketplace = {
    Enabled = true,
    Tax     = 0.05,  -- 5% removed from the sale price
}

---------------------------------------------------------------------
-- Furniture
---------------------------------------------------------------------
Config.Furniture = {
    MaxPieces   = 400,   -- per property (walls, floors and stairs count as pieces too)
    SellBack    = 0.5,   -- 50% refund when selling a piece back
    PlaceRadius = 45.0,  -- max distance from the interior spawn where furniture can be placed
    OpenKey     = 'O',   -- press anywhere inside your house to open the furniture panel
    -- Thumbnails: html/img/furniture/<model>.png|jpg|webp is detected automatically and used first.
    -- Otherwise this url is tried (%s = prop model). Set to false to use category icons only.
    ImageUrl    = 'https://gta-objects.xyz/gallery/objects/%s.jpg',
}

---------------------------------------------------------------------
-- World
---------------------------------------------------------------------
Config.BucketOffset   = 5000
-- Shell interiors (k4mb1 starter shells) are spawned under the door at this height offset
Config.ShellZOffset   = -35.0   -- routing bucket = offset + property id (each house is its own instance)
Config.DoorDistance   = 1.8
Config.DrawMarker     = true

Config.Blips = {
    Owned     = { sprite = 40,  color = 2,  scale = 0.75 },  -- your houses
    Key       = { sprite = 40,  color = 3,  scale = 0.65 },
    Available = { sprite = 350, color = 47, scale = 0.6, show = true },
    Market    = { sprite = 374, color = 0,  scale = 0.6, show = true },
}

-- Property map inside the iPad (html/img/map.jpg). Calibrate if you use another map image.
Config.Map = {
    image = 'img/map.jpg',
    -- world bounds that the image covers
    minX = -4140.0, maxX = 4860.0,
    minY = -4300.0, maxY = 8400.0,
}

---------------------------------------------------------------------
-- House detection (auto)
---------------------------------------------------------------------
-- Drop shell files (.ydr / .ytyp) into rox_realestate/stream/houses/  (or ensure any shell resource)
-- and pictures into html/img/houses/<model or interior key>.jpg|png|webp.
-- On start the server scans for shells + pictures, every client checks the model is really streamed,
-- and the shell appears in the "Create Property" interior list automatically.
Config.Detect = {
    Enabled      = true,
    ScanFiles    = true,               -- scan resource folders for .ydr files (needs io.popen, falls back silently)
    NamePatterns = { 'shell', 'k4mb1', 'furnitured', 'house', 'apart', 'mlo' }, -- .ydr names containing one of these
    OwnFolder    = 'stream/houses',    -- everything in this folder counts as a shell, whatever its name
    UploadResource = 'rox_houses',     -- upload folder resource: stream/ (map files) + images/ (pictures) + houses.json
    Extra        = {},                 -- extra shell model names, e.g. { 'my_villa_shell' }
    Command      = 'realestate_scan',  -- ace 'rox_realestate.realtor' or realtor: rescan without restart
    EntryCommand = 'houseentry',       -- realtor inside a detected shell: save the entry point where you stand
}

---------------------------------------------------------------------
-- Gangs (ROX Gang Hideouts)
---------------------------------------------------------------------
Config.Gangs = {
    -- QBCore: PlayerData.gang.name is checked, ESX: the job name
    Jobs = { 'ballas', 'vagos', 'families', 'lostmc', 'marabunta', 'triads', 'cartel', 'gang' },
    RealtorCanSell = true, -- realtors can still create hideouts and send contracts (only gang members can sign)
}

-- OPEN HOUSE: real houses of the map that players walk into (no teleport).
-- The realtor picks "Open House" in Create Property, draws the zone around the house and marks its doors.
Config.OpenHouse = {
    Enabled        = true,
    StreamDistance = 70.0,  -- doors / removed doors / furniture are handled inside this distance
    DoorDistance   = 1.7,   -- distance to lock / unlock a door with E
    DefaultHeight  = 12.0,  -- zone height (metres), SCROLL changes it while drawing
    Snap           = 0.25,  -- corner snapping grid (hold SHIFT for no snap)
    MaxCorners     = 24,
    MaxDoors       = 12,
}
