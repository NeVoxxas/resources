local joinCooldown = {}

local function Notify(src, message, kind, title)
    TriggerClientEvent('ox_lib:notify', src, {
        title = title or 'Darbo sistema',
        description = message,
        type = kind or 'inform'
    })
end

RegisterNetEvent('grp_jobs:server:joinJob', function(jobId)
    local src = source
    if type(jobId) ~= 'string' then return end

    local cfg = Config.Jobs[jobId]
    if not cfg or not cfg.employment or cfg.employment.type ~= 'public'
        or not cfg.employment.coords then
        return
    end

    local now = GetGameTimer()
    if joinCooldown[src] and now - joinCooldown[src] < Config.JoinCooldownMs then
        return
    end
    joinCooldown[src] = now

    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    local maxDistance = cfg.employment.serverDistance or 5.0
    if #(GetEntityCoords(ped) - cfg.employment.coords) > maxDistance then
        if Config.Debug then
            print(('[GRP JOBS] %d bandė įsidarbinti per toli (%s)'):format(src, jobId))
        end
        return
    end

    local success, message = GRPJobs.Employment.JoinJob(src, jobId)
    Notify(src, message, success and 'success' or 'error', cfg.label)
end)

RegisterNetEvent('grp_jobs:server:setDuty', function(jobId, working)
    local src = source
    local success, message = GRPJobs.Duty.SetDuty(src, jobId, working)
    if message then
        local cfg = type(jobId) == 'string' and Config.Jobs[jobId] or nil
        Notify(src, message, success and 'success' or 'error', cfg and cfg.label)
    end
end)

RegisterCommand('paliktidarba', function(src)
    if src == 0 then return end
    local success, message = GRPJobs.Employment.LeaveJob(src)
    Notify(src, message, success and 'success' or 'error')
end, false)

AddEventHandler('playerDropped', function()
    joinCooldown[source] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    joinCooldown[src] = nil
end)

-- Pastaba: testinės komandos sąmoningai neperkeltos į produkcinę versiją.
