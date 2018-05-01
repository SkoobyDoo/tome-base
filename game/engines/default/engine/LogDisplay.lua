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
require "engine.ui.Base"
local Shader = require "engine.Shader"
local Mouse = require "engine.Mouse"
local Slider = require "engine.ui.Slider"

--- Module that handles message history in a mouse wheel scrollable zone
-- @classmod engine.LogDisplay
module(..., package.seeall, class.inherit(engine.ui.Base))

--- Creates the log zone
function _M:init(x, y, w, h, max, fontname, fontsize, color)
	color = color or {255,255,255}
	self.color = {color[1] / 255, color[2] / 255, color[3] / 255, 1}
	self.fontsize = fontsize or 12
	self.font = core.display.newFont(fontname or "/data/font/DroidSans.ttf", self.fontsize)
	self.font_h = self.font:lineSkip()
	self.log = {}
	getmetatable(self).__call = _M.call
	self.max_log = max or 4000
	self.scroll = 0
	self.changed = true

	self.renderer = core.renderer.renderer("stream"):setRendererName("LogDisplay")

	self:resize(x, y, w, h)

	self.cache_next_id = 1
	self.cache = {}

--	if config.settings.log_to_disk then self.out_f = fs.open("/game-log-"..(game and type(game) == "table" and game.__mod_info and game.__mod_info.short_name or "default").."-"..os.time()..".txt", "w") end
end

local UI = require "engine.ui.Base"
_M.setTextOutline = UI.setTextOutline
_M.setTextShadow = UI.setTextShadow
_M.applyShadowOutline = UI.applyShadowOutline

function _M:enableFading(v)
	self.fading = v
end

--- Resize the display area
function _M:resize(x, y, w, h)
	self.display_x, self.display_y = math.floor(x), math.floor(y)
	self.w, self.h = math.floor(w), math.floor(h)
	self.fw, self.fh = self.w - 4, self.font:lineSkip()
	self.max_display = math.floor(self.h / self.fh)
	self.changed = true

	self.renderer:clear()

	local wself = self:weakSelf()
	local cb = core.renderer.callback(function()
		if not wself() then return end
		wself():update()
	end)
	self.renderer:add(cb)

	self.renderer:cutoff(0, 0, w, h)
	self.renderer:translate(self.display_x, self.display_y, 0)
	self.history_container = core.renderer.container()
	self.renderer:add(self.history_container)

	self.scrollbar = Slider.new{size=self.h - 20, max=1, inverse=true}

	self.mouse = Mouse.new()
	self.mouse.delegate_offset_x = self.display_x
	self.mouse.delegate_offset_y = self.display_y
	self.mouse:registerZone(0, 0, self.w, self.h, function(button, x, y, xrel, yrel, bx, by, event) self:mouseEvent(button, x, y, xrel, yrel, bx, by, event) end)
end

