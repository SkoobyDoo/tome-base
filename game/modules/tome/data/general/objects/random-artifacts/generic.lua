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

local Stats = require "engine.interface.ActorStats"
local Talents = require "engine.interface.ActorTalents"

-- Themes list: physical, mental, spell, defense, misc, fire, lightning, acid, mind, arcane, blight, nature, temporal, light, dark, antimagic, cold

----------------------------------------------------------------
-- Spell Themes
----------------------------------------------------------------
----------------------------------------------------------------
-- Spell damage
----------------------------------------------------------------
newEntity{ theme={spell=true}, name="spellpower", points = 1, rarity = 8, level_range = {1, 50},
	wielder = { combat_spellpower = resolvers.randartmax(2, 20), },
}
newEntity{ theme={spell=true}, name="spellcrit", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { combat_spellcrit = resolvers.randartmax(1, 15), },
}
newEntity{ theme={spell=true}, name="spell crit magnitude", points = 3, rarity = 15, level_range = {1, 50},
	wielder = { combat_critical_power = resolvers.randartmax(5, 25), },
}
newEntity{ theme={spell=true}, name="spellsurge", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { spellsurge_on_crit = resolvers.randartmax(2, 10), },
}
----------------------------------------------------------------
-- Resources
----------------------------------------------------------------
newEntity{ theme={spell=true}, name="mana regeneration", points = 1, rarity = 15, level_range = {1, 50},
	wielder = { mana_regen = resolvers.randartmax(.04, .6), },
}
newEntity{ theme={spell=true}, name="increased mana", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { max_mana = resolvers.randartmax(20, 100), },
}
newEntity{ theme={spell=true}, name="mana on crit", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { mana_on_crit = resolvers.randartmax(1, 10), },
}
newEntity{ theme={spell=true}, name="increased vim", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { max_vim = resolvers.randartmax(10, 50), },
}
newEntity{ theme={spell=true}, name="vim on crit", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { vim_on_crit = resolvers.randartmax(1, 5), },
}
----------------------------------------------------------------
-- Misc
----------------------------------------------------------------
newEntity{ theme={spell=true}, name="phasing", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { damage_shield_penetrate = resolvers.randartmax(10, 50), },
}

----------------------------------------------------------------
-- Mental Themes
----------------------------------------------------------------
----------------------------------------------------------------
-- Mental Damage
----------------------------------------------------------------
newEntity{ theme={mental=true}, name="mindpower", points = 1, rarity = 8, level_range = {1, 50},
	wielder = { combat_mindpower = resolvers.randartmax(2, 20), },
}
newEntity{ theme={mental=true}, name="mindcrit", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { combat_mindcrit = resolvers.randartmax(1, 15), },
}
newEntity{ theme={mental=true}, name="mind crit magnitude", points = 3, rarity = 15, level_range = {1, 50},
	wielder = { combat_critical_power = resolvers.randartmax(5, 25), },
}
----------------------------------------------------------------
-- Resources
----------------------------------------------------------------
newEntity{ theme={mental=true}, name="equilibrium on hit", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { equilibrium_regen_when_hit = resolvers.randartmax(.04, 2), },
}
newEntity{ theme={mental=true}, name="max hate", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { max_hate = resolvers.randartmax(2, 10), },
}
newEntity{ theme={mental=true}, name="hate on crit", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { hate_on_crit = resolvers.randartmax(1, 5), },
}
newEntity{ theme={mental=true}, name="max psi", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { max_psi = resolvers.randartmax(10, 50), },
}
newEntity{ theme={mental=true}, name="psi on hit", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { psi_regen_when_hit = resolvers.randartmax(.04, 2), },
}

----------------------------------------------------------------
-- Misc
----------------------------------------------------------------
newEntity{ theme={mental=true}, name="summon heal", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { heal_on_nature_summon  = resolvers.randartmax(10, 50), },
}

