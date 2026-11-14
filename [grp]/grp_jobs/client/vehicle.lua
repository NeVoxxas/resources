-- Darbo transportas ir maršrutai (kliento pusė).
-- Visą logiką tikrina serveris (server/vehicles.lua, server/routes.lua); čia tik sąsaja.

GRPClient = GRPClient or {}
GRPClient.hasVehicle = false

local vehicleNetId = nil
local vehicleJobId = nil
local route = nil            -- { jobId, routeId, index, stops, blip, waiting, waitingSince }
local menuOpen = false
local offerRoute = false     -- ar reikia pasiūlyti maršrutą, kai žaidėjas atsisės

local function Notify(message, kind)
    lib.notify({ title = 'Darbo sistema', description = message, type = kind or 'inform' })
end

local function GetJobVehicle()
    if not vehicleNetId or not NetworkDoesNetworkIdExist(vehicleNetId) then return 0 end

    local entity = NetworkGetEntityFromNetworkId(vehicleNetId)

    if not entity or entity == 0 or not DoesEntityExist(entity) then return 0 end

    return entity
end

local function IsDriving()
    local veh = GetJobVehicle()
    if veh == 0 then return false end

    local ped = PlayerPedId()

    return GetVehiclePedIsIn(ped, false) == veh and GetPedInVehicleSeat(veh, -1) == ped
end

-- -----------------------------------------------------
--                 GAUTI TRANSPORTĄ
-- -----------------------------------------------------

function GRPClient.RequestVehicle(jobId)
    local options = lib.callback.await('grp_jobs:server:getVehicleOptions', false, jobId)

    if not options or #options == 0 then
        Notify('Šiuo metu transporto gauti negali.', 'error')
        return
    end

    if #options == 1 then
        TriggerServerEvent('grp_jobs:server:getVehicle', jobId, options[1].model)
        return
    end

    local menu = {}

    for _, entry in ipairs(options) do
        menu[#menu + 1] = {
            title = entry.label or entry.model,
            icon = 'fa-solid fa-bus',
            onSelect = function()
                TriggerServerEvent('grp_jobs:server:getVehicle', jobId, entry.model)
            end
        }
    end

    lib.registerContext({ id = 'grp_jobs_vehicle_menu', title = 'Pasirink transportą', options = menu })
    lib.showContext('grp_jobs_vehicle_menu')
end

RegisterNetEvent('grp_jobs:client:vehicleState', function(has, netId, jobId)
    GRPClient.hasVehicle = has == true
    vehicleNetId = has and netId or nil
    vehicleJobId = has and jobId or nil
    offerRoute = has == true
end)

-- -----------------------------------------------------
--                 MARŠRUTAI
-- -----------------------------------------------------

local function ClearBlip()
    if route and route.blip and DoesBlipExist(route.blip) then
        RemoveBlip(route.blip)
    end

    if route then route.blip = nil end
end

local function PlaceBlip()
    ClearBlip()

    if not route then return end

    local stop = route.stops[route.index]
    if not stop then return end

    local blip = AddBlipForCoord(stop.coords.x, stop.coords.y, stop.coords.z)

    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 5)
    SetBlipRoute(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Sustojimas %d/%d'):format(route.index, #route.stops))
    EndTextCommandSetBlipName(blip)

    route.blip = blip
end

local function ClearRoute()
    ClearBlip()
    route = nil
end

local function ShowRouteMenu(jobId, finished)
    local cfg = Config.Jobs[jobId]

    if not cfg or not cfg.routes or menuOpen then return end

    local options = {}

    for _, entry in ipairs(cfg.routes) do
        options[#options + 1] = {
            title = entry.label or entry.id,
            description = ('Sustojimų: %d'):format(#entry.stops),
            icon = 'fa-solid fa-route',
            onSelect = function()
                TriggerServerEvent('grp_jobs:server:selectRoute', jobId, entry.id)
            end
        }
    end

    if finished then
        options[#options + 1] = {
            title = 'Baigti pamainą',
            description = 'Pamaina baigiama, o transportas grąžinamas.',
            icon = 'fa-solid fa-door-open',
            onSelect = function()
                TriggerServerEvent('grp_jobs:server:declineNextRoute', jobId)
            end
        }
    end

    menuOpen = true

    lib.registerContext({
        id = 'grp_jobs_route_menu',
        title = finished and 'Maršrutas baigtas. Kas toliau?' or 'Pasirink maršrutą',
        options = options,
        onExit = function() menuOpen = false end
    })

    lib.showContext('grp_jobs_route_menu')
end

RegisterNetEvent('grp_jobs:client:routeStarted', function(jobId, routeId, index)
    menuOpen = false

    local cfg = Config.Jobs[jobId]
    local def

    for _, entry in ipairs(cfg and cfg.routes or {}) do
        if entry.id == routeId then def = entry break end
    end

    if not def then return end

    ClearRoute()
    route = { jobId = jobId, routeId = routeId, index = index, stops = def.stops, waiting = false }
    PlaceBlip()
end)

RegisterNetEvent('grp_jobs:client:routeProgress', function(index)
    if not route then return end

    route.index = index
    route.waiting = false
    PlaceBlip()
    Notify(('Kitas sustojimas: %d/%d'):format(index, #route.stops))
end)

RegisterNetEvent('grp_jobs:client:routeFinished', function(jobId)
    ClearRoute()
    menuOpen = false
    ShowRouteMenu(jobId, true)
end)

RegisterNetEvent('grp_jobs:client:routeCleared', function()
    ClearRoute()
end)

-- Pasiūlo maršrutą, kai žaidėjas atsisėda į savo darbo transportą be aktyvaus maršruto
CreateThread(function()
    local wasDriving = false

    while true do
        Wait(1000)

        -- Meniu galėjo užsidaryti pasirinkus veiksmą ar ESC
        if menuOpen and not lib.getOpenContextMenu() then
            menuOpen = false
        end

        local driving = GRPClient.hasVehicle and IsDriving()

        if driving and not wasDriving then
            offerRoute = true
        end

        wasDriving = driving

        if driving and offerRoute and not route and not menuOpen then
            offerRoute = false
            ShowRouteMenu(vehicleJobId, false)
        end
    end
end)

-- Žymeklis ir atvykimo tikrinimas
CreateThread(function()
    while true do
        local sleep = 500

        if route then
            local stop = route.stops[route.index]
            local radius = stop.radius or 10.0
            local distance = #(GetEntityCoords(PlayerPedId()) - stop.coords)

            if distance < 80.0 then
                sleep = 0

                DrawMarker(1, stop.coords.x, stop.coords.y, stop.coords.z - 1.0,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, radius * 2, radius * 2, 1.5,
                    255, 200, 0, 120, false, false, 2, false, nil, nil, false)
            end

            if route.waiting then
                if GetGameTimer() - route.waitingSince > 5000 then
                    route.waiting = false
                end
            elseif distance <= radius and IsDriving() and GetEntitySpeed(GetJobVehicle()) < 2.0 then
                route.waiting = true
                route.waitingSince = GetGameTimer()

                TriggerServerEvent('grp_jobs:server:arrivedStop', route.jobId, route.routeId, route.index)
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    ClearBlip()
end)
