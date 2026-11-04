--[[
    Interiors the realtor can choose from when creating a property.
    spawn  = where the player appears inside (also the exit point)
    image  = picture shown in the iPad (put your own screenshots in html/img/houses/)
             can also be a full https:// url
    ipl    = optional IPL to request (executive apartments need bob74_ipl or the IPL loaded)
    tier   = low / mid / high / luxury  (only for display)
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
}

-- Plain table version for the NUI / network
function InteriorsForUI()
    local list = {}
    for key, v in pairs(Interiors) do
        list[#list + 1] = {
            key = key, label = v.label, labelAr = v.labelAr, tier = v.tier,
            rooms = v.rooms, image = v.image,
        }
    end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end