----------------------------------------------------------------
-- Physical Themes
----------------------------------------------------------------
----------------------------------------------------------------
-- Physical Damage
----------------------------------------------------------------
newEntity{ theme={physical=true}, name="phys dam", points = 1, rarity = 8, level_range = {1, 50},
	wielder = { combat_dam = resolvers.randartmax(2, 20), },
}
newEntity{ theme={physical=true}, name="phys apr", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { combat_apr = resolvers.randartmax(1, 15), },
}
newEntity{ theme={physical=true}, name="phys crit", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { combat_physcrit = resolvers.randartmax(1, 15), },
}
newEntity{ theme={physical=true}, name="phys atk", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { combat_atk = resolvers.randartmax(2, 20), },
}
newEntity{ theme={physical=true}, name="phys crit magnitude", points = 3, rarity = 15, level_range = {1, 50},
	wielder = { combat_critical_power = resolvers.randartmax(3, 25),   },
}
----------------------------------------------------------------
-- Resources
----------------------------------------------------------------
newEntity{ theme={physical=true}, name="stamina regeneration", points = 1, rarity = 15, level_range = {1, 50},
	wielder = { stamina_regen = resolvers.randartmax(.2, 3), },
}
newEntity{ theme={physical=true}, name="increased stamina", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { max_stamina = resolvers.randartmax(5, 75), },
}
newEntity{ theme={physical=true}, name="life regeneration", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { life_regen = resolvers.randartmax(.2, 3), },
}
newEntity{ theme={physical=true}, name="increased life", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { max_life = resolvers.randartmax(10, 150), },
}
newEntity{ theme={physical=true}, name="improve heal", points = 1, rarity = 15, level_range = {1, 50},
	wielder = { healing_factor = resolvers.randartmax(0.05, .5), },
}
----------------------------------------------------------------
-- Misc
----------------------------------------------------------------
newEntity{ theme={misc=true}, name="decreased fatigue", points = 1, rarity = 15, level_range = {1, 50},
	wielder = { fatigue = -2 },
}
----------------------------------------------------------------
-- Defense Themes
----------------------------------------------------------------
----------------------------------------------------------------
-- Defense
----------------------------------------------------------------
newEntity{ theme={defense=true, physical=true}, name="def", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { combat_def = resolvers.randartmax(3, 9),
				combat_def_ranged = resolvers.randartmax(3, 9), },
}
newEntity{ theme={defense=true, physical=true}, name="armor", points = 1, rarity = 10, level_range = {1, 50},
	wielder = { combat_armor = resolvers.randartmax(2, 6), },
}
----------------------------------------------------------------
-- Saves
----------------------------------------------------------------
newEntity{ theme={defense=true, physical=true}, name="save physical", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { combat_physresist = resolvers.randartmax(3, 18), },
}
newEntity{ theme={defense=true, spell=true, antimagic=true}, name="save spell", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { combat_spellresist = resolvers.randartmax(3, 18), },
}
newEntity{ theme={defense=true, mental=true}, name="save mental", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { combat_mentalresist = resolvers.randartmax(3, 18), },
}
--------------------------------------------------------------
-- Immunities
--------------------------------------------------------------
newEntity{ theme={defense=true}, name="immune stun", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { stun_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune knockback", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { knockback_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune blind", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { blind_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune confusion", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { confusion_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune pin", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { pin_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune poison", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { poison_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune disease", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { disease_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune silence", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { silence_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune disarm", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { disarm_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune cut", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { cut_immune = resolvers.randartmax(0.05, 0.5), },
}
newEntity{ theme={defense=true}, name="immune teleport", points = 1, rarity = 20, level_range = {1, 50},
	wielder = { teleport_immune = resolvers.randartmax(0.05, 0.5), },
}
--------------------------------------------------------------
-- Resist %
--------------------------------------------------------------
newEntity{ theme={defense=true, physical=true}, name="resist physical", points = 2, rarity = 15, level_range = {1, 50},
	wielder = { resists = { [DamageType.PHYSICAL] = resolvers.randartmax(1, 15), }, },
}
newEntity{ theme={defense=true, mind=true}, name="resist mind", points = 2, rarity = 15, level_range = {1, 50},
	wielder = { resists = { [DamageType.MIND] = resolvers.randartmax(3, 15), }, },
}
newEntity{ theme={defense=true, antimagic=true, fire=true}, name="resist fire", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.FIRE] = resolvers.randartmax(3, 30), }, },
}
newEntity{ theme={defense=true, antimagic=true, cold=true}, name="resist cold", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.COLD] = resolvers.randartmax(3, 30), }, },
}
newEntity{ theme={defense=true, antimagic=true, acid=true}, name="resist acid", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.ACID] = resolvers.randartmax(3, 30), }, },
}
newEntity{ theme={defense=true, antimagic=true, lightning=true}, name="resist lightning", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.LIGHTNING] = resolvers.randartmax(3, 30), }, },
}
newEntity{ theme={defense=true, antimagic=true, arcane=true}, name="resist arcane", points = 1, rarity = 15, level_range = {1, 50},
	wielder = { resists = { [DamageType.ARCANE] = resolvers.randartmax(5, 5), }, },
}
newEntity{ theme={defense=true, antimagic=true, nature=true}, name="resist nature", points = 2, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.NATURE] = resolvers.randartmax(3, 20), }, },
}
newEntity{ theme={defense=true, antimagic=true, blight=true}, name="resist blight", points = 2, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.BLIGHT] = resolvers.randartmax(3, 20), }, },
}
newEntity{ theme={defense=true, antimagic=true, light=true}, name="resist light", points = 2, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.LIGHT] = resolvers.randartmax(3, 20), }, },
}
newEntity{ theme={defense=true, antimagic=true, dark=true}, name="resist darkness", points = 2, rarity = 11, level_range = {1, 50},
	wielder = { resists = { [DamageType.DARKNESS] = resolvers.randartmax(3, 20), }, },
}
newEntity{ theme={defense=true, antimagic=true, temporal=true}, name="resist temporal", points = 2, rarity = 15, level_range = {1, 50},
	wielder = { resists = { [DamageType.TEMPORAL] = resolvers.randartmax(3, 15), }, },
}