--- Returns a clone of the full log
function _M:getLog(extra, timestamp)
	local log = {}
	for i = 1, #self.log do
		if timestamp and self.log[i].timestamp <= timestamp then break end
		if not extra then
			log[#log+1] = self.log[i].str
		else
			log[#log+1] = {str=self.log[i].str, src=self.log[i]}
		end
	end
	return log
end

function _M:getLogLast()
	if not self.log[1] then return 0 end
	return self.log[1].timestamp
end

--- Make a dialog popup with the full log
function _M:showLogDialog(title, shadow)
	local log = self:getLog()
	local d = require_first("mod.dialogs.ShowLog", "engine.dialogs.ShowLog").new(title or "Message Log", shadow, {log=log})
	game:registerDialog(d)
end

local urlfind = (lpeg.P"http://" + lpeg.P"https://") * (1-lpeg.P" ")^0
local urlmatch = lpeg.anywhere(lpeg.C(urlfind))

--- Appends text to the log
-- This method is set as the call methamethod too, this means it is usable like this:<br/>
-- log = LogDisplay.new(...)<br/>
-- log("foo %s", s)
function _M:call(str, ...)
	str = str or ""
	str = str:format(...)
	print("[LOG]", str)
	local tstr = str:toString()
	if self.out_f then self.out_f:write(tstr:removeColorCodes()) self.out_f:write("\n") end

	local lines = str:splitLines(self.fw, self.font)

	for _, line in ipairs(lines) do
		local url = urlmatch:match(line)
		if url then
			line = line:lpegSub(urlfind, "#LIGHT_BLUE##{italic}#"..url.."#{normal}##LAST#")
		end

		local d = {str=line, timestamp = core.game.getTime(), url=url, id=self.cache_next_id}
		table.insert(self.log, 1, d)
		self.cache_next_id = self.cache_next_id + 1

		while #self.log > self.max_log do
			local od = table.remove(self.log)
			self.cache[od.id] = nil
		end
	end
	self.max = #self.log
	self.changed = true
end

--- Gets the newest log line
function _M:getNewestLine()
	if self.log[1] then return self.log[1].str, self.log[1] end
	return nil
end

--- Clear the log
function _M:empty()
	self.log = {}
	self.cache_next_id = 1
	self.cache = {}
	self.changed = true
end

--- Remove some lines from the log, starting with the newest
-- @param line = number of lines to remove (default 1) or the last line (table, reference) to leave in the log
-- @param [type=table, optional] ret table in which to append removed lines
-- @param [type=number, optional] timestamp of the oldest line to remove
-- @return the table of removed lines or nil
function _M:rollback(line, ret, timestamp)
	local nb = line or 1
	if type(line) == "table" then
		nb = 0
		for i, ln in ipairs(self.log) do
			if ln == line then nb = i - 1 break end
		end
	end
	if nb > 0 then
		for i = 1, nb do
			local removed = self.log[1]
			if not timestamp or removed.timestamp >= timestamp then
				print("[LOG][remove]", removed.timestamp, removed.str)
				table.remove(self.log, 1)
				if ret then ret[#ret+1] = removed end
			else break
			end
		end
		self.changed = true
	end
	return ret
end

--- Get the oldest lines from the log
-- @param number number of lines to retrieve
function _M:getLines(number)
	local from = number
	if from > #self.log then from = #self.log end
	local lines = { }
	for i = from, 1, -1 do
		lines[#lines+1] = tostring(self.log[i].str)
	end
	return lines
end

function _M:onMouse(fct)
	self.on_mouse = fct
end

function _M:mouseEvent(button, x, y, xrel, yrel, bx, by, event)
	if button == "wheelup" then self:scrollUp(1)
	elseif button == "wheeldown" then self:scrollUp(-1)
	else
		if not self.on_mouse or not self.dlist then return end
		local citem = nil
		local ci
		for i = 1, #self.dlist do
			local item = self.dlist[i]
			if item.dh and by >= item.dh - self.mouse.delegate_offset_y then citem = self.dlist[i] ci=i break end
		end
		if citem then
			local sub_es = {}
			for e, _ in pairs(citem.item._dduids) do sub_es[#sub_es+1] = e end

			if citem.url and button == "left" and event == "button" then
				util.browserOpenUrl(citem.url, {is_external=true})
			else
				self.on_mouse(citem, sub_es, button, event, x, y, xrel, yrel, bx, by)
			end
		else
			self.on_mouse(nil, nil, button, event, x, y, xrel, yrel, bx, by)
		end
	end
end

function _M:update()
	-- If nothing changed, return the same surface as before
	if not self.changed then return end
	self.changed = false

	-- Erase and the display
	self.history_container:clear()
	self.dlist = {}
	local h = 0
	for z = 1 + self.scroll, #self.log do
		local tid = self.log[z].id
		local tstr = self.log[z].str
		local gen

		local text
		if self.cache[tid] then
			text = self.cache[tid]
		else
			text = core.renderer.text(self.font)
			self:applyShadowOutline(text)
			text:textColor(unpack(self.color))
			text:text(tstr)
			self.cache[tid] = text
		end

		local fw, fh = text:getStats()
		h = h + fh

		self.dlist[#self.dlist+1] = {item=text, date=self.log[z].reset_fade or self.log[z].timestamp, url=self.log[z].url}
		text:removeFromParent():translate(0, self.h - h, 10)
		self.history_container:add(text)

		if self.fading and not text:hasTween("wait") then text:tween(30 * self.fading, "wait", function(text) text:tween(30, "a", nil, 0, "linear") end) end

		if h > self.h - self.fh then break end
	end
	return
end

function _M:toScreen()
	self.renderer:toScreen()

	if not self.fading and self.scrollbar then
		self.scrollbar.pos = self.scroll
		self.scrollbar.max = self.max - self.max_display + 1
		self.scrollbar:display(self.display_x + self.w - self.scrollbar.w, self.display_y)
	end
end

--- Scroll the zone
-- @param i number representing how many lines to scroll
function _M:scrollUp(i)
	self.scroll = self.scroll + i
	if self.scroll > #self.log - 1 then self.scroll = #self.log - 1 end
	if self.scroll < 0 then self.scroll = 0 end
	self.changed = true
	self:resetFade()
end

function _M:resetFade()
	-- Reset fade
	for _, d in ipairs(self.cache) do
		d:cancelTween(true):tween(5, "a", nil, 1, "linear")
	end
end
