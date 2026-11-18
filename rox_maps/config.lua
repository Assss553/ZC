-- ROX Store | All rights reserved
Config = {}
-- Map origin = position of the 3 entities in rox_diner.ymap (default near Pacific Standard, Vinewood).
-- If you move/rotate the map in CodeWalker, change ONLY these two values: everything below follows.
Config.Origin  = vec3(232.0, 300.0, 105.6)
Config.Heading = 0.0

-- Gangs allowed to use the secret wall / elevator: [gang name] = minimum grade
Config.Gangs = { ballas = 0, vagos = 0, families = 0 }

Config.Wall = {
    model     = `rox_secret_wall`,
    hinge     = vec3(6.7, 7.0, 0.0),   -- local offset (Blender coords) of the hinge
    openAngle = -80.0,                 -- degrees it swings into the diner
    speed     = 1.4,                   -- seconds to open/close
    autoClose = 10,                    -- seconds before it closes again
    target    = vec3(7.5, 6.6, 1.2),   -- ox_target point on the wall (diner side)
}
Config.Lift = {
    top    = { button = vec3(8.2, 8.9, 1.25), spawn = vec4(7.5, 8.0, 0.05, 180.0) },
    bottom = { button = vec3(8.2, 6.35, -4.7), spawn = vec4(7.5, 7.0, -5.85, 0.0) },
    rideTime = 3500,
}
Config.Blip = { sprite = 93, color = 48, label = 'ROX Diner' }

-- local Blender offset -> world coords (respects Config.Heading)
function Config.ToWorld(o)
    local h = math.rad(Config.Heading)
    local x = o.x * math.cos(h) - o.y * math.sin(h)
    local y = o.x * math.sin(h) + o.y * math.cos(h)
    return vec3(Config.Origin.x + x, Config.Origin.y + y, Config.Origin.z + o.z)
end
