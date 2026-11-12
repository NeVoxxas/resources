local zones = {}
local activeDutyId = nil

RegisterNetEvent('grp_jobs:client:dutyState', function(working, jobId)
    if working then
        activeDutyId = jobId
    else
        activeDutyId = nil
    end
end)

CreateThread(function()
    for jobId, cfg in pairs(Config.Jobs) do
        local id = jobId -- atskira lokali reikšmė kiekvienai callback funkcijai

        if cfg.employment and cfg.employment.type == 'public'
            and cfg.employment.coords then
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

        if cfg.duty and cfg.duty.coords then
            zones[#zones + 1] = exports.ox_target:addSphereZone({
                coords = cfg.duty.coords,
                radius = cfg.duty.distance or 2.0,
                debug = Config.Debug,
                options = {
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
                    },
                    {
                        name = 'grp_jobs_duty_end_' .. id,
                        icon = 'fa-solid fa-user-xmark',
                        label = 'Baigti pamainą: ' .. (cfg.label or id),
                        distance = cfg.duty.distance or 2.0,
                        canInteract = function()
                            return activeDutyId == id
                        end,
                        onSelect = function()
                            TriggerServerEvent('grp_jobs:server:setDuty', id, false)
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
