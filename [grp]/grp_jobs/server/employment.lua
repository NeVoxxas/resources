GRPJobs = GRPJobs or {}
GRPJobs.Employment = GRPJobs.Employment or {}

function GRPJobs.Employment.CanJoinJob(src, jobId)
    local jobConfig = Config.Jobs[jobId]

    if not jobConfig then
        return false, 'Darbas neegzistuoja.'
    end

    local player = exports.qbx_core:GetPlayer(src)

    if not player or not player.PlayerData then
        return false, 'Veikejas nerastas.'
    end

    local data = player.PlayerData

    if not data.job or data.job.name ~= 'unemployed' then
        return false, 'Pirmiausia turi buti bedarbis.'
    end

    local xp = exports.grp_core:GetPlayerXP(src)

    if type(xp) ~= 'number' then
        return false, 'Nepavyko gauti XP.'
    end

    local requiredXP = jobConfig.requiredXP or 0

    if xp < requiredXP then
        return false, ('Truksta %d XP.')
            :format(requiredXP - xp)
    end

    if not jobConfig.jobName
        or not exports.qbx_core:GetJob(jobConfig.jobName) then
        return false, 'Darbas neregistruotas Qbox.'
    end

    return true, 'Reikalavimai atitinka.'
end

function GRPJobs.Employment.JoinJob(src, jobId)
    local allowed, message =
        GRPJobs.Employment.CanJoinJob(src, jobId)

    if not allowed then
        return false, message
    end

    local jobConfig = Config.Jobs[jobId]

    local success = exports.qbx_core:SetJob(
        src,
        jobConfig.jobName,
        jobConfig.grade or 0
    )

    if not success then
        return false, 'Nepavyko suteikti darbo.'
    end

    if Config.Debug then
        print(('[GRP JOBS] Zaidejas %d isidarbino: %s')
            :format(src, jobConfig.jobName))
    end

    return true, 'Sekmingai isidarbinai: ' .. jobConfig.label
end
