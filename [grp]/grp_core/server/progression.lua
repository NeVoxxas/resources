
GRP.Progression = {}

local JobXPCategories = {
    law = 'law_xp',
    taxi = 'taxi_xp',
    medic = 'medic_xp',
    mechanic = 'mechanic_xp',
    trucking = 'trucking_xp',
    civilian = 'civilian_xp'
}

function GRP.Progression.IsValidCategory(category)
    return type(category) == 'string' and JobXPCategories[category] ~= nil
end

-- Grąžina žaidėjo darbo XP nurodytoje kategorijoje (arba nil)
function GRP.Progression.GetJobXP(source, category)
    local column = JobXPCategories[category]
    if not column then return nil end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.PlayerData then return nil end

    local citizenid = player.PlayerData.citizenid
    if not citizenid then return nil end

    local row = GRP.Database.LoadJobXP(citizenid)
    if not row then return nil end

    return tonumber(row[column])
end

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

function GRP.Progression.RewardMinute(citizenid, amount)
    if type(citizenid) ~= 'string' or citizenid == '' then
        return false
    end

    if type(amount) ~= 'number'
        or amount < 0
        or amount % 1 ~= 0
        or amount > 100 then
        return false
    end

    local affected = MySQL.update.await([[
        UPDATE grp_progression
        SET
            xp = xp + ?,
            playtime = playtime + 1
        WHERE citizenid = ?
          AND xp <= 4294967295 - ?
          AND playtime < 4294967295
    ]], { amount, citizenid, amount })

    return affected == 1
end

CreateThread(function()
    while true do
        Wait(Config.XP.Interval)

        local players = exports.qbx_core:GetQBPlayers()

        for _, player in pairs(players) do
            local data = player.PlayerData

            if data and data.citizenid then
                local citizenid = data.citizenid


                local src = data.source
                local amount = Config.XP.Normal

                -- Patikriname darbo rezima
                if GRP.Duty.IsWorking(src) then
                    amount = Config.XP.Working
                end

                -- AFK zaidejas negauna XP
                if Config.AFK.Enabled and GRP.AFK.IsAFK(src) then
                    amount = 0
                end

                local progression = GRP.Database.LoadProgression(citizenid)

                if progression then
                    local success = GRP.Progression.RewardMinute(
                        citizenid,
                        amount
                    )

                    if Config.Debug then
                        print(('[GRP] %s: +%d XP, +1 minute. Sekme: %s')
                            :format(
                                citizenid,
                                amount,
                                tostring(success)
                            ))
                    end

                    -- Darbo XP už pamainos minutę (AFK žaidėjas negauna)
                    if success and amount > 0 then
                        local info = GRP.Duty.GetWorkingInfo(src)

                        if info then
                            local jobSuccess = GRP.Progression.AddJobXP(
                                src,
                                info.xpCategory,
                                info.jobXP
                            )

                            if Config.Debug then
                                print(('[GRP] %s: +%d %s XP. Sekme: %s')
                                    :format(
                                        citizenid,
                                        info.jobXP,
                                        info.xpCategory,
                                        tostring(jobSuccess)
                                    ))
                            end
                        end
                    end
                end
            end
        end
    end
end)