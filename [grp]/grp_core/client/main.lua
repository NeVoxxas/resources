
CreateThread(function()
    print('[GRP] Kliento modulis paleistas!')
end)

RegisterNetEvent('grp_core:client:showInfo', function(message)
    print('[GRP DEBUG] Klientas gavo informacija!')

    lib.notify({
        title = 'GRP - Zaidejo informacija',
        description = table.concat(message, '\n'),
        type = 'inform',
        duration = 10000,
        position = 'top-right'
    })
end)
