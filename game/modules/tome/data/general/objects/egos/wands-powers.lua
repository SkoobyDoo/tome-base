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

--[[
Wands
*detection
*light
*trap destruction
*firewall
*lightning
*conjuration
]]

newEntity{
	name = " of clairvoyance", addon=true, instant_resolve=true,
	keywords = {clairvoyance=true},
	level_range = {1, 50},
	rarity = 8,

	charm_power_def = {add=8, max=10, floor=true},
	resolvers.charm(function(self, who)
		return ("reveal the area around you, dispelling darkness (radius %d, power %d based on Magic), and detect the presence of nearby creatures for 3 turns"):format(self.use_power.radius(self, who), self.use_power.litepower(self, who))
	end,
	6,
	function(self, who)
		local rad = self.use_power.radius(self, who)
		who:setEffect(who.EFF_SENSE, 3, {
			range = rad,
			actor = 1,
		})
		game.logSeen(who, "%s uses %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
		who:project({type="ball", range=0, selffire=true, radius=rad}, who.x, who.y, engine.DamageType.LITE, self.use_power.litepower(self, who))

		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{no_npc_use=true,
	radius = function(self, who) return self:getCharmPower(who) end,
	litepower = function(self, who) return who:combatStatScale("mag", 25, 75) + self:getCharmPower(who) end}),
}

newEntity{
	name = " of trap destruction", addon=true, instant_resolve=true,
	keywords = {trap=true},
	level_range = {1, 50},
	rarity = 14,

	charm_power_def = {add=resolvers.genericlast(function(e) return e.material_level * 8 end), max=100, floor=true,
		range = function(self, who) return who:combatStatScale("mag", 2, 4) end},
	resolvers.charm(
		function(self, who) return ("disarm traps (%d bonus disarm power, based on Magic) along a range %d line"):format( self:getCharmPower(who), self.charm_power_def:range(who)) end,
		15,
		function(self, who)
		local tg = {type="beam", range = self.charm_power_def:range(who)}
		local x, y = who:getTarget(tg)
		if not x or not y then return nil end
		game.logSeen(who, "%s uses %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
		who:project(tg, x, y, function(px, py)
			local trap = game.level.map(px, py, engine.Map.TRAP)
			if not trap then return end
			local inc = self:getCharmPower(who)
			who:attr("can_disarm", 1)
			who:attr("disarm_bonus", inc)

			trap:disarm(px, py, who)

			who:attr("disarm_bonus", -inc)
			who:attr("can_disarm", -1)
		end)
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{no_npc_use=true}),
}

newEntity{
	name = " of firewall", addon=true, instant_resolve=true,
	keywords = {firewall=true},
	level_range = {15, 50},
	rarity = 10,

	charm_power_def = {add=25, max=400, floor=true},
	resolvers.charm(function(self, who)
		local dam = who:damDesc(engine.DamageType.FIRE, self.use_power.damage(self, who))
		return ("creates a wall of flames lasting 4 turns (dealing %d fire damage overall)"):format(dam)
	end,
	6,
	function(self, who)
		local tg = self.use_power.target(self, who)
		local x, y = who:getTarget(tg)
		if not x or not y then return nil end
		local dam = self.use_power.damage(self, who)
		game.logSeen(who, "%s conjures a wall of fire from %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
		who:project(tg, x, y, function(px, py)
			game.level.map:addEffect(who, px, py, 4, engine.DamageType.FIRE, dam / 4, 0, 5, nil, {type="inferno"}, nil, true)
		end)
		game:playSoundNear(who, "talents/fire")
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{range = 5,
	requires_target = true,
	no_npc_use = function(self, who) return self:restrictAIUseObject(who) end, -- don't let dumb ai hurt friends
	target = function(self, who) return {type="wall", range=self.use_power.range, halflength=3, halfmax_spots=3+1} end,
	tactical = {ATTACKAREA = {FIRE = 2}},
	damage = function(self, who) return self:getCharmPower(who) end
	}),
}

newEntity{
	name = " of conjuration", addon=true, instant_resolve=true,
	keywords = {conjure=true},
	level_range = {6, 50},
	rarity = 6,

	charm_power_def = {add=25, max=600, floor=true},
	resolvers.charm(function(self, who)
			local dam = self.use_power.damage(self, who)
			return ("fire a bolt of a random element with (base) damage %d to %d"):format(dam/2, dam)
		end,
		10,
		function(self, who)
			local tg = self.use_power.target(self, who)
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			local dam = self.use_power.damage(self, who)
			local elem = rng.table{
				{engine.DamageType.FIRE, "flame"},
				{engine.DamageType.COLD, "freeze"},
				{engine.DamageType.LIGHTNING, "lightning_explosion"},
				{engine.DamageType.ACID, "acid"},
				{engine.DamageType.NATURE, "slime"},
				{engine.DamageType.BLIGHT, "slime"},
			}
			game.logSeen(who, "%s activates %s %s!", who.name:capitalize(), who:his_her(), self:getName({no_add_name = true, do_color = true}))
			who:project(tg, x, y, elem[1], rng.avg(dam / 2, dam, 3), {type=elem[2]})
			game:playSoundNear(who, "talents/fire")
			return {id=true, used=true}
		end,
		"T_GLOBAL_CD",
		{ range = 8,
		requires_target = true,
		target = function(self, who) return {type="bolt", range=self.use_power.range} end,
		damage = function(self, who) return self:getCharmPower(who) end,
		tactical = {ATTACK = 1}}
	),
}
