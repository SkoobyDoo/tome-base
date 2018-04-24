-- ToME - Tales of Maj'Eyal
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
local Map = require "engine.Map"

module(..., package.seeall, class.make)

function _M:init(font, size)
	self.font = core.display.newFont(font, size, true)
	self.renderer = core.renderer.renderer("static"):setRendererName("BigNews")
end

local UI = require "engine.ui.Base"
_M.setTextOutline = UI.setTextOutline
_M.setTextShadow = UI.setTextShadow
_M.applyShadowOutline = UI.applyShadowOutline

function _M:say(time, txt, ...)
	return self:easing(time, nil, txt, ...)
end

function _M:easing(time, easing, txt, ...)
	self:easingSimple(time, easing, txt, ...)
	game.logPlayer(game.player, "%s", txt:toString())
end

function _M:saySimple(time, txt, ...)
	return self:easingSimple(time, nil, txt, ...)
end

function _M:easingSimple(time, easing, txt, ...)
	txt = txt:format(...)

	if game.player then
		if game.player.stopRun then game.player:stopRun("important news") end
		if game.player.stopRest then game.player:stopRest("important news") end
	end
	self:triggerHook{"BigNews:talk", text=txt}	

	local text = core.renderer.text(self.font):maxWidth(math.floor(game.w * 0.8))
	self:applyShadowOutline(text)
	text:text(txt:toString()):center()
	self.renderer:add(text)

	local w, h, nb_lines = text:getStats()
	text:translate(math.floor(game.w / 2), math.floor(game.h / 5))

	text:tween(time or 60, "y", nil, math.floor(game.h / 5) - self.font:height() * 2, easing or "inQuint")
	text:tween(time or 60, "scale_x", nil, 0.001, easing or "inQuint")
	text:tween(time or 60, "scale_y", nil, 0.001, easing or "inQuint", function() self.renderer:remove(text) end)
end

function _M:display(nb_keyframes)
	self.renderer:toScreen()
end
