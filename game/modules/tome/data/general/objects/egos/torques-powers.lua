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
Torques
*psionic shield
*psychoportation
*clear mind
*mind wave
]]

-- This is too important to nerf, but it should be noted that all charm powers have to be balanced against its existence, same as the teleport amulet
-- In order for non-teleport charms to be worth wasting the charm CD on they need to be very good, because the opportunity cost is *not just the item slot*
newEntity{
	name = " of psychoportation", addon=true, instant_resolve=true,
	keywords = {psyport=true},
	level_range = {15, 50},
	rarity = 10,

	charm_power_def = {add=15, max=60, floor=true},
	resolvers.charm("teleport randomly (rad %d)", 30,
		function(self, who)
			game.level.map:particleEmitter(who.x, who.y, 1, "teleport")
			who:teleportRandom(who.x, who.y, self:getCharmPower(who))
			game.level.map:particleEmitter(who.x, who.y, 1, "teleport")
			game.logSeen(who, "%s uses %s!", who.name:capitalize(), self:getName{no_add_name=true, do_color=true})
			return {id=true, used=true}
		end,
		"T_GLOBAL_CD",
		{no_npc_use = true} -- This wouldn't be the least bit annoying.....
	),
}

newEntity{
	name = " of kinetic psionic shield", addon=true, instant_resolve=true,
	keywords = {kinshield=true},
	level_range = {1, 50},
	rarity = 7,

	charm_power_def = {add=3, max=200, floor=true},
	resolvers.charm("setup a psionic shield, reducing all physical, nature, temporal and acid damage by %d for 7 turns", 20, function(self, who)
		who:setEffect(who.EFF_PSIONIC_SHIELD, 7, {kind="kinetic", power=self:getCharmPower(who)})
		game.logSeen(who, "%s uses %s!", who.name:capitalize(), self:getName{no_add_name=true, do_color=true})
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{on_pre_use = function(self, who)
		local shield = who:hasEffect(who.EFF_PSIONIC_SHIELD)
		return not (shield and shield.kind == "kinetic")
	end,
	tactical = { DEFEND = 2 }}),
}


newEntity{
	name = " of thermal psionic shield", addon=true, instant_resolve=true,
	keywords = {thermshield=true},
	level_range = {1, 50},
	rarity = 7,

	charm_power_def = {add=3, max=200, floor=true},
	resolvers.charm("setup a psionic shield, reducing all fire, cold, light, and arcane damage by %d for 7 turns", 20, function(self, who)
		who:setEffect(who.EFF_PSIONIC_SHIELD, 7, {kind="thermal", power=self:getCharmPower(who)})
		game.logSeen(who, "%s uses %s!", who.name:capitalize(), self:getName{no_add_name=true, do_color=true})
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{on_pre_use = function(self, who)
		local shield = who:hasEffect(who.EFF_PSIONIC_SHIELD)
		return not (shield and shield.kind == "thermal")
	end,
	tactical = { DEFEND = 2 }}),
}

newEntity{
	name = " of charged psionic shield", addon=true, instant_resolve=true,
	keywords = {chargedshield=true},
	level_range = {10, 50},
	rarity = 8,

	charm_power_def = {add=3, max=200, floor=true},
	resolvers.charm("setup a psionic shield, reducing all lightning, blight, mind, and darkness damage by %d for 7 turns", 20, function(self, who)
		who:setEffect(who.EFF_PSIONIC_SHIELD, 7, {kind="charged", power=self:getCharmPower(who)})
		game.logSeen(who, "%s uses %s!", who.name:capitalize(), self:getName{no_add_name=true, do_color=true})
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{on_pre_use = function(self, who)
		local shield = who:hasEffect(who.EFF_PSIONIC_SHIELD)
		return not (shield and shield.kind == "charged")
	end,
	tactical = { DEFEND = 2 }}),
}

newEntity{
	name = " of clear mind", addon=true, instant_resolve=true,
	keywords = {clearmind=true},
	level_range = {15, 50},
	rarity = 12,

	charm_power_def = {add=1, max=5, floor=true},
	resolvers.charm("absorb and nullify at most %d detrimental mental status effects in the next 10 turns", 10, function(self, who)
		who:setEffect(who.EFF_CLEAR_MIND, 10, {power=self:getCharmPower(who)})
		game.logSeen(who, "%s uses %s!", who.name:capitalize(), self:getName{no_add_name=true, do_color=true})
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{tactical = {CURE = function(who, t, aitarget) -- if we're debuffed, try to prevent more
			if who:hasEffect(who.EFF_CLEAR_MIND) then return 0 end
			local nb = 0
			for eff_id, p in pairs(who.tmp) do
				local e = who.tempeffect_def[eff_id]
				if e.status == "detrimental" and e.type == "mental" then
					nb = nb + 1
				end
			end
			return math.ceil(nb/2)
		end,
		DEFEND = function(who, t, aitarget) -- if the target can debuff us with mental abilities, prepare
			if not aitarget or who:hasEffect(who.EFF_CLEAR_MIND) then return 0 end
			local count, nb = 0, 0
			for t_id, p in pairs(aitarget.talents) do
				count = count + 1
				local tal = aitarget.talents_def[t_id]
				if tal.is_mind then
					if type(tal.tactical) == "table" and tal.tactical.disable then
						nb = nb + 1
					end
				end
			end
			return math.min(5*(nb/count)^.5, 5)
		end}}
	),
}

newEntity{
	name = " of mindblast", addon=true, instant_resolve=true,
	keywords = {mindblast=true},
	level_range = {15, 50},
	rarity = 8,
	charm_power_def = {add=45, max=400, floor=true},
	resolvers.charm(
		function(self, who)
			local dam = who:damDesc(engine.DamageType.Mind, self.use_power.damage(self, who))
			return ("fire a blast of psionic energies in a range %d beam dealing %0.2f to %0.2f mind damage"):format(self.use_power.range(self, who), dam/2, dam)
		end,
		6,
		function(self, who)
			local tg = self.use_power.target(self, who)
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			local dam = self.use_power.damage(self, who)
			game.logSeen(who, "%s uses %s %s!", who.name:capitalize(), who:his_her(), self:getName{no_add_name=true, do_color=true})
			who:project(tg, x, y, engine.DamageType.MIND, rng.avg(dam / 2, dam, 3), {type="mind"})
			return {id=true, used=true}
		end,
		"T_GLOBAL_CD",
		{range = function(self, who) return math.floor(who:combatStatScale("wil", 6, 10)) end,
		damage = function(self, who) return self:getCharmPower(who) end,
		target = function(self, who) return {type="beam", range=self.use_power.range(self, who)} end,
		requires_target = true,
		tactical = { attackarea = { mind = 2} }
		}
	),
}
