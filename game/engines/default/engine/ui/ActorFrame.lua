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
local Base = require "engine.ui.Base"
local Tiles = require "engine.Tiles"


--- @classmod engine.ui.ActorFrame
module(..., package.seeall, class.inherit(Base))

function _M:init(t)
	self:proxyData{"actor", "entity"}

	self.actor = t.actor or t.entity
	self.w = assert(t.w or t.width, "no actorframe w")
	self.h = assert(t.h or t.height, "no actorframe h")
	self.tiles = t.tiles or Tiles.new(self.w, self.h, nil, nil, true, nil)
	self.back_color = t.back_color

	t.request_renderer = true
	Base.init(self, t)

	self.inited = true
	if self.actor then self:setActor(self.actor) end
end

function _M:setActor(actor)
	self.actor = actor
end
_M.setEntity = _M.setActor

function _M:generate()
	self.mouse:reset()
	self.key:reset()
end

function _M:proxyDataSet(k, v)
	if (k == "actor" or k == "entity") and self.inited then
		local actor = v
		if actor.getDO then
			self.do_container:clear()
			if self.back_color then self.do_container:add(core.renderer.colorQuad(0, 0, self.w, self.h, colors.smart1unpack(self.back_color))) end
			self.do_container:add(actor:getDO(self.w, self.h))
		end
	end
	return true
end
