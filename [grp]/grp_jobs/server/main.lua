CreateThread(function()
    print('[GRP JOBS] Darbu sistema paleista!')
    print('[GRP JOBS] Autobuso vairuotojas: paruosiamas')
end)

local joinCooldown = {}
local dutyCooldown = {}
local pendingUniform = {}

local function GetManagedJob(jobName)
    if type(jobName) ~= 'string' then
        return nil
    end

    for jobId, jobConfig in pairs(Config.Jobs) do
        if jobConfig.jobName == jobName then
            return jobConfig, jobId
        end
    end

    return nil
end

RegisterNetEvent('grp_jobs:server:joinJob', function(jobId)
    local src = source

    -- Patikriname darbo ID
    if type(jobId) ~= 'string' then return end

    local jobConfig = Config.Jobs[jobId]
    if not jobConfig then return end

    -- Tikriname, ar darbas turi isidarbinimo vieta
    if not jobConfig.location then return end

    -- Apsauga nuo daznu uzklausu
    local now = GetGameTimer()

    if joinCooldown[src]
        and now - joinCooldown[src] < 2000 then
        return
    end

    joinCooldown[src] = now

    -- Gauname zaidejo pozicija
    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local maxDistance = jobConfig.serverDistance or 5.0

    -- Atstumo patikrinimas serverio puseje
    if #(coords - jobConfig.location) > maxDistance then
        print(('[GRP JOBS] Zaidejas %d bande isidarbinti per toli!')
            :format(src))
        return
    end

    -- Universali isidarbinimo funkcija
    local success, message =
        GRPJobs.Employment.JoinJob(src, jobId)

    TriggerClientEvent('ox_lib:notify', src, {
        title = jobConfig.label or 'Darbo sistema',
        description = message,
        type = success and 'success' or 'error'
    })
end)

AddEventHandler('playerDropped', function()
    joinCooldown[source] = nil
end)

RegisterNetEvent('grp_jobs:server:setBusDuty', function(working)
    local src = source
    local bus = Config.Jobs.bus

    if type(working) ~= 'boolean' then return end
    if pendingUniform[src] then return end

    local now = GetGameTimer()

    if dutyCooldown[src]
        and now - dutyCooldown[src] < 2000 then
        return
    end

    dutyCooldown[src] = now

    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData then return end

    if not player.PlayerData.job
        or player.PlayerData.job.name ~= bus.jobName then
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    if #(GetEntityCoords(ped) - bus.dutyLocation) > 5.0 then
        return
    end

    -- Baigiant pamaina XP bonusa isjungiame iskart
    if not working then
        exports.grp_core:SetWorking(src, false)
    end

    pendingUniform[src] = {
        working = working,
        citizenid = player.PlayerData.citizenid,
        expires = now + 10000
    }

    TriggerClientEvent(
        'grp_jobs:client:changeUniform',
        src,
        working
    )
end)


RegisterNetEvent('grp_jobs:server:uniformResult', function(working, success)
    local src = source
    local pending = pendingUniform[src]

    if not pending then return end
    pendingUniform[src] = nil

    if type(working) ~= 'boolean'
        or type(success) ~= 'boolean'
        or working ~= pending.working
        or GetGameTimer() > pending.expires then
        return
    end

    local player = exports.qbx_core:GetPlayer(src)

    if not player or not player.PlayerData then return end

    if player.PlayerData.citizenid ~= pending.citizenid then
        return
    end

    if not player.PlayerData.job
        or player.PlayerData.job.name ~= Config.Jobs.bus.jobName then
        return
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    if #(GetEntityCoords(ped) - Config.Jobs.bus.dutyLocation) > 5.0 then
        return
    end

    if not success then return end

    local changed = true

    if working then
        changed = exports.grp_core:SetWorking(src, true)
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Autobusu parkas',
        description = changed
            and (working and 'Pradejai darbo pamaina!'
                or 'Baigei darbo pamaina!')
            or 'Nepavyko pakeisti darbo busenos.',
        type = changed and 'success' or 'error'
    })
end)

-- -----------------------------------------------------
--                 COMMANDS
-- -----------------------------------------------------

RegisterCommand('paliktidarba', function(source)
    if source == 0 then return end

    local player = exports.qbx_core:GetPlayer(source)

    if not player or not player.PlayerData then
        return
    end

    local data = player.PlayerData
    local job = data.job

    if not job or job.name == 'unemployed' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Darbo sistema',
            description = 'Tu siuo metu neturi darbo!',
            type = 'error'
        })
        return
    end

    local oldJob = job.label or job.name

    -- Pakeiciame darba i bedarbi
    local success = exports.qbx_core:SetJob(
        source,
        'unemployed',
        0
    )

    if not success then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Darbo sistema',
            description = 'Nepavyko palikti darbo.',
            type = 'error'
        })
        return
    end

    TriggerClientEvent('grp_jobs:client:restoreClothes', source)

    -- Pranesimas zaidejui
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Darbo sistema',
        description = 'Sekmingai palikai darba: ' .. oldJob,
        type = 'success'
    })

    if Config.Debug then
        print(('[GRP JOBS] %s paliko darba: %s')
            :format(data.citizenid, oldJob))
    end
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    print('[GRP JOBS] Isjungiamos darbo pamainos...')

    local players = GetPlayers()

    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)

        if src then
            local player = exports.qbx_core:GetPlayer(src)

            if player and player.PlayerData then
                local job = player.PlayerData.job

                if job and GetManagedJob(job.name) then
                    local success = exports.grp_core:SetWorking(
                        src,
                        false
                    )

                    if Config.Debug then
                        print(('[GRP JOBS] Zaidejas %d | Pamaina isjungta: %s')
                            :format(src, tostring(success)))
                    end
                end
            end
        end
    end
end)

RegisterCommand('testjobduty', function(src)
    if src == 0 then return end

    if not IsPlayerAceAllowed(src, 'grp.admin') then
        return
    end

    local jobId =
        GRPJobs.Duty.GetPlayerJob(src)

    if not jobId then
        print('[GRP JOBS] Valdomas darbas nerastas.')
        return
    end

    local allowed, message =
        GRPJobs.Duty.CanChangeDuty(src, jobId)

    print(('[GRP JOBS] Darbas: %s | Leidziama: %s | %s')
        :format(jobId, tostring(allowed), message))
end, false)
