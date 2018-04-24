-- TE4 - T-Engine 4
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

require "engine.class"
local UI = require "engine.ui.Base"

--- Definitions and instances of hotkeys to go in HotkeysIconsDisplay
-- @classmod engine.HotkeysIcons
module(..., package.seeall, class.make)

kinds_def = {}

--- Defines hotkeys kinds
-- Static!
function _M:loadDefinition(file, env)
	env = env or setmetatable({
		newKind = function(t) self:newKind(t) end,
		load = function(f) self:loadDefinition(f, env) end
	}, {__index=getfenv(2)})
	local f, err = util.loadfilemods(file, env)
	if not f and err then error(err) end
	f()
end

function _M:newKind(t)
	assert(t.kind, "No hotkeys kind")
	assert(t.display_data, "No hotkeys display_data")
	assert(t.use, "No hotkeys use")
	assert(t.drag_display_object, "No hotkeys drag_display_object")
	self.kinds_def[t.kind] = t
end

function _M:use(def, actor)
	if not kinds_def[def[1]] then return false end
	kinds_def[def[1]].use(_M.new(def), actor)
	return true
end

function _M:init(def)
	assert(kinds_def[def[1]], "Unknown kind of hotkey! "..tostring(def[1]))

	self.kind = def[1]
	self.data = def[2]
end

function _M:isInvalid(def, x, y)
	if self.kind ~= def[1] or self.data ~= def[2] then return true end
	if self.x ~= x or self.y ~= y then return true end
	return false
end

function _M:displayData(actor)
	return kinds_def[self.kind].display_data(self, actor)
end

function _M:getDragDO(actor)
	return kinds_def[self.kind].drag_display_object(self, actor)
end

function _M:addTo(hks, actor, page, bi, i, x, y)
	local display_entity, pie_color, pie_angle, frame, txt = self:displayData(actor)
	self.x, self.y, self.i = x, y, i

	self.keybound = "HOTKEY_"..hks.page_to_hotkey[page]..bi

	self.frame = UI:cloneFrameDO(hks.base_frame)
	hks.frames_layer:add(self.frame.container:translate(x - 4, y - 4, 0))

	self.pie = core.renderer.vertexes():plainColorQuad():color(1, 1, 1, 0)
	hks.cooldowns_layer:add(self.pie:translate(x, y, 0))
	self.oldpie_color = {1, 1, 1, 0}

	if display_entity then
		self.display_entity = display_entity:getEntityDisplayObject(hks.tiles, hks.icon_w, hks.icon_h, false, true)
		hks.icons_layer:add(self.display_entity:removeFromParent():translate(x, y, 0))
	end

	self.selframe = core.renderer.colorQuad(0, 0, 1, 1, 0.5, 0.5, 1, 1):color(1, 1, 1, 0):translate(x, y):scale(hks.icon_w, hks.icon_h, 1)
	hks.sel_frames[i] = self.selframe
	hks.sels_layer:add(hks.sel_frames[i])

	self.txtkey = core.renderer.text(hks.fontbig)
	hks:applyShadowOutline(self.txtkey)
	self.txtkey:textColor(colors.unpack1(colors.ANTIQUE_WHITE)):scale(0.5, 0.5, 0.5) -- Scale so we can usethe same atlas for all text
	hks.texts_layer:add(self.txtkey)

	self.txt = core.renderer.text(hks.fontbig)
	hks:applyShadowOutline(self.txt)
	hks.texts_layer:add(self.txt)

	self:updateKeybind(hks, actor)
end

local frames_colors = {
	ok = {0.3, 0.6, 0.3, 1},
	sustain = {0.6, 0.6, 0, 1},
	cooldown = {0.6, 0, 0, 1},
	disabled = {0.65, 0.65, 0.65, 1},
}

function _M:removeFrom(hks, actor)
	self.frame.container:removeFromParent()
	self.pie:removeFromParent()
	self.selframe:removeFromParent()
	self.txtkey:removeFromParent()
	self.txt:removeFromParent()
	if self.display_entity then self.display_entity:removeFromParent() end
end

