fx_version 'cerulean'
game 'gta5'

author 'JUST PVP'
description 'QBCore Discord VIP cars menu with boost coins'
version '3.0.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'data/cars.json'
}
