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
Totems
*healing
*cure illness
*thorny skin
]]

newEntity{
	name = " of cure ailments", addon=true, instant_resolve=true,
	keywords = {ailments=true},
	level_range = {1, 50},
	rarity = 8,

	charm_power_def = {add=1, max=5, floor=true},
	resolvers.charm(
		function(self, who) return ("remove up to %d poisons or diseases from a target within range %d (based on Willpower)"):format(self.use_power.cures(self, who), self.use_power.range(self, who)) end,
		10,
		function(self, who)
		local tg = self.use_power.target(self, who)
		local x, y = who:getTarget(tg)
		if not x or not y then return nil end
		local nb = self.use_power.cures(self, who)
		game.logSeen(who, "%s activates %s %s!", who.name:capitalize(), who:his_her(), self:getName{no_add_name = true, do_color = true})
		who:project(tg, x, y, function(px, py)
			local target = game.level.map(px, py, engine.Map.ACTOR)
			if not target then return end
			local effs = {}

			-- Go through all temporary effects
			for eff_id, p in pairs(target.tmp) do
				local e = target.tempeffect_def[eff_id]
				if e.subtype.poison or e.subtype.disease then
					effs[#effs+1] = {"effect", eff_id}
				end
			end

			for i = 1, nb do
				if #effs == 0 then break end
				local eff = rng.tableRemove(effs)

				if eff[1] == "effect" then
					target:removeEffect(eff[2])
				end
			end
		end)
		game:playSoundNear(who, "talents/heal")
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{range = function(self, who) return math.floor(who:combatStatScale("wil", 6, 10)) end,
	cures = function(self, who) return self:getCharmPower(who) end,
	target = function(self, who) return {default_target=who, type="hit", nowarning=true, range=self.use_power.range(self, who), first_target="friend"} end,
	tactical = {CURE = function(who, t, aitarget) -- count number of effects that can be removed
			local nb = 0
			for eff_id, p in pairs(who.tmp) do
				local e = who.tempeffect_def[eff_id]
				if e.status == "detrimental" and (e.subtype.poison or e.subtype.disease) then
					nb = nb + 1
				end
			end
			return nb
			end,
			},
	}),
}

newEntity{
	name = " of thorny skin", addon=true, instant_resolve=true,
	keywords = {thorny=true},
	level_range = {1, 50},
	rarity = 6,

	charm_power_def = {add=5, max=100, floor=true},
	resolvers.charm(function(self) return ("harden the skin for 7 turns increasing armour by %d and armour hardiness by %d%%%%"):format(self:getCharmPower(who), 20 + self.material_level * 10) end, 20, function(self, who)
		game.logSeen(who, "%s activates %s %s!", who.name:capitalize(), who:his_her(), self:getName{no_add_name = true, do_color = true})
		who:setEffect(who.EFF_THORNY_SKIN, 7, {ac=self:getCharmPower(who), hard=20 + self.material_level * 10})
		game:playSoundNear(who, "talents/heal")
		return {id=true, used=true}
	end,
	"T_GLOBAL_CD",
	{on_pre_use = function(self, who)
		return not who:hasEffect(who.EFF_THORNY_SKIN)
	end,
	tactical = {DEFEND = 1.5}}),
}

newEntity{
	name = " of healing", addon=true, instant_resolve=true,
	keywords = {heal=true},
	level_range = {25, 50},
	rarity = 20,

	charm_power_def = {add=50, max=250, floor=true},
	resolvers.charm(
		function(self, who) return ("heal a target within range %d (based on Willpower) for %d"):format(self.use_power.range(self, who), self.use_power.damage(self, who)) end,
		20,
		function(self, who)
			local tg = self.use_power.target(self, who)
			local x, y = who:getTarget(tg)
			if not x or not y then return nil end
			local dam = self.use_power.damage(self, who)
			game.logSeen(who, "%s activates %s %s!", who.name:capitalize(), who:his_her(), self:getName{no_add_name = true, do_color = true})
			who:project(tg, x, y, engine.DamageType.HEAL, dam)
			game:playSoundNear(who, "talents/heal")
			return {id=true, used=true}
		end,
		"T_GLOBAL_CD",
		{range = function(self, who) return math.floor(who:combatStatScale("wil", 6, 10)) end,
		damage = function(self, who) return self:getCharmPower(who) end,
		target = function(self, who) return {default_target=who, type="hit", nowarning=true, range=self.use_power.range(self, who), first_target="friend"} end,
		tactical = {HEAL = 2}}
	),
}
