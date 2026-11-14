GRPClient = GRPClient or {}

local zones = {}
local activeDutyId = nil

RegisterNetEvent('grp_jobs:client:dutyState', function(working, jobId)
    if working then
        activeDutyId = jobId
    else
        activeDutyId = nil
        GRPClient.hasVehicle = false
    end
end)

CreateThread(function()
    for jobId, cfg in pairs(Config.Jobs) do
        local id = jobId -- atskira lokali reikšmė kiekvienai callback funkcijai
        local joinType = cfg.employment and cfg.employment.type

        -- Įsidarbinimo taškas (atviriems ir pakvietimo darbams)
        if (joinType == 'public' or joinType == 'invite') and cfg.employment.coords then
            zones[#zones + 1] = exports.ox_target:addSphereZone({
                coords = cfg.employment.coords,
                radius = cfg.employment.distance or 2.0,
                debug = Config.Debug,
                options = {
                    {
                        name = 'grp_jobs_employment_' .. id,
                        icon = 'fa-solid fa-briefcase',
                        label = 'Įsidarbinti: ' .. (cfg.label or id),
                        distance = cfg.employment.distance or 2.0,
                        onSelect = function()
                            TriggerServerEvent('grp_jobs:server:joinJob', id)
                        end
                    }
                }
            })
        end

        -- Pamainos punktas: Pradėti pamainą -> Gauti transportą / Baigti pamainą
        if cfg.duty and cfg.duty.coords then
            local options = {
                {
                    name = 'grp_jobs_duty_start_' .. id,
                    icon = 'fa-solid fa-user-check',
                    label = 'Pradėti pamainą: ' .. (cfg.label or id),
                    distance = cfg.duty.distance or 2.0,
                    canInteract = function()
                        return activeDutyId == nil
                    end,
                    onSelect = function()
                        TriggerServerEvent('grp_jobs:server:setDuty', id, true)
                    end
                }
            }

            if cfg.vehicle then
                options[#options + 1] = {
                    name = 'grp_jobs_duty_vehicle_' .. id,
                    icon = 'fa-solid fa-bus',
                    label = 'Gauti transportą',
                    distance = cfg.duty.distance or 2.0,
                    canInteract = function()
                        return activeDutyId == id and not GRPClient.hasVehicle
                    end,
                    onSelect = function()
                        GRPClient.RequestVehicle(id)
                    end
                }
            end

            options[#options + 1] = {
                name = 'grp_jobs_duty_end_' .. id,
                icon = 'fa-solid fa-user-xmark',
                label = 'Baigti pamainą',
                distance = cfg.duty.distance or 2.0,
                canInteract = function()
                    return activeDutyId == id
                end,
                onSelect = function()
                    TriggerServerEvent('grp_jobs:server:setDuty', id, false)
                end
            }

            zones[#zones + 1] = exports.ox_target:addSphereZone({
                coords = cfg.duty.coords,
                radius = cfg.duty.distance or 2.0,
                debug = Config.Debug,
                options = options
            })
        end

        -- Vadovo taškas (tik darbams su pakvietimu; matomas to darbo darbuotojams)
        if joinType == 'invite' and cfg.management and cfg.management.coords then
            zones[#zones + 1] = exports.ox_target:addSphereZone({
                coords = cfg.management.coords,
                radius = cfg.management.distance or 2.0,
                debug = Config.Debug,
                options = {
                    {
                        name = 'grp_jobs_management_' .. id,
                        icon = 'fa-solid fa-clipboard-user',
                        label = 'Vadovo valdymas',
                        distance = cfg.management.distance or 2.0,
                        groups = cfg.jobName,
                        onSelect = function()
                            GRPClient.OpenManagement(id)
                        end
                    }
                }
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, zoneId in ipairs(zones) do
        exports.ox_target:removeZone(zoneId)
    end
end)
