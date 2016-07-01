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

require "engine.class"
local FontPackage = require "engine.FontPackage"
local LogDisplay = require "engine.LogDisplay"
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"

--- Log display for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

function _M:init(minimalist)
	MiniContainer.init(self, minimalist)

	local font, size = FontPackage:getFont("default")
	self.logdisplay = LogDisplay.new(0, 0, self.w, self.h, nil, font, size, nil, nil)
	self.logdisplay.resizeToLines = function() end
	self.logdisplay:enableShadow(1)
	self.logdisplay:enableFading(config.settings.tome.log_fade or 3)

	minimalist.logdisplay = self.logdisplay -- for old code compatibility
end

function _M:getDefaultGeometry()
	local x = 0
	local w = math.floor(game.w / 2)
	local h = math.floor(game.h / 5)
	local y = game.h - h
	return x, y, w, h
end

function _M:getDO()
	return self.logdisplay.renderer
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
	self:getDO():translate(x, y, 0)
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
	self.logdisplay:resize(0, 0, w, h)
	self:getDO():translate(self.x, self.y, 0)
end

function _M:getPlace()
	local w, h = core.display.size()

	local th = 52
	if config.settings.tome.hotkey_icons then th = (8 + config.settings.tome.hotkey_icons_size) * config.settings.tome.hotkey_icons_rows end
	local hup = h - th
	return "gamelog", {x=0, y=0, scale=1, a=0}
end
