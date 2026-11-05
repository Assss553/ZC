--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

--[[
    Interiors the realtor can choose from when creating a property.
    spawn  = where the player appears inside (also the exit point)
    image  = picture shown in the iPad (put your own screenshots in html/img/houses/)
             can also be a full https:// url
    ipl    = optional IPL to request (executive apartments need bob74_ipl or the IPL loaded)
    tier   = low / mid / high / luxury  (only for display)

    SHELLS (k4mb1 "Free Props & Starter Shells" – https://forum.cfx.re/t/free-props-starter-shells-for-housing-scripts/4826922)
    shell  = shell prop model. The shell is spawned under the house door (Config.ShellZOffset)
    offset = entry/exit point relative to the shell origin (x, y, z, heading)
    You must download the shells resource from the forum post and `ensure` it BEFORE this resource.
]]

Interiors = {
    low_apartment = {
        label = 'Low-End Apartment', labelAr = 'شقة اقتصادية',
        tier = 'low', rooms = 1, image = 'img/houses/low_apartment.jpg',
        spawn = vec4(266.05, -1007.42, -101.01, 0.0),
    },
    medium_apartment = {
        label = 'Medium Apartment', labelAr = 'شقة متوسطة',
        tier = 'mid', rooms = 2, image = 'img/houses/medium_apartment.jpg',
        spawn = vec4(346.55, -1012.32, -99.20, 0.0),
    },
    floyd_apartment = {
        label = 'Vespucci Beach Apartment', labelAr = 'شقة فسبوتشي البحرية',
        tier = 'low', rooms = 2, image = 'img/houses/floyd_apartment.jpg',
        spawn = vec4(-1150.70, -1520.70, 10.63, 35.0),
    },
    franklin_aunt = {
        label = 'Forum Drive House', labelAr = 'بيت فورم درايف',
        tier = 'low', rooms = 2, image = 'img/houses/franklin_aunt.jpg',
        spawn = vec4(-14.31, -1438.04, 31.10, 0.0),
    },
    trailer = {
        label = 'Sandy Shores Trailer', labelAr = 'كرفان ساندي شورز',
        tier = 'low', rooms = 1, image = 'img/houses/trailer.jpg',
        spawn = vec4(1973.00, 3816.00, 33.43, 30.0),
    },
    lester_house = {
        label = 'El Burro House', labelAr = 'بيت البورو',
        tier = 'mid', rooms = 2, image = 'img/houses/lester_house.jpg',
        spawn = vec4(1273.90, -1719.30, 54.77, 20.0),
    },
    integrity_way = {
        label = '4 Integrity Way Apt', labelAr = 'شقة انتغريتي واي',
        tier = 'high', rooms = 2, image = 'img/houses/integrity_way.jpg',
        spawn = vec4(-18.08, -583.67, 79.47, 160.0),
    },
    tinsel_towers = {
        label = 'Tinsel Towers Apt', labelAr = 'شقة تينسل تاورز',
        tier = 'high', rooms = 2, image = 'img/houses/tinsel_towers.jpg',
        spawn = vec4(-603.43, 58.95, 98.20, 90.0),
    },
    north_conker = {
        label = 'North Conker Villa', labelAr = 'فيلا نورث كونكر',
        tier = 'high', rooms = 3, image = 'img/houses/north_conker.jpg',
        spawn = vec4(341.76, 437.84, 149.39, 110.0),
    },
    wild_oats = {
        label = 'Wild Oats Villa', labelAr = 'فيلا وايلد أوتس',
        tier = 'high', rooms = 3, image = 'img/houses/wild_oats.jpg',
        spawn = vec4(117.21, 559.51, 184.30, 180.0),
    },
    franklin_vinewood = {
        label = 'Vinewood Hills Villa', labelAr = 'فيلا فاينوود هيلز',
        tier = 'luxury', rooms = 4, image = 'img/houses/franklin_vinewood.jpg',
        spawn = vec4(7.11, 538.30, 176.03, 160.0),
    },
    michael_house = {
        label = 'Rockford Hills Mansion', labelAr = 'قصر روكفورد هيلز',
        tier = 'luxury', rooms = 5, image = 'img/houses/michael_house.jpg',
        spawn = vec4(-815.60, 178.90, 72.15, 110.0),
    },
    penthouse_modern = {
        label = 'Eclipse Penthouse - Modern', labelAr = 'بنتهاوس إكلبس - مودرن',
        tier = 'luxury', rooms = 3, image = 'img/houses/penthouse_modern.jpg',
        spawn = vec4(-786.87, 315.76, 217.64, 270.0), ipl = 'apa_v_mp_h_01_a',
    },
    penthouse_moody = {
        label = 'Eclipse Penthouse - Moody', labelAr = 'بنتهاوس إكلبس - داكن',
        tier = 'luxury', rooms = 3, image = 'img/houses/penthouse_moody.jpg',
        spawn = vec4(-774.01, 342.04, 196.69, 90.0), ipl = 'apa_v_mp_h_02_b',
    },
    penthouse_vibrant = {
        label = 'Eclipse Penthouse - Vibrant', labelAr = 'بنتهاوس إكلبس - حيوي',
        tier = 'luxury', rooms = 3, image = 'img/houses/penthouse_vibrant.jpg',
        spawn = vec4(-786.96, 315.62, 187.91, 270.0), ipl = 'apa_v_mp_h_03_c',
    },

    ------------------------------------------------------------------
    -- k4mb1 starter shells (offsets from qb-interior)
    ------------------------------------------------------------------
    shell_container = {
        label = 'Container Room', labelAr = 'غرفة كونتينر',
        tier = 'low', rooms = 1, image = 'img/houses/shell_container.jpg',
        shell = 'container_shell', offset = vec4(0.08, -5.73, 1.24, 359.32),
    },
    shell_trailer = {
        label = 'Caravan (Shell)', labelAr = 'كرفان',
        tier = 'low', rooms = 1, image = 'img/houses/shell_trailer.jpg',
        shell = 'shell_trailer', offset = vec4(-1.40, -2.10, 3.30, 358.63),
    },
    shell_v16low = {
        label = 'Starter Apartment', labelAr = 'شقة بداية',
        tier = 'low', rooms = 1, image = 'img/houses/shell_v16low.jpg',
        shell = 'shell_v16low', offset = vec4(4.69, -6.02, 1.11, 358.63),
    },
    shell_motel = {
        label = 'Modern Motel Room', labelAr = 'غرفة موتيل مودرن',
        tier = 'low', rooms = 1, image = 'img/houses/shell_motel.jpg',
        shell = 'modernhotel_shell', offset = vec4(4.98, 4.35, 1.16, 179.79),
    },
    shell_v16mid = {
        label = 'Mid Apartment (Shell)', labelAr = 'شقة متوسطة (شل)',
        tier = 'mid', rooms = 2, image = 'img/houses/shell_v16mid.jpg',
        shell = 'shell_v16mid', offset = vec4(1.56, -14.31, 1.15, 2.26),
    },
    shell_furnished = {
        label = 'Furnished Apartment', labelAr = 'شقة مفروشة',
        tier = 'mid', rooms = 2, image = 'img/houses/shell_furnished.jpg',
        shell = 'furnitured_midapart', offset = vec4(1.46, -10.33, 1.06, 0.39),
    },
    shell_trevor = {
        label = 'Trevor House', labelAr = 'بيت تريفور',
        tier = 'low', rooms = 2, image = 'img/houses/shell_trevor.jpg',
        shell = 'shell_trevor', offset = vec4(0.37, -3.79, 2.43, 358.63),
    },
    shell_lester = {
        label = 'Lester House', labelAr = 'بيت ليستر',
        tier = 'mid', rooms = 2, image = 'img/houses/shell_lester.jpg',
        shell = 'shell_lester', offset = vec4(-1.78, -0.80, 1.10, 270.30),
    },
    shell_frankaunt = {
        label = 'Family House', labelAr = 'بيت عائلي',
        tier = 'mid', rooms = 3, image = 'img/houses/shell_frankaunt.jpg',
        shell = 'shell_frankaunt', offset = vec4(-0.36, -5.89, 1.70, 358.21),
    },
    shell_ranch = {
        label = 'Ranch House', labelAr = 'بيت مزرعة',
        tier = 'mid', rooms = 3, image = 'img/houses/shell_ranch.jpg',
        shell = 'shell_ranch', offset = vec4(-1.26, -5.47, 2.50, 270.57),
    },
    shell_michael = {
        label = 'Grand Mansion (Shell)', labelAr = 'قصر فخم (شل)',
        tier = 'luxury', rooms = 5, image = 'img/houses/shell_michael.jpg',
        shell = 'shell_michael', offset = vec4(-9.49, 5.54, 9.91, 270.86),
    },
    shell_garage = {
        label = 'Medium Garage', labelAr = 'كراج متوسط',
        tier = 'mid', rooms = 1, image = 'img/houses/shell_garage.jpg',
        shell = 'shell_garagemed', offset = vec4(13.90, 1.63, 1.00, 87.05),
    },
    shell_office = {
        label = 'Office', labelAr = 'مكتب',
        tier = 'mid', rooms = 2, image = 'img/houses/shell_office.jpg',
        shell = 'shell_office1', offset = vec4(1.88, 5.06, 2.05, 180.07),
    },
    shell_store = {
        label = 'Shop / Store', labelAr = 'محل تجاري',
        tier = 'mid', rooms = 1, image = 'img/houses/shell_store.jpg',
        shell = 'shell_store1', offset = vec4(-2.61, -4.73, 1.08, 1.0),
    },
    shell_warehouse = {
        label = 'Warehouse', labelAr = 'مستودع',
        tier = 'high', rooms = 1, image = 'img/houses/shell_warehouse.jpg',
        shell = 'shell_warehouse1', offset = vec4(-8.95, 0.51, 1.04, 268.82),
    },
}

-- Custom / MLO: the realtor aims at the inside point (use it for MLO maps or any place in the world)
Interiors.custom = {
    label = 'Custom location / MLO', labelAr = 'موقع مخصص / MLO',
    tier = 'mid', rooms = 1, image = 'img/houses/custom.jpg', custom = true, order = -1,
}

-- Where the player appears inside a property.
-- Returns spawn (vec4, ped position), shellPos (vector3, shells only) and autoEntry (true when the
-- shell has no saved entry offset yet: the client then finds the floor in the middle of the shell).
function GetInteriorSpawn(interiorKey, door, inside)
    local i = Interiors[interiorKey]
    if not i or not door then return nil end
    if i.custom then
        if not inside then return nil end
        return vec4(inside.x + 0.0, inside.y + 0.0, inside.z + 0.0, (inside.h or 0.0) + 0.0), nil, false
    end
    if i.shell then
        local pos = vector3(door.x + 0.0, door.y + 0.0, door.z + Config.ShellZOffset)
        local o = i.offset
        if not o then return vec4(pos.x, pos.y, pos.z + 1.0, 0.0), pos, true end
        return vec4(pos.x + o.x, pos.y + o.y, pos.z + o.z, o.w), pos, false
    end
    return i.spawn, nil, false
end

-- Plain table version for the NUI / network
function InteriorsForUI()
    local list = {}
    for key, v in pairs(Interiors) do
        list[#list + 1] = {
            key = key, label = v.label, labelAr = v.labelAr, tier = v.tier,
            rooms = v.rooms, image = v.image, shell = v.shell, custom = v.custom or false,
            auto = v.auto or false, needsEntry = v.shell ~= nil and v.offset == nil, order = v.order or (v.auto and 1 or 0),
        }
    end
    table.sort(list, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.label < b.label
    end)
    return list
end
