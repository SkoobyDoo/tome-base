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

local tween = require "tween"
local DOVertexes = core.game.getCClass("gl{vertexes}")
local DORenderer = core.game.getCClass("gl{renderer}")
local DOText = core.game.getCClass("gl{text}")
local DOContainer = core.game.getCClass("gl{container}")
local DOTarget = core.game.getCClass("gl{target}")
local DOCallback = core.game.getCClass("gl{callback}")
local DOTileMap = core.game.getCClass("gl{tilemap}")
local DOTileObject = core.game.getCClass("gl{tileobject}")
local DOSpriter = core.game.getCClass("gl{spriter}")
local DOAll = { DOVertexes, DORenderer, DOText, DOContainer, DOTarget, DOCallback, DOTileObject, DOTileMap, DOSpriter }

-----------------------------------------------------------------------------------
-- Loaders and initializers
-----------------------------------------------------------------------------------

function DOVertexes:debugQuad()
	self:quad(
		100, 100, 0, 0,
		164, 100, 1, 0,
		164, 164, 1, 1,
		100, 164, 0, 1,
		1, 1, 1, 1
	)
	return self
end

local white = core.display.loadImage("/data/gfx/white.png"):glTexture()
core.renderer.white = white
core.renderer.plaincolor = white

function DOVertexes:plainColorQuad()
	self:texture(white)
	return self
end

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

function core.renderer.colorQuad(x, y, w, h, r, g, b, a, v)
	v = v or core.renderer.vertexes()
	local x1, x2 = x, x + w
	local y1, y2 = y, y + h
	local u1, u2 = 0, 1
	local v1, v2 = 0, 1
	v:quad(
		x1, y1, u1, v1,
		x2, y1, u2, v1,
		x2, y2, u2, v2,
		x1, y2, u1, v2,
		r, g, b, a
	)
	v:texture(white)
	return v
end

function core.renderer.image(file, x, y, w, h, r, g, b, a, v)
	local s = core.display.loadImage(file)
	return core.renderer.surface(s, x, y, w, h, r, g, b, a, v)
end

function core.renderer.surface(s, x, y, w, h, r, g, b, a, v)
	if not s then return v or core.renderer.container() end
	r = r or 1 g = g or 1 b = b or 1 a = a or 1 
	local tex, rw, rh, tw, th, iw, ih = s:glTexture()
	x = x or 0
	y = y or 0
	w = w or iw
	h = h or ih
	if not v then v = core.renderer.vertexes() end
	local x1, x2 = x, x + w
	local y1, y2 = y, y + h
	local u1, u2 = 0, iw / rw
	local v1, v2 = 0, ih / rh
	v:quad(
		x1, y1, u1, v1,
		x2, y1, u2, v1,
		x2, y2, u2, v2,
		x1, y2, u1, v2,
		r, g, b, a
	)
	v:texture(tex)
	return v, w, h
end

function core.renderer.texture(tex, x, y, w, h, r, g, b, a, v)
	r = r or 1 g = g or 1 b = b or 1 a = a or 1 
	local rw, rh = tex:getSize()
	x = x or 0
	y = y or 0
	w = w or rw
	h = h or rh
	if not v then v = core.renderer.vertexes() end
	local x1, x2 = x, x + w
	local y1, y2 = y, y + h
	local u1, u2 = 0, 1
	local v1, v2 = 0, 1
	v:quad(
		x1, y1, u1, v1,
		x2, y1, u2, v1,
		x2, y2, u2, v2,
		x1, y2, u1, v2,
		r, g, b, a
	)
	v:texture(tex)
	return v, w, h
end

function core.renderer.textureTable(s)
	if type(s) == "string" then s = core.display.loadImage(s) end
	local t = {tx=0, ty=0}
	t.w, t.h = s:getSize()
	t.t, t.tw, t.th = s:glTexture()
	t.tw = t.w / t.tw
	t.th = t.h / t.th
	return t
end

function core.renderer.fromSurface(s, x, y, w, h, repeat_quads, r, g, b, a, v)
	local t = core.renderer.textureTable(s)
	return core.renderer.fromTextureTable(t, x, y, w, h, repeat_quads, r, g, b, a, v)
