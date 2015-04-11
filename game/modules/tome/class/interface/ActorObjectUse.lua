-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2015 Nicolas Casalini
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

require "engine.class"
--local Chat = require "engine.Chat"
--local Dialog = require "engine.ui.Dialog"
local Talents = require "engine.interface.ActorTalents"
local ActorInventory = require "engine.interface.ActorInventory"

module(..., package.seeall, class.make)
--[[
--- Interface for NPC (non-player controlled actors) to use objects with activatable powers
--  When a usable object is added to an Actor inventory, the Actor may get a talent that can be activated to use the power.
--  This talent is similar to normal talents, but translates the object definition as needed for NPC use.
--	The activatable object may have either .use_power (most uniquely defined powers), .use_simple (uniquely defined, mostly for consumables), or .use_talent (many charms and other objects that activate a talent as their power)
--	Energy use matches the object (based on standard action speed)

Objects with a .use_power field are usable unless the .no_npc_use flag is set.
For these items:
	use_power = {
		name = constant or function(object, who), description of the power for the user
		power = number, power points used when activated
		use = function(object, who), called when the object is used, should include all effects and special log messages
		target = table or function(object, who), targeting parameters (interpreted by engine.Target:getType and used by the AI when targeting the power
		requires_target<optional> = boolean or function(object, who), if true, the ai will not use the power if it's target is out of range, should generally be false for powers that target the user
		tactical = {TACTIC1 = constant or function(who, t, aitarget),
				TACTIC2 = constant or function(who, t, aitarget), ...} tactics table for interpretation by by the tactical AI (mod.ai.tactical.lua), uses the same format as talents, t is the talent defined here
		range = number or function(object, who), optional should be defined here to allow the AI to determine the range of the power for targeting other Actors with the power, defaults to 1
		radius = number or function(object, who), as range, defaults to 0
		on_pre_use<optional> = function(obj, who), optional function (similar to talent.on_pre_use, to test if the power is usable via the talents defined here (return true to allow use)
		on_pre_use_ai<optional> = function(obj, who), like on_pre_use, but only called by the AI
	}
	The raw talent level of the activation talent(defined here) equals the material level of the object.

Objects with a .use_simple field (uniquely defined, mostly for consumables), are not usable unless .allow_npc_use is true or the .tactical field is defined.
They otherwise use the same format as .use_power.

Objects with a .use_talent field use a defined talent as their power.  They are usable if .allow_npc_use is true or talent.no_npc_use is not true
For these items:
	use_talent = {
		id = string, talent_id to use (i.e. Talents.T_ILLUMINATE)
		level = number, raw talent level for the power (uses the user's mastery levels)
		power = number, power points used when activated
		
		on_pre_use<optional> = function(who, t), override talent.on_pre_use function
		on_pre_use_ai<optional> = function(who, t), override talent.on_pre_use_ai function
	
		message<optional> = function(who, t), override talent use message if any
	}
	The raw talent level of the activation talent equals the talent level specified in use_talent.
	
If more than one of the fields is defined only one will be used: use_power before use_simple before use_talent
	
--]]

local base_talent_name = "Activate Object"
_M.max_object_use_talents = 50 --(allows for approximately 15 items worn and 35 items carried.)

-- returns tid, short_name
local useObjectTalentId = function(base_name, num)
	num = num or 1
	base_name = base_name or base_talent_name
	local short_name = base_name:upper():gsub("[ ]", "_").."_"..num
	return "T_"..short_name, short_name
end

--- Init object use tables
--	Note: this applies to all actors but is only used for npcs (including uncontrolled party members)
function _M:init(t)
	self.useable_objects_data = self.useable_objects_data or {}
end

-- call a function within an object talent
-- returning values from the object data table, (possibly defaulting to those specified in a talent definition if appropriate)
function _M:callObjectTalent(tid, what, ...)
	local data = self.useable_objects_data and self.useable_objects_data[tid]
	if not data then return end
	local item = data[what]
	
	if data.tid then -- defined by a talent, functions(self, t, ...) format (may be overridden)
--	if type(data[what]) == "function" then
		local t = self:getTalentFromId(data.tid)
		item = item or t[what]
		if type(item) == "function" then
--			local t = self:getTalentFromId(data.tid)

			if data.old_talent_level then self.talents[data.tid] = data.old_talent_level end
			data.old_talent_level = self.talents[data.tid]; self.talents[data.tid] = data.talent_level
--game.log("#YELLOW#[callObjectTalent] %s calculating use_talent (%s) %s for talent level %0.1f", self.name, t.name, what, self:getTalentLevel(t))
print(("#YELLOW#[callObjectTalent] %s calculating use_talent (%s) %s for talent level %0.1f"):format(self.name, t.name, what, self:getTalentLevel(t)))
			local ret = item(self, t, ...)
			self.talents[data.tid] = data.old_talent_level; data.old_talent_level = nil
			return ret
		else
			return item
		end
	else -- defined in object code, functions (obj, who, ...) format
		if type(item) == "function" then
			return item(data.obj, self, ...)
		else
			return item
		end
	end
end

-- base talent template
_M.useObjectBaseTalent ={
	name = base_talent_name,
	type = {"misc/objects", 1},
	points = 1,
--	hide = "always",
	never_fail = true, -- most actor status effects will not prevent use
	innate = true, -- make sure this talent can't be put on cooldown by other talents or effects
	display_name = function(self, t)
		local data = self.useable_objects_data[t.id]
		if not (data and data.obj and data.obj:isIdentified()) then return "Activate an object" end
		local objname = data.obj:getName({no_add_name = true, do_color = true})
		return "Activate: "..objname
	end,
	no_message = true, --messages handled by object code or action function
	is_object_use = true, -- Flag for npc control and masking from player
	no_energy = function(self, t) -- energy use based on object
		return self:callObjectTalent(t.id, "no_energy")
	end,
	getObject = function(self, t)
		return self.useable_objects_data and self.useable_objects_data[t.id] and self.useable_objects_data[t.id].obj
	end,
--	no_energy = true,
	on_pre_use = function(self, t, silent, fake) -- test for item useability, not on COOLDOWN, etc.
		if self.no_inventory_access then return end
		local data = self.useable_objects_data[t.id]
		if not data then
			print("[ActorObjectUse] ERROR: Talent ", t.name, " has no object data")
--game.log("#YELLOW#[pre use] ERROR No object use data found for talent %s", t.name)
			return false
		end
		local o = data.obj
		if not o then
			print("[ActorObjectUse] ERROR: Talent ", t.name, " has no object")
--game.log("#YELLOW#[pre use] no object for talent %s", t.name)
			return false
		end
		local cooldown = o:getObjectCooldown(self) -- disable while object is cooling down
		if cooldown and cooldown > 0 then
--game.log("#YELLOW#[pre use] object %s is cooling down", o.name)
			return false
		end
		local useable, msg = o:canUseObject(who)
		if not useable and not (silent or fake) then
			game.logPlayer(self, msg)
			print("[ActorObjectUse] Talent ", t.name, "(", o.name, ") is not usable ", msg)
--game.log("#YELLOW#[pre use] object %s is not useable (%s)", o.name, msg)
			return false
		end
		if data.on_pre_use or (data.tid and self.talents_def[data.tid].on_pre_use) then
			return self:callObjectTalent(t.id, "on_pre_use", silent, fake)
		end
		return true 
--[[
--		if (data.on_pre_use and not data.on_pre_use(o, self, silent, fake)) then
		if data.on_pre_use then
	--game.log("#YELLOW#[pre use] %s: Object %s not usable due to on_pre_use check", self.name, o.name)
--				return false
			if data.tid then -- test talent on_pre_use check function overriding talent level)
				local tal = self:getTalentFromId(data.tid)
				if tal.on_pre_use then
	--				if data.talent_override then self.talents[data.tid] = data.old_talent_level end -- safety check if talent crashed previously
	--				data.talent_override = true
					if data.old_talent_level then self.talents[data.tid] = data.old_talent_level end -- safety check if talent crashed previously
					data.old_talent_level = self.talents[data.tid]
					self.talents[data.tid] = data.talent_level
					local ret = not tal.on_pre_use(self, tal, silent, fake)
					self.talents[data.tid] = data.old_talent_level
	--				data.talent_override = nil
					data.old_talent_level = nil
					if ret then return false end
				end
			else
				return data.on_pre_use(o, self, silent, fake)
			end
		end
--]]
	end,
	on_pre_use_ai = function(self, t, silent, fake)
		local data = self.useable_objects_data[t.id]
		if data.on_pre_use_ai or (data.tid and self.talents_def[data.tid].on_pre_use_ai) then
			return self:callObjectTalent(t.id, "on_pre_use_ai", silent, fake)
		end
		return true
	end,
	mode = "activated",  -- Assumes all abilities are activated
--	cooldown = function(self, t)
--		return self:callObjectTalent(t.id, "cooldown")
--	end,
	range = function(self, t)
		return self:callObjectTalent(t.id, "range") or 1
	end,
	radius = function(self, t)
		return self:callObjectTalent(t.id, "radius") or 0
	end,
	proj_speed = function(self, t) -- remove?
		return self:callObjectTalent(t.id, "proj_speed")
	end,
	requires_target = function(self, t)
		return self:callObjectTalent(t.id, "requires_target")
	end,
	target = function(self, t)
		return self:callObjectTalent(t.id, "target")
	end,
	action = function(self, t)
		local data = self.useable_objects_data[t.id]
game.log("#YELLOW#Pre Action Object (%s [uid %d]) Activation by %s [uid %d, energy %d]", data.obj.name, data.obj.uid, self.name, self.uid, self.energy.value)
		local obj, inven = data.obj, data.inven_id
		local ret
--game.log("#YELLOW#Actor %s Pre Use Object %s, ", self.name, obj.name)
		local co = coroutine.create(function()
--game.log("#YELLOW#Coroutine Pre Use Object (%s [uid %d]) Activation by %s [uid %d, energy %d]", data.obj.name, data.obj.uid, self.name, self.uid, self.energy.value)
			if data.tid then -- replaces normal talent use message
				game.logSeen(self, "%s activates %s %s!", self.name:capitalize(), self:his_her(), data.obj:getName({no_add_name=true, do_color = true}))
				local msg = self:useTalentMessage(self:getTalentFromId(data.tid))
				if msg then game.logSeen(self, "%s", msg) end
			end
			ret = obj:use(self, nil, data.inven_id, slot)
print(self.name, self.uid, " return table:")
table.print(ret)
			if ret and ret.used then
game.log("#YELLOW#Post Use Object: Actor %s (%d energy) Object %s, ", self.name, self.energy.value, obj.name)
				if ret.destroy then -- destroy the item after use
					local _, item = self:findInInventoryByObject(self:getInven(data.inven_id), data.obj)
					if item then self:removeObject(data.inven_id, item) end
				end
			else
game.log("#YELLOW#Post No Use Object: Actor %s (%d energy) Object %s, ", self.name, self.energy.value, obj.name)				return
			end
		end)
		coroutine.resume(co)
	end,
	info = function(self, t) -- should these talents be visible to the player?
		local data = self.useable_objects_data[t.id]
		if not (data and data.obj and data.obj:isIdentified()) then return "Activate an object." end
		local objname = (data and data.obj and data.obj:getName({do_color = true})) or "(no object)"
		local usedesc = (data and data.obj and data.obj:isIdentified() and data.obj:getUseDesc(self)) or ""
		return ([[Use %s:

%s]]):format(objname, usedesc)
	end,
--	short_info = function(self, t)
--		return ([[Use this object.]]):format()
--	end,
}

-- define object use talent based on number
-- defines a new talent if it doesn't already exist
function _M:useObjectTalent(base_name, num)
	base_name = base_name or base_talent_name
	local tid, short_name = useObjectTalentId(base_name, num)
	local t = Talents:getTalentFromId(tid)
	if not t then -- define a new talent
		t = table.clone(self.useObjectBaseTalent)
		t.id = tid
		t.short_name = short_name
		t.name = t.name .. "("..num..")"
		print("ActorObjectUse] Defining new Talent ", short_name)
		Talents:newTalent(t)
		-- define this after parsing in data.talents.lua
		t.tactical = function(self, t)
			return self:callObjectTalent(t.id, "tactical")
		end
	end
	return t.id, t
end

--- Set up an object for actor use via talent interface
-- @param o = object to set up to use
-- @param inven_id = id of inventory holding object
-- @param slot = inventory position of object
-- @param returns false or o, talent id, talent definition, talent level if the item is usable
function _M:useObjectEnable(o, inven_id, slot, base_name)
	if not o:canUseObject() or o.quest or o.lore then -- don't enable certain objects (lore, quest)
game.log("#YELLOW#[ActorObjectUse] Object %s is ineligible for talent interface", o.name)
		return
	end	
	print(("[ActorObjectUse] useObjectEnable: o: %s, inven/slot = %s/%s"):format(o and o.name or "none", inven_id, slot))
	self.useable_objects_data = self.useable_objects_data or {} -- for older actors
	-- Check allowance
	local data = self.useable_objects_data
	if data[o] and o == data[data[o]].obj then -- already enabled
		return o, data[o], self:getTalentFromId(data[o])
	end
	local tid, t, place
	if not inven_id then -- find the object if needed
		place, inven_id, slot = self:findInAllInventoriesByObject(o)
	end
	if o:wornInven() and not o.wielded and not o.use_no_wear then
		return false
	end

	local i = #data + 1
	local talent_level = false
	
	if i <= self.max_object_use_talents then --find an unused talentid
		-- find the next open object use talent
		for j = 1, self.max_object_use_talents do
			tid = useObjectTalentId(base_name, j)
			if not self:knowTalent(tid) then break end
		end
		talent_level = self:useObjectSetData(tid, o)
		if not talent_level then return false end --includes checks for npc useability
		data[i] = tid
		data[tid].inven_id = inven_id
		data[tid].slot = slot
		self:learnTalent(tid, true, talent_level)
		self.talents[tid] = talent_level
	else
		return false
	end
-- temporary hotkeys for testing
	t=self:getTalentFromId(tid)
	-- Hotkey
	if oldpos then
		local name = t.short_name
		for i = 1, 12 * self.nb_hotkey_pages do
			if self.hotkey[i] and self.hotkey[i][1] == "talent" and self.hotkey[i][2] == "T_"..name then self.hotkey[i] = nil end
		end
		self.hotkey[oldpos] = {"talent", "T_"..name}
	end

	return o, tid, t, talent_level
end

-- disable object use (when object is removed from inventory)
function _M:useObjectDisable(o, inven_id, slot, tid, base_name)
--game.log("#YELLOW# useObjectDisable: o: %s, inven/slot = %s/%s {tid = %s}", o and o.name or "none", inven_id, slot, tid)
	base_name = base_name or base_talent_name
	if not (o or tid) then --clear all object use data and unlearn all object use talents
		for i = 1, self.max_object_use_talents do
			tid = useObjectTalentId(base_name, i)
			self:unlearnTalentFull(tid)
		end
		self.useable_objects_data = {}
		return
	end
	
	if o then
		tid = tid or self.useable_objects_data[o]
	else
		o = self.useable_objects_data[tid] and self.useable_objects_data[tid].obj
	end
	if o then self.useable_objects_data[o]=nil end
	--auto use/confirmable  talents?
	--self.talents_auto
	--self.talents_confirm_use
	if tid then
		if self.useable_objects_data[tid].old_talent_level then self.talents[tid] = self.useable_objects_data[tid].old_talent_level end
		self.useable_objects_data[tid]=nil
		table.removeFromList(self.useable_objects_data, tid)
		self.talents[tid] = 1
	end
	self:unlearnTalentFull(tid)
end

local lowerTacticals = function(tacticals) --convert tactical tables to lower case
	local tacts = {}
	for tact, val in pairs(tacticals) do
		tact = tact:lower()
		tacts[tact] = val
	end
	return tacts
end

-- function to call base talent-defined tactical functions from the object talent (with overridden talent level)
local AOUtactical_translate = function(self, t, aitarget, tactic) -- called by mod.ai.tactical
	local data = self.useable_objects_data[t.id]
	local tal = self.talents_def[data.tid]
	if data.old_talent_level then self.talents[tal.id]=data.old_talent_level end -- recover if talent previously crashed
	data.old_talent_level = self.talents[tal.id]; self.talents[tal.id]=data.talent_level
	local ret = tal.tactical and tal.tactical[tactic] and tal.tactical[tactic](self, tal, aitarget)
	self.talents[tal.id]=data.old_talent_level;	data.old_talent_level = nil
	return ret
end

--- sets up the object data for the talent
--	@param tid = the talent id
--	@param o = the usable object
--	o.use_talent is usable unless the talent.no_npc_use flag is set
--	o.use_power is usable unless use_power.no_npc_use is set
--  o.use_simple is usable if use_simple.allow_npc_use is set or use_simple.tactical is defined
--	returns raw talent level if successful
function _M:useObjectSetData(tid, o)
	self.useable_objects_data[tid] = {obj = o}
	self.useable_objects_data[o] = tid
	local data = self.useable_objects_data[tid]
	local ok = false
	local power
	if o.use_power then -- power is a general power
		power = o.use_power
		if not power.no_npc_use then
			ok = o.material_level or 1
		end
	elseif o.use_simple then -- Generally for consumables
		power = o.use_simple
		if power.allow_npc_use or power.tactical then
			ok = o.material_level or 1
		end
	elseif o.use_talent then -- power is a talent
		local t = self:getTalentFromId(o.use_talent.id)
		local use_talent = o.use_talent
		if t and t.mode == "activated" and (use_talent.allow_npc_use or not t.no_npc_use) then
			data.tid = o.use_talent.id
			data.talent_level = use_talent.level
			
			data.on_pre_use = use_talent.on_pre_use
			data.on_pre_use_ai = use_talent.on_pre_use_ai
			-- tactical table override not currently supported
			data.tactical = use_talent.tactical or table.clone(t.tactical)
--			if use_talent.tactical then
--				data.tactical = use_talent.tactical
--			else
--				data.tactical = table.clone(t.tactical)
				-- convert tactical table functions to use the talent reference
			if type(data.tactical) == "table" then
--				data.tactical_functions = {}
				for tact, val in pairs(data.tactical) do
					if type(val) == "function" then
---						data.tactical_functions[tact] = val
						data.tactical[tact] = AOUtactical_translate
					end
				end
			end

--			data.target = t.target
			ok = data.talent_level
		end
	else
		print("[ActorObjectUse]: ERROR, object", o.name, o.uid, "has no usable power")
	end
	data.no_energy = o.use_no_energy -- talent speed determined by object
	if not ok then
		self.useable_objects_data[o] = nil
		data = nil
	elseif power then
		data.on_pre_use = power.on_pre_use
		data.on_pre_use_ai = power.on_pre_use_ai
		data.range = power.range
		data.radius = power.radius
		data.target = power.target
		data.requires_target = power.requires_target
		if power.tactical then 
			data.tactical = lowerTacticals(power.tactical)
		end
	end
	return ok -- the raw talent level to use for ai
end
