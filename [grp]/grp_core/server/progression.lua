
GRP.Progression = {}

local JobXPCategories = {
    law = 'law_xp',
    taxi = 'taxi_xp',
    medic = 'medic_xp',
    mechanic = 'mechanic_xp',
    trucking = 'trucking_xp',
    civilian = 'civilian_xp'
}

function GRP.Progression.AddXP(source, amount)
    if not source or source <= 0 then return false end

    if type(amount) ~= 'number'
        or amount <= 0
        or amount % 1 ~= 0
        or amount > 100000 then
        return false
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.PlayerData then
        return false
    end

    local citizenid = player.PlayerData.citizenid
    if not citizenid then return false end

    GRP.Database.LoadProgression(citizenid)

    local affected = MySQL.update.await([[
        UPDATE grp_progression
        SET xp = xp + ?
        WHERE citizenid = ?
    ]], { amount, citizenid })

    return affected == 1
end

function GRP.Progression.AddJobXP(source, category, amount)
    local column = JobXPCategories[category]

    if not column then return false end
    if not source or source <= 0 then return false end

    if type(amount) ~= 'number'
        or amount <= 0
        or amount % 1 ~= 0
        or amount > 100000 then
        return false
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.PlayerData then
        return false
    end

    local citizenid = player.PlayerData.citizenid
    if not citizenid then return false end

    GRP.Database.LoadJobXP(citizenid)

    local query = ('UPDATE grp_job_xp SET %s = %s + ? WHERE citizenid = ?')
        :format(column, column)

    local affected = MySQL.update.await(query, {
        amount,
        citizenid
    })

    return affected == 1
end

function GRP.Progression.AddPlaytime(citizenid, minutes)
    if type(citizenid) ~= 'string' or citizenid == '' then
        return false
    end

    if type(minutes) ~= 'number'
        or minutes < 1
        or minutes % 1 ~= 0 then
        return false
    end

    local progression = GRP.Database.LoadProgression(citizenid)

    if not progression then
        return false
    end

    local affected = MySQL.update.await([[
        UPDATE grp_progression
        SET playtime = playtime + ?
        WHERE citizenid = ?
    ]], { minutes, citizenid })

    return affected == 1
end

CreateThread(function()
    while true do
        Wait(60000)

        local players = exports.qbx_core:GetQBPlayers()

        for _, player in pairs(players) do
            local data = player.PlayerData

            if data and data.citizenid then
                local success = GRP.Progression.AddPlaytime(
                    data.citizenid,
                    1
                )

                if Config.Debug and success then
                    print(('[GRP] +1 zaidimo minute: %s')
                        :format(data.citizenid))
                end
            end
        end
    end
end)
