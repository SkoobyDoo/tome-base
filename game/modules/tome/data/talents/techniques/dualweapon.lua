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

newTalent{
	name = "Dual Weapon Training",
	type = {"technique/dualweapon-training", 1},
	mode = "passive",
	points = 5,
	require = techs_dex_req1,
	-- called by  _M:getOffHandMult in mod\class\interface\Combat.lua
	-- This talent could probably use a slight buff at higher talent levels after diminishing returns kick in
	getoffmult = function(self,t)
		return	self:combatTalentLimit(t, 1, 0.65, 0.85)-- limit <100%
	end,
	info = function(self, t)
		return ([[Increases the damage of your off-hand weapon to %d%%.]]):format(100 * t.getoffmult(self,t))
	end,
}


newTalent{ -- Note: classes: Temporal Warden, Rogue, Shadowblade, Marauder
	name = "Dual Weapon Defense",
	type = {"technique/dualweapon-training", 2},
	mode = "passive",
	points = 5,
	require = techs_dex_req2,
	-- called by _M:combatDefenseBase in mod.class.interface.Combat.lua
	getDefense = function(self, t) return self:combatScale(self:getTalentLevel(t) * self:getDex(), 4, 0, 45.7, 500) end,
	getDeflectChance = function(self, t) --Chance to parry with an offhand weapon
		return self:combatLimit(self:getTalentLevel(t)*self:getDex(), 100, 15, 20, 60, 250) -- ~67% at TL 6.5, 55 dex
	end,
	getDeflectPercent = function(self, t) -- Percent of offhand weapon damage used to deflect
		return math.max(0, self:combatTalentLimit(self:getTalentLevel(t), 100, 10, 50))
	end,
	getDamageChange = function(self, t, fake)
		local dam,_,weapon = 0,self:hasDualWeapon()
		if not weapon or weapon.subtype=="mindstar" and not fake then return 0 end
		if weapon then
			dam = self:combatDamage(weapon.combat) * self:getOffHandMult(weapon.combat)
		end
		return t.getDeflectPercent(self, t) * dam/100
	end,
	-- deflect count handled in physical effect "PARRY" in mod.data.timed_effects.physical.lua
	getDeflects = function(self, t, fake)
		if not self:hasDualWeapon() and not fake then return 0 end
		return self:combatStatScale("cun", 1, 2.25)
	end,
	callbackOnActBase = function(self, t) -- refresh the buff each turn in mod.class.Actor.lua _M:actBase
		if self:hasDualWeapon() then
			self:setEffect(self.EFF_PARRY,1,{chance=t.getDeflectChance(self, t), dam=t.getDamageChange(self, t), deflects=t.getDeflects(self, t)})
		end
	end,
	on_unlearn = function(self, t)
		self:removeEffect(self.EFF_PARRY)
	end,
	info = function(self, t)
		return ([[You have learned to block incoming blows with your offhand weapon.
		When dual wielding, your defense is increased by %d.
		Up to %0.1f times a turn, you have a %d%% chance to parry up to %d damage (%d%% of your offhand weapon damage) from a melee attack.
		A successful parry reduces damage like armour (before any attack multipliers) and prevents critical strikes.  Partial parries have a proportionally reduced chance to succeed.  It is difficult to parry attacks from unseen attackers and you cannot parry with a mindstar.
		The defense and chance to parry improve with Dexterity.  The number of parries increases with Cunning.]]):format(t.getDefense(self, t), t.getDeflects(self, t, true), t.getDeflectChance(self,t), t.getDamageChange(self, t, true), t.getDeflectPercent(self,t))
	end,
}

