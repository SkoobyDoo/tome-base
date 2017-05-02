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

local ActorResource = require "engine.interface.ActorResource"
local ActorTalents = require "engine.interface.ActorTalents"
print("[Resources] Defining Actor Resources")

-- Actor resources
-- Additional (ToME specific) fields:
-- cost_factor increases/decreases resource cost (used mostly to account for the effect of armor-based fatigue)
-- invert_values = true means the resource increases as it is consumed (equilibrium/paradox)
-- status_text = function(actor) returns a textual description of the resource status (defaults to "val/max")
-- color = text color string ("#COLOR#") to use to display the resource (text or uiset graphics)
-- hidden_resource = true prevents display of the resource in various interfaces
-- depleted_unsustain = true makes sustained talents using the resource (with .remove_on_zero == true) deactivate when the resource is depleted
-- CharacterSheet = table of parameters to be used with the CharacterSheet (mod.dialogsCharacterSheet.lua):
--		status_text = function(act1, act2, compare_fields) generate text of resource status
-- Minimalist = table of parameters to be used with the Minimalist uiset (see uiset.Minimalist.lua)
ActorResource:defineResource("Air", "air", nil, "air_regen", "Air capacity in your lungs. Entities that need not breathe are not affected.", nil, nil, {
	color = "#LIGHT_STEEL_BLUE#",
	-- wait_on_rest = true,
})
ActorResource:defineResource("Stamina", "stamina", ActorTalents.T_STAMINA_POOL, "stamina_regen", "Stamina represents your physical fatigue.  Most physical abilities consume it.", nil, nil, {
	color = "#ffcc80#",
	cost_factor = function(self, t, check) return (check and self:hasEffect(self.EFF_ADRENALINE_SURGE)) and 0 or (100 + self:combatFatigue()) / 100 end,
	depleted_unsustain = true,
	wait_on_rest = true,
	randomboss_enhanced = true,
})
ActorResource:defineResource("Mana", "mana", ActorTalents.T_MANA_POOL, "mana_regen", "Mana represents your reserve of magical energies. Most spells cast consume mana and each sustained spell reduces your maximum mana.", nil, nil, {
	color = "#7fffd4#",
	cost_factor = function(self, t) return (100 + 2 * self:combatFatigue()) / 100 end,
	depleted_unsustain = true,
	wait_on_rest = true,
	randomboss_enhanced = true,
})
ActorResource:defineResource("Equilibrium", "equilibrium", ActorTalents.T_EQUILIBRIUM_POOL, "equilibrium_regen", "Equilibrium represents your standing in the grand balance of nature. The closer it is to 0 the more balanced you are. Being out of equilibrium will adversely affect your ability to use Wild Gifts.", 0, false, {
	color = "#00ff74#", invert_values = true,
	wait_on_rest = true,
	randomboss_enhanced = true,
	status_text = function(act)
		local _, chance = act:equilibriumChance()
		return ("%d (%d%%%% fail)"):format(act:getEquilibrium(), 100 - chance)
	end,
	CharacterSheet = { -- special params for the character sheet
		status_text = function(act1, act2, compare_fields)
			local text = compare_fields(act1, act2, function(act) local _, chance = act:equilibriumChance() return 100-chance end, "%d%%", "%+d%%", 1, true)
			return ("%d(fail: %s)"):format(act1:getEquilibrium(),text)
		end,
	},
	Minimalist = { --parameters for the Minimalist uiset
		images = {front = "resources/front_nature.png", front_dark = "resources/front_nature_dark.png"},
		highlight = function(player, vc, vn, vm, vr) -- dim the resource display if fail chance <= 15%
			if player then
				local _, chance = player:equilibriumChance()
				if chance > 85 then return true end
			end
		end,
		shader_params = {display_resource_bar = function(player, shader, x, y, color, a) -- update the resource bar shader
				if player ~= table.get(game, "player") or not shader or not a then return end
				local _, chance = player:equilibriumChance()
				local s = 100 - chance
				if s > 15 then s = 15 end
				s = s / 15
				if shader.shad then
					shader:setUniform("pivot", math.sqrt(s))
					shader:setUniform("a", a)
					shader:setUniform("speed", 10000 - s * 7000)
					shader.shad:use(true)
				end

				local p = chance / 100
				shat[1]:toScreenPrecise(x+49, y+10, shat[6] * p, shat[7], 0, p * 1/shat[4], 0, 1/shat[5], color[1], color[2], color[3], a)
				if shader.shad then shader.shad:use(false) end
			end
		}
	}
})

