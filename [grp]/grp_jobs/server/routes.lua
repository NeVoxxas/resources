GRPJobs = GRPJobs or {}
GRPJobs.Routes = {}

-- Maršrutai: žaidėjas sėdi darbo transporte (vairuotojo vietoje), pasirenka maršrutą,
-- stoja sustojimuose. Baigus maršrutą siūlomas kitas; atsisakius pamaina baigiama
-- ir transportas ištrinamas. Atlygis mokamas ne čia (žr. payroll.lua).

local state = {}   -- [src] = { jobId, routeId, index, lastAt, finished }

local MAX_STOP_SPEED = 5.0       -- serverio pusės greičio riba stovint sustojime (m/s)
local MIN_STOP_INTERVAL = 2000   -- ms tarp sustojimų patvirtinimų
local DISTANCE_TOLERANCE = 10.0  -- serverio papildomas atstumas virš sustojimo radius

local function Notify(src, message, kind)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Maršrutas',
        description = message,
        type = kind or 'inform'
    })
end

local function FindRoute(cfg, routeId)
    for _, route in ipairs(cfg.routes or {}) do
        if route.id == routeId then return route end
    end

    return nil
end

-- Žaidėjas privalo būti savo darbo transporto vairuotojo vietoje
local function DrivingJobVehicle(src)
    local rec = GRPJobs.Vehicles.Get(src)
    if not rec then return nil end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end

    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or veh ~= rec.entity then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end

    return veh
end

local function Clear(src, notifyClient)
    if not state[src] then return end

    state[src] = nil

    if notifyClient then
        TriggerClientEvent('grp_jobs:client:routeCleared', src)
    end
end

function GRPJobs.Routes.GetState(src)
    return state[src]
end

RegisterNetEvent('grp_jobs:server:selectRoute', function(jobId, routeId)
    local src = source

    if type(jobId) ~= 'string' or type(routeId) ~= 'string' then return end

    local cfg = Config.Jobs[jobId]
    if not cfg or not cfg.routes then return end

    if GRPJobs.Duty.GetActiveJob(src) ~= jobId then return end

    local route = FindRoute(cfg, routeId)
    if not route or #route.stops == 0 then return end

    if state[src] and not state[src].finished then
        Notify(src, 'Maršrutas jau vykdomas.', 'error')
        return
    end

    if not DrivingJobVehicle(src) then
        Notify(src, 'Maršrutą gali pasirinkti tik sėdėdamas darbo transporto vairuotojo vietoje.', 'error')
        return
    end

    state[src] = { jobId = jobId, routeId = routeId, index = 1, lastAt = 0, finished = false }

    TriggerClientEvent('grp_jobs:client:routeStarted', src, jobId, routeId, 1)
    Notify(src, ('Pasirinktas maršrutas: %s'):format(route.label or routeId), 'success')
end)

RegisterNetEvent('grp_jobs:server:arrivedStop', function(jobId, routeId, index)
    local src = source
    local s = state[src]

    if not s or s.finished then return end
    if s.jobId ~= jobId or s.routeId ~= routeId or s.index ~= index then return end

    local now = GetGameTimer()
    if now - s.lastAt < MIN_STOP_INTERVAL then return end

    local cfg = Config.Jobs[jobId]
    local route = cfg and FindRoute(cfg, routeId)
    local stop = route and route.stops[index]
    if not stop then return end

    local veh = DrivingJobVehicle(src)
    if not veh then return end

    if GetEntitySpeed(veh) > MAX_STOP_SPEED then return end

    local radius = (stop.radius or 10.0) + DISTANCE_TOLERANCE
    if not GRPJobs.IsPlayerNear(src, stop.coords, radius) then return end

    s.lastAt = now
    s.index = index + 1

    if s.index > #route.stops then
        s.finished = true
        TriggerClientEvent('grp_jobs:client:routeFinished', src, jobId)
        Notify(src, 'Maršrutas baigtas! Pasirink kitą arba baik pamainą.', 'success')
        return
    end

    TriggerClientEvent('grp_jobs:client:routeProgress', src, s.index)
end)

-- Žaidėjas atsisakė tęsti darbą po baigto maršruto: pamaina baigiama, transportas ištrinamas
RegisterNetEvent('grp_jobs:server:declineNextRoute', function(jobId)
    local src = source
    local s = state[src]

    if type(jobId) ~= 'string' or not s or not s.finished or s.jobId ~= jobId then return end
    if GRPJobs.Duty.GetActiveJob(src) ~= jobId then return end

    GRPJobs.Duty.ForceEnd(src, true)
    Notify(src, 'Pamaina baigta, transportas grąžintas.', 'inform')
end)

AddEventHandler('grp_jobs:dutyEnded', function(src)
    Clear(src, true)
end)

AddEventHandler('grp_jobs:vehicleRemoved', function(src)
    Clear(src, true)
end)

AddEventHandler('playerDropped', function()
    state[source] = nil
end)
