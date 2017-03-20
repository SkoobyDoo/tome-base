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

require "engine.class"
require "engine.ui.Dialog"
local List = require "engine.ui.List"
local GetQuantity = require "engine.dialogs.GetQuantity"

module(..., package.seeall, class.inherit(engine.ui.Dialog))

function _M:init()
	self:generateList()
	engine.ui.Dialog.init(self, "DEBUG -- Summon Creature", 1, 1)

	local list = List.new{width=400, height=500, list=self.list, fct=function(item) self:use(item) end}

	self:loadUI{
		{left=0, top=0, ui=list},
	}
	self:setupUI(true, true)

	self.key:addCommands{ __TEXTINPUT = function(c)
		for i = list.sel + 1, #self.list do
			local v = self.list[i]
			if v.name:sub(1, 1):lower() == c:lower() then list:select(i) return end
		end
		for i = 1, list.sel do
			local v = self.list[i]
			if v.name:sub(1, 1):lower() == c:lower() then list:select(i) return end
		end
	end}
	self.key:addBinds{ EXIT = function() game:unregisterDialog(self) end,
		LUA_CONSOLE = function()
			if config.settings.cheat then
				local DebugConsole = require "engine.DebugConsole"
				game:registerDialog(DebugConsole.new())
			end
		end,}
end

function _M:on_register()
	game:onTickEnd(function() self.key:unicodeInput(true) end)
end

function _M:use(item)
	if not item then return end
	game:unregisterDialog(self)

	if item.action then
		item:action()
	else
		local m = game.zone:finishEntity(game.level, "actor", item.e)
		self:placeCreature(m)
	end
end

function _M:placeCreature(m)
	local p = game.player
	local tg = {type="hit", range=100, no_restrict=true, nowarning=true, act_exclude={[p.uid]=true}}
	local x, y, act
	local co = coroutine.create(function()
			x, y, act = p:getTarget(tg)
			if x and y then
				if act then
					game.log("#LIGHT_BLUE#Actor [%s]%s already occupies (%d, %d)", act.uid, act.name, x, y)
					return
				end
				game.zone:addEntity(game.level, m, "actor", x, y)
				local Dstring = m.getDisplayString and m:getDisplayString() or ""
				game.log("#LIGHT_BLUE#Added %s[%s]%s at (%d, %d)", Dstring, m.uid, m.name, x, y)
				return x, y, act
			end
			return
		end
	)
	coroutine.resume(co)
end

function _M:generateList()
	local list = {}

	for i, e in ipairs(game.zone.npc_list) do
		list[#list+1] = {name=e.name, unique=e.unique, e=e}
	end
	table.sort(list, function(a,b)
		if a.unique and not b.unique then return true
		elseif not a.unique and b.unique then return false end
		return a.name < b.name
	end)

	table.insert(list, 1, {name = " Test Dummy", action=function(item)
		local m = mod.class.NPC.new{define_as="TRAINING_DUMMY",
			type = "training", subtype = "dummy",
			name = "Test Dummy", color=colors.GREY,
			desc = "Test dummy.", image = "npc/lure.png",
			level_range = {1, 1}, exp_worth = 0,
			rank = 3,
			max_life = 300000, life_rating = 0,
			life_regen = 300000,
			never_move = 1,
			training_dummy = 1,
		}
		m:resolve()
		m:resolve(nil, true)
		self:placeCreature(m)
	end})
	
	local chars = {}
	for i, v in ipairs(list) do
		v.name = v.name
		chars[self:makeKeyChar(i)] = i
	end
	list.chars = chars

	self.list = list
end
