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
                        'grp_jobs:server:joinBusJob'
                    )
                end
            }
        }
    })
end)
