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
Interface for NPC (non-player controlled actors) to use objects with activatable powers
When a usable object is added to an Actor inventory, the Actor may get a talent that can be activated to use the power.
This talent is similar to normal talents, but translates the object definition as needed for NPC use.
The activatable object may have either .use_power (most uniquely defined powers), .use_simple (uniquely defined, mostly for consumables), or .use_talent (many charms and other objects that activate a talent as their power) If more than one of the fields is defined only one will be used: use_power before use_simple before use_talent.
	Energy use matches the object (based on standard action speed)

Objects with a .use_power field are usable unless the .no_npc_use (which may be a function(obj, who)) is true.
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

Objects with a .use_simple field (uniquely defined, mostly for consumables), are not usable unless .allow_npc_use (which can be a function(obj, who) is true or the .tactical field is defined.
They otherwise use the same format as .use_power.

Objects with a .use_talent field use a defined talent as their power.  They are usable if .allow_npc_use (which can be a function(obj, who)) is true or talent.no_npc_use (may be a function(obj, who) )is not true
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
	
--]]

local base_talent_name = "Activate Object"
_M.max_object_use_talents = 50 --(allows for approximately 15 items worn and 35 items carried.)

--_M.max_object_use_talents = 3

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
	self.object_talent_data = self.object_talent_data or {}
end

-- call a function within an object talent
-- returning values from the object data table, (possibly defaulting to those specified in a talent definition if appropriate)
function _M:callObjectTalent(tid, what, ...)
	local data = self.object_talent_data and self.object_talent_data[tid]
	if not data then return end
	local item = data[what]
	
	if data.tid then -- defined by a talent, functions(self, t, ...) format (may be overridden)
		local t = self:getTalentFromId(data.tid)
		item = item or t[what]
		if type(item) == "function" then
			if data.old_talent_level then self.talents[data.tid] = data.old_talent_level end
			data.old_talent_level = self.talents[data.tid]; self.talents[data.tid] = data.talent_level
print(("[callObjectTalent] %s calculating use_talent (%s) %s for talent level %0.1f"):format(self.name, t.name, what, self:getTalentLevel(t)))
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

