--load("/data/general/npcs/sandworm.lua")

local Talents = require("engine.interface.ActorTalents")

-- They make the tunnels, temporarily
-- High life to not kill them by accident
newEntity{ define_as = "SANDWORM_TUNNELER",
	type = "vermin", subtype = "sandworm",
	name = "sandworm tunneler",
	display = "w", color=colors.GREEN,
	desc = [[This sandworm seems to not care about your presence at all and simply continues digging its way through the sand.
	Maybe following it is the only way to move around here...]],
	level_range = {12, 18}, exp_worth = 2,
	max_life = 500,
	energy = {mod=0.5},

	autolevel = "warrior",
	ai = "sandworm_tunneler", ai_state = {},
}

-- The boss of trollshaws, no "rarity" field means it will not be randomly generated
newEntity{ define_as = "SANDWORM_QUEEN",
	type = "vermin", subtype = "sandworm", unique = true,
	name = "Sandworm Queen",
	display = "w", color=colors.VIOLET,
	desc = [[]],
	level_range = {12, 18}, exp_worth = 2,
	max_life = 200, life_rating = 17, fixed_rating = true,
	max_stamina = 85,
	max_mana = 200,
	stats = { str=25, dex=10, cun=8, mag=20, wil=20, con=20 },

	resists = { [DamageType.FIRE] = -50 },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1 },
	equipment = resolvers.equip{ {type="armor", subtype="shield", defined="OLD_MAN_WILLOW_SHIELD"}, },
	drops = resolvers.drops{chance=100, nb=5, {ego_chance=100} },

	talents = resolvers.talents{
		[Talents.T_STAMINA_POOL]=1, [Talents.T_STUN]=2,

		[Talents.T_MANA_POOL]=1,
		[Talents.T_ICE_STORM]=1,
		[Talents.T_TIDAL_WAVE]=1,
		[Talents.T_FREEZE]=2,
	},

	autolevel = "caster",
	ai = "dumb_talented_simple", ai_state = { talent_in=3, },
}
