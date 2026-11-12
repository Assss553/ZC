--[[
    ROX Real Estate  ·  © ROX Store – All rights reserved.
    Made for ROX Store. Do not resell or redistribute without permission.
]]

--[[
    House detection
    ----------------
    1. Shell models
       - every .ydr inside rox_realestate/stream/houses/ (any name)
       - every .ydr in a started resource whose name matches Config.Detect.NamePatterns
       - a list of well-known shell names from popular packs
       - Config.Detect.Extra and every shell saved in the rox_shells table
       Each client then checks IsModelInCdimage, so only shells that are really streamed show in the iPad.
    2. Pictures
       html/img/houses/<interior key or shell model>.jpg|png|webp|jpeg
       html/img/furniture/<prop model>.jpg|png|webp|jpeg
    3. Entry point
       Detected shells without a known entry offset get one automatically (centre of the shell floor).
       A realtor standing inside can save the exact entry with /houseentry [label].
]]

Detect = {}
Registry = { interiors = {}, furnitureImages = {}, scannedAt = 0, files = false }

local RES = GetCurrentResourceName()
local IMG_EXT = { '.jpg', '.png', '.webp', '.jpeg' }

-- names used by popular shell packs; only the ones actually streamed will show up (client check)
local KNOWN = {
    'shell_highend', 'shell_highendv2', 'shell_medium2', 'shell_medium3', 'shell_westons', 'shell_westons2',
    'shell_banana', 'shell_apartment1', 'shell_apartment2', 'shell_apartment3', 'shell_garagem', 'shell_garages',
    'shell_garagel', 'shell_office2', 'shell_officebig', 'shell_store2', 'shell_store3', 'shell_warehouse2',
    'shell_warehouse3', 'shell_gunstore', 'shell_barber', 'shell_coke1', 'shell_coke2', 'shell_meth', 'shell_weed',
    'shell_weed2', 'shell_cabin', 'shell_motel', 'shell_hotel1', 'shell_tier1', 'shell_tier2', 'shell_tier3',
    'shell_mansion', 'shell_villa', 'furnitured_lowapart', 'furnitured_motel', 'standardmotel_shell',
}

---------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------
local function isWindows() return package.config:sub(1, 1) == '\\' end

local function canPopen() return Config.Detect.ScanFiles and io and io.popen ~= nil end

