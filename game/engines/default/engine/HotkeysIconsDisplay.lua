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
local Shader = require "engine.Shader"
local Entity = require "engine.Entity"
local Tiles = require "engine.Tiles"
local UI = require "engine.ui.Base"
local HotkeysIcons = require "engine.HotkeysIcons"

--- Display of hotkeys with icons
-- @classmod engine.HotkeysIconsDisplay
module(..., package.seeall, class.make)

SEL_FRAME_MAX_ALPHA = 0.313

--- Init
-- @param[type=Actor] actor
-- @number x x coordinate
-- @number y y coordinate
-- @number w width
-- @number h height
-- @param[type=table] bg_color background color
-- @string[opt="DroidSansMono"] fontname
-- @number[opt=10] fontsize
-- @number icon_w icon width
-- @number icon_h icon height
function _M:init(actor, x, y, w, h, bg_color, fontname, fontsize, icon_w, icon_h)
	self.actor = actor
	if type(bg_color) ~= "string" then
		self.bg_color = bg_color
	else
		self.bg_color = nil
		self.bg_image = bg_color
	end
	self.font = core.display.newFont(fontname or "/data/font/DroidSansMono.ttf", fontsize or 10)
	self.fontbig = core.display.newFont(fontname or "/data/font/DroidSansMono.ttf", (fontsize or 10) * 2)
	self.font_h = self.font:lineSkip()
	self.dragclics = {}
	self.clics = {}
	self.fontname = fontname
	self.fontsize = fontsize

	self.renderer = core.renderer.renderer("static"):translate(x, y, 0):setRendererName("HotkeysRenderer"):countDraws(false)

	self.frames = {}
	-- self.makeFrame = function() UI:makeFrame("ui/icon-frame/frame", icon_w + 8, icon_h + 8)  --doesn't really matter since we pass a different size

	self.default_entity = Entity.new{display='?', color=colors.WHITE}

	self:resize(x, y, w, h, icon_w, icon_h)
end

--- Enable our shadows
local UI = require "engine.ui.Base"
_M.setTextOutline = UI.setTextOutline
_M.setTextShadow = UI.setTextShadow
_M.applyShadowOutline = UI.applyShadowOutline

--- Resize the display area
-- @number x x coordinate
-- @number y y coordinate
-- @number w width
-- @number h height
-- @number iw icon width
-- @number ih icon height
function _M:resize(x, y, w, h, iw, ih)
	self.display_x, self.display_y = math.floor(x), math.floor(y)
	self.w, self.h = math.floor(w), math.floor(h)
	if self.actor then self.actor.changed = true end

	if iw and ih and (self.icon_w ~= iw or self.icon_h ~= ih) then
		self.icon_w = iw
		self.icon_h = ih
		self.frames.w = iw + 8
		self.frames.fx = 4
		self.frames.h = ih + 8
		self.frames.fy = 4
		self.tiles = Tiles.new(iw, ih, self.fontname or "/data/font/DroidSansMono.ttf", self.fontsize or 10, true, true)
		self.tiles.use_images = true
		self.tiles.force_back_color = {r=0, g=0, b=0}
	end

	self.max_cols = math.floor(self.w / self.frames.w)
	self.max_rows = math.floor(self.h / self.frames.h)

	self.base_frame = UI:makeFrameDO("ui/icon-frame/frame", self.icon_w + 8, self.icon_h + 8)

	self.renderer:clear()

	self.bg_container = core.renderer.container()
	self.renderer:add(self.bg_container)

	self.icons_layer = core.renderer.renderer("dynamic"):setRendererName("Hotkeys: Icons"):translate(0, 0, 0) self.renderer:add(self.icons_layer)
	self.cooldowns_layer = core.renderer.renderer("dynamic"):setRendererName("Hotkeys: Cooldowns"):translate(0, 0, 10) self.renderer:add(self.cooldowns_layer)
	self.texts_layer = core.renderer.renderer("dynamic"):setRendererName("Hotkeys: Texts"):translate(0, 0, 20) self.renderer:add(self.texts_layer)
	self.frames_layer = core.renderer.renderer("dynamic"):setRendererName("Hotkeys: Frames"):translate(0, 0, 30) self.renderer:add(self.frames_layer)
	self.sels_layer = core.renderer.renderer("dynamic"):setRendererName("Hotkeys: sels"):translate(0, 0, 40) self.renderer:add(self.sels_layer)
	self.unseens_layer = core.renderer.renderer("dynamic"):setRendererName("Hotkeys: Unseen"):translate(0, 0, 0):color(1, 1, 1, 0) self.renderer:add(self.unseens_layer)
	self.sel_frames = {}

	if self.bg_image then self.bg_container:add(core.renderer.image(self.bg_image, 0, 0, self.w, self.h)) end
	if self.bg_color then self.bg_container:add(core.renderer.colorQuad(0, 0, self.w, self.h, colors.smart1unpack(self.bg_color))) end

	self.dragclics = {}
	self.clics = {}
	self.hk_cache = {}
