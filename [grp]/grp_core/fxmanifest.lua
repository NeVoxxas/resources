fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'grp_core'
author 'Voxx - GRP Dev'
description 'LSVG GRP 5M'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua',
    'client/afk.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/duty.lua',
    'server/afk.lua',
    'server/progression.lua',
    'server/main.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql'
}