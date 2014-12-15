-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2014 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-- Nicolas Casalini "DarkGod"
-- darkgod@te4.org

---------------------------------------------------------
--                       Giants                         --
---------------------------------------------------------
newBirthDescriptor{
	type = "race",
	name = "Giant",
	locked = function() return profile.mod.allow_build.race_giant end,
	locked_desc = "WRITE ME",
	desc = {
		"WRITE ME",
	},
	descriptor_choices =
	{
		subrace =
		{
			Ogre = "allow",
			__ALL__ = "disallow",
		},
	},
	copy = {
		type = "giant", subtype="giant",
		starting_zone = "trollmire",
		starting_quest = "start-allied",
		resolvers.inventory{ id=true, {defined="ORB_SCRYING"} },
	},
}

---------------------------------------------------------
--                       Ogres                         --
---------------------------------------------------------
newBirthDescriptor
{
	type = "subrace",
	name = "Ogre",
	locked = function() return profile.mod.allow_build.race_ogre end,
	locked_desc = "WRITE ME",
	desc = {
		"WRITE ME",
		"They possess the #GOLD#Ogric Wrath#WHITE# talent which allows them a boost of speed every once in a while.",
		"#GOLD#Stat modifiers:",
		"#LIGHT_BLUE# * +3 Strength, -1 Dexterity, +0 Constitution",
		"#LIGHT_BLUE# * +2 Magic, -2 Willpower, +2 Cunning",
		"#GOLD#Life per level:#LIGHT_BLUE# 13",
		"#GOLD#Experience penalty:#LIGHT_BLUE# 30%",
	},
	moddable_attachement_spots = "race_ogre",
	inc_stats = { str=3, mag=2, wil=-2, cun=2, dex=1, con=0 },
	experience = 1.3,
	talents_types = { ["race/ogre"]={true, 0} },
	talents = { [ActorTalents.T_OGRE_WRATH]=1 },
	copy = {
		moddable_tile = "ogre_#sex#",
		random_name_def = "shalore_#sex#", random_name_max_syllables = 4,
		default_wilderness = {"playerpop", "shaloren"},
		starting_zone = "scintillating-caves",
		starting_quest = "start-shaloren",
		faction = "shalore",
		starting_intro = "ogre",
		life_rating = 13,
		size_category = 4,
		resolvers.inscription("RUNE:_SHIELDING", {cooldown=14, dur=5, power=100}),
		resolvers.inscription("RUNE:_PHASE_DOOR", {cooldown=7, range=10, dur=5, power=15}),
	},
	experience = 1.3,
	random_escort_possibilities = { {"tier1.1", 1, 2}, {"tier1.2", 1, 2}, {"daikara", 1, 2}, {"old-forest", 1, 4}, {"dreadfell", 1, 8}, {"reknor", 1, 2}, },
}
