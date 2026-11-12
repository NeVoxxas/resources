
GRP.Duty = {}

local workingPlayers = {}

function GRP.Duty.SetWorking(source, working)
    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        return false
    end

    if type(working) ~= 'boolean' then
        return false
    end

    if working then
    local job = player.PlayerData.job

    if not job or not job.name
        or job.name == 'unemployed' then
        return false
    end

    workingPlayers[source] = {
        citizenid = player.PlayerData.citizenid,
        job = job.name
    }
    else
    workingPlayers[source] = nil
    end

    return true
end

function GRP.Duty.IsWorking(source)
    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        return false
    end

    local duty = workingPlayers[source]
    local data = player.PlayerData

    if not duty or not data.job then
    return false
    end

    return duty.citizenid == data.citizenid
    and duty.job == data.job.name
    and data.job.name ~= 'unemployed'
end

AddEventHandler('playerDropped', function()
    workingPlayers[source] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    workingPlayers[source] = nil
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    local duty = workingPlayers[source]

    if not duty then return end

    if not job or duty.job ~= job.name then
        workingPlayers[source] = nil

        if Config.Debug then
            print(('[GRP] Darbo rezimas isjungtas zaidejui %s')
                :format(source))
        end
    end
end)

-- -----------------------------------------------------
--                  EXPORTS
-- -----------------------------------------------------

exports('SetWorking', function(src, working)
    -- Kol kas tik grp_jobs gali valdyti darbo busena
    if GetInvokingResource() ~= 'grp_jobs' then
        return false
    end

    return GRP.Duty.SetWorking(src, working)
end)
