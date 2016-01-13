-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

newBirthDescriptor{
	type = "world",
	name = "A Twist of Fate",
	display_name = "A Twist of Fate",
	desc =
	{
		"All of time and space are in danger: A dangerous anomaly threatens to destroy reality!",
		"The Keepers of Reality are working hard to stave off the coming Temporal Ekpyrosis.",
		"But will you be the one to stop the catastrophe and find whomever is causing it?",
		"What does Fate have in store for you?"
		
	},
	descriptor_choices = getBirthDescriptor("world", "Maj'Eyal").descriptor_choices,
	copy = {
		-- Override normal stuff
		before_starting_zone = function(self)
			self.starting_level = 1
			self.money = 200
			self.starting_level_force_down = nil
			self.starting_zone = "atof+abandoned-village"
			self.starting_quest = "atof+ashes-to-ashes"
			self.starting_intro = "atof"
			self.faction = "keepers-of-reality" 
		end,
	},
	game_state = {
		campaign_name = "a-twist-of-fate",
		__allow_transmo_chest = true,
		ignore_prodigies_special_reqs = true,
	},
}

