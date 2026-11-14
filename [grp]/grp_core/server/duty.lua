
GRP.Duty = {}

local workingPlayers = {}

-- options (nebūtina): { xpCategory = 'civilian', jobXP = 3 }
-- Kol žaidėjas dirba pamainoje, XP timeris kas minutę prideda jobXP
-- nurodytai darbo XP kategorijai (jei žaidėjas ne AFK).
function GRP.Duty.SetWorking(source, working, options)
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

        local xpCategory, jobXP = nil, 0

        if options ~= nil then
            if type(options) ~= 'table'
                or not GRP.Progression.IsValidCategory(options.xpCategory)
                or type(options.jobXP) ~= 'number'
                or options.jobXP < 0
                or options.jobXP % 1 ~= 0
                or options.jobXP > 1000 then
                return false
            end

            xpCategory = options.xpCategory
            jobXP = options.jobXP
        end

        workingPlayers[source] = {
            citizenid = player.PlayerData.citizenid,
            job = job.name,
            xpCategory = xpCategory,
            jobXP = jobXP
        }
    else
        workingPlayers[source] = nil
    end

    return true
end

-- Grąžina { xpCategory, jobXP } aktyvios pamainos žaidėjui, kitu atveju nil
function GRP.Duty.GetWorkingInfo(source)
    if not GRP.Duty.IsWorking(source) then
        return nil
    end

    local duty = workingPlayers[source]

    if not duty or not duty.xpCategory or duty.jobXP <= 0 then
        return nil
    end

    return {
        xpCategory = duty.xpCategory,
        jobXP = duty.jobXP
    }
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

exports('SetWorking', function(src, working, options)
    -- Kol kas tik grp_jobs gali valdyti darbo busena
    if GetInvokingResource() ~= 'grp_jobs' then
        return false
    end

    return GRP.Duty.SetWorking(src, working, options)
end)

-- Tik skaitymas: kitiems resursams (pvz. grp_jobs atlygio skaičiavimui)
exports('GetJobXP', function(src, category)
    return GRP.Progression.GetJobXP(src, category)
end)

exports('IsAFK', function(src)
    return GRP.AFK.IsAFK(src)
end)