-- base Object Activation talent template
_M.useObjectBaseTalent ={
	name = base_talent_name,
	type = {"misc/objects", 1},
	points = 1,
--	hide = "always",
	never_fail = true, -- most actor status effects will not prevent use
	innate = true, -- make sure this talent can't be put on cooldown by other talents or effects
	display_name = function(self, t)
		local data = self.object_talent_data[t.id]
		if not (data and data.obj and data.obj:isIdentified()) then return "Activate an object" end
		local objname = data.obj:getName({no_add_name = true, do_color = true})
		return "Activate: "..objname
	end,
	no_message = true, --messages handled by object code or action function
	is_object_use = true, -- flag for npc control and masking from player
	no_energy = function(self, t) -- energy use based on object
		return self:callObjectTalent(t.id, "no_energy")
	end,
--	cooldown = function(self, t) return 1 end ,
--	fixed_cooldown = true,
	getObject = function(self, t)
		return self.object_talent_data and self.object_talent_data[t.id] and self.object_talent_data[t.id].obj
	end,
	on_pre_use = function(self, t, silent, fake) -- test for item usability, not on COOLDOWN, etc.
		if self.no_inventory_access then return end
		local data = self.object_talent_data[t.id]
		if not data then
			print("[ActorObjectUse] ERROR: Talent ", t.name, " has no object data")
			return false
		end
		local o = data.obj
		if not o then
			print("[ActorObjectUse] ERROR: Talent ", t.name, " has no object")
			return false
		end
		local cooldown = o:getObjectCooldown(self) -- disable while object is cooling down
		if cooldown and cooldown > 0 then
			return false
		end
		local useable, msg = o:canUseObject(who)
		if not useable and not (silent or fake) then
			game.logPlayer(self, msg)
			print("[ActorObjectUse] Talent ", t.name, "(", o.name, ") is not usable ", msg)
			return false
		end
		if data.on_pre_use or (data.tid and self.talents_def[data.tid].on_pre_use) then
			return self:callObjectTalent(t.id, "on_pre_use", silent, fake)
		end
		return true 
	end,
	on_pre_use_ai = function(self, t, silent, fake)
		local data = self.object_talent_data[t.id]
		if data.on_pre_use_ai or (data.tid and self.talents_def[data.tid].on_pre_use_ai) then
			return self:callObjectTalent(t.id, "on_pre_use_ai", silent, fake)
		end
		return true
	end,
	mode = "activated",  -- Assumes all abilities are activated
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
		local data = self.object_talent_data[t.id]
print(("##[ActorObjectUse]Pre Action Object (%s [uid %d]) Activation by %s [uid %d, energy %d]"):format(data.obj.name, data.obj.uid, self.name, self.uid, self.energy.value))
		local obj, inven = data.obj, data.inven_id
		local ret
		local co = coroutine.create(function()
			if data.tid then -- replace normal talent use message
				game.logSeen(self, "%s activates %s %s!", self.name:capitalize(), self:his_her(), data.obj:getName({no_add_name=true, do_color = true}))
				local msg = self:useTalentMessage(self:getTalentFromId(data.tid))
				if msg then game.logSeen(self, "%s", msg) end
			end
			ret = obj:use(self, nil, data.inven_id, slot)
print(self.name, self.uid, " return table:")
table.print(ret)
			if ret and ret.used then
print(("##[ActorObjectUse]Post Use Object: Actor %s (%d energy) Object %s, "):format(self.name, self.energy.value, obj.name))
				if ret.destroy then -- destroy the item after use
					local _, item = self:findInInventoryByObject(self:getInven(data.inven_id), data.obj)
					if item then self:removeObject(data.inven_id, item) end
				end
			else
print(("##[ActorObjectUse]Post No Use Object: Actor %s (%d energy) Object %s, "):format(self.name, self.energy.value, obj.name))
				return
			end
		end)
		coroutine.resume(co)
	end,
	info = function(self, t)
		local data = self.object_talent_data
		local o = t.getObject(self, t)
		-- forget settings for objects no longer in the party
		if data.cleanup then
			for o, r in pairs(data.cleanup) do
game.log("---%s: %s tagged for cleanup", self.name, o.name)
				local found = false
				for j, mem in ipairs(game.party.m_list) do
					if mem:findInAllInventoriesByObject(o) then
game.log("---Found %s with %s", o.name, mem.name)
						found = true
						break
					end
				end
				if not found then
game.log("#YELLOW# -- Cleaning up: %s", tostring(o.name))
					for j, mem in ipairs(game.party.m_list) do
						-- clean up local stored object data
						if mem.object_talent_data then mem.object_talent_data[o] = nil end
						if mem.ai_talents then mem.ai_talents[o] = nil end
						-- clean up summoner stored_ai_talents object data
						if mem.stored_ai_talents then
							for memname, tt in pairs(mem.stored_ai_talents) do
								tt[o] = nil
--							and self.summoner.stored_ai_talents[self.name] then self.summoner.stored_ai_talents[self.name][o] = nil end
							end
						end
					end
				end
			end
			data.cleanup = nil
		end
		if not (o and o:isIdentified()) then return "Activate an object." end
		local objname = o:getName({do_color = true}) or "(no object)"
		local usedesc = o and o:getUseDesc(self) or ""
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
--[[
local function save_object_use_data(self, o, tid)
	self.object_talent_data[o] = {tid = tid, talents_auto = self:isTalentAuto(tid), talents_confirm_use = self:isTalentConfirmable()} --.talents_auto, .talents_confirm_use, .ai_talents
end

local function recover_object_use_data(self, o, tid)
	if self.object_talent_data[o] then
		self:setTalentAuto(tid, true, self.object_talent_data[o].talents_auto)
		self:setTalentConfirmable(tid, self.object_talent_data[o].talents_confirm_use)
		--.ai_talents?
	end
end
--]]
--- Set up an object for actor use via talent interface
-- @param o = object to set up to use
-- @param inven_id = id of inventory holding object
-- @param slot = inventory position of object
-- @param returns false or o, talent id, talent definition, talent level if the item is usable
function _M:useObjectEnable(o, inven_id, slot, base_name)
	if not o:canUseObject() or o.quest or o.lore or (o:wornInven() and not o.wielded and not o.use_no_wear) then -- don't enable certain objects (lore, quest)
print(("##[ActorObjectUse] Object %s is ineligible for talent interface"):format(o.name))
		return
	end

--print(("[ActorObjectUse] useObjectEnable: o: %s, by %s inven/slot = %s/%s"):format(o and o.name or "none", self.name, inven_id, slot))
game.log(("#YELLOW#[ActorObjectUse] useObjectEnable: o: %s, by %s inven/slot = %s/%s"):format(o and o.name or "none", self.name, inven_id, slot))
	self.object_talent_data = self.object_talent_data or {} -- for older actors
	local data = self.object_talent_data
--	if data[o] and o == data[data[o]].obj then -- already enabled
--		return o, data[o], self:getTalentFromId(data[o])
--	end
	local tid, t, place
	local oldobjdata = data[o]
	if oldobjdata then
		if oldobjdata.tid and data[oldobjdata.tid] and data[oldobjdata.tid].obj == o then --object already enabled
			return o, data[o], self:getTalentFromId(data[o])
		elseif not self:knowTalent(oldobjdata.tid) then -- use old talent level
			tid = oldobjdata.tid
		end
	end

	if not inven_id then -- find the object if needed
		place, inven_id, slot = self:findInAllInventoriesByObject(o)
	end
	
	local talent_level = false
-- use last used talent id?
	if not tid then --find an unused talentid (if possible)
		data.last_talent = data.last_talent or 0
		local tries = self.max_object_use_talents
		repeat
			tries = tries - 1
			data.last_talent = data.last_talent%self.max_object_use_talents + 1
			tid = useObjectTalentId(base_name, data.last_talent)
			if not self:knowTalent(tid) then break else tid = nil end
		until tries <= 0
--[[
		local i = #data + 1
		if i <= self.max_object_use_talents then 
			-- find the next open object use talent
			for j = 1, self.max_object_use_talents do
				tid = useObjectTalentId(base_name, j)
				if not self:knowTalent(tid) then break else tid = nil end
			end
		end
		--]]
	end
	if not tid then return false end
		
	talent_level = self:useObjectSetData(tid, o)
	if not talent_level then return false end --includes checks for npc useability
--	data[i] = tid
	data[tid].inven_id = inven_id
	data[tid].slot = slot
	self:learnTalent(tid, true, talent_level)
--	self.talents[tid] = talent_level
	
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
	self.object_talent_data = self.object_talent_data or {} -- for older versions
	base_name = base_name or base_talent_name
	if not (o or tid) then --clear all object use data and unlearn all object use talents
		for i = 1, self.max_object_use_talents do
			tid = useObjectTalentId(base_name, i)
			self:unlearnTalentFull(tid)
		end
		self.object_talent_data = {}
		return
	end
	local data = self.object_talent_data
	if o then
		tid = tid or data[o] and data[o].tid
		if (tid and data[tid] and data[tid].obj) ~= o then tid = nil end
game.log("%s tagged for CLEANUP", o.name)
		data.cleanup = data.cleanup or {}  -- set up object to check for cleanup later
		data.cleanup[o]=true
	else
		o = data[tid] and data[tid].obj
	end
game.log("#YELLOW# useObjectDisable: o: %s, by %s inven/slot = %s/%s (tid = %s)", o and o.name or "none", self.name, inven_id, slot, tid)
--	if o then data[o]=nil end
--[[
	if o then -- keep old object preferences (clean up)
--	game:onTickEnd(function()
		if not game.party:findInAllPartyInventoriesBy("name", o.name) then
game.log("Forgetting values")
			data[o]=nil
		elseif tid then -- save settings for object in case it's enabled again later
--			save_object_use_data(self, o, tid)
game.log("Remembering values")
			data[o] = {tid = tid, talents_auto = self:isTalentAuto(tid), talents_confirm_use = self:isTalentConfirmable()} --.talents_auto, .talents_confirm_use, .ai_talents
		end
--	end)
	end
--]]
--[[
	if o then -- keep old object preferences (clean up)
--	game:onTickEnd(function()
		if tid then -- save settings for object in case it's enabled again later
--			save_object_use_data(self, o, tid)
game.log("Remembering values")
			data[o] = {tid = tid, talents_auto = self:isTalentAuto(tid), talents_confirm_use = self:isTalentConfirmable()} --.talents_auto, .talents_confirm_use, .ai_talents
		end
		data.cleanup = table.merge(data.cleanup or {}, {o}) -- set up to check later
--	end)
	end
--]]
	--auto use/confirmable  talents?
	--self.talents_auto
	--self.talents_confirm_use
	if tid then
		if data[tid] and data[tid].old_talent_level then self.talents[tid] = data[tid].old_talent_level end
		data[tid]=nil
		table.removeFromList(data, tid)
		if o then
			data[o] = {tid = tid,
				talents_auto = self:isTalentAuto(tid),
				talents_confirm_use = self:isTalentConfirmable(tid),
				ai_talent = self.ai_talents and self.ai_talents[tid],}
				-- store with summoner?
				if self.summoner and self.summoner.stored_ai_talents and self.summoner.stored_ai_talents[self.name] then
					self.summoner.stored_ai_talents[self.name][o] = self.ai_talents and self.ai_talents[tid]
--					data[o].ai_talents = self.ai_talents
				end
--				summoner_ai_talents = self.summoner and self.summoner.stored_ai_talents and self.summoner.stored_ai_talents[tid]} --.talents_auto, .talents_confirm_use, .ai_talents
game.log("    #YELLOW# %s Saving talent settings for %s", self.name, tid)
--			data.cleanup = data.cleanup or {}
--			data.cleanup[o]=true -- set up to check later
		end
