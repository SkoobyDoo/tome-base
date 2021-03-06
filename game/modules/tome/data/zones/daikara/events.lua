-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2018 Nicolas Casalini
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

local events = { one_per_level=true,
	{group="outdoor-majeyal-gloomy"},
	{group="outdoor-majeyal-generic"},
	{group="majeyal-generic"},
	{name="cultists", percent=10},
	{name="font-life", minor=true, percent=30},
	{name="whistling-vortex", minor=true, percent=30},
}

if self.is_volcano then
	events[#events+1] = {name="pyroclast", minor=true, percent=100}
else
	events[#events+1] = {name="icy-ground", minor=true, percent=50}

end

return events