Config = {}

-- 'auto' | 'qb' | 'esx' | 'standalone'
Config.Framework = 'auto'

-- طريقة التفاعل مع الجهاز: 'auto' | 'ox_target' | 'qb-target' | 'key'
Config.Interaction = 'auto'
Config.InteractDistance = 1.6   -- مسافة الضغط على E
Config.MaxServerDistance = 8.0  -- السيرفر يرفض أي عملية لو اللاعب بعيد عن الجهاز

Config.Currency = '$'
Config.Payments = { 'bank', 'cash' }   -- طرق الدفع المسموحة (أول وحدة = الافتراضية)
Config.PlateFormat = 'VC2 ####'        -- # = رقم ، @ = حرف (8 خانات كحد أقصى)
Config.QBGarage = 'pillboxgarage'      -- قراج السيارة بعد الشراء (QBCore)
Config.Webhook = ''                    -- رابط ديسكورد لتسجيل عمليات الشراء (اختياري)

Config.TestDrive = {
    enabled = true,
    duration = 60,      -- ثواني
    cooldown = 120,     -- ثواني بين كل تجربة وتجربة لنفس اللاعب
    maxDistance = 600.0 -- لو ابتعد عن الجهاز أكثر من كذا تنتهي التجربة
}

-- أجهزة المعرض (الكشك الخارجي)
Config.Kiosks = {
    {
        label = 'معرض VC2 - وسط المدينة',
        coords = vector4(-57.35, -1096.85, 25.42, 25.0), -- مكان الجهاز (z = الأرض)
        model = 'prop_atm_03',   -- شكل الجهاز في اللعبة
        spawnProp = true,        -- false لو تبي تستخدم جهاز موجود بالماب
        blip = { sprite = 326, color = 47, scale = 0.8 },
        delivery = {             -- مواقف استلام السيارة بعد الشراء
            vector4(-56.79, -1109.85, 26.43, 71.5),
            vector4(-51.20, -1111.40, 26.43, 71.5),
            vector4(-45.60, -1113.00, 26.43, 71.5),
        },
        testDrive = vector4(-46.99, -1095.47, 26.42, 200.0) -- موقع بداية تجربة القيادة
    },
}

-- الألوان (primary = رقم لون GTA)
Config.Colors = {
    { label = 'أسود',     hex = '#15161a', primary = 0 },
    { label = 'أبيض',     hex = '#eceef0', primary = 111 },
    { label = 'فضي',      hex = '#a9adb3', primary = 4 },
    { label = 'أحمر',     hex = '#b3141b', primary = 27 },
    { label = 'برتقالي',  hex = '#e4501c', primary = 38 },
    { label = 'أصفر',     hex = '#f2c21b', primary = 88 },
    { label = 'أزرق',     hex = '#1f4fae', primary = 64 },
    { label = 'أخضر',     hex = '#1f6b3a', primary = 53 },
}

-- الأقسام (shape = شكل رسمة السيارة بالواجهة: sedan | sport | super | suv | moto)
Config.Categories = {
    { id = 'sedan',  label = 'سيدان',     shape = 'sedan' },
    { id = 'suv',    label = 'دفع رباعي', shape = 'suv' },
    { id = 'sports', label = 'رياضية',    shape = 'sport' },
    { id = 'super',  label = 'سوبر',      shape = 'super' },
    { id = 'moto',   label = 'دراجات',    shape = 'moto' },
}

-- السيارات: stats من 0 إلى 100 ، image اختياري (رابط صورة)
Config.Vehicles = {
    { model = 'asea',      label = 'Asea',       brand = 'Declasse', category = 'sedan',  price = 18000,  seats = 4, stats = { speed = 52, accel = 45, brake = 50, handling = 55 } },
    { model = 'tailgater', label = 'Tailgater',  brand = 'Obey',     category = 'sedan',  price = 45000,  seats = 4, stats = { speed = 66, accel = 62, brake = 60, handling = 64 } },
    { model = 'schafter2', label = 'Schafter',   brand = 'Benefactor', category = 'sedan', price = 62000, seats = 4, stats = { speed = 70, accel = 66, brake = 62, handling = 66 } },
    { model = 'baller2',   label = 'Baller',     brand = 'Gallivanter', category = 'suv', price = 90000,  seats = 4, stats = { speed = 64, accel = 58, brake = 55, handling = 52 } },
    { model = 'granger',   label = 'Granger',    brand = 'Declasse', category = 'suv',    price = 55000,  seats = 8, stats = { speed = 58, accel = 50, brake = 48, handling = 46 } },
    { model = 'dubsta2',   label = 'Dubsta',     brand = 'Benefactor', category = 'suv',  price = 110000, seats = 4, stats = { speed = 60, accel = 55, brake = 52, handling = 50 } },
    { model = 'elegy2',    label = 'Elegy RH8',  brand = 'Annis',    category = 'sports', price = 150000, seats = 2, stats = { speed = 80, accel = 78, brake = 70, handling = 82 } },
    { model = 'sultan',    label = 'Sultan',     brand = 'Karin',    category = 'sports', price = 85000,  seats = 4, stats = { speed = 74, accel = 72, brake = 66, handling = 76 } },
    { model = 'comet2',    label = 'Comet',      brand = 'Pfister',  category = 'sports', price = 175000, seats = 2, stats = { speed = 82, accel = 80, brake = 72, handling = 80 } },
    { model = 'zentorno',  label = 'Zentorno',   brand = 'Pegassi',  category = 'super',  price = 725000, seats = 2, stats = { speed = 94, accel = 92, brake = 82, handling = 86 } },
    { model = 't20',       label = 'T20',        brand = 'Progen',   category = 'super',  price = 850000, seats = 2, stats = { speed = 95, accel = 94, brake = 84, handling = 88 } },
    { model = 'bati',      label = 'Bati 801',   brand = 'Pegassi',  category = 'moto',   price = 25000,  seats = 2, stats = { speed = 86, accel = 90, brake = 60, handling = 70 } },
    { model = 'akuma',     label = 'Akuma',      brand = 'Dinka',    category = 'moto',   price = 22000,  seats = 2, stats = { speed = 84, accel = 88, brake = 58, handling = 68 } },
}

-- يتنفذ بعد ما تنزل السيارة (مفاتيح / بنزين) عدله حسب سكربتاتك
Config.OnVehicleSpawned = function(vehicle, plate, isTestDrive)
    if GetResourceState('LegacyFuel') == 'started' then
        exports['LegacyFuel']:SetFuel(vehicle, 100.0)
    elseif GetResourceState('ox_fuel') == 'started' then
        Entity(vehicle).state.fuel = 100.0
    else
        SetVehicleFuelLevel(vehicle, 100.0)
    end
    if GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerEvent('vehiclekeys:client:SetOwner', plate)
    end
end
