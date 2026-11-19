-- ROX Store | All rights reserved
Config = {}
Config.Name = 'ROX OUTFITTERS'
Config.Blip = { sprite = 73, color = 48, label = 'Clothing Store' }
Config.Locations = {
    vec3(72.3, -1399.1, 29.4), vec3(-708.7, -152.1, 37.4), vec3(-164.7, -302.0, 39.7), vec3(428.7, -800.1, 29.5),
    vec3(-829.4, -1073.7, 11.3), vec3(-1447.8, -242.5, 49.8), vec3(11.6, 6514.2, 31.9), vec3(123.6, -219.4, 54.6),
    vec3(1696.3, 4829.3, 42.1), vec3(618.1, 2759.6, 42.1), vec3(1190.6, 2713.4, 38.2), vec3(-1193.4, -772.3, 17.3),
    vec3(-3172.5, 1048.1, 20.9), vec3(-1108.4, 2708.9, 19.1),
}
-- kind: 'comp' (component id) or 'prop' (prop id). price per item, colour swatches = textures.
Config.Categories = {
    { label = 'Hats',        kind = 'prop', id = 0,  price = 45,  cam = 'head' },
    { label = 'Glasses',     kind = 'prop', id = 1,  price = 60,  cam = 'head' },
    { label = 'Neckwear',    kind = 'comp', id = 1,  price = 35,  cam = 'head' },
    { label = 'Tops',        kind = 'comp', id = 11, price = 90,  cam = 'body', torso = true },
    { label = 'Undershirts', kind = 'comp', id = 8,  price = 40,  cam = 'body' },
    { label = 'Body Armor',  kind = 'comp', id = 9,  price = 275, cam = 'body', armor = 50 },
    { label = 'Pants',       kind = 'comp', id = 4,  price = 70,  cam = 'legs' },
    { label = 'Shoes',       kind = 'comp', id = 6,  price = 80,  cam = 'feet' },
    { label = 'Watches',     kind = 'prop', id = 6,  price = 150, cam = 'body' },
    { label = 'Bags',        kind = 'comp', id = 5,  price = 120, cam = 'body' },
}
Config.Payment = { 'cash', 'bank' }
