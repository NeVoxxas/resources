
GRPJobs = GRPJobs or {}
GRPJobs.Duty = GRPJobs.Duty or {}

function GRPJobs.Duty.GetPlayerJob(src)
    local player = exports.qbx_core:GetPlayer(src)

    if not player or not player.PlayerData then
        return nil, nil
    end

    local currentJob = player.PlayerData.job

    if not currentJob or not currentJob.name then
        return nil, nil
    end

    for jobId, jobConfig in pairs(Config.Jobs) do
        if jobConfig.jobName == currentJob.name then
            return jobId, jobConfig
        end
    end

    return nil, nil
end

function GRPJobs.Duty.CanChangeDuty(src, jobId)
    if type(jobId) ~= 'string' then
        return false, 'Neteisingas darbo ID.'
    end

    local jobConfig = Config.Jobs[jobId]

    if not jobConfig then
        return false, 'Darbas neegzistuoja.'
    end

    local playerJobId =
        GRPJobs.Duty.GetPlayerJob(src)

    if playerJobId ~= jobId then
        return false, 'Tu nedirbi siame darbe.'
    end

    if not jobConfig.dutyLocation then
        return false, 'Pamainos vieta nenustatyta.'
    end

    local ped = GetPlayerPed(src)

    if ped == 0 then
        return false, 'Veikejas nerastas.'
    end

    local coords = GetEntityCoords(ped)

    local maxDistance =
        jobConfig.dutyServerDistance or 5.0

    if #(coords - jobConfig.dutyLocation) > maxDistance then
        return false, 'Esi per toli nuo persirengimo vietos.'
    end

    return true, 'Pamainos reikalavimai atitinka.'
end