newTalent{
	name = "Precision",
	type = {"technique/dualweapon-training", 3},
	mode = "sustained",
	points = 5,
	require = techs_dex_req3,
	no_energy = true,
	cooldown = 10,
	sustain_stamina = 20,
	tactical = { BUFF = 2 },
	on_pre_use = function(self, t, silent) if not self:hasDualWeapon() then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	getApr = function(self, t) return self:combatScale(self:getTalentLevel(t) * self:getDex(), 4, 0, 25, 500, 0.75) end,
	activate = function(self, t)
		local weapon, offweapon = self:hasDualWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Precision without dual wielding!")
			return nil
		end

		return {
			apr = self:addTemporaryValue("combat_apr",t.getApr(self, t)),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_apr", p.apr)
		return true
	end,
	info = function(self, t)
		return ([[You have learned to hit the right spot, increasing your armor penetration by %d when dual wielding.
		The Armour penetration bonus will increase with your Dexterity.]]):format(t.getApr(self, t))
	end,
}

newTalent{
	name = "Momentum",
	type = {"technique/dualweapon-training", 4},
	mode = "sustained",
	points = 5,
	cooldown = 30,
	sustain_stamina = 50,
	require = techs_dex_req4,
	tactical = { BUFF = 2 },
	on_pre_use = function(self, t, silent) if self:hasArcheryWeapon() or not self:hasDualWeapon() then if not silent then game.logPlayer(self, "You require two melee weapons to use this talent.") end return false end return true end,
	getSpeed = function(self, t) return self:combatTalentScale(t, 0.11, 0.40, 0.75) end,
	activate = function(self, t)
		local weapon, offweapon = self:hasDualWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Momentum without dual wielding melee weapons!")
			return nil
		end

		return {
			combat_physspeed = self:addTemporaryValue("combat_physspeed", t.getSpeed(self, t)),
			stamina_regen = self:addTemporaryValue("stamina_regen", -6),
		}
	end,
	deactivate = function(self, t, p)
		self:removeTemporaryValue("combat_physspeed", p.combat_physspeed)
		self:removeTemporaryValue("stamina_regen", p.stamina_regen)
		return true
	end,
	info = function(self, t)
		return ([[When dual wielding, increases attack speed by %d%%, but drains stamina quickly (-6 stamina/turn).]]):format(t.getSpeed(self, t)*100)
	end,
}

------------------------------------------------------
-- Attacks
------------------------------------------------------
newTalent{
	name = "Dual Strike",
	type = {"technique/dualweapon-attack", 1},
	points = 5,
	random_ego = "attack",
	cooldown = 6,
	stamina = 15,
	require = techs_dex_req1,
	requires_target = true,
	tactical = { ATTACK = { weapon = 1 }, DISABLE = { stun = 2 } },
	on_pre_use = function(self, t, silent) if not self:hasDualWeapon() then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	getStunDuration = function(self, t) return math.floor(self:combatTalentScale(t, 3, 7)) end,
	action = function(self, t)
		local weapon, offweapon = self:hasDualWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Dual Strike without dual wielding!")
			return nil
		end

		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end

		-- First attack with offhand
		local speed, hit = self:attackTargetWith(target, offweapon.combat, nil, self:getOffHandMult(offweapon.combat, self:combatTalentWeaponDamage(t, 0.7, 1.5)))

		-- Second attack with mainhand
		if hit then
			if target:canBe("stun") then
				target:setEffect(target.EFF_STUNNED, t.getStunDuration(self, t), {apply_power=self:combatAttack()})
			else
				game.logSeen(target, "%s resists the stunning strike!", target.name:capitalize())
			end

			-- Attack after the stun, to benefit from backstabs
			self:attackTargetWith(target, weapon.combat, nil, self:combatTalentWeaponDamage(t, 0.7, 1.5))
		end

		return true
	end,
	info = function(self, t)
		return ([[Attack with your offhand weapon for %d%% damage. If the attack hits, the target is stunned for %d turns, and you hit it with your mainhand weapon doing %d%% damage.
		The stun chance increases with your Accuracy.]])
		:format(100 * self:combatTalentWeaponDamage(t, 0.7, 1.5), t.getStunDuration(self, t), 100 * self:combatTalentWeaponDamage(t, 0.7, 1.5))
	end,
}

newTalent{
	name = "Flurry",
	type = {"technique/dualweapon-attack", 2},
	points = 5,
	random_ego = "attack",
	cooldown = 12,
	stamina = 15,
	require = techs_dex_req2,
	requires_target = true,
	tactical = { ATTACK = { weapon = 4 } },
	on_pre_use = function(self, t, silent) if not self:hasDualWeapon() then if not silent then game.logPlayer(self, "You require two weapons to use this talent.") end return false end return true end,
	action = function(self, t)
		local weapon, offweapon = self:hasDualWeapon()
		if not weapon then
			game.logPlayer(self, "You cannot use Flurry without dual wielding!")
			return nil
		end

		local tg = {type="hit", range=self:getTalentRange(t)}
		local x, y, target = self:getTarget(tg)
		if not x or not y or not target then return nil end
		if core.fov.distance(self.x, self.y, x, y) > 1 then return nil end
		self:attackTarget(target, nil, self:combatTalentWeaponDamage(t, 0.4, 1.0), true)
		self:attackTarget(target, nil, self:combatTalentWeaponDamage(t, 0.4, 1.0), true)
		self:attackTarget(target, nil, self:combatTalentWeaponDamage(t, 0.4, 1.0), true)

		return true
	end,
	info = function(self, t)
		return ([[Lashes out with a flurry of blows, hitting your target three times with each weapon for %d%% damage.]]):format(100 * self:combatTalentWeaponDamage(t, 0.4, 1.0))
	end,
}

newTalent{
	name = "Heartseeker",
	type = {"technique/dualweapon-attack", 3},
	points = 5,
	random_ego = "attack",
	cooldown = 8,
	stamina = 18,
	require = techs_dex_req3,
	getDamage = function (self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.7) end,
	getCrit = function(self, t) return self:combatTalentLimit(t, 50, 10, 30) end,
	target = function(self, t) return {type="bolt", range=self:getTalentRange(t)} end,
	range = function(self, t) return math.ceil(self:combatTalentLimit(t, 10, 3, 5)) end,
	requires_target = true,
	tactical = { ATTACK = { weapon = 2 }, CLOSEIN = 2 },
	on_pre_use = function(self, t, silent) 
		if not self:hasDualWeapon() then 
			if not silent then 
			game.logPlayer(self, "You require two weapons to use this talent.") 
		end 
			return false 
		end
		if self:attr("never_move") then return false end
		return true 
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y, target = self:getTarget(tg)
		if not target or not self:canProject(tg, x, y) then return nil end

		if core.fov.distance(self.x, self.y, x, y) > 1 then
			local block_actor = function(_, bx, by) return game.level.map:checkEntity(bx, by, Map.TERRAIN, "block_move", self) end
			local linestep = self:lineFOV(x, y, block_actor)
	
			local tx, ty, lx, ly, is_corner_blocked
			repeat  -- make sure each tile is passable
				tx, ty = lx, ly
				lx, ly, is_corner_blocked = linestep:step()
			until is_corner_blocked or not lx or not ly or game.level.map:checkAllEntities(lx, ly, "block_move", self)
	
			if not tx or not ty or core.fov.distance(x, y, tx, ty) > 1 then return nil end
	
			local ox, oy = self.x, self.y
			self:move(tx, ty, true)
			if config.settings.tome.smooth_move > 0 then
				self:resetMoveAnim()
				self:setMoveAnim(ox, oy, 8, 5)
			end
		end
		
		-- Attack
		if not core.fov.distance(self.x, self.y, x, y) == 1 then return nil end
		
		local critstore = self.combat_critical_power or 0
		self.combat_critical_power = nil
		self.combat_critical_power = critstore + t.getCrit(self,t)
			
		self:attackTarget(target, nil, t.getDamage(self,t), true)
		
		self.combat_critical_power = nil
		self.combat_critical_power = critstore

		

		return true
	end,
	info = function(self, t)
		dam = t.getDamage(self,t)*100
		crit = t.getCrit(self,t)
		return ([[Swiftly leap to your target and strike at their vital points with both weapons, dealing %d%% weapon damage. This attack deals %d%% increased critical strike damage.]]):
		format(dam, crit)
	end,
}

newTalent{
	name = "Whirlwind",
	type = {"technique/dualweapon-attack", 4},
	points = 5,
	random_ego = "attack",
	cooldown = 10,
	stamina = 30,
	require = techs_dex_req4,
	tactical = { ATTACKAREA = { weapon = 2 }, CLOSEIN = 1.5 },
	range = function(self, t) if self:getTalentLevel(t) >=3 then return 3 else return 2 end end,
	radius = 1,
	requires_target = true,
	target = function(self, t)
		return  {type="beam", range=self:getTalentRange(t), talent=t }
	end,
	getDamage = function (self, t) return self:combatTalentWeaponDamage(t, 1.0, 1.6) end,
	proj_speed = 20, --not really a projectile, so make this super fast
	on_pre_use = function(self, t, silent) 
		if not self:hasDualWeapon() then 
			if not silent then 
			game.logPlayer(self, "You require two weapons to use this talent.") 
		end 
			return false 
		end
		if self:attr("never_move") then return false end
		return true 
	end,
	action = function(self, t)
		local tg = self:getTalentTarget(t)
		local x, y = self:getTarget(tg)
		if not x or not y then return nil end
		local _ _, x, y = self:canProject(tg, x, y)
		if core.fov.distance(self.x, self.y, x, y) > self:getTalentRange(t) or not self:hasLOS(x, y) then return nil end
		if target or game.level.map:checkEntity(x, y, Map.TERRAIN, "block_move", self) then return nil end

		self:projectile(tg, x, y, function(px, py, tg, self)
			local aoe = {type="ball", radius=1, friendlyfire=true, selffire=false, talent=t, display={ } }
			
			self:project(aoe, px, py, function(tx, ty)
				local target = game.level.map(tx, ty, engine.Map.ACTOR)
				if not target then return end
				if target.turn_procs.whirlwind then return end
				target.turn_procs.whirlwind = true
				local oldlife = target.life
				local hit = self:attackTarget(target, nil, t.getDamage(self,t), true)
				local life_diff = oldlife - target.life
				if life_diff > 0 and target:canBe('cut') then
					target:setEffect(target.EFF_CUT, 5, {power=life_diff * 0.1, src=self, apply_power=self:combatPhysicalpower(), no_ct_effect=true})
				end
			end)
			
		end)
		
		local mx, my = util.findFreeGrid(x, y, 1, true, {[Map.ACTOR]=true})
		if not mx or not mx then 
			game.logSeen(self, "You cannot jump to that location.")
			return nil 
		end

		self:move(mx, my, true)	
		
		return true
	end,
	info = function(self, t)
		local damage = t.getDamage(self, t)
		local range = self:getTalentRange(t)
		return ([[You quickly move 2 tiles (or 3 at talent level 3 and above) to the target location, leaping around and over anyone in your path and striking any adjacent enemies with both weapons for %d%% weapon damage. All those struck will bleed for 50%% of the damage dealt over 5 turns.]]):
		format(damage*100)
	end,
}