--		self.talents[tid] = 1
		if self.ai_talents then self.ai_talents[tid] = nil end
		self:setTalentConfirmable(tid, false)
		self:setTalentAuto(tid)
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
	local data = self.object_talent_data[t.id]
	local tal = self.talents_def[data.tid]
	if data.old_talent_level then self.talents[tal.id]=data.old_talent_level end -- recover if talent previously crashed
	data.old_talent_level = self.talents[tal.id]; self.talents[tal.id]=data.talent_level
	local ret = tal.tactical and tal.tactical[tactic] and tal.tactical[tactic](self, tal, aitarget)
	self.talents[tal.id]=data.old_talent_level;	data.old_talent_level = nil
	return ret
end


--	if self.summoner and self.summoner.stored_ai_talents and self.summoner.stored_ai_talents[self.name] and self.summoner.stored_ai_talents[self.name][o] then
--		self.ai_talents = self.ai_talents or {}
--		self.ai_talents[tid} = self.summoner.stored_ai_talents[self.name][o]
--				self.summoner.stored_ai_talents[self.name][o] = self.ai_talents and self.ai_talents[tid]
--					data[o].ai_talents = self.ai_talents
--	end


--- sets up the object data for the talent
--	@param tid = the talent id
--	@param o = the usable object
--	o.use_talent is usable unless the talent.no_npc_use flag is set
--	o.use_power is usable unless use_power.no_npc_use is set
--  o.use_simple is usable if use_simple.allow_npc_use is set or use_simple.tactical is defined
--	returns raw talent level if successful
function _M:useObjectSetData(tid, o)
	self.object_talent_data[tid] = {obj = o}
