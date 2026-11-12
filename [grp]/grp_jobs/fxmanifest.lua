fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'GRP'
description 'Universali GRP darbu sistema (Qbox)'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/jobs/*.lua'
}

client_scripts {
    'client/uniform.lua',
    'client/main.lua'
}

server_scripts {
    'server/employment.lua',
    'server/duty.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'grp_core',
    'ox_lib',
    'ox_target',
    'illenium-appearance'
}
