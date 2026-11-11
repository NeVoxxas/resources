
CreateThread(function()
    print('[GRP] Kliento modulis paleistas!')
end)

RegisterNetEvent('grp_core:client:showInfo', function(data)
    local dutyStatus = data.working and 'Dirba' or 'Nedirba'

    lib.registerContext({
        id = 'grp_info_menu',
        title = 'GRP - Zaidejo informacija',
        options = {
            {
                title = data.name,
                description = 'Zaidejo ID: ' .. data.id,
                icon = 'user'
            },
            {
                title = 'Bendras XP',
                description = tostring(data.xp) .. ' XP',
                icon = 'star'
            },
            {
                title = 'Zaidimo laikas',
                description = data.hours .. ' val. ' ..
                    data.minutes .. ' min.',
                icon = 'clock'
            },
            {
                title = 'Darbas',
                description = data.job,
                icon = 'briefcase'
            },
            {
                title = 'Darbo busena',
                description = dutyStatus,
                icon = 'user-check'
            },
            {
                title = 'Grynieji pinigai',
                description = '$' .. data.cash,
                icon = 'wallet'
            },
            {
                title = 'Banko saskaita',
                description = '$' .. data.bank,
                icon = 'building-columns'
            }
        }
    })

    lib.showContext('grp_info_menu')
end)
