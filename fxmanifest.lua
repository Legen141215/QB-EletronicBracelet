fx_version 'cerulean'
game 'gta5'

author 'Legen'
description 'Eletronic Bracelet for QBCore'
version '1.0.0'

dependencies {
    'qb-core',
    'oxmysql'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

client_scripts {
    'config.lua',
    'client.lua'
}

shared_scripts {
    'config.lua'
}