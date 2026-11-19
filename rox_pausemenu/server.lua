-- ROX Store | All rights reserved
lib.callback.register('rox_pausemenu:data', function(src)
    local d = { id = src, players = #GetPlayers(), maxPlayers = GetConvarInt('sv_maxclients', 48), name = GetPlayerName(src) }
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if ok and p then
        local pd = p.PlayerData
        local ci = pd.charinfo or {}
        d.name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', '')
        d.cid = pd.citizenid
        d.cash = pd.money and pd.money.cash or 0
        d.bank = pd.money and pd.money.bank or 0
        if pd.job then d.job = (pd.job.label or pd.job.name) .. (pd.job.grade and pd.job.grade.name and (' · ' .. pd.job.grade.name) or '') end
    end
    return d
end)

RegisterNetEvent('rox_pausemenu:quit', function() DropPlayer(source, 'Quit the game') end)
