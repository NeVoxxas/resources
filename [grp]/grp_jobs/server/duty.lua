GRPJobs = GRPJobs or {}
GRPJobs.Duty = GRPJobs.Duty or {}

local active = {}          -- [src] = { citizenid, jobId }
local pending = {}         -- [src] = { citizenid, jobId, requestId, expires }
local cooldown = {}        -- [src] = game timer timestamp
local requestSeq = 0

local function Notify(src, message, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Darbo sistema',
        description = message,
        type = kind or 'inform'
    })
end

local function Identity(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData then return nil, nil end
    return player.PlayerData.citizenid, player.PlayerData.job
end

local function ClearPending(src, restore)
    pending[src] = nil
    if restore then
        TriggerClientEvent('grp_jobs:client:restoreClothes', src)
    end
end

local function ClearStale(src)
    local citizenid, job = Identity(src)
    local a = active[src]
    if a and (not citizenid or a.citizenid ~= citizenid or not job
        or Config.Jobs[a.jobId] == nil
        or job.name ~= Config.Jobs[a.jobId].jobName) then
        -- grp_core pats patikrina citizenid. Nepalikti aktyvaus seno src įrašo.
        exports.grp_core:SetWorking(src, false)
        active[src] = nil
        TriggerClientEvent('grp_jobs:client:restoreClothes', src)
    end
    local p = pending[src]
    if p and (not citizenid or p.citizenid ~= citizenid) then
        pending[src] = nil
    end
end

function GRPJobs.Duty.GetPlayerJob(src)
    local _, currentJob = Identity(src)
    if not currentJob or not currentJob.name then return nil, nil end

    for jobId, cfg in pairs(Config.Jobs) do
        if cfg.jobName == currentJob.name then
            return jobId, cfg
        end
    end
    return nil, nil
end

function GRPJobs.Duty.CanChangeDuty(src, jobId)
    if type(jobId) ~= 'string' then
        return false, 'Neteisingas darbo ID.'
    end
    local cfg = Config.Jobs[jobId]
    if not cfg or not cfg.duty or not cfg.duty.coords then
        return false, 'Pamainos vieta nenustatyta.'
    end

    local actualJobId = GRPJobs.Duty.GetPlayerJob(src)
    if actualJobId ~= jobId then
        return false, 'Tu nedirbi šiame darbe.'
    end

    local ped = GetPlayerPed(src)
    if ped == 0 then return false, 'Veikėjas nerastas.' end

    local distance = cfg.duty.serverDistance or 5.0
    if #(GetEntityCoords(ped) - cfg.duty.coords) > distance then
        return false, 'Esi per toli nuo persirengimo vietos.'
    end

    return true, 'Pamainos reikalavimai atitinka.'
end

function GRPJobs.Duty.IsActive(src)
    ClearStale(src)
    return active[src] ~= nil
end

-- restore: ar reikia siųsti komandą drabužių atkūrimui
function GRPJobs.Duty.ForceEnd(src, restore)
    local a = active[src]
    local p = pending[src]
    active[src] = nil
    pending[src] = nil
    cooldown[src] = nil

    if a then
        exports.grp_core:SetWorking(src, false)
    end

    if restore and (a or p) then
        TriggerClientEvent('grp_jobs:client:restoreClothes', src)
    end
    if a then
        TriggerClientEvent('grp_jobs:client:dutyState', src, false, a.jobId)
    end
end

function GRPJobs.Duty.SetDuty(src, jobId, working)
    if type(working) ~= 'boolean' then return false, 'Neteisingas veiksmas.' end
    ClearStale(src)

    if pending[src] then
        if GetGameTimer() >= pending[src].expires then
            ClearPending(src, true)
        else
            return false, 'Aprangos keitimas dar vyksta.'
        end
    end

    local allowed, message = GRPJobs.Duty.CanChangeDuty(src, jobId)
    if not allowed then return false, message end

    local now = GetGameTimer()
    if cooldown[src] and now - cooldown[src] < Config.DutyCooldownMs then
        return false, 'Palauk prieš keisdamas pamainą.'
    end
    cooldown[src] = now

    local citizenid = Identity(src)
    if not citizenid then return false, 'Veikėjas nerastas.' end

    if working then
        if active[src] then return false, 'Pamaina jau pradėta.' end

        local cfg = Config.Jobs[jobId]
        if not cfg.uniform then
            local success = exports.grp_core:SetWorking(src, true)
            if not success then return false, 'Nepavyko pradėti pamainos.' end
            active[src] = { citizenid = citizenid, jobId = jobId }
            TriggerClientEvent('grp_jobs:client:dutyState', src, true, jobId)
            return true, 'Pamaina pradėta.'
        end

        -- Uniformos rezultato laukiame tik tada, kai darbui jos reikia.
        requestSeq = requestSeq + 1
        local requestId = requestSeq
        pending[src] = {
            citizenid = citizenid,
            jobId = jobId,
            requestId = requestId,
            expires = now + Config.UniformTimeoutMs
        }
        TriggerClientEvent('grp_jobs:client:applyUniform', src, jobId, requestId)

        SetTimeout(Config.UniformTimeoutMs, function()
            local p = pending[src]
            if p and p.requestId == requestId then
                ClearPending(src, true)
                Notify(src, 'Nepavyko patvirtinti uniformos. Bandyk dar kartą.', 'error')
            end
        end)
        return true, nil -- Pradžia bus patvirtinta tik per uniformResult.
    end

    local a = active[src]
    if not a or a.jobId ~= jobId then
        return false, 'Aktyvios šio darbo pamainos nėra.'
    end

    GRPJobs.Duty.ForceEnd(src, true)
    return true, 'Pamaina baigta.'
end

RegisterNetEvent('grp_jobs:server:uniformResult', function(jobId, requestId, success)
    local src = source
    local p = pending[src]
    if not p or p.jobId ~= jobId or p.requestId ~= requestId then return end

    pending[src] = nil
    if GetGameTimer() >= p.expires or success ~= true then
        TriggerClientEvent('grp_jobs:client:restoreClothes', src)
        Notify(src, 'Nepavyko apsirengti darbo uniformos.', 'error')
        return
    end

    local citizenid = Identity(src)
    local allowed = GRPJobs.Duty.CanChangeDuty(src, jobId)
    if citizenid ~= p.citizenid or not allowed or active[src] then
        TriggerClientEvent('grp_jobs:client:restoreClothes', src)
        Notify(src, 'Pamainos pradėti nebegalima.', 'error')
        return
    end

    local started = exports.grp_core:SetWorking(src, true)
    if not started then
        TriggerClientEvent('grp_jobs:client:restoreClothes', src)
        Notify(src, 'Nepavyko pradėti pamainos.', 'error')
        return
    end

    active[src] = { citizenid = citizenid, jobId = jobId }
    TriggerClientEvent('grp_jobs:client:dutyState', src, true, jobId)
    Notify(src, 'Pamaina pradėta.', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    -- Neįspėjame atsijungusio kliento.
    GRPJobs.Duty.ForceEnd(src, false)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    GRPJobs.Duty.ForceEnd(src, false)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
    local a = active[src]
    local p = pending[src]
    if not a and not p then return end

    local record = a or p
    local cfg = Config.Jobs[record.jobId]
    if not job or not cfg or job.name ~= cfg.jobName then
        GRPJobs.Duty.ForceEnd(src, true)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(active) do
        GRPJobs.Duty.ForceEnd(src, false)
    end
    for src in pairs(pending) do
        pending[src] = nil
    end
end)
