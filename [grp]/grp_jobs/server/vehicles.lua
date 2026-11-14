GRPJobs = GRPJobs or {}
GRPJobs.Vehicles = {}

-- Darbo transportas: gaunamas pamainos punkte (Gauti transportą), vienas žaidėjui.
-- Ištrinamas, kai pamaina baigiasi (grp_jobs:dutyEnded), žaidėjas išeina ar resursas sustoja.

local vehicles = {}   -- [src] = { entity, netId, jobId, model }
local spawning = {}
local lastRequest = {}

local function Notify(src, message, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Darbo transportas',
        description = message,
        type = kind or 'inform'
    })
end

local function Remove(src, notifyClient)
    local rec = vehicles[src]
    if not rec then return end

    vehicles[src] = nil

    if rec.entity and DoesEntityExist(rec.entity) then
        DeleteEntity(rec.entity)
    end

    if notifyClient then
        TriggerClientEvent('grp_jobs:client:vehicleState', src, false)
    end

    TriggerEvent('grp_jobs:vehicleRemoved', src)
end

-- Grąžina žaidėjo darbo transporto įrašą (arba nil). Dingusį transportą išvalo.
function GRPJobs.Vehicles.Get(src)
    local rec = vehicles[src]

    if rec and not DoesEntityExist(rec.entity) then
        Remove(src, true)
        Notify(src, 'Darbo transportas dingo. Gali gauti naują pamainos punkte.', 'error')
        return nil
    end

    return rec
end

-- Transportai, kuriuos šiuo metu gali gauti (pagal rangą)
lib.callback.register('grp_jobs:server:getVehicleOptions', function(src, jobId)
    if type(jobId) ~= 'string' then return nil end
    if GRPJobs.Duty.GetActiveJob(src) ~= jobId then return nil end

    local cfg = Config.Jobs[jobId]
    if not cfg or not cfg.vehicle then return nil end

    return GRPJobs.Management.GetAllowedVehicles(src, jobId)
end)

RegisterNetEvent('grp_jobs:server:getVehicle', function(jobId, model)
    local src = source

    if type(jobId) ~= 'string' or type(model) ~= 'string' then return end

    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < Config.VehicleCooldownMs then return end
    lastRequest[src] = now

    local cfg = Config.Jobs[jobId]
    if not cfg or not cfg.vehicle or not cfg.vehicle.spawn then return end

    if GRPJobs.Duty.GetActiveJob(src) ~= jobId then
        Notify(src, 'Pirmiausia pradėk pamainą.', 'error')
        return
    end

    local allowed, message = GRPJobs.Duty.CanChangeDuty(src, jobId)
    if not allowed then
        Notify(src, message, 'error')
        return
    end

    if GRPJobs.Vehicles.Get(src) then
        Notify(src, 'Jau turi darbo transportą.', 'error')
        return
    end

    if spawning[src] then return end

    local entry
    for _, candidate in ipairs(GRPJobs.Management.GetAllowedVehicles(src, jobId)) do
        if candidate.model == model then
            entry = candidate
            break
        end
    end

    if not entry then
        Notify(src, 'Šio transporto gauti negali.', 'error')
        return
    end

    spawning[src] = true

    local ped = GetPlayerPed(src)
    local ok, netId = pcall(qbx.spawnVehicle, {
        model = model,
        spawnSource = cfg.vehicle.spawn,
        warp = ped
    })

    spawning[src] = nil

    local veh = ok and netId and netId ~= 0 and NetworkGetEntityFromNetworkId(netId) or nil

    if not veh or veh == 0 or not DoesEntityExist(veh) then
        Notify(src, 'Nepavyko sukurti transporto.', 'error')
        return
    end

    -- Žaidėjas galėjo baigti pamainą ar išeiti, kol transportas kūrėsi
    if GRPJobs.Duty.GetActiveJob(src) ~= jobId then
        DeleteEntity(veh)
        return
    end

    SetVehicleNumberPlateText(veh, ('%s%04d'):format(cfg.vehicle.platePrefix or 'GRP', math.random(0, 9999)))

    pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, veh, true) end)
    pcall(function() Entity(veh).state:set('fuel', 100.0, true) end)

    vehicles[src] = { entity = veh, netId = netId, jobId = jobId, model = model }

    TriggerClientEvent('grp_jobs:client:vehicleState', src, true, netId, jobId)
    Notify(src, ('Gavai transportą: %s'):format(entry.label or model), 'success')
end)

-- Pamainai baigus transportas ištrinamas
AddEventHandler('grp_jobs:dutyEnded', function(src)
    Remove(src, true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    Remove(src, false)
    spawning[src] = nil
    lastRequest[src] = nil
end)

-- Sutvarkome transportą, kuris buvo sunaikintas ar ištrintas kito resurso
CreateThread(function()
    while true do
        Wait(5000)

        for src in pairs(vehicles) do
            GRPJobs.Vehicles.Get(src)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for src in pairs(vehicles) do
        Remove(src, false)
    end
end)
