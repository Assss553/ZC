local blip

CreateThread(function()
  local b = Config.Blip
  blip = AddBlipForCoord(Config.Tower.x, Config.Tower.y, Config.Tower.z)
  SetBlipSprite(blip, b.sprite); SetBlipColour(blip, b.color)
  SetBlipScale(blip, b.scale); SetBlipAsShortRange(blip, true)
  BeginTextCommandSetBlipName('STRING'); AddTextComponentString(b.label)
  EndTextCommandSetBlipName(blip)
end)

local function help(msg)
  BeginTextCommandDisplayHelp('STRING'); AddTextComponentSubstringPlayerName(msg)
  EndTextCommandDisplayHelp(0, false, true, -1)
end

local function teleport(c)
  local ped = PlayerPedId()
  DoScreenFadeOut(400); while not IsScreenFadedOut() do Wait(0) end
  SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
  SetEntityHeading(ped, c.w)
  Wait(300); DoScreenFadeIn(400)
end

local menuOpen, sel = false, 1

CreateThread(function()
  while true do
    local sleep = 750
    local pos = GetEntityCoords(PlayerPedId())
    for i, f in ipairs(Config.Floors) do
      if #(pos - f.coords.xyz) < 10.0 then
        sleep = 0
        DrawMarker(1, f.coords.x, f.coords.y, f.coords.z - 1.0, 0,0,0, 0,0,0, 1.0,1.0,0.4, 201,162,74,150, false,false,2,false)
        if #(pos - f.coords.xyz) < Config.Distance then
          if not menuOpen then
            help('~INPUT_CONTEXT~ المصعد - IAA Elevator')
            if IsControlJustPressed(0, Config.Key) then menuOpen, sel = true, i end
          end
        elseif menuOpen and sel == i then menuOpen = false end
      end
    end
    if menuOpen then
      local txt = 'IAA Elevator  (↑/↓ + Enter, Backspace)\n'
      for i, f in ipairs(Config.Floors) do txt = txt .. (i == sel and '> ' or '  ') .. f.label .. '\n' end
      help(txt)
      if IsControlJustPressed(0, 172) then sel = sel > 1 and sel - 1 or #Config.Floors end
      if IsControlJustPressed(0, 173) then sel = sel < #Config.Floors and sel + 1 or 1 end
      if IsControlJustPressed(0, 191) then menuOpen = false; teleport(Config.Floors[sel].coords) end
      if IsControlJustPressed(0, 177) then menuOpen = false end
    end
    Wait(sleep)
  end
end)
