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

--- Interface for NPC (non-player controlled actors) to use objects with activatable powers
--  When a usable object is added to an Actor inventory, the Actor may get a talent that can be activated to use the power.
--  This talent is similar to normal talents, but translates the object definition as needed for NPC use.
--  objects with a .use_power (most uniquely defined powers) are usable unless the .no_npc_use flag is set
--  objects with a .use_simple field (mostly consumables) are not usable unless the .allow_npc_use flag is set or the .tactical field is defined
--  objects with a .use_talent field (many charms and artifacts) are usable so long as the talent definition does not have the .no_npc_use flag set
--	Energy use matches the object (based on standard action speed)
--the new talent .on_pre_use function handles checking for object cooldowns inventory access and t.on_pre_use (for talent-based powers)
-- Important fields defined within object.use_simple or object.use_power:
--	.tactical = tactics table for interpretation by the tactical ai, subfields may be functions(who, t, aitarget) where who = object user, t = talent used (defined here), aitarget = who's (actor) target
--		This should be defined for NPC's to use the object intelligently
--	.on_pre_use = function(obj, who) that must return true for the object to be used.
--	.range = range of the ability (defaults to 1, may be a function(self, t))
-- 	.radius = radius of ability (defaults to 0, may be a function(self, t))
--	.target = targeting parameters (table, may be a function(self, t)), interpreted by engine.Target:getType
--	.requires_target, if true, don't use the object if the target is beyond radius + range

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

function _M:callObjectTalent(tid, what)
	local data = self.useable_objects_data and self.useable_objects_data[tid]
	if not data then
		return
	elseif type(data[what]) == "function" then
--			local t = self:getTalentFromId(data.tid)
--game.log("#YELLOW# calculating use_talent %s for data %s", what, tostring(data))
			if data.tid then 
				local old_level = self.talents[data.tid]; self.talents[data.tid] = data.talent_level
				local ret = self:callTalent(data.tid, what)
				self.talents[data.tid] = old_level
				return ret
			else
				return data[what](data.obj, self)
			end
	else
		return data[what]
	end
end

_M.useObjectBaseTalent ={
	name = base_talent_name,
	type = {"misc/objects", 1},
	points = 1,
--	hide = "always",
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
--	on_pre_use_ai = function(self, ab, silent, fake)
	on_pre_use = function(self, t, silent, fake) -- test for item useability, not on cooldown, etc.
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
		local cooldown = o:getObjectCooldown(self)
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

		if (data.on_pre_use and not data.on_pre_use(o, self, silent, fake)) then
	--game.log("#YELLOW#[pre use] %s: Object %s not usable due to on_pre_use check", self.name, o.name)
				return false
		elseif data.tid then -- test talent on_pre_use check function
			local tal = self:getTalentFromId(data.tid)
			if tal.on_pre_use then
				if data.talent_override then self.talents[data.tid] = data.old_talent_level end -- safety check if talent crashed previously
				data.talent_override = true
				data.old_talent_level = self.talents[data.tid]
				self.talents[data.tid] = data.talent_level
				local ret = not tal.on_pre_use(self, tal, silent, fake)
				self.talents[data.tid] = data.old_talent_level
				data.talent_override = nil
				if ret then return false end
			end
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
	proj_speed = function(self, t)
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
game.log("#YELLOW#Pre Use Object (%s [uid %d]) Activation by %s [uid %d, energy %d]", data.obj.name, data.obj.uid, self.name, self.uid, self.energy.value)
		local obj, inven = data.obj, data.inven_id
		local ret
--game.log("#YELLOW#Actor %s Pre Use Object %s, ", self.name, obj.name)
		local co = coroutine.create(function()
			ret = obj:use(self, nil, data.inven_id, slot)
			if ret and ret.used then
print(self.name, self.uid, " return table:")
table.print(ret)
				if data.tid then -- replaces normal talent use message
					game.logSeen(self, "%s activates %s %s!", self.name:capitalize(), self:his_her(), data.obj:getName({no_add_name=true, do_color = true}))
					local msg = self:useTalentMessage(self:getTalentFromId(data.tid))
					if msg then game.logSeen(self, "%s", msg) end
				end
game.log("#YELLOW#Post Use Object: Actor %s (%d energy) Object %s, ", self.name, self.energy.value, obj.name)
				if ret.destroy then -- destroy the item after use
					local _, item = self:findInInventoryByObject(self:getInven(data.inven_id), data.obj)
					if item then self:removeObject(data.inven_id, item) end
				end
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
--print("[ActorObjectUse] Checking Talent ", short_name)
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
-- @param returns o, talent id, talent definition if the item is usable
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

	if i <= self.max_object_use_talents then --find an unused talentid
		-- find the next open object use talent
		for j = 1, self.max_object_use_talents do
			tid = useObjectTalentId(base_name, j)
			if not self:knowTalent(tid) then break end
		end
		if not self:useObjectSetData(tid, o) then return false end --includes checks for npc useability
		data[i] = tid
		data[tid].inven_id = inven_id
		data[tid].slot = slot
		self:learnTalent(tid, true, o.material_level or 1)
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

	return o, tid, t
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
	if tid then
		self.useable_objects_data[tid]=nil
		table.removeFromList(self.useable_objects_data, tid)
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

--- sets up the object data for the talent
--	@param tid = the talent id
--	@param o = the usable object
--	o.use_talent is usable unless the talent.no_npc_use flag is set
--	o.use_power is usable unless use_power.no_npc_use is set
--  o.use_simple is usable if use_simple.allow_npc_use is set or use_simple.tactical is defined
--	returns ok if successful
function _M:useObjectSetData(tid, o)
	self.useable_objects_data[tid] = {obj = o}
	self.useable_objects_data[o] = tid
	local data = self.useable_objects_data[tid]
	local ok = false
	local power
	if o.use_power then -- power is a general power
		power = o.use_power
		if not power.no_npc_use then --tactical check here?
			ok = true
		end
	elseif o.use_simple then -- Generally for consumables
		power = o.use_simple
		if power.allow_npc_use or power.tactical then
			ok = true
		end
	elseif o.use_talent then -- power is a talent
--game.log("#YELLOW# setting up use_talent for %s", o.name)
		local t = self:getTalentFromId(o.use_talent.id)
		if t and t.mode == "activated" and not t.no_npc_use then
			data.tid = o.use_talent.id
			data.talent_level = o.use_talent.level
			
			data.message = t.message
			data.range = t.range

--			data.no_energy = o.use_no_energy or t.no_energy -- energy cost specified in item overrides talent
			data.radius = t.radius
			data.requires_target = t.requires_target
			data.proj_speed = t.proj_speed
			data.cooldown = t.cooldown
			data.tactical = t.tactical
			data.target = t.target
			data.talent_cooldown = o.talent_cooldown
			ok = true
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
		data.range = power.range
		data.radius = power.radius
		data.target = power.target
		data.requires_target = power.requires_target
		if power.tactical then 
			data.tactical = lowerTacticals(power.tactical)
		end
	end
	return ok
end