ActorResource:defineResource("Vim", "vim", ActorTalents.T_VIM_POOL, "vim_regen", "Vim represents the amount of life energy/souls you have stolen. Each corruption talent requires some.", nil, nil, {
	color = "#904010#",
	wait_on_rest = true,
	randomboss_enhanced = true,
	Minimalist = {shader_params = {color = {0x90/255, 0x40/255, 0x10/255}}} --parameters for the Minimalist uiset
})
ActorResource:defineResource("Positive energy", "positive", ActorTalents.T_POSITIVE_POOL, "positive_regen", "Positive energy represents your reserve of positive power. It slowly decreases.", nil, nil, {
	color = "#ffd700#",
	randomboss_enhanced = true,
	cost_factor = function(self, t) return (100 + self:combatFatigue()) / 100 end,
	Minimalist = {highlight = function(player, vc, vn, vm, vr) return vc >=0.7*vm end},
})
ActorResource:defineResource("Negative energy", "negative", ActorTalents.T_NEGATIVE_POOL, "negative_regen", "Negative energy represents your reserve of negative power. It slowly decreases.", nil, nil, {
	color = "#7f7f7f#",
	randomboss_enhanced = true,
	cost_factor = function(self, t) return (100 + self:combatFatigue()) / 100 end,
	Minimalist = {highlight = function(player, vc, vn, vm, vr) return vc >=0.7*vm end},
})
ActorResource:defineResource("Hate", "hate", ActorTalents.T_HATE_POOL, "hate_regen", "Hate represents your soul's primal antipathy towards others.  It generally decreases whenever you have no outlet for your rage, and increases when you are damaged or destroy others.", nil, nil, {
	color = "#ffa0ff#",
	cost_factor = function(self, t) return (100 + self:combatFatigue()) / 100 end,
	Minimalist = {highlight = function(player, vc, vn, vm, vr) return vc >=100 end},
})
ActorResource:defineResource("Paradox", "paradox", ActorTalents.T_PARADOX_POOL, "paradox_regen", "Paradox represents how much damage you've done to the space-time continuum. A high Paradox score makes Chronomancy less reliable and more dangerous to use but also amplifies its effects.", 0, false, {
	color = "#4198dc#", invert_values = true,
	randomboss_enhanced = true,
	status_text = function(act)
		local chance = act:paradoxFailChance()
		return ("%d/%d (%d%%%%)"):format(act:getModifiedParadox(), act:getParadox(), chance), chance
	end,
	CharacterSheet = { -- special params for the character sheet
		status_text = function(act1, act2, compare_fields)
			local text = compare_fields(act1, act2, function(act) return act:paradoxFailChance() end, "%d%%", "%+d%%", 1, true)
			return ("%d/%d(anom: %s)"):format(act1:getModifiedParadox(), act1:getParadox(), text)
		end,
	},
	Minimalist = { --parameters for the Minimalist uiset
		highlight = function(player, vc, vn, vm, vr) -- highlight the resource display if fail chance > 10%
			if player then
				local chance = player:paradoxFailChance()
				if chance > 10 then return true end
			end
		end,
		shader_params = {display_resource_bar = function(player, shader, x, y, color, a) -- update the resource bar shader
			if player ~= table.get(game, "player") or not shader or not a then return end
			local chance = player:paradoxFailChance()
			local vm = player:getModifiedParadox()
			local s = chance
			if s > 15 then s = 15 end
			s = s / 15
			if shader.shad then
				shader:setUniform("pivot", math.sqrt(s))
				shader:setUniform("a", a)
				shader:setUniform("speed", 10000 - s * 7000)
				shader.shad:use(true)
			end
			local p = util.bound(600-vm, 0, 300) / 300
			shat[1]:toScreenPrecise(x+49, y+10, shat[6] * p, shat[7], 0, p * 1/shat[4], 0, 1/shat[5], color[1], color[2], color[3], a)
			if shader.shad then shader.shad:use(false) end
		end
		}
	},
})
ActorResource:defineResource("Psi", "psi", ActorTalents.T_PSI_POOL, "psi_regen", "Psi represents your reserve of psychic energy.", nil, nil, {
	color = "#4080ff#",
	wait_on_rest = true,
	randomboss_enhanced = true,
	cost_factor = function(self, t) return (100 + 2 * self:combatFatigue()) / 100 end,
})
ActorResource:defineResource("Souls", "soul", ActorTalents.T_SOUL_POOL, "soul_regen", "This is the number of soul fragments you have extracted from your foes for your own use.", 0, 10, {
	color = "#bebebe#",
	randomboss_enhanced = true,
	Minimalist = {images = {front = "resources/front_souls.png", front_dark = "resources/front_souls_dark.png"}},
})
