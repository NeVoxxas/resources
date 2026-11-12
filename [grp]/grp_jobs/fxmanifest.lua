
fx_version 'cerulean'
game 'gta5'

name 'grp_jobs'
author 'GRP Development'
description 'GRP - darbu sistema'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

server_scripts {
    'server/employment.lua',
    'server/duty.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua',
    'client/uniform.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'grp_core',
    'ox_target',
    'illenium-appearance'
}
