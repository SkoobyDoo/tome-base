-- TE4 - T-Engine 4
-- Copyright (C) 2009, 2010 Nicolas Casalini
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
local Dialog = require "engine.ui.Dialog"
local TreeList = require "engine.ui.TreeList"
local Textzone = require "engine.ui.Textzone"
local Separator = require "engine.ui.Separator"
local KeyBind = require "engine.KeyBind"

module(..., package.seeall, class.inherit(Dialog))

function _M:init(key_source, force_all)
	Dialog.init(self, "Key bindings", 800, game.h)

	self:generateList(key_source, force_all)

	self.c_tree = TreeList.new{width=self.iw, height=self.ih, sel_by_col=true, scrollbar=true, columns={
		{width=40, display_prop="name"},
		{width=30, display_prop="b1"},
		{width=30, display_prop="b2"},
	}, tree=self.tree,
		fct=function(item, sel, v) self:use(item, sel, v) end,
	}

	self:loadUI{
		{left=0, top=0, ui=self.c_tree},
	}
	self:setupUI()

	self.key:addBinds{
		EXIT = function()
			game:unregisterDialog(self)
			key_source:bindKeys()
			KeyBind:saveRemap()
		end,
	}
end

function _M:use(item)
	local t = item
	local curcol = self.c_tree.cur_col - 1
	if not item or item.nodes or curcol < 1 or curcol > 2 then return end

	--
	-- Make a dialog to ask for the key
	--
	local title = "Press a key (or escape) for: "..tostring(t.name)
	local font = self.font
	local w, h = font:size(title)
	local d = engine.Dialog.new(title, w + 8, h + 25, nil, nil, nil, font)
	d:keyCommands{__DEFAULT=function(sym, ctrl, shift, alt, meta, unicode)
		-- Modifier keys are not treated
		if sym == KeyBind._LCTRL or sym == KeyBind._RCTRL or
		   sym == KeyBind._LSHIFT or sym == KeyBind._RSHIFT or
		   sym == KeyBind._LALT or sym == KeyBind._RALT or
		   sym == KeyBind._LMETA or sym == KeyBind._RMETA then
			return
		end

		if sym == KeyBind._BACKSPACE then
			KeyBind.binds_remap[t.type] = KeyBind.binds_remap[t.type] or t.k.default
			KeyBind.binds_remap[t.type][curcol] = nil
		elseif sym ~= KeyBind._ESCAPE then
			local ks = KeyBind:makeKeyString(sym, ctrl, shift, alt, meta, unicode)
			print("Binding", t.name, "to", ks, "::", curcol)

			KeyBind.binds_remap[t.type] = KeyBind.binds_remap[t.type] or t.k.default
			KeyBind.binds_remap[t.type][curcol] = ks
		end
		self.c_tree:drawItem(item)
		game:unregisterDialog(d)
	end}

	d:mouseZones{ norestrict=true,
		{ x=0, y=0, w=game.w, h=game.h, fct=function(button, x, y, xrel, yrel, tx, ty)
			if xrel or yrel then return end
			if button == "left" then return end

			local ks = KeyBind:makeMouseString(
				button,
				core.key.modState("ctrl") and true or false,
				core.key.modState("shift") and true or false,
				core.key.modState("alt") and true or false,
				core.key.modState("meta") and true or false
			)
			print("Binding", t.name, "to", ks)

			KeyBind.binds_remap[t.type] = KeyBind.binds_remap[t.type] or t.k.default
			KeyBind.binds_remap[t.type][curcol] = ks
			self.c_tree:drawItem(item)
			game:unregisterDialog(d)
		end },
	}

	d.drawDialog = function(self, s)
		s:drawColorStringBlendedCentered(self.font, curcol == 1 and "Bind key" or "Bind alternate key", 2, 2, self.iw - 2, self.ih - 2)
	end
	game:registerDialog(d)
end

function _M:generateList(key_source, force_all)
	local l = {}

	for virtual, t in pairs(KeyBind.binds_def) do
		if (force_all or key_source.virtuals[virtual]) and t.group ~= "debug" then
			l[#l+1] = t
		end
	end
	table.sort(l, function(a,b)
		if a.group ~= b.group then
			return a.group < b.group
		else
			return a.order < b.order
		end
	end)

	-- Makes up the list
	local tree = {}
	local groups = {}
	for _, k in ipairs(l) do
		local item = {
			k = k,
			name = tstring{{"font","italic"}, {"color","AQUAMARINE"}, k.name, {"font","normal"}},
			sortname = k.name;
			type = k.type,
			bind1 = function(item) return KeyBind:getBindTable(k)[1] end,
			bind2 = function(item) return KeyBind:getBindTable(k)[2] end,
			b1 = function(item) return KeyBind:formatKeyString(util.getval(item.bind1, item)) end,
			b2 = function(item) return KeyBind:formatKeyString(util.getval(item.bind2, item)) end,
		}
		groups[k.group] = groups[k.group] or {}
		table.insert(groups[k.group], item)
	end

	for group, data in pairs(groups) do
		tree[#tree+1] = {
			name = tstring{{"font","bold"}, {"color","GOLD"}, group:capitalize(), {"font","normal"}},
			sortname = group:capitalize(),
			b1 = "", b2 = "",
			shown = true,
			nodes = data,
		}
	end
	table.sort(tree, function(a, b) return a.sortname < b.sortname end)

	self.tree = tree
end