-- recursive list of files with the given extension (lower case, without dot)
local function listFiles(dir, ext)
    if not canPopen() or not dir or dir == '' then return {} end
    local cmd
    if isWindows() then
        cmd = ('dir "%s\\*.%s" /b /s /a-d 2>nul'):format(dir:gsub('/', '\\'), ext)
    else
        cmd = ('find "%s" -type f -iname "*.%s" 2>/dev/null'):format(dir, ext)
    end
    local ok, handle = pcall(io.popen, cmd)
    if not ok or not handle then return {} end
    local out = {}
    for line in handle:lines() do out[#out + 1] = line:gsub('\\', '/') end
    handle:close()
    Registry.files = true
    return out
end

local function baseName(path)
    return (path:match('([^/]+)$') or path):gsub('%.[^%.]+$', ''):lower()
end

local function matchesPattern(name)
    for _, p in ipairs(Config.Detect.NamePatterns) do
        if name:find(p, 1, true) then return true end
    end
    return false
end

local function prettify(model)
    local s = model:gsub('^shell_', ''):gsub('_shell$', ''):gsub('[_%-]+', ' ')
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end

local UP = Config.Detect.UploadResource

local function uploadStarted()
    return UP and GetResourceState(UP) == 'started'
end

-- picture uploaded in rox_houses/images (served to the NUI with nui://)
local function findUploadImage(names)
    if not uploadStarted() then return nil end
    for _, name in ipairs(names) do
        if name then
            if name:find('%.') and LoadResourceFile(UP, 'images/' .. name) then return ('nui://%s/images/%s'):format(UP, name) end
            for _, ext in ipairs(IMG_EXT) do
                if LoadResourceFile(UP, 'images/' .. name .. ext) then return ('nui://%s/images/%s%s'):format(UP, name, ext) end
            end
        end
    end
end

-- rox_houses/houses.json
local function uploadManifest()
    if not uploadStarted() then return {} end
    local raw = LoadResourceFile(UP, 'houses.json')
    if not raw then return {} end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        print(('^1[rox_realestate]^7 %s/houses.json is not valid JSON'):format(UP))
        return {}
    end
    return type(data.houses) == 'table' and data.houses or {}
end

local function vec4From(t)
    if type(t) ~= 'table' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not (x and y and z) then return nil end
    return vec4(x, y, z, tonumber(t.h) or 0.0)
end

local function findImage(folder, names)
    for _, name in ipairs(names) do
        if name then
            for _, ext in ipairs(IMG_EXT) do
                local path = ('html/img/%s/%s%s'):format(folder, name, ext)
                if LoadResourceFile(RES, path) then return 'img/' .. folder .. '/' .. name .. ext end
            end
        end
    end
end

---------------------------------------------------------------------
-- scan
---------------------------------------------------------------------
local function scanShellFiles()
    local found = {}
    -- our own drop folder: everything counts
    local own = GetResourcePath(RES) .. '/' .. Config.Detect.OwnFolder
    for _, f in ipairs(listFiles(own, 'ydr')) do found[baseName(f)] = RES end
    -- upload resource (rox_houses/stream): everything counts too
    if uploadStarted() then
        for _, f in ipairs(listFiles(GetResourcePath(UP) .. '/stream', 'ydr')) do found[baseName(f)] = UP end
    end
    -- other started resources: only names that look like shells
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        if res and res ~= RES and res ~= UP and GetResourceState(res) == 'started' then
            local path = GetResourcePath(res)
            if path and path ~= '' then
                for _, f in ipairs(listFiles(path, 'ydr')) do
                    local name = baseName(f)
                    if matchesPattern(name) and not found[name] then found[name] = res end
                end
            end
            if i % 20 == 0 then Wait(0) end
        end
    end
    -- ROX open-house interiors are walk-in models, not teleport shells
    for name in pairs(found) do if name:find('^rox_open') or name:find('^rox_b_') then found[name] = nil end end
    return found
end

local function shellModels()
    local models = {}
    for _, i in pairs(Interiors) do if i.shell then models[i.shell] = true end end
    return models
end

function Detect.Run()
    if not Config.Detect.Enabled then return 0 end
    local saved = {}
    for _, row in ipairs(DB.LoadShells()) do
        local o = row.offset and json.decode(row.offset)
        if o and o.abs then
            -- saved entry for a GTA interior
            local i = Interiors[row.model]
            if i and not i.shell then i.spawn = vec4(o.x, o.y, o.z, o.h or 0.0) end
        else
            saved[row.model] = { label = row.label, offset = o and vec4(o.x, o.y, o.z, o.h or 0.0) }
        end
    end

    -- remove previously auto-registered entries (rescan)
    for key, i in pairs(Interiors) do if i.auto then Interiors[key] = nil end end

    local candidates = {}
    for _, m in ipairs(KNOWN) do candidates[m] = 'known' end
    for _, m in ipairs(Config.Detect.Extra or {}) do candidates[m:lower()] = 'config' end
    for m in pairs(saved) do candidates[m] = candidates[m] or 'saved' end
    for m, res in pairs(scanShellFiles()) do candidates[m] = res end

    local existing = shellModels()
    local added = 0
    for model, source in pairs(candidates) do
        if not existing[model] and not Interiors[model] then
            local s = saved[model] or {}
            Interiors[model] = {
                label = s.label or prettify(model), labelAr = s.label or prettify(model),
                tier = 'mid', rooms = 1, shell = model, offset = s.offset, auto = true, source = source,
            }
            added = added + 1
        end
    end

    -- houses.json entries from the upload resource (names, pictures, entry, ROX design, MLOs)
    for _, h in ipairs(uploadManifest()) do
        if type(h) == 'table' then
            local isMlo = h.type == 'mlo'
            local key = tostring(h.key or h.model or ''):gsub('[^%w_%-]', ''):lower()
            if key ~= '' and (not Interiors[key] or Interiors[key].auto) then
                local s = (h.model and saved[h.model]) or {}
                local design = (h.design == 'warehouse' or h.design == 'hideout') and h.design or nil
                local entry = {
                    label = h.label or prettify(key), labelAr = h.labelAr or h.label or prettify(key),
                    tier = ({ low = 1, mid = 1, high = 1, luxury = 1 })[h.tier] and h.tier or 'mid',
                    rooms = tonumber(h.rooms) or 1, auto = true, uploaded = true, source = UP,
                    decor = design, gangOnly = h.gangOnly == true, order = -1,
                }
                if isMlo then
                    entry.spawn = vec4From(h.spawn)
                else
                    entry.shell = tostring(h.model):lower()
                    entry.offset = s.offset or vec4From(h.entry)
                end
                if (isMlo and entry.spawn) or (not isMlo and h.model) then
                    entry.image = findUploadImage({ h.image, key, h.model })
                    if not Interiors[key] then added = added + 1 end
                    -- the json entry replaces the plain detected one for the same model
                    if not isMlo and Interiors[entry.shell] and Interiors[entry.shell].auto and entry.shell ~= key then Interiors[entry.shell] = nil end
                    Interiors[key] = entry
                end
            end
        end
    end

    -- saved offsets also fix built-in shells
    for _, i in pairs(Interiors) do
        if i.shell and not i.auto and saved[i.shell] and saved[i.shell].offset then i.offset = saved[i.shell].offset end
    end

    -- pictures for every interior: key first, then shell model
    for key, i in pairs(Interiors) do
        local img = findUploadImage({ key, i.shell }) or findImage('houses', { key, i.shell })
        if img then i.image = img elseif i.auto and not i.uploaded then i.image = nil end
    end

    Registry.furnitureImages = {}
    for _, item in ipairs(FurnitureCatalog) do
        local img = item.image or findImage('furniture', { item.model })
        if img then Registry.furnitureImages[item.model] = img end
    end

    Registry.interiors = InteriorsForUI()
    Registry.scannedAt = os.time()
    TriggerClientEvent('rox_re:registry', -1, Registry)
    print(('^2[rox_realestate]^7 detection: %d candidate shells, file scan %s, %d furniture pictures'):format(
        added, Registry.files and 'ok' or 'unavailable (io.popen)', (function() local n = 0 for _ in pairs(Registry.furnitureImages) do n = n + 1 end return n end)()))
    return added
end

RegisterNetEvent('rox_re:requestSync', function()
    TriggerClientEvent('rox_re:registry', source, Registry)
end)

---------------------------------------------------------------------
-- realtor tools
---------------------------------------------------------------------
RegisterCallback('rescan', function(src)
    if not HasApp(src, 'create') then return false, L('not_realtor') end
    Detect.Run()
    Bridge.Notify(src, LP(src, 'scan_done', #Registry.interiors), 'success')
    return true
end)

-- save the entry point of the shell you are standing in (+ optional label)
RegisterCallback('saveEntry', function(src, label)
    if not IsRealtor(src) then return false, L('not_realtor') end
    local prop = GetProp(Inside[src])
    local interior = prop and Interiors[prop.interior]
    if not interior or interior.custom then return false, L('not_inside') end
    label = type(label) == 'string' and label:gsub('[<>]', ''):sub(1, 48) or nil
    if label == '' then label = nil end

    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    if not interior.shell then
        -- GTA interior: save the absolute entry point (ped centre, like the built-in spawns)
        local a = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped), abs = true }
        DB.SaveShell(prop.interior, label, a)
        interior.spawn = vec4(a.x, a.y, a.z, a.h)
        Registry.interiors = InteriorsForUI()
        TriggerClientEvent('rox_re:registry', -1, Registry)
        Bridge.Notify(src, LP(src, 'entry_saved', prop.interior), 'success')
        return true
    end
    local _, shellPos = GetInteriorSpawn(prop.interior, prop.door, prop.inside)
    local o = { x = c.x - shellPos.x, y = c.y - shellPos.y, z = c.z - shellPos.z, h = GetEntityHeading(ped) }
    if math.abs(o.x) > 60 or math.abs(o.y) > 60 or math.abs(o.z) > 30 then return false, L('too_far_place') end
    DB.SaveShell(interior.shell, label or (interior.auto and interior.label) or nil, o)
    for _, i in pairs(Interiors) do
        if i.shell == interior.shell then
            i.offset = vec4(o.x, o.y, o.z, o.h)
            if label and i.auto then i.label, i.labelAr = label, label end
        end
    end
    Registry.interiors = InteriorsForUI()
    TriggerClientEvent('rox_re:registry', -1, Registry)
    Bridge.Notify(src, LP(src, 'entry_saved', interior.shell), 'success')
    return true
end)

-- realtor: write the generated warehouse as a CodeWalker ymap XML (exports/<name>.ymap.xml)
RegisterCallback('exportDecor', function(src, name, list)
    if not IsRealtor(src) then return false, L('not_realtor') end
    if type(name) ~= 'string' or name == '' or type(list) ~= 'table' or #list == 0 or #list > 2000 then return false, L('invalid_data') end
    name = name:gsub('[^%w_%-]', ''):sub(1, 48)
    local minV, maxV = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
    local items = {}
    for _, e in ipairs(list) do
        local x, y, z = tonumber(e.x), tonumber(e.y), tonumber(e.z)
        local m = type(e.m) == 'string' and e.m:gsub('[^%w_]', '') or nil
        if x and y and z and m then
            minV = { math.min(minV[1], x), math.min(minV[2], y), math.min(minV[3], z) }
            maxV = { math.max(maxV[1], x), math.max(maxV[2], y), math.max(maxV[3], z) }
            -- ymap stores the inverse rotation
            items[#items + 1] = ([[
    <Item type="CEntityDef">
      <archetypeName>%s</archetypeName>
      <flags value="32" />
      <guid value="0" />
      <position x="%.4f" y="%.4f" z="%.4f" />
      <rotation x="%.6f" y="%.6f" z="%.6f" w="%.6f" />
      <scaleXY value="1" />
      <scaleZ value="1" />
      <parentIndex value="-1" />
      <lodDist value="120" />
      <childLodDist value="0" />
      <lodLevel>LODTYPES_DEPTH_ORPHANHD</lodLevel>
      <numChildren value="0" />
      <priorityLevel>PRI_REQUIRED</priorityLevel>
      <extensions />
      <ambientOcclusionMultiplier value="255" />
      <artificialAmbientOcclusion value="255" />
      <tintValue value="0" />
    </Item>]]):format(m, x, y, z, -(tonumber(e.qx) or 0), -(tonumber(e.qy) or 0), -(tonumber(e.qz) or 0), tonumber(e.qw) or 1)
        end
    end
    local pad = 60.0
    local xml = ([[<?xml version="1.0" encoding="UTF-8"?>
<!-- ROX Real Estate · ROX warehouse design · © ROX Store – All rights reserved -->
<CMapData>
  <name>%s</name>
  <parent />
  <flags value="0" />
  <contentFlags value="1" />
  <streamingExtentsMin x="%.2f" y="%.2f" z="%.2f" />
  <streamingExtentsMax x="%.2f" y="%.2f" z="%.2f" />
  <entitiesExtentsMin x="%.2f" y="%.2f" z="%.2f" />
  <entitiesExtentsMax x="%.2f" y="%.2f" z="%.2f" />
  <entities>%s
  </entities>
  <containerLods />
  <boxOccluders />
  <occludeModels />
  <physicsDictionaries />
  <instancedData>
    <ImapLink />
    <PropInstanceList />
    <GrassInstanceList />
  </instancedData>
  <timeCycleModifiers />
  <carGenerators />
  <block>
    <version value="0" />
    <flags value="0" />
    <name>%s</name>
    <exportedBy>ROX Store</exportedBy>
    <owner />
    <time />
  </block>
</CMapData>
]]):format(name, minV[1] - pad, minV[2] - pad, minV[3] - pad, maxV[1] + pad, maxV[2] + pad, maxV[3] + pad,
        minV[1], minV[2], minV[3], maxV[1], maxV[2], maxV[3], table.concat(items), name)
    local path = ('exports/%s.ymap.xml'):format(name)
    if not SaveResourceFile(RES, path, xml, -1) then return false, 'save failed (create the exports folder)' end
    print(('^2[ROX Store]^7 exported %d props to %s/%s'):format(#items, RES, path))
    return true, path
end)

RegisterCommand(Config.Detect.Command, function(src)
    if src ~= 0 and not IsRealtor(src) then return end
    CreateThread(function()
        local n = Detect.Run()
        if src ~= 0 then Bridge.Notify(src, LP(src, 'scan_done', #Registry.interiors), 'success') else print('rescanned', n) end
    end)
end, false)