end

_M.page_to_hotkey = {"", "SECOND_", "THIRD_", "FOURTH_", "FIFTH_"}

-- Displays the hotkeys, keybinds & cooldowns
function _M:display()
	local a = self.actor
	if not a or not a.changed then return end

	local bpage = a.hotkey_page
	local spage = bpage

	local orient = self.orient or "down"
	local x = 0
	local y = 0
	local col, row = 0, 0
	self.items = {}
	local w, h = self.frames.w, self.frames.h

	for page = bpage, #self.page_to_hotkey do for i = 1, 12 do
		local bi = i
		local j = i + (12 * (page - 1))
		x = self.frames.w * col
		y = self.frames.h * row
		local has_hk = a.hotkey[j] and a.hotkey[j][1] and true or false
		if not self.hk_cache[j] then
			if has_hk then self.hk_cache[j] = HotkeysIcons.new(a.hotkey[j])
			else self.hk_cache[j] = HotkeysIcons:getEmpty(j) end
			self.hk_cache[j]:addTo(self, a, page, bi, j, x, y)
			self.dragclics[j] = {x,y,w,h}
			self.clics[j] = {x,y,w,h,fake=not has_hk}
		elseif not self.hk_cache[j]:isInvalid(a.hotkey[j] or {"none", j}) then
			self.hk_cache[j]:removeFrom(self, a)
			if has_hk then self.hk_cache[j] = HotkeysIcons.new(a.hotkey[j])
			else self.hk_cache[j] = HotkeysIcons:getEmpty(j) end
			self.hk_cache[j]:addTo(self, a, page, bi, j, x, y)
			self.dragclics[j] = {x,y,w,h}
			self.clics[j] = {x,y,w,h,fake=not has_hk}
		end
		self.hk_cache[j]:update(self, a)

		if orient == "down" or orient == "up" then
			col = col + 1
			if col >= self.max_cols then
				col = 0
				row = row + 1
				if row >= self.max_rows then return end
			end
		elseif orient == "left" or orient == "right" then
			row = row + 1
			if row >= self.max_rows then
				row = 0
				col = col + 1
				if col >= self.max_cols then return end
			end
		end
	end end
end

--- Our toScreen override
function _M:toScreen()
	self:display()
	self.renderer:toScreen()
end

