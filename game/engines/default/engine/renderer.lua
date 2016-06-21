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

local tween = require "tween"
local DOVertexes = core.game.getCClass("gl{vertexes}")
local DORenderer = core.game.getCClass("gl{renderer}")
local DOText = core.game.getCClass("gl{text}")
local DOContainer = core.game.getCClass("gl{container}")
local DOTarget = core.game.getCClass("gl{target}")
local DOCallback = core.game.getCClass("gl{callback}")
local DOTileMap = core.game.getCClass("gl{tilemap}")
local DOTileObject = core.game.getCClass("gl{tileobject}")
local DOAll = { DOVertexes, DORenderer, DOText, DOContainer, DOTarget, DOCallback, DOTileObject, DOTileMap }

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
	return v
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
	return v
end

function core.renderer.fromSurface(s, x, y, w, h, repeat_quads, r, g, b, a, v)
	local t = {tx=0, ty=0}
	t.w, t.h = s:getSize()
	t.t, t.tw, t.th = s:glTexture()
	t.tw = t.w / t.tw
	t.th = t.h / t.th
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
		return v
	else
		if not v then v = core.renderer.vertexes() end
		v:texture(t.t)
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

				v:quad(
					x1, y1, u1, v1,
					x2+0.1, y1, u2, v1,
					x2+0.1, y2+0.1, u2, v2,
					x1, y2+0.1, u1, v2,
					r, g, b, a
				)
			end
		end
		return v
	end
end

-----------------------------------------------------------------------------------
-- Tweening stuff
-----------------------------------------------------------------------------------
local tweenstore = setmetatable({}, {__mode="k"})

function core.renderer.dumpCurrentTweens()
	print("== Tweenstore ==")
	for DO, list in pairs(tweenstore) do
		print("* "..tostring(DO))
		for tn, tw in pairs(list) do
			print("  - "..tn.." => "..tostring(tw))
		end
	end
end

local function doCancelAllTweens(self)
	if not self then return end
	if self.__getstrong then self = self.__getstrong end
	if not tweenstore[self] then return end
	for tn, tw in pairs(tweenstore[self]) do
		tween.stop(tw)
	end
	tweenstore[self] = nil
end

local function doCancelTween(self, tn)
	if tn == "toto" then print("!!TOTO CANCEL") util.show_backtrace() end
	if not self then return end
	if self.__getstrong then self = self.__getstrong end
	if not tweenstore[self] or not tweenstore[self][tn] then return end
	tween.stop(tweenstore[self][tn])
	tweenstore[self][tn] = nil
end

local function doColorTween(self, tn, time, component, from, to, mode, on_end)
	local weak = class.weakSelf(self)
	if not tn then tn = rng.range(1, 99999) else doCancelTween(self, tn) end
	local base_on_end = on_end
	on_end = function() if base_on_end then base_on_end() end doCancelTween(weak.__getstrong, tn) end
	local tw
	mode = mode or "linear"
	local fr, fg, fb, fa = self:getColor()
	if component == "r" then
		from = from or fr
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:color(v, -1, -1, -1) end end, {from, to}, mode, on_end)
	elseif component == "g" then
		from = from or fg
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:color(-1, v, -1, -1) end end, {from, to}, mode, on_end)
	elseif component == "b" then
		from = from or fb
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:color(-1, -1, v, -1) end end, {from, to}, mode, on_end)
	else
		from = from or fa
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:color(-1, -1, -1, v) end end, {from, to}, mode, on_end)
	end
	if tw then
		if not tweenstore[self] then tweenstore[self] = setmetatable({}, {__mode="v"}) end
		tweenstore[self][tn] = tw
	end
	return tw
end

local function doRotateTween(self, tn, time, component, from, to, mode, on_end)
	local weak = class.weakSelf(self)
	if not tn then tn = rng.range(1, 99999) else doCancelTween(self, tn) end
	local base_on_end = on_end
	on_end = function() if base_on_end then base_on_end() end doCancelTween(weak.__getstrong, tn) end
	local tw
	mode = mode or "linear"
	local x, y, z = self:getRotate()
	if component == "x" then
		from = from or x
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:rotate(v, y, z) end end, {from, to}, mode, on_end)
	elseif component == "y" then
		from = from or y
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:rotate(x, v, z) end end, {from, to}, mode, on_end)
	else
		from = from or z
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:rotate(x, y, v) end end, {from, to}, mode, on_end)
	end
	if tw then
		if not tweenstore[self] then tweenstore[self] = setmetatable({}, {__mode="v"}) end
		tweenstore[self][tn] = tw
	end
	return tw
end

local function doTranslateTween(self, tn, time, component, from, to, mode, on_end)
	local weak = class.weakSelf(self)
	if not tn then tn = rng.range(1, 99999) else doCancelTween(self, tn) end
	local base_on_end = on_end
	on_end = function() if base_on_end then base_on_end() end print("????", base_on_end) doCancelTween(weak.__getstrong, tn) end
	local tw
	mode = mode or "linear"
	local x, y, z = self:getTranslate()
	if component == "x" then
		from = from or x
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:translate(v, y, z) end end, {from, to}, mode, on_end)
	elseif component == "y" then
		from = from or y
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:translate(x, v, z) end end, {from, to}, mode, on_end)
	else
		from = from or z
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:translate(x, y, v) end end, {from, to}, mode, on_end)
	end
	if tw then
		if not tweenstore[self] then tweenstore[self] = setmetatable({}, {__mode="v"}) end
		tweenstore[self][tn] = tw
	end
	return tw
end

local function doScaleTween(self, tn, time, component, from, to, mode, on_end)
	local weak = class.weakSelf(self)
	if not tn then tn = rng.range(1, 99999) else doCancelTween(self, tn) end
	local base_on_end = on_end
	on_end = function() if base_on_end then base_on_end() end doCancelTween(weak.__getstrong, tn) end
	local tw
	mode = mode or "linear"
	local x, y, z = self:getScale()
	if component == "x" then
		from = from or x
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:scale(v, y, z) end end, {from, to}, mode, on_end)
	elseif component == "y" then
		from = from or y
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:scale(x, v, z) end end, {from, to}, mode, on_end)
	else
		from = from or z
		tw = tween(time, function(v) if weak.__getstrong then weak.__getstrong:scale(x, y, v) end end, {from, to}, mode, on_end)
	end
	if tw then
		if not tweenstore[self] then tweenstore[self] = setmetatable({}, {__mode="v"}) end
		tweenstore[self][tn] = tw
	end
	return tw
end

for _, DO in pairs(DOAll) do
	DO.cancelTween = doCancelTween
	DO.cancelAllTweens = doCancelAllTweens
	DO.colorTween = doColorTween
	DO.translateTween = doTranslateTween
	DO.rotateTween = doRotateTween
	DO.scaleTween = doScaleTween
end
