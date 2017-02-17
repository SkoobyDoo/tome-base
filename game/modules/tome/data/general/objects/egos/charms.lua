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

-- modify the power and cooldown of charm powers
-- This makes adjustments after zone:finishEntity is finished, which handles any egos added via e.addons
local function modify_charm(e, e, zone, level)
	for i, c_mod in ipairs(e.charm_power_mods) do
		c_mod(e, e, zone, level)
	end
	if e._old_finish and e._old_finish ~= e._modify_charm then return e._old_finish(e, e, zone, level) end
end

newEntity{
	name = "quick ", prefix=true,
	keywords = {quick=true},
	level_range = {1, 50},
	rarity = 15,
	cost = 5,
	_modify_charm = modify_charm,
	resolvers.genericlast(function(e)
		if e.finish ~= e._modify_charm then e._old_finish = e.finish end
		e.finish = e._modify_charm
		e.charm_power_mods = e.charm_power_mods or {}
		table.insert(e.charm_power_mods, function(e, e, zone, level)
			if e.charm_power and e.use_power and e.use_power.power then
				print("\t Applying quick ego changes.")
				e.use_power.power = math.ceil(e.use_power.power * rng.float(0.6, 0.8))
				e.charm_power = math.ceil(e.charm_power * rng.float(0.6, 0.9))
			else
				print("\tquick ego changes aborted.")
			end
		end)
	end),
}

newEntity{
	name = "supercharged ", prefix=true,
	keywords = {['super.c']=true},
	level_range = {1, 50},
	rarity = 15,
	cost = 5,
	_modify_charm = modify_charm,
	resolvers.genericlast(function(e)
		if e.finish ~= e._modify_charm then e._old_finish = e.finish end
		e.finish = e._modify_charm
		e.charm_power_mods = e.charm_power_mods or {}
		table.insert(e.charm_power_mods, function(e, e, zone, level)
			if e.charm_power and e.use_power and e.use_power.power then
				print("\t Applying supercharged ego changes.")
				e.use_power.power = math.ceil(e.use_power.power * rng.float(1.1, 1.3))
				e.charm_power = math.ceil(e.charm_power * rng.float(1.3, 1.5))
			else
				print("\tsupercharged ego changes aborted.")
			end
		end)
	end),
}

newEntity{
	name = "overpowered ", prefix=true,
	keywords = {['overpower']=true},
	level_range = {30, 50},
	greater_ego = 1,
	rarity = 16,
	cost = 5,
	_modify_charm = modify_charm,
	resolvers.genericlast(function(e)
		if e.finish ~= e._modify_charm then e._old_finish = e.finish end
		e.finish = e._modify_charm
		e.charm_power_mods = e.charm_power_mods or {}
		table.insert(e.charm_power_mods, function(e, e, zone, level)
			if e.charm_power and e.use_power and e.use_power.power then
				print("\t Applying overpowered ego changes.")
				e.use_power.power = math.ceil(e.use_power.power * rng.float(1.2, 1.5))
				e.charm_power = math.ceil(e.charm_power * rng.float(1.6, 1.9))
			else
				print("\toverpowered ego changes aborted.")
			end
		end)
	end),
}