function _M:update(hks, actor)
	local display_entity, pie_color, pie_angle, frame, txt = self:displayData(actor)

	if frame ~= self.oldframe then
		self.frame.container
			:tween(7, "r", nil, frames_colors[frame][1])
			:tween(7, "g", nil, frames_colors[frame][2])
			:tween(7, "b", nil, frames_colors[frame][3])
			:tween(7, "a", nil, frames_colors[frame][4])
		-- self.frame.container:color(unpack(frames_colors[frame]))
		self.oldframe = frame
	end

	if pie_color[1] ~= self.oldpie_color[1] or pie_color[2] ~= self.oldpie_color[2] or pie_color[3] ~= self.oldpie_color[3] or pie_color[4] ~= self.oldpie_color[4] then
		self.pie:color(unpack(pie_color))
		self.oldpie_color = pie_color
	end
	if self.oldpie_angle ~= pie_angle then
		self.pie:clear():quadPie(0, 0, hks.icon_w, hks.icon_h, 0, 0, 1, 1, pie_angle, 1, 1, 1, 1)
		self.oldpie_angle = pie_angle
	end

	if txt ~= self.oldtxt then
		if txt then self.txt:text(txt) else self.txt:text("") end
		local tw, th = self.txt:getStats()
		self.txt:translate(self.x + (hks.icon_w - tw) / 2, self.y + (hks.icon_h - th) / 2, 0)
		self.oldtxt = txt
	end
end

function _M:updateKeybind(hks, actor)
	local ks = game.key:formatKeyString(game.key:findBoundKeys(self.keybound))
	if ks ~= self.oldks then
		self.txtkey:text(ks)
		local tw, th = self.txtkey:getStats()
		self.txtkey:translate(self.x + hks.icon_w - tw/2, self.y + hks.icon_h - th/2, 10) -- /2 because we scale by 0.5
		self.oldks = ks
	end
end
------------------------------------------------------------------
-- Empty frame version
------------------------------------------------------------------
local Empty = class.make{}

function Empty:init(def)
	self.kind = def[1]
	self.data = def[2]
end

function Empty:isInvalid(def, x, y)
	if self.kind ~= def[1] or self.data ~= def[2] then return true end
	if self.x ~= x or self.y ~= y then return true end
	return false
end

function Empty:getDragDO(actor)
	return nil
end

function Empty:addTo(hks, actor, page, bi, i, x, y)
	self.x, self.y, self.i = x, y, i

	self.keybound = "HOTKEY_"..hks.page_to_hotkey[page]..bi

	self.frame = UI:cloneFrameDO(hks.base_frame)
	hks.unseens_layer:add(self.frame.container:translate(x - 4, y - 4, 0):color(unpack(frames_colors.disabled)))

	self.selframe = core.renderer.colorQuad(0, 0, 1, 1, 0.5, 0.5, 1, 1):color(1, 1, 1, 0):translate(x, y):scale(hks.icon_w, hks.icon_h, 1)
	hks.sel_frames[i] = self.selframe
	hks.unseens_layer:add(hks.sel_frames[i])

	self.txtkey = core.renderer.text(hks.fontbig)
	hks:applyShadowOutline(self.txtkey)
	self.txtkey:textColor(colors.unpack1(colors.ANTIQUE_WHITE)):scale(0.5, 0.5, 0.5) -- Scale so we can usethe same atlas for all text
	hks.unseens_layer:add(self.txtkey)

	self:updateKeybind(hks, actor)
end

function Empty:removeFrom(hks, actor)
	self.frame.container:removeFromParent()
	self.selframe:removeFromParent()
	self.txtkey:removeFromParent()
end

function Empty:update(hks, actor)
end

function Empty:updateKeybind(hks, actor)
	local ks = game.key:formatKeyString(game.key:findBoundKeys(self.keybound))
	if ks ~= self.oldks then
		self.txtkey:text(ks)
		local tw, th = self.txtkey:getStats()
		self.txtkey:translate(self.x + hks.icon_w - tw/2, self.y + hks.icon_h - th/2, 10) -- /2 because we scale by 0.5
		self.oldks = ks
	end
end

function _M:getEmpty(j)
	return Empty.new{"none", j}
end
