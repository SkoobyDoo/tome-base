-- TE4 - T-Engine 4
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

require "engine.class"
local Module = require "engine.Module"
local Dialog = require "engine.ui.Dialog"
local Button = require "engine.ui.Button"
local Textzone = require "engine.ui.Textzone"
local Numberbox = require "engine.ui.Numberbox"
local Checkbox = require "engine.ui.Checkbox"

--- Generic popup for getting quantity
-- @classmod engine.dialogs.GetQuantity
module(..., package.seeall, class.inherit(Dialog))

--- store for modified actor backups
_M.last_actors = {}

function _M:init(data)
	self.actor = data and data.actor or game.player
table.set(game, "debug", "AdvanceActor", self) -- debugging
	
	Dialog.init(self, ("DEBUG -- Levelup Actor: [%s] %s"):format(self.actor.uid, self.actor.name), 800, 500)

	self.inputs = {}
	self.c_tut = Textzone.new{auto_width=true, auto_height=true, no_color_bleed=true, font=self.font,
	text=[[Levelup an actor.
Optionally set Stat levels, learn all talents possible, and gain points to spend on Levelup. 
The actor is backed up before changes are made.  (Use the "Restore" button to recover.)
]]}
	local top = self.c_tut.h + 10
	local lev_box = Numberbox.new{title="Advance to level: ", number=self.actor.level or 50, max=1000, min=1, chars=10, fct=function(value)
game.log("setting levelup to %s", value)
			self.inputs.levelup = value
			self:finish()
		end
	}
	self.lev_box = lev_box

	local restore_text = function(self)
		local last_actor = _M.last_actors[self.actor]
		if last_actor and #last_actor > 0 then
			return ("Restore: %s (v%d)"):format(last_actor[#last_actor].name, #last_actor), 1
		else
			return "Restore: none", 0.5
		end
	end
	local rest_text, rest_alpha = restore_text(self)
	local restore = Button.new{text=rest_text, alpha_unfocus=rest_alpha,
		fct=function()
			local last_actor = _M.last_actors[self.actor]
			
			if last_actor and #last_actor > 0 then
				local uid = self.actor.uid
				local la = table.remove(last_actor, #last_actor)
				game.log("#LIGHT_BLUE#Restoring [%s]%s from backup version %d", self.actor.uid, la.name, #last_actor+1)
				self.actor:replaceWith(la)
				self.actor.uid = uid
				self.lev_box.number = self.actor.level
				self.lev_box:updateText(0)
			end
			self.restore.text, self.restore.alpha_unfocus = restore_text(self)
			self.restore:generate() -- force redraw
			self:setFocus(self.lev_box)
		end
	}
	self.restore = restore
	
	local get_points = Checkbox.new{title="Set unlimited respec and gain points for stats, talents, and prodigies ", text="Text", default=false, check_last=false,
		fct=function(checked)
		end,
		on_change=function(checked)
			self.inputs.get_points = checked
		end
	}
	self.get_points = get_points
	
	local set_statlvl = Checkbox.new{title=" Change Stats ", default=false, check_last=true,
		fct=function(checked)
			self.inputs.levelup_stats = checked
		end,
		on_change=function(checked)
			self.inputs.levelup_stats = checked
		end
	}
	self.set_statlvl = set_statlvl
	local stat_box = Numberbox.new{title="Force all stats to: ", number="maximum for level", max=1000, min=1, chars=20, fct=function(value)
			self.stat_box:updateText(0)
			self.inputs.stat_levelup = value
			self:finish()
		end,
		on_change = function(value)
			if not self.stat_box.inputted then value = 100 self.stat_box.inputted = true end
			if not self.set_statlvl.checked then self.set_statlvl:select() end
			self.stat_box.number = value
			self.stat_box:updateText(0)
			self.inputs.stat_levelup = value
		end
	}
	self.stat_box = stat_box

	local set_tl = Checkbox.new{title="Learn Talents ", text="Text", default=false, check_last=true,
		fct=function(checked)
		end,
		on_change=function(checked)
			self.inputs.levelup_talents = checked
		end
	}
	self.set_tl = set_tl
	local tl_box = Numberbox.new{title="Unlock & Learn all available talents to level: ", number="maximum allowed", max=1000, min=1, chars=20, fct=function(value)
			self.tl_box:updateText(0)
			self.inputs.talent_levelup = value
			self:finish()
		end,
		on_change = function(value)
			if not self.tl_box.inputted then value = 5 self.tl_box.inputted = true end
			if not self.set_tl.checked then self.set_tl:select() end
			self.tl_box.number = value
			self.tl_box:updateText(0)
			self.inputs.talent_levelup = value
		end
	}
	self.tl_box = tl_box

	local force_tl = Checkbox.new{title="Ignore requirements", text="Text", default=false, check_last=false,
		fct=function(checked)
			self.inputs.ignore_talent_limits = checked
		end,
		on_change=function(checked)
			self.inputs.ignore_talent_limits = checked
		end
	}
	self.force_tl = force_tl
	
	local mastery_box = Numberbox.new{title="Force all talent mastery levels to (0.1-5.0): ", number="no change", max=5.0, min=0.1, chars=10, step=0.1, fct=function(value)
			local old = self.mastery_box.number
			self.mastery_box:updateText(0)
			self.inputs.set_mastery = value
			if old == self.mastery_box.number then self:finish() end
		end,
		on_change = function(value)
			if not self.mastery_box.inputted then
				value = 1.0
				self.mastery_box.inputted = true
				self.mastery_box.number = value
				self.mastery_box:updateText(0)
			end
			self.inputs.set_mastery = self.mastery_box.number
		end
	}
	self.mastery_box = mastery_box
	
	local learn_all_talents = Checkbox.new{title="Unlock all talent types (slow)", default=false, check_last=false,
		fct=function(checked)
			self.inputs.alltalents = checked
		end,
		on_change=function(checked)
			self.inputs.alltalents = checked
		end
	}
	self.learn_all_talents = learn_all_talents
	
	local ok = Button.new{text="Accept", fct=function() self:finish() end}
	local cancel = Button.new{text="Cancel", fct=function() self:cancelclick() end}

	local top = lev_box.h + get_points.h + self.c_tut.h + 15
	self:loadUI{
		{left=10, top=0, padding_h=10, ui=self.c_tut},
		{left=10, top=self.c_tut.h+5, padding_h=10, ui=lev_box},
		{left=10, top=self.c_tut.h+lev_box.h+10, padding_h=10, ui=get_points},
		{right=10, top=0, padding_h=10, ui=restore},
		{left=10, top=top, padding_h=10, ui=set_statlvl},
		{left=set_statlvl.w+20, top=top, padding_h=10, ui=stat_box},
		{left=10, top=top+stat_box.h+5, padding_h=10, ui=set_tl},
		{left=set_tl.w+20, top=top+stat_box.h+5, padding_h=10, ui=tl_box},
		{right=10, top=top+stat_box.h+5, padding_h=10, ui=force_tl},
		{left=10, top=top+stat_box.h+tl_box.h+10, padding_h=10, ui=mastery_box},
		{right=10, top=top+stat_box.h+tl_box.h+10, padding_h=10, ui=learn_all_talents},
		{left=10, bottom=0, ui=ok},
		{right=10, bottom=0, ui=cancel},
	}

	self:setFocus(lev_box)
	self:setupUI(true, true)
	self.key:addBinds{
		EXIT = function()
			game:unregisterDialog(self)
		end,
		RETURN = function()
		end,
		LUA_CONSOLE = function()
			if config.settings.cheat then
				local DebugConsole = require "engine.DebugConsole"
				game:registerDialog(DebugConsole.new())
			end
		end,
	}
end

-- Levelup the actor
function _M:finish()
	self.inputs.levelup = self.inputs.levelup or tonumber(self.lev_box.number)
	print("[ForceLevelUp] inputs:", self.inputs) table.print(self.inputs, '\t_inputs_')
	game:unregisterDialog(self)
	local data = table.clone(self.inputs)
	data.stat_level = self.inputs.levelup_stats and (self.inputs.stat_levelup or self:autoStatLevel(self.inputs.levelup))
	data.talent_level = self.inputs.levelup_talents and (self.inputs.talent_levelup or self:autoTalentLevel(self.inputs.levelup))
	self:levelupActor(self.actor, self.inputs.levelup, data)
end

function _M:cancelclick()
	self.key:triggerVirtual("EXIT")
end

function _M:autoTalentLevel(charlev)
	return 5 + math.max(0, math.floor((charlev - 50) / 10))
end

function _M:autoStatLevel(charlev)
	return math.min(charlev*1.4 + 20, 60 + math.max(0, charlev - 50))
end

--- Levelup Actor, possibly increasing stats, and learning talents
-- who = actor to level up
-- lev = target character level
-- data = table of optional levelup parameters:
-- 		stat_level: adjust stat bonuses to force all primary stats to this value
-- 		talent_level: learn all possible talent to this (raw) level
--		ignore_talent_limits: ignore restrictions when levelling up talents
-- 		alltalents: unlock all talent types in the game (before learning talents)
-- 		set_mastery: force mastery level for all talent types
function _M:levelupActor(who, lev, data)
	who = who or game.player
	 -- backup the character
	_M.last_actors[who] = _M.last_actors[who] or {}
	table.insert(_M.last_actors[who], who:cloneFull())
	game.log("#LIGHT_BLUE#Advancing actor %s[%s]", who.name, who.uid)
	local tt_def=who.talents_types_def
	who.lastLearntTalentsMax = function(what) return 500 end
	
	who.max_level = nil
	if lev then
		if who.max_level then who.max_level = lev end
		who:forceLevelup(lev)
	end
	lev = who.level

	game.logPlayer(who, "#LIGHT_BLUE#Level %d: Setting primary stats to %s, maximum talent levels to %s", lev, data.stat_level, data.talent_level)
	if data.stat_level then
		game.logPlayer(who, "#GOLD#Forcing all Stats to %s", data.stat_level)
		for stat = 1, 6 do
			local inc = data.stat_level - who:getStat(stat)
			who:incIncStat(stat, inc)
		end
	end
	if data.set_mastery then game.logPlayer(who, "#GOLD#Resetting all talents_types_mastery to %s", data.set_mastery) end
	if data.alltalents then
		game.logPlayer(who, "#GOLD#Unlocking All Talent Types")
		for key, value in ipairs(tt_def) do
			who:learnTalentType(tt_def[key].type)
			game.logPlayer(who, "#LIGHT_BLUE#%s -- %s",key, value.type)
		end
	end
	for tt, _ in pairs(who.talents_types) do
		local ttd = tt_def[tt]
		if data.set_mastery and ttd then
			who:setTalentTypeMastery(tt, data.set_mastery)
		end
		if ttd and data.talent_level then
			game.logPlayer(who, "#GOLD#Checking %s Talents (%s)", tt, who:getTalentTypeMastery(tt))
			who:learnTalentType(tt, true)
			for i, t in pairs(ttd.talents) do
				if not (t.is_object_use or t.is_inscription or t.uber) then
					local learn_levels = (t.points == 1 and t.points or data.talent_level) - who:getTalentLevelRaw(t)
					local learned = false
					if learn_levels > 0 then
						for i = 1, learn_levels do
							if data.ignore_talent_limits or who:canLearnTalent(t, 1, false) then
								who:learnTalent(t.id, true, 1) learned = true
							else break
							end
						end
						if learned then game.logPlayer(who, "#LIGHT_BLUE#Talent %s learned to level %d", t.id, who:getTalentLevelRaw(t)) end
					end
				end
			end
		end
	end
	if data.get_points then
		who:attr("infinite_respec", 1)
		game.state.birth.ignore_prodigies_special_reqs = true
		game.state.birth.force_town_respec=false
		who.unused_talents = who.unused_talents + 200
		who.unused_generics = who.unused_generics + 200
		who.unused_prodigies = who.unused_prodigies + 20
		who.unused_talents_types = who.unused_talents_types + 20
		who.unused_stats = who.unused_stats + 200

		local points = {}
		if who.unused_stats > 0 then points[#points+1] = ("%d stat point(s)"):format(who.unused_stats) end
		if who.unused_talents > 0 then points[#points+1] = ("%d class talent point(s)"):format(who.unused_talents) end
		if who.unused_generics > 0 then points[#points+1] = ("%d generic talent point(s)"):format(who.unused_generics) end
		if who.unused_talents_types > 0 then points[#points+1] = ("%d category point(s)"):format(who.unused_talents_types) end
		if who.unused_prodigies > 0 then points[#points+1] = ("#ORCHID#%d prodigy point(s)#LAST#"):format(who.unused_prodigies) end
		if #points > 0 then game.log("#LIGHT_BLUE#%s has %s to spend", who.name:capitalize(), table.concatNice(points, ", ", ", and ")) end
	end
end