----------------------------------------------------------------
--- Elemental Themes ---
----------------------------------------------------------------
----------------------------------------------------------------
----------------------------------------------------------------
-- Elemental Retribution
----------------------------------------------------------------
newEntity{ theme={physical=true}, name="physical retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.PHYSICAL] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={mind=true, mental=true}, name="mind retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.MIND] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={acid=true}, name="acid retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.ACID] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={lightning=true}, name="lightning retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.LIGHTNING] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={fire=true}, name="fire retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.FIRE] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={cold=true}, name="cold retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.COLD] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={light=true}, name="light retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.LIGHT] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={dark=true}, name="dark retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.DARKNESS] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={blight=true, spell=true}, name="blight retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.BLIGHT] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={nature=true}, name="nature retribution", points = 1, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.NATURE] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={arcane=true, spell=true}, name="arcane retribution", points = 2, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.ARCANE] = resolvers.randartmax(4, 20), }, },
}
newEntity{ theme={temporal=true}, name="temporal retribution", points = 2, rarity = 35, level_range = {15, 50},
	wielder = { on_melee_hit = {[DamageType.TEMPORAL] = resolvers.randartmax(4, 20), }, },
}

----------------------------------------------------------------
-- Damage %
----------------------------------------------------------------
newEntity{ theme={physical=true}, name="inc damage physical", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.PHYSICAL] = resolvers.randartmax(3, 30), }, },
}
newEntity{ theme={mind=true, mental=true}, name="inc damage mind", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.MIND] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={fire=true}, name="inc damage fire", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.FIRE] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={cold=true}, name="inc damage cold", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.COLD] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={acid=true}, name="inc damage acid", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.ACID] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={lightning=true}, name="inc damage lightning", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.LIGHTNING] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={arcane=true, spell=true}, name="inc damage arcane", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.ARCANE] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={nature=true}, name="inc damage nature", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.NATURE] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={blight=true, spell=true}, name="inc damage blight", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.BLIGHT] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={light=true}, name="inc damage light", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.LIGHT] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={dark=true}, name="inc damage darkness", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.DARKNESS] = resolvers.randartmax(3, 30),  }, },
}
newEntity{ theme={temporal=true}, name="inc damage temporal", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { inc_damage = { [DamageType.TEMPORAL] = resolvers.randartmax(3, 30),  }, },
}

