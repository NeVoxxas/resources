fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'GRP'
description 'Universali GRP darbu sistema (Qbox)'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/config.lua',
    'shared/jobs/*.lua'
}

client_scripts {
    'client/uniform.lua',
    'client/vehicle.lua',
    'client/management.lua',
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/employment.lua',
    'server/duty.lua',
    'server/management.lua',
    'server/vehicles.lua',
    'server/routes.lua',
    'server/payroll.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'grp_core',
    'ox_lib',
    'ox_target',
    'oxmysql',
    'illenium-appearance'
}
