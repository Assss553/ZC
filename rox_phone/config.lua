-- ROX Store | rox_phone | All rights reserved.
Config = {}
Config.Command = 'phone'
Config.Key = 'M'                 -- players can rebind in GTA settings > Key Bindings > FiveM
Config.RequireItem = false       -- set to 'phone' to require the item (ox_inventory)
Config.ImpoundFee = 500
-- props / animations per layout (0 phone, 1 half open, 2 tablet)
Config.Layouts = {
    [0] = { prop = `prop_npc_phone_02`, bone = 28422, pos = vec3(0.0, 0.0, 0.0), rot = vec3(0.0, 0.0, 0.0),
            dict = 'cellphone@', anim = 'cellphone_text_read_base' },
    [1] = { prop = `prop_cs_tablet`, bone = 28422, pos = vec3(0.0, -0.03, 0.0), rot = vec3(20.0, -90.0, 0.0), scale = 0.75,
            dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', anim = 'base' },
    [2] = { prop = `prop_cs_tablet`, bone = 60309, pos = vec3(0.03, 0.002, -0.0), rot = vec3(10.0, 160.0, 0.0),
            dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', anim = 'base' },
}
