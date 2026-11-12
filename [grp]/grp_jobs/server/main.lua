CreateThread(function()
    print('[GRP JOBS] Darbu sistema paleista!')
    print('[GRP JOBS] Autobuso vairuotojas: paruosiamas')
end)

local function CanJoinBusJob(source)
    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        return false, 'Veikejas nerastas.'
    end

    local data = player.PlayerData
    local bus = Config.Jobs.bus

    if not data.job or data.job.name ~= 'unemployed' then
        return false, 'Pirmiausia turi buti bedarbis.'
    end

    local xp = exports.grp_core:GetPlayerXP(source)

    if not xp then
        return false, 'Nepavyko gauti XP.'
    end

    if xp < bus.requiredXP then
        return false, ('Truksta %d XP.')
            :format(bus.requiredXP - xp)
    end

    if not exports.qbx_core:GetJob(bus.jobName) then
        return false, 'Qbox darbas nerastas.'
    end

    return true, 'Reikalavimai atitinka.'
end

RegisterNetEvent('grp_jobs:server:joinBusJob', function()
    local src = source
    local bus = Config.Jobs.bus

    -- Tikriname, ar zaidejas yra darbo vietoje
    local ped = GetPlayerPed(src)

    if ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local distance = #(coords - bus.location)

    if distance > bus.serverDistance then
        print(('[GRP JOBS] %s bande isidarbinti per toli!')
            :format(src))
        return
    end

    -- Patikriname XP ir dabartini darba
    local allowed, message = CanJoinBusJob(src)

    if not allowed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Autobusu parkas',
            description = message,
            type = 'error'
        })
        return
    end

    -- Suteikiame darba
    local success = exports.qbx_core:SetJob(
        src,
        bus.jobName,
        bus.grade
    )

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Autobusu parkas',
        description = success
            and 'Sekmingai isidarbinai autobuso vairuotoju!'
            or 'Nepavyko suteikti darbo.',
        type = success and 'success' or 'error'
    })
end)

RegisterCommand('testbusjob', function(source)
    if source == 0 then return end

    if not IsPlayerAceAllowed(source, 'grp.admin') then
        return
    end

    local allowed, message = CanJoinBusJob(source)

    print('[GRP JOBS] ' .. message)

    if not allowed then
        return
    end

    local bus = Config.Jobs.bus

    local success = exports.qbx_core:SetJob(
        source,
        bus.jobName,
        bus.grade
    )

    if success then
        print('[GRP JOBS] Autobuso vairuotojo darbas suteiktas!')
    else
        print('[GRP JOBS] Nepavyko suteikti darbo!')
    end
end, false)
