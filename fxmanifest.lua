fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Rico Scripts'
description 'RS Banking with bank branches, secure PIN terminals and ATM transactions'
version '1.0.0'

rs_sql 'sql/rs-banking.sql'

ui_page 'web/index.html'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }
client_script 'client/main.lua'
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }

files { 'web/index.html', 'web/style.css', 'web/app.js' }

dependencies { 'es_extended', 'ox_lib', 'oxmysql', 'ox_target', 'rs-economie' }
