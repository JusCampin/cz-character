fx_version 'cerulean'
game 'gta5'

author 'CoreZ Team'
version '0.3.0'

shared_scripts {
    'configs/*.lua',
    'shared/locale.lua',
    'languages/*.lua'
}

client_scripts {
    'client/spawn.lua',
    'client/main.lua'
}
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
