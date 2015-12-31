-- TE4 - T-Engine 4
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

local DOVertexes = getmetatable(core.renderer.vertexes()).__index

function DOVertexes:debugQuad()
	self:quad(
		100, 100, 0, 0,
		164, 100, 1, 0,
		164, 164, 1, 1,
		100, 164, 0, 1,
		1, 1, 1, 1
	)
end

local white = core.display.loadImage("/data/gfx/white.png"):glTexture()
function core.renderer.redPoint()
	local v = core.renderer.vertexes()
	local x1, x2 = -4, 4
	local y1, y2 = -4, 4
	local u1, u2 = 0, 1
	local v1, v2 = 0, 1
	v:quad(
		x1, y1, u1, v1,
		x2, y1, u2, v1,
		x2, y2, u2, v2,
		x1, y2, u1, v2,
		1, 0, 0, 1
	)
	v:texture(white)
	return v
end

function core.renderer.fromTextureTable(t, x, y, w, h, repeat_quads)
	x = math.floor(x)
	y = math.floor(y)
	local u1, v1 = t.tx, t.ty
	local u2, v2 = u1 + t.tw, v1 + t.th
	w = math.floor(w or t.w)
	h = math.floor(h or t.h)
	if not repeat_quads or (w <= t.w and h <= t.h) then
		local x1, y1 = x, y
		local x2, y2 = x + w, y + h
		local v = core.renderer.vertexes()
		v:quad(
			x1, y1, u1, v1,
			x2+0.1, y1, u2, v1,
			x2+0.1, y2+0.1, u2, v2,
			x1, y2+0.1, u1, v2,
			1, 1, 1, 1
		)
		v:texture(t.t)
		return v
	else
		local c = core.renderer.container()
		local Mi, Mj = math.ceil(w / t.w) - 1, math.ceil(h / t.h) - 1
		for i = 0, Mi do
			for j = 0, Mj do
				local u1, u2, v1, v2 = u1, u2, v1, v2
				local x1, y1 = x + i * t.w, y + j * t.h
				local x2, y2 = x1 + t.w, y1 + t.h

				if i == Mi and w % t.w > 0 then
					x2 = x1 + w % t.w
					u2 = u1 + t.tw * (w % t.w) / t.w
				end
				if j == Mj and h % t.h > 0 then
					y2 = y1 + h % t.h
					v2 = v1 + t.th * (h % t.h) / t.h
				end

				local v = core.renderer.vertexes()
				v:quad(
					x1, y1, u1, v1,
					x2+0.1, y1, u2, v1,
					x2+0.1, y2+0.1, u2, v2,
					x1, y2+0.1, u1, v2,
					1, 1, 1, 1
				)
				v:texture(t.t)
				c:add(v)
			end
		end
		return c
	end
end