end

function core.renderer.fromTextureTable(t, x, y, w, h, repeat_quads, r, g, b, a, v)
	r = r or 1 g = g or 1 b = b or 1 a = a or 1 
	x = math.floor(x or 0)
	y = math.floor(y or 0)
	local u1, v1 = t.tx, t.ty
	local u2, v2 = u1 + t.tw, v1 + t.th
	w = math.floor(w or t.w)
	h = math.floor(h or t.h)
	if not repeat_quads or (w <= t.w and h <= t.h) then
		local x1, y1 = x, y
		local x2, y2 = x + w, y + h
		if not v then v = core.renderer.vertexes() end
		v:quad(
			x1, y1, u1, v1,
			x2+0.1, y1, u2, v1,
			x2+0.1, y2+0.1, u2, v2,
			x1, y2+0.1, u1, v2,
			r, g, b, a
		)
		v:texture(t.t)
		return v, w, h
	else
		if not v then v = core.renderer.vertexes() end
		v:texture(t.t)
		local Mi, Mj = math.ceil(w / t.w) - 1, math.ceil(h / t.h) - 1
		v:reserve((Mi+1) * (Mj+1)) -- To prevent multiple reallocations each time we :quad
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

				v:quad(
					x1, y1, u1, v1,
					x2+0.1, y1, u2, v1,
					x2+0.1, y2+0.1, u2, v2,
					x1, y2+0.1, u1, v2,
					r, g, b, a
				)
			end
		end
		return v, w, h
	end
end

function core.renderer.fromTextureTableCut(t, x, y, w, h, py, ph, r, g, b, a, v)
	r = r or 1 g = g or 1 b = b or 1 a = a or 1 
	x = math.floor(x or 0)
	y = math.floor(y or 0)
	local u1, v1 = t.tx, t.ty
	local u2, v2 = u1 + t.tw, v1 + t.th
	w = math.floor(w or t.w)
	h = math.floor(h or t.h)

	if py > 0 then
		v1 = t.ty + t.th * py
		y = y + h * py
	end
	if ph < 1 then
		v2 = t.ty + t.th * ph
		h = h * ph
	end

	local x1, y1 = x, y
	local x2, y2 = x + w, y + h
	if not v then v = core.renderer.vertexes() end
	v:quad(
		x1, y1, u1, v1,
		x2+0.1, y1, u2, v1,
		x2+0.1, y2+0.1, u2, v2,
		x1, y2+0.1, u1, v2,
		r, g, b, a
	)
	v:texture(t.t)
	return v, w, h
end


function core.renderer.targetDisplay(target)
	local v = core.renderer.vertexes()
	local w, h = target:displaySize()
	local x1, x2 = 0, w
	local y1, y2 = 0, h
	local u1, u2 = 0, 1
	local v1, v2 = 1, 0
	v:quad(
		x1, y1, u1, v1,
		x2, y1, u2, v1,
		x2, y2, u2, v2,
		x1, y2, u1, v2,
		1, 1, 1, 1
	)
	v:textureTarget(target, 0)
	return v
end