----------------------------------------------------------------
-- Resist Penetration %
----------------------------------------------------------------
newEntity{ theme={physical=true}, name="resists pen physical", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.PHYSICAL] = resolvers.randartmax(5, 25), }, },
}
newEntity{ theme={mind=true, mental=true}, name="resists pen mind", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.MIND] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={fire=true}, name="resists pen fire", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.FIRE] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={cold=true}, name="resists pen cold", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.COLD] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={acid=true}, name="resists pen acid", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.ACID] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={lightning=true}, name="resists pen lightning", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.LIGHTNING] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={arcane=true, spell=true}, name="resists pen arcane", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.ARCANE] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={nature=true}, name="resists pen nature", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.NATURE] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={blight=true, spell=true}, name="resists pen blight", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.BLIGHT] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={light=true}, name="resists pen light", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.LIGHT] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={dark=true}, name="resists pen darkness", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.DARKNESS] = resolvers.randartmax(5, 25),  }, },
}
newEntity{ theme={temporal=true}, name="resists pen temporal", points = 1, rarity = 16, level_range = {1, 50},
	wielder = { resists_pen = { [DamageType.TEMPORAL] = resolvers.randartmax(5, 25),  }, },
}

----------------------------------------------------------------
--- Misc Themes ---
----------------------------------------------------------------
----------------------------------------------------------------
-- Stats
----------------------------------------------------------------
newEntity{ theme={misc=true, physical=true}, name="stat str", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { inc_stats = { [Stats.STAT_STR] = resolvers.randartmax(1, 10), }, },
}
newEntity{ theme={misc=true, physical=true}, name="stat dex", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { inc_stats = { [Stats.STAT_DEX] = resolvers.randartmax(1, 10), }, },
}
newEntity{ theme={misc=true, spell=true}, name="stat mag", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { inc_stats = { [Stats.STAT_MAG] = resolvers.randartmax(1, 10), }, },
}
newEntity{ theme={misc=true, spell=true, mental=true}, name="stat wil", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { inc_stats = { [Stats.STAT_WIL] = resolvers.randartmax(1, 10), }, },
}
newEntity{ theme={misc=true, mental=true}, name="stat cun", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { inc_stats = { [Stats.STAT_CUN] = resolvers.randartmax(1, 10), }, },
}
newEntity{ theme={misc=true, physical=true}, name="stat con", points = 1, rarity = 7, level_range = {1, 50},
	wielder = { inc_stats = { [Stats.STAT_CON] = resolvers.randartmax(1, 10), }, },
}
----------------------------------------------------------------
-- Other
----------------------------------------------------------------
newEntity{ theme={misc=true, darkness=true}, name="see invisible", points = 1, rarity = 11, level_range = {1, 50},
	wielder = { see_invisible = resolvers.randartmax(3, 24), },
}
newEntity{ theme={misc=true, darkness=true}, name="infravision radius", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { infravision = resolvers.randartmax(1, 3), },
}
newEntity{ theme={misc=true, light=true}, name="lite radius", points = 1, rarity = 14, level_range = {1, 50},
	wielder = { lite = resolvers.randartmax(1, 3), },
}
newEntity{ theme={misc=true, mental=true}, name="telepathy", points = 60, rarity = 100, level_range = {1, 50},
	wielder = { esp_all = 1 },
}
newEntity{ theme={misc=true, mental=true}, name="orc telepathy", points = 2, rarity = 50, level_range = {1, 50},
	wielder = { esp = {["humanoid/orc"]=1}, },
}
newEntity{ theme={misc=true, mental=true}, name="dragon telepathy", points = 2, rarity = 40, level_range = {1, 50},
	wielder = { esp = {dragon=1}, },
}
newEntity{ theme={misc=true, mental=true}, name="demon telepathy", points = 2, rarity = 40, level_range = {1, 50},
	wielder = { esp = {["demon/minor"]=1, ["demon/major"]=1}, },
}

----------------------------------------------------------------
-- Melee damage Projection (rare)
----------------------------------------------------------------
newEntity{ theme={blight=true}, name="corrupted blood melee", points = 2, rarity = 25, level_range = {1, 50},
	wielder = { 
		melee_project = {[DamageType.ITEM_BLIGHT_DISEASE] = resolvers.randartmax(10, 20), }, 
		--ranged_project = {[DamageType.ITEM_BLIGHT_DISEASE] = resolvers.randartmax(10, 30), }, 
	}
}

newEntity{ theme={acid=true}, name="acid corrode melee", points = 2, rarity = 20, level_range = {1, 50},
	wielder = { melee_project = {[DamageType.ITEM_ACID_CORRODE] = resolvers.randartmax(15, 30), },
				--ranged_project = {[DamageType.ITEM_ACID_CORRODE] = resolvers.randartmax(15, 40), }, 
			}
	 }
