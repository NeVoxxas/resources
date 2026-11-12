CreateThread(function()
    print('[GRP JOBS] Kliento modulis paleistas!')
end)

CreateThread(function()
    local bus = Config.Jobs.bus

    exports.ox_target:addSphereZone({
        coords = bus.location,
        radius = 1.5,
        debug = Config.Debug,

        options = {
            {
                name = 'grp_bus_employment',
                icon = 'fa-solid fa-bus',
                label = 'Isidarbinti autobuso vairuotoju',
                distance = bus.interactionDistance,

                onSelect = function()
                    TriggerServerEvent(
                        'grp_jobs:server:joinJob',
                        'bus'
                    )
                end
            }
        }
    })
end)

CreateThread(function()
    local bus = Config.Jobs.bus

    exports.ox_target:addSphereZone({
        name = 'grp_bus_duty',
        coords = bus.dutyLocation,
        radius = 1.2,
        debug = Config.Debug,

        options = {
            {
                name = 'grp_bus_start_duty',
                icon = 'fa-solid fa-shirt',
                label = 'Pradeti darbo pamaina',
                distance = bus.dutyDistance,

                onSelect = function()
                    TriggerServerEvent(
                        'grp_jobs:server:setBusDuty',
                        true
                    )
                end
            },
            {
                name = 'grp_bus_end_duty',
                icon = 'fa-solid fa-door-open',
                label = 'Baigti darbo pamaina',
                distance = bus.dutyDistance,

                onSelect = function()
                    TriggerServerEvent(
                        'grp_jobs:server:setBusDuty',
                        false
                    )
                end
            }
        }
    })
end)