-----------------------------------------------------------------------------------
-- Tweening stuff
-----------------------------------------------------------------------------------
local tweenslots = {
	x=0, y=1, z=2,
	scale_x = 3, scale_y = 4, scale_z = 5, 
	rot_x = 6, rot_y = 7, rot_z = 8, 
	r = 9, g = 10, b = 11, a = 12,
	wait = 13,
}
local easings = table.reverse{
	"linear",
	"quadraticIn",
	"quadraticOut",
	"quadraticInOut",
	"cubicIn",
	"cubicOut",
	"cubicInOut",
	"quarticIn",
	"quarticOut",
	"quarticInOut",
	"quinticIn",
	"quinticOut",
	"quinticInOut",
	"sinusoidalIn",
	"sinusoidalOut",
	"sinusoidalInOut",
	"exponentialIn",
	"exponentialOut",
	"exponentialInOut",
	"circularIn",
	"circularOut",
	"circularInOut",
	"bounceOut",
	"bounceIn",
	"bounceInOut",
	"elasticIn",
	"elasticOut",
	"elasticInOut",
	"backIn",
	"backOut",
	"backInOut",
}
local compat_easings = {
	linear = "linear",
	inQuad    = "quadraticIn",    outQuad    = "quadraticOut",    inOutQuad    = "quadraticInOut",    --outInQuad    = "outInQuad",
	inCubic   = "cubicIn",   outCubic   = "cubicOut",   inOutCubic   = "cubicInOut",   --outInCubic   = "outInCubic",
	inQuart   = "quarticIn",   outQuart   = "quarticOut",   inOutQuart   = "quarticInOut",   --outInQuart   = "outInQuart",
	inQuint   = "quinticIn",   outQuint   = "quinticOut",   inOutQuint   = "quinticInOut",   --outInQuint   = "outInQuint",
	inSine    = "sinusoidalIn",    outSine    = "sinusoidalOut",    inOutSine    = "sinusoidalInOut",    --outInSine    = "outInSine",
	inExpo    = "exponentialIn",    outExpo    = "exponentialOut",    inOutExpo    = "exponentialInOut",    --outInExpo    = "outInExpo",
	inCirc    = "circularIn",    outCirc    = "circularOut",    inOutCirc    = "circularInOut",    --outInCirc    = "outInCirc",
	inElastic = "elasticIn", outElastic = "elasticOut", inOutElastic = "elasticInOut", --outInElastic = "outInElastic",
	inBack    = "backIn",    outBack    = "backOut",    inOutBack    = "backInOut",    --outInBack    = "outInBack",
	inBounce  = "bounceIn",  outBounce  = "bounceOut",  inOutBounce  = "bounceInOut",  --outInBounce  = "outInBounce",
}
local function doTween(self, time, slot, from, to, easing, on_end, on_change)
	easing = easing or "linear"
	local slotid = tweenslots[slot]
	if not slotid then error("tweening on wrong slot: "..tostring(slot)) end
	if slot == "wait" then
		-- If we use the wait slot, "from", "to", "easing" parameters are useless, so we dont use them
		-- So from becomes on_end and to becaomes on_change
		return self:rawtween(slotid, 0, 0, 1, time, from, to)
	else
		local easingid = easings[compat_easings[easing] or easing]
		if not easingid then error("tweening on wrong easing: "..tostring(easing)) end
		return self:rawtween(slotid, easingid-1, from, to, time, on_end, on_change)
	end
end
local function doCancelTween(self, slot)
	if slot == true then return self:rawcancelTween(true) end
	local slotid = tweenslots[slot]
	if not slotid then error("tweening on wrong slot: "..tostring(slot)) end
	return self:rawcancelTween(slotid)
end

-----------------------------------------------------------------------------------
-- Misc other convenient stuff
-----------------------------------------------------------------------------------
local function doShader(self, shader)
	local t = type(shader)
	if t == "userdata" or t == "nil" then
		return self:_shader(shader)
	elseif t == "table" and shader.__CLASSNAME then
		if shader:isClassName("engine.Shader") then
			if shader.shad then
				return self:_shader(shader.shad)
			else
				error("Setting shader without .shad")
			end
		end
	else
		error("Trying to set shader of type "..t.." on DO "..tostring(self))
	end
end

local function doContainerAdd(self, d)
	local t = type(d)
	if t == "userdata" then
		return self:_add(d)
	elseif t == "table" and d.__CLASSNAME then
		if d:isClassName("engine.Particles") then
			return self:_add(d:getDO())
		end
	else
		error("Trying to add value of type "..t.." into container "..tostring(self))
	end
end

-----------------------------------------------------------------------------------
-- Alter the DOs metatables to add the new methods
-----------------------------------------------------------------------------------
for _, DO in pairs(DOAll) do
	if DO.shader then DO._shader, DO.shader = DO.shader, doShader end
	if DO.add then DO._add, DO.add = DO.add, doContainerAdd end

	DO.tween = doTween
	DO.cancelTween = doCancelTween
end