newEntity{ theme={light=true}, name="light blind melee", points = 2, rarity = 20, level_range = {1, 50},
	wielder = { 
		melee_project = {[DamageType.ITEM_LIGHT_BLIND] = resolvers.randartmax(15, 30), }, 
		--ranged_project = {[DamageType.ITEM_LIGHT_BLIND] = resolvers.randartmax(15, 40), }, 
	},
}
newEntity{ theme={temporal=true}, name="temporal energize melee", points = 2, rarity = 20, level_range = {1, 50},
	wielder = { 
		melee_project = {[DamageType.ITEM_TEMPORAL_ENERGIZE] = resolvers.randartmax(10, 40), },
		--ranged_project = {[DamageType.ITEM_TEMPORAL_ENERGIZE] = resolvers.randartmax(10, 40), },  
	},
}
newEntity{ theme={lightning=true}, name="lightning daze melee", points = 2, rarity = 20, level_range = {1, 50},
	wielder = { 
		melee_project = {[DamageType.ITEM_LIGHTNING_DAZE] = resolvers.randartmax(15, 30), }, 
		--ranged_project = {[DamageType.ITEM_LIGHTNING_DAZE] = resolvers.randartmax(15, 40), }, 

	},
}
newEntity{ theme={antimagic=true}, name="manaburn melee", points = 2, rarity = 18, level_range = {1, 50},
	wielder = { 
		melee_project = {[DamageType.ITEM_ANTIMAGIC_MANABURN] = resolvers.randartmax(10, 20), }, 
		--ranged_project = {[DamageType.ITEM_ANTIMAGIC_MANABURN] = resolvers.randartmax(10, 40), }, 
	},
}
newEntity{ theme={nature=true, antimagic=true}, name="slime melee", points = 2, rarity = 18, level_range = {1, 50},
	wielder = { 
		melee_project = {[DamageType.ITEM_NATURE_SLOW] = resolvers.randartmax(15, 30), },
		--ranged_project = {[DamageType.ITEM_NATURE_SLOW] = resolvers.randartmax(15, 40), }, 

	},
}
newEntity{ theme={dark=true}, name="dark numbing melee", points = 2, rarity = 24, level_range = {1, 50},
	wielder = { 
		melee_project = {[DamageType.ITEM_DARKNESS_NUMBING] = resolvers.randartmax(15, 30), }, 
		--ranged_project = {[DamageType.ITEM_DARKNESS_NUMBING] = resolvers.randartmax(15, 40), }, 
	},

}

----------------------------------------------------------------
-- High level -- These help PCs (mostly) scale various important stats that tend to fall behind late game or are of particular importance late game
-- We can safely assume that highly scaled PCs use a lot of randart gear
----------------------------------------------------------------

-- The ultimate Ghoul buff
newEntity{ theme={physical=true, defense=true}, name="die at greater", points = 1, rarity = 15, level_range = {20, 50},
	wielder = { die_at = resolvers.randartmax(-20, -80), },
}

newEntity{ theme={defense=true, misc=true}, name="ignore crit greater", points = 1, rarity = 15, level_range = {30, 50},
	wielder = { ignore_direct_crits = resolvers.randartmax(5, 15), },
}

-- High level partly for power but mostly because you need to assemble some tools before this is useful
newEntity{ theme={defense=true, spell=true, temporal=true}, name="void", points = 2, rarity = 20, level_range = {20, 50},
	wielder = { defense_on_teleport = resolvers.randartmax(5, 15), 
				resist_all_on_teleport = resolvers.randartmax(5, 15), 
				effect_reduction_on_teleport = resolvers.randartmax(5, 15)
	},
}

newEntity{ theme={defense=true, physical=true}, name="save physical greater", points = 1, rarity = 18, level_range = {30, 50},
	wielder = { combat_physresist = resolvers.randartmax(10, 30), },
}
newEntity{ theme={defense=true, spell=true, antimagic=true}, name="save spell greater", points = 1, rarity = 18, level_range = {30, 50},
	wielder = { combat_spellresist = resolvers.randartmax(10, 30), },
}
newEntity{ theme={defense=true, mental=true}, name="save mental greater", points = 1, rarity = 18, level_range = {30, 50},
	wielder = { combat_mentalresist = resolvers.randartmax(10, 30), },
}


