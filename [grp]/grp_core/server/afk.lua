GRP = GRP or {}
GRP.AFK = {}

local afkPlayers = {}

RegisterNetEvent('grp_core:server:setAFK', function(isAFK)
    local src = source

    if type(isAFK) ~= 'boolean' then
        return
    end

    local player = exports.qbx_core:GetPlayer(src)

    if not player or not player.PlayerData then
        return
    end

    local citizenid = player.PlayerData.citizenid

    if not citizenid then
        return
    end

    if isAFK then
        afkPlayers[src] = citizenid
    else
        afkPlayers[src] = nil
    end

    if Config.Debug then
        print(('[GRP AFK] %s | AFK: %s')
            :format(citizenid, tostring(isAFK)))
    end
end)

function GRP.AFK.IsAFK(src)
    local player = exports.qbx_core:GetPlayer(src)

    if not player or not player.PlayerData then
        return false
    end

    local citizenid = player.PlayerData.citizenid

    return afkPlayers[src] == citizenid
end

AddEventHandler('playerDropped', function()
    afkPlayers[source] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    afkPlayers[src] = nil
end)