--- Call when a mouse event arrives in this zone  
-- This is optional, only if you need mouse support
-- @string butto	n
-- @number mx mouse x
-- @number my mouse y
-- @param[type=boolean] click did they click
-- @param[type=function] on_over callback for hover
-- @param[type=function] on_click callback for click
function _M:onMouse(button, mx, my, click, on_over, on_click)
	local orient = self.orient or "down"
	mx, my = mx - self.display_x, my - self.display_y
	local a = self.actor

	if button == "wheelup" and click then
		a:prevHotkeyPage()
		return
	elseif button == "wheeldown" and click then
		a:nextHotkeyPage()
		return
	elseif button == "drag-start-global" then
		self.unseens_layer:tween(7, "a", nil, 1)
		return
	elseif button == "drag-end-global" then
		self.unseens_layer:tween(7, "a", nil, 0)
		return
	elseif button == "drag-end" then
		local drag = game.mouse.dragged.payload
		if drag.kind == "talent" or drag.kind == "inventory" then
			for i, zone in pairs(self.dragclics) do
				if mx >= zone[1] and mx < zone[1] + zone[3] and my >= zone[2] and my < zone[2] + zone[4] then
					local old = self.actor.hotkey[i]

					if i <= #self.page_to_hotkey * 12 then -- Only add this hotkey if we support a valid page for it.
						self.actor.hotkey[i] = {drag.kind, drag.id}

						if drag.source_hotkey_slot then
							self.actor.hotkey[drag.source_hotkey_slot] = old
						end

						-- Update the quickhotkeys table immediately rather than waiting for a save.
						if self.actor.save_hotkeys then
							engine.interface.PlayerHotkeys:updateQuickHotkey(self.actor, i)
							engine.interface.PlayerHotkeys:updateQuickHotkey(self.actor, drag.source_hotkey_slot)
						end
					end
					game.mouse:usedDrag()
					self.actor.changed = true
					break
				end
			end
		end
	end

	for i, zone in pairs(self.clics) do
		if mx >= zone[1] and mx < zone[1] + zone[3] and my >= zone[2] and my < zone[2] + zone[4] then
			if on_click and click and not zone.fake then
				if on_click(i, a.hotkey[i]) then click = false end
			end
			local oldsel = self.cur_sel
			if oldsel ~= i then
				if oldsel and self.sel_frames[oldsel] then self.sel_frames[oldsel]:tween(7, "a", nil, 0) end
				if not zone.fake and self.sel_frames[i] then self.sel_frames[i]:tween(7, "a", nil, SEL_FRAME_MAX_ALPHA) end
			end
			self.cur_sel = i
			if button == "left" and not zone.fake then
				if click then
					a:activateHotkey(i)
				else
					MAEK DRAG AND DROP WORK AND MOVE THAT TO HotkeysIcons CLASS
					if a.hotkey[i][1] == "talent" then
						local t = self.actor:getTalentFromId(a.hotkey[i][2])
						local DO = t.display_entity:getEntityDisplayObject(nil, 64, 64)
						game.mouse:startDrag(mx, my, DO, {kind=a.hotkey[i][1], id=a.hotkey[i][2], source_hotkey_slot=i}, function(drag, used) if not used then self.actor.hotkey[i] = nil self.actor.changed = true end end)
					elseif a.hotkey[i][1] == "inventory" then
						local o = a:findInAllInventories(a.hotkey[i][2], {no_add_name=true, force_id=true, no_count=true})
						local DO = nil
						if o then DO = o:getEntityDisplayObject(nil, 64, 64) end
						game.mouse:startDrag(mx, my, DO, {kind=a.hotkey[i][1], id=a.hotkey[i][2], source_hotkey_slot=i}, function(drag, used) if not used then self.actor.hotkey[i] = nil self.actor.changed = true end end)
					end
				end
			elseif button == "right" and click and not zone.fake then
				a.hotkey[i] = nil
				a.changed = true
			else
				a.changed = true
				if on_over and self.cur_sel ~= oldsel and not zone.fake then
					local text = ""
					if a.hotkey[i] and a.hotkey[i][1] == "talent" then
						local t = self.actor:getTalentFromId(a.hotkey[i][2])
						text = tstring{{"color","GOLD"}, {"font", "bold"}, t.name .. (config.settings.cheat and " ("..t.id..")" or ""), {"font", "normal"}, {"color", "LAST"}, true}
						text:merge(self.actor:getTalentFullDescription(t))
					elseif a.hotkey[i] and a.hotkey[i][1] == "inventory" then
						local o = a:findInAllInventories(a.hotkey[i][2], {no_add_name=true, force_id=true, no_count=true})
						if o then
							text = o:getDesc()
						else text = "Missing!" end
					end
					on_over(text)
				end
			end
			return
		end
	end

	self.cur_sel = nil
	for i, f in ipairs(self.sel_frames) do
		f:tween(7, "a", nil, 0)
	end
end
