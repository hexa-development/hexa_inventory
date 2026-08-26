-- Hexa Inventory source.
fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

author 'Hexa Framework; based on RSG Inventory by Rexshack-RedM'
description 'Hexa Inventory - RedM inventory with RSG and VORP compatibility APIs'
version '3.0.0'

dependencies {
    'hexa_core',
    'oxmysql',
}

shared_scripts {
    'config/general.lua',
    'config/items.lua',
    'config/features.lua',
    'config/shops.lua',
    'shared/framework.lua',
    'shared/runtime.lua',
    'shared/helpers.lua',
    'shared/categories.lua',

    'config/cfg.weapons.lua',
    'shared/weapon_class.lua',
}

client_scripts {
    'client/drops/functions.lua',
    'client/functions.lua',
    'client/compat.lua',
    'client/commands.lua',
    'client/exports.lua',

    'client/dataview.lua',
    'client/weapon_items.lua',
    'client/weapons.lua',
    'client/events.lua',
    'client/drops/events.lua',
    'client/ui/events.lua',
    'client/ui/callbacks.lua',
    'client/ui/trade_events.lua',
    'client/ui/trade_callbacks.lua',
    'client/ui/trade_target.lua',
    'client/drops/ui/callbacks.lua',
    'client/main.lua',
    'client/drops/loops.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/functions.lua',
    'server/vault_store.lua',
    'server/drops/store.lua',
    'server/shops/functions.lua',
    'server/history.lua',
    'server/exports.lua',
    'server/compat/rsg.lua',
    'server/compat/vorp.lua',
    'server/shops/exports.lua',
    'server/weapon_slots.lua',
    'server/main.lua',
    'server/events/*.lua',
    'server/drops/events/*.lua',
    'server/shops/events/*.lua',
    'server/commands.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    'shared/*.lua',
    'locales/*.json',
    'html/images/*.png',
    'html/assets/*.*',
}