--	self.object_talent_data[o] = tid
--	self.object_talent_data[o] = {tid = tid, talents_auto = self:isTalentAuto(tid), talents_confirm_use = self:isTalentConfirmable()} --.talents_auto, .talents_confirm_use, .ai_talents
--	recover_object_use_data(self, o, tid)

	if self.object_talent_data[o] then --get talent settings
game.log("    #YELLOW# Recalling talent settings for %s %s", tid, o.name)
		self:setTalentAuto(tid, true, self.object_talent_data[o].talents_auto)
		self:setTalentConfirmable(tid, self.object_talent_data[o].talents_confirm_use)
		-- handle ai_talents weights
		if self.summoner and self.summoner.stored_ai_talents and self.summoner.stored_ai_talents[self.name] and self.summoner.stored_ai_talents[self.name][o] then -- get summoner's tactical weight for this actor and object
game.log("    #YELLOW# Recalling summoner (%s) talent settings for %s %s", self.summoner.name, tid, self.name)
			self.ai_talents = self.ai_talents or {}
			self.ai_talents[tid] = self.summoner.stored_ai_talents[self.name][o]
		elseif self.object_talent_data[o].ai_talent then -- get last used tactical weight for this object
			self.ai_talents = self.ai_talents or {}
			self.ai_talents[tid] = self.object_talent_data[o].ai_talent
		end
		self.object_talent_data[o].tid = tid
	else
		self.object_talent_data[o] = {tid = tid}
	end
--	self.object_talent_data[o] = self.object_talent_data[o] or {}
--	self.object_talent_data[o].tid = tid 
	
	local data = self.object_talent_data[tid]
	local talent_level = false
	local power
	
	-- assign use data based on object power definition or used talent
	if o.use_power then -- power is a general power
		power = o.use_power
--		if not power.no_npc_use then
		if not util.getval(power.no_npc_use, o, self) then
			talent_level = o.material_level or 1
		end
	elseif o.use_simple then -- Generally for consumables
		power = o.use_simple
--		if power.allow_npc_use or power.tactical then
		if power.tactical or util.getval(power.allow_npc_use, o, self) then
			talent_level = o.material_level or 1
		end
	elseif o.use_talent then -- power is a talent
		local t = self:getTalentFromId(o.use_talent.id)
		local use_talent = o.use_talent
--		if t and t.mode == "activated" and (use_talent.allow_npc_use or not t.no_npc_use) then
		if t and t.mode == "activated" and (not t.no_npc_use or util.getval(use_talent.allow_npc_use, o, self)) then
			data.tid = o.use_talent.id
			data.talent_level = use_talent.level
			
			data.on_pre_use = use_talent.on_pre_use
			data.on_pre_use_ai = use_talent.on_pre_use_ai
			data.tactical = use_talent.tactical or table.clone(t.tactical)
			if type(data.tactical) == "table" then
				for tact, val in pairs(data.tactical) do
					if type(val) == "function" then
						data.tactical[tact] = AOUtactical_translate
					end
				end
			end
			talent_level = data.talent_level
		end
	else
		print("[ActorObjectUse]: ERROR, object", o.name, o.uid, "has no usable power")
	end
	data.no_energy = o.use_no_energy -- talent speed determined by object
	if not talent_level then
		self.object_talent_data[o] = nil
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
	return talent_level -- the raw talent level to use for ai
end
