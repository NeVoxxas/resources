GRPJobs = GRPJobs or {}
GRPJobs.Employment = GRPJobs.Employment or {}

function GRPJobs.Employment.CanJoinJob(src, jobId)
    if type(jobId) ~= 'string' then
        return false, 'Neteisingas darbo ID.'
    end

    local cfg = Config.Jobs[jobId]
    local joinType = cfg and cfg.employment and cfg.employment.type
    if joinType ~= 'public' and joinType ~= 'invite' then
        return false, 'Šiame darbe įsidarbinti šiuo būdu negalima.'
    end

    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData then
        return false, 'Veikėjas nerastas.'
    end

    local current = player.PlayerData.job
    local req = cfg.requirements or {}
    if req.unemployed ~= false and (not current or current.name ~= 'unemployed') then
        return false, 'Pirmiausia turi būti bedarbis.'
    end

    -- Darbai su pakvietimu: reikia pakvietimo (direktorius ir pavaduotojas XP reikalavimo neturi)
    local isStaff = false
    if joinType == 'invite' then
        local ok, inviteMessage, staff = GRPJobs.Management.CheckInviteAccess(src, jobId)
        if not ok then return false, inviteMessage end
        isStaff = staff == true
    end

    local requiredXP = req.minXP or 0
    if type(requiredXP) ~= 'number' or requiredXP < 0 then
        return false, 'Neteisinga darbo XP konfigūracija.'
    end

    if not isStaff then
        local xp = exports.grp_core:GetPlayerXP(src)
        if type(xp) ~= 'number' then
            return false, 'Nepavyko gauti XP.'
        end
        if xp < requiredXP then
            return false, ('Trūksta %d XP.'):format(requiredXP - xp)
        end
    end

    if type(cfg.jobName) ~= 'string' or not exports.qbx_core:GetJob(cfg.jobName) then
        return false, 'Darbas neregistruotas Qbox.'
    end

    return true, 'Gali įsidarbinti.'
end

function GRPJobs.Employment.JoinJob(src, jobId)
    local allowed, message = GRPJobs.Employment.CanJoinJob(src, jobId)
    if not allowed then return false, message end

    local cfg = Config.Jobs[jobId]
    local success = exports.qbx_core:SetJob(src, cfg.jobName, cfg.grade or 0)
    if not success then
        return false, 'Nepavyko suteikti darbo.'
    end

    if cfg.employment.type == 'invite' then
        GRPJobs.Management.OnJoined(src, jobId)
    end

    if Config.Debug then
        print(('[GRP JOBS] %d įsidarbino: %s'):format(src, jobId))
    end
    return true, ('Sėkmingai įsidarbinai: %s'):format(cfg.label or jobId)
end

function GRPJobs.Employment.LeaveJob(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.job then
        return false, 'Veikėjas nerastas.'
    end

    if player.PlayerData.job.name == 'unemployed' then
        return false, 'Jau esi bedarbis.'
    end

    -- Leidžiame palikti tik grp_jobs valdomus darbus.
    local managed = false
    for _, cfg in pairs(Config.Jobs) do
        if cfg.jobName == player.PlayerData.job.name then
            managed = true
            break
        end
    end
    if not managed then
        return false, 'Šį darbą reikia palikti jo darbovietėje.'
    end

    -- Jeigu pamaina aktyvi, išjungiame XP bonusą PRIEŠ keičiant darbą.
    if GRPJobs.Duty then GRPJobs.Duty.ForceEnd(src, true) end

    local success = exports.qbx_core:SetJob(src, 'unemployed', 0)
    if not success then
        return false, 'Nepavyko palikti darbo.'
    end

    TriggerClientEvent('grp_jobs:client:restoreClothes', src)
    return true, 'Sėkmingai palikai darbą.'
end
