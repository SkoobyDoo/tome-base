--- Return to @{engine.Birther.newBirthDescriptor}
newBirthDescriptor{
	type = "base",
	name = "base",
	desc = {
	},
	descriptor_choices =
	{
		world =
		{
			["Maj'Eyal"] = "allow",
			Infinite = "allow",
			Arena = "allow",
		},
		class =
		{
			-- Specific to some races
			None = "disallow",
		},
	},
	talents = {},
	experience = 1.0,
	body = { INVEN = 1000, QS_MAINHAND = 1, QS_OFFHAND = 1, MAINHAND = 1, OFFHAND = 1, FINGER = 2, NECK = 1, LITE = 1, BODY = 1, HEAD = 1, CLOAK = 1, HANDS = 1, BELT = 1, FEET = 1, TOOL = 1, QUIVER = 1, QS_QUIVER = 1 },

	copy = {
		-- Some basic stuff
		move_others = true,
		no_auto_resists = true, no_auto_saves = true,
		no_auto_high_stats = true,
		resists_cap = {all=70},
		keep_inven_on_death = true,
		can_change_level = true,
		can_change_zone = true,
		save_hotkeys = true,

		-- Mages are unheard of at first, nobody but them regenerates mana
		mana_rating = 6,
		mana_regen = 0,

		max_level = 50,
		money = 15,
		resolvers.equip{ id=true,
			{type="lite", subtype="lite", name="brass lantern", ignore_material_restriction=true, ego_chance=-1000},
		},
		make_tile = function(e)
			if not e.image then e.image = "player/"..e.descriptor.subrace:lower():gsub("[^a-z0-9_]", "_").."_"..e.descriptor.sex:lower():gsub("[^a-z0-9_]", "_")..".png" end
		end,
	},
	game_state = {
		force_town_respec = 1,
	}
}