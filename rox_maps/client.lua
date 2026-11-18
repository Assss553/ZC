-- ROX Store | All rights reserved
CreateThread(function()
    local b = AddBlipForCoord(Config.Restaurant.x, Config.Restaurant.y, Config.Restaurant.z)
    SetBlipSprite(b, Config.Blip.sprite); SetBlipColour(b, Config.Blip.color); SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING'); AddTextComponentString(Config.Blip.label); EndTextCommandSetBlipName(b)
end)

local function use(inside)
    if not lib.callback.await('rox_maps:canEnter', false) then
        return lib.notify({ type = 'error', description = 'This wall looks solid...' })
    end
    if lib.progressCircle({ duration = 2500, label = inside and 'Leaving...' or 'Opening secret wall...',
        position = 'bottom', disable = { move = true, combat = true },
        anim = { dict = 'anim@heists@keycard@', clip = 'exit' } }) then
        DoScreenFadeOut(400); Wait(450)
        TriggerServerEvent('rox_maps:enter', inside)
        Wait(600); DoScreenFadeIn(500)
    end
end

exports.ox_target:addSphereZone({ coords = Config.SecretWall.coords, radius = 1.0,
    options = { { name = 'rox_secret_in', icon = 'fa-solid fa-dungeon', label = 'Inspect wall',
        onSelect = function() use(false) end } } })
exports.ox_target:addSphereZone({ coords = Config.HQ.coords.xyz, radius = 1.5,
    options = { { name = 'rox_secret_out', icon = 'fa-solid fa-stairs', label = 'Go upstairs',
        onSelect = function() use(true) end } } })
