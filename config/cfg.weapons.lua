-- Hexa Inventory source.
cfg = cfg or {}

cfg.weapons = {}

cfg.weapons.dualWield = true

cfg.weapons.drawOnUse = true

cfg.weapons.dualWieldInHand = true

cfg.weapons.dualWieldMode = 'item'

cfg.weapons.offhandHolster = {
    enabled = true,

    clothing = {
        male   = 'CLOTHING_ITEM_M_OFFHAND_000_TINT_004',
        female = 'CLOTHING_ITEM_F_OFFHAND_000_TINT_004',
    },

    clothingSlot = 0xF20B6B4A,
    upgrade      = 'UPGRADE_OFFHAND_HOLSTER',
    upgradeSlot  = 0x39E57B01,
}

cfg.weapons.categories = {
    sidearm  = { hands = 1, slot = 'sidearm', label = 'ปืนสั้น' },
    repeater = { hands = 2, slot = 'longarm', label = 'ไรเฟิลยิงซ้ำ' },
    rifle    = { hands = 2, slot = 'longarm', label = 'ไรเฟิล' },
    sniper   = { hands = 2, slot = 'longarm', label = 'ไรเฟิลระยะไกล' },
    shotgun  = { hands = 2, slot = 'longarm', label = 'ลูกซอง' },
    bow      = { hands = 2, slot = 'longarm', label = 'ธนู' },
    melee    = { hands = 1, slot = false,     label = 'อาวุธประชิด' },
    thrown   = { hands = 1, slot = false,     label = 'อาวุธขว้าง' },
    lasso    = { hands = 1, slot = false,     label = 'เชือก' },
    kit      = { hands = 2, slot = false,     label = 'อุปกรณ์' },
}

cfg.weapons.categoryOf = {

    ['weapon_repeater_carbine']    = 'repeater',
    ['weapon_repeater_winchester'] = 'repeater',
    ['weapon_repeater_henry']      = 'repeater',
    ['weapon_repeater_evans']      = 'repeater',

    ['weapon_repeater_lancaster']  = 'repeater',
    ['weapon_repeater_litchfield'] = 'repeater',

    ['weapon_rifle_boltaction']    = 'rifle',
    ['weapon_rifle_springfield']   = 'rifle',
    ['weapon_rifle_varmint']       = 'rifle',
    ['weapon_rifle_elephant']      = 'rifle',

    ['weapon_sniperrifle_rollingblock']        = 'sniper',
    ['weapon_sniperrifle_rollingblock_exotic'] = 'sniper',
    ['weapon_sniperrifle_carcano']             = 'sniper',

    ['weapon_shotgun_doublebarrel']        = 'shotgun',
    ['weapon_shotgun_doublebarrel_exotic'] = 'shotgun',
    ['weapon_shotgun_pump']                = 'shotgun',
    ['weapon_shotgun_semiauto']            = 'shotgun',
    ['weapon_shotgun_repeating']           = 'shotgun',

    ['weapon_bow']          = 'bow',
    ['weapon_bow_improved'] = 'bow',

    ['weapon_shotgun_sawedoff'] = 'sidearm',
}

cfg.weapons.categoryByPrefix = {
    { 'weapon_revolver_',    'sidearm'  },
    { 'weapon_pistol_',      'sidearm'  },
    { 'weapon_repeater_',    'repeater' },
    { 'weapon_sniperrifle_', 'sniper'   },
    { 'weapon_rifle_',       'rifle'    },
    { 'weapon_shotgun_',     'shotgun'  },
    { 'weapon_bow',          'bow'      },
    { 'weapon_melee_',       'melee'    },
    { 'weapon_thrown_',      'thrown'   },
    { 'weapon_lasso',        'lasso'    },
    { 'weapon_kit_',         'kit'      },
}

cfg.weapons.slots = {
    { key = 'sidearm_right',    class = 'sidearm', attach = 2,     hand = 1, label = 'ซองขวา' },
    { key = 'sidearm_left',     class = 'sidearm', attach = 3,     hand = 0, label = 'ซองซ้าย' },
    { key = 'longarm_back',     class = 'longarm', attach = false,           label = 'สะพายหลัง' },
    { key = 'longarm_shoulder', class = 'longarm', attach = false,           label = 'สะพายบ่า' },
}

cfg.weapons.slotFullBehaviour = 'swap'

cfg.weapons.toggleCooldown = 150

cfg.weapons.action = {
    shortcut = {
        type = 'blacklist',
        list = {
            'GADGET_PARACHUTE',

        }
    },
    use = {
        type = 'blacklist',
        list = {
            'GADGET_PARACHUTE',

        }
    },
    drop = {
        type = 'whitelist',
        list = {

        }
    },
    give = {
        type = 'whitelist',
        list = {

        }
    },
    search = {
        type = 'whitelist',
        list = {

        }
    }
}

cfg.weapons.closeInventory = {
    use = {
        type = 'blacklist',
        list = {
            'GADGET_PARACHUTE',

        }
    },
    drop = {
        type = 'blacklist',
        list = {
            'GADGET_PARACHUTE',

        }
    }
}

cfg.weapons.noAmmo = {
	'GADGET_PARACHUTE',

	'WEAPON_DAGGER',
	'WEAPON_BAT',
	'WEAPON_BOTTLE',
	'WEAPON_CROWBAR',
	'WEAPON_FLASHLIGHT',
	'WEAPON_GOLFCLUB',
	'WEAPON_HAMMER',
	'WEAPON_HATCHET',
	'WEAPON_KNUCKLE',
	'WEAPON_KNIFE',
	'WEAPON_MACHETE',
	'WEAPON_SWITCHBLADE',
	'WEAPON_NIGHTSTICK',
	'WEAPON_WRENCH',
	'WEAPON_BATTLEAXE',
	'WEAPON_POOLCUE',
	'WEAPON_STONE_HATCHET',
	'WEAPON_CANDYCANE',

	'WEAPON_STUNGUN',
	'WEAPON_STUNGUN_MP',
}

cfg.weapons.animationMode = 'fast'
cfg.weapons.animationBlock = true
cfg.weapons.animations = {
	default = {
		put_in = {
			dict = 'reaction@intimidation@1h',
			anim = 'outro',
			flag = 50,
			action_on = 1800,
			duration = 1900
		},
		take_out = {
			dict = 'reaction@intimidation@1h',
			anim = 'intro',
			flag = 50,
			action_on = 800,
			duration = 2600
		}
	},
	customs = {
		['WEAPON_SWITCHBLADE'] = {
			put_in = {
				dict = 'anim@melee@switchblade@holster',
				anim = 'holster',
				flag = 50,
				action_on = 1400,
				duration = 1900
			},
			take_out = {
				dict = 'anim@melee@switchblade@holster',
				anim = 'unholster',
				flag = 50,
				action_on = 200,
				duration = 1500
			}
		},
	}
}
