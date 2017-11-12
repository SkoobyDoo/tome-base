-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2017 Nicolas Casalini
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

local function shimmer(player, slot)
	return function()
		package.loaded['mod.dialogs.Shimmer'] = nil
		local d = require("mod.dialogs.Shimmer").new(player, slot)
		game:registerDialog(d)
	end
end

local answers = {}

for slot, inven in pairs(player.inven) do
	if player.inven_def[slot].infos and player.inven_def[slot].infos.shimmerable and inven[1] then
		local o = inven[1]
		if o.slot then
			answers[#answers+1] = {"[Alter the appearance of "..o:getName{do_color=true, no_add_name=true}.."]", action=shimmer(player, slot), jump="welcome"}
		end
	end
end
answers[#answers+1] = {"[Leave the mirror alone]"}
	
newChat{ id="welcome",
	text = [[*#LIGHT_GREEN#As you gaze into the mirror you see an infinite number of slightly different reflections of yourself. You feel dizzy.#WHITE#*]],
	answers = answers
}

return "welcome"
