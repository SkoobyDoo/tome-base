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

--- Handles a particles system
-- Used by engine.Map
-- @classmod engine.Particles
module(..., package.seeall, class.make)

local __particles_gl = {}
setmetatable(__particles_gl, {__mode="v"})

--- Make a particle emitter
function _M:init(def, radius, args, shader)
	self.args = args or {}
	self.def = def
	self.radius = radius or 1
	self.shader = shader

	self:loaded()
end

--- Serialization
function _M:save()
	return class.save(self, {
		ps = true,
		_do = true,
		gl_texture = true,
		_shader = true,
	})
end

function _M:cloned()
	self:loaded()
end

function _M:loaded()
	if not self.args then self.args = {} end
	local base_size = nil
	local gl = nil
	local islast = false
	local allow_bloom = false
	local sub_particle = self.args.sub_particle
	local sub_particle_args = self.args.sub_particle_args
	if type(self.def) == "string" then	
		if not config.settings.cheat and not fs.exists("/data/gfx/particles/"..self.def..".lua") then
			print("[PARTICLES] system"..self.def.." does not exist, replacing with dummy")
			self.def = "dummy"
		end
		
		local f, err = loadfile("/data/gfx/particles/"..self.def..".lua")
		if not f and err then error(err) end
		local t = self.args or {}
		local _
		setfenv(f, setmetatable(t, {__index=_G}))
		_, _ , _, gl, _ = f()
		setmetatable(t, nil)

		if t.use_shader then self.shader = t.use_shader end
		if t.alterscreen then islast = true end
		if t.allow_bloom then allow_bloom = true end
		if t.toback then self.toback = true end
		if t.sub_particle then sub_particle = t.sub_particle end
		if t.sub_particle_args then sub_particle_args = t.sub_particle_args end
		if t.can_shift then self.can_shift = true end
		if t.supports_death_anim then self.supports_death_anim = true end
	else error("unsupported particle type: "..type(self.def))
	end

	gl = gl or "particle"
	if not __particles_gl[gl] then __particles_gl[gl] = core.loader.png("/data/gfx/"..gl..".png", false, false, true) end
	if not __particles_gl[gl] then __particles_gl[gl] = core.loader.png("/data/gfx/particle.png", false, false, true) end
	gl = __particles_gl[gl]

	-- Zoom accordingly
	self.base_size = base_size
	self:updateZoom()

	-- Serialize arguments for passing into the particles threads
	local args = table.serialize(self.args or {}, nil, true)
	args = args.."tile_w="..engine.Map.tile_w.."\ntile_h="..engine.Map.tile_h

	self.update = fct

	local sha = nil
	if self.shader then
		if self.shader.__CLASSNAME == "engine.Shader" then
			sha = self.shader.shad
		else
			if not self._shader then
				local Shader = require 'engine.Shader'
				self._shader = Shader.new(self.shader.type, self.shader)
			end

			sha = self._shader.shad
		end
	end

	if islast and allow_bloom then error("Particle defined with both bloom and alterscreen") end
	self.ps = core.particles.newEmitter("/data/gfx/particles/"..self.def..".lua", args, self.zoom, config.settings.particles_density or 100, gl, sha, islast, allow_bloom, self.can_shift)
	self.gl_texture = gl

	if sub_particle then
		self:setSub(sub_particle, 1, sub_particle_args)
	end

end

--- Gets a DisplayObject representing this particle
-- Beware, do not keep a reference to the Particles afterwards unless needed; just keep one to the DO which will itself reference the Particles
function _M:getDO()
	if not self.ps then return end
	return self.ps:getDO()
end

function _M:setSub(def, radius, args, shader)
	self.subps = _M.new(def, radius, args, shader)
	self.ps:setSub(self.subps.ps)
end

function _M:updateZoom()
	self.zoom = self.zoom or 1
	if self.base_size then
		self.zoom = ((engine.Map.tile_w + engine.Map.tile_h) / 2) / self.base_size
	end
end

function _M:checkDisplay()
	if self.ps then return end
	self:loaded()
end

function _M:onDie(fct)
	self.on_die = fct
end

function _M:dieDisplay(no_callback)
	if not self.ps then return end
	if not no_callback and self.on_die then self:on_die() end
	self.ps:die()
	self.ps = nil
end

function _M:shift(map, mo)
	if not self.can_shift then return end
	local Map = require "engine.Map"
	if not Map.tile_w then return end

	local adx, ady = mo:getWorldPos()
	if self._adx then
		self.ps:shift((self._adx - adx) * Map.tile_w, (self._ady - ady) * Map.tile_h)
	end					
	self._adx, self._ady = adx, ady
end

function _M:shiftCustom(dx, dy)
	if not self.can_shift then return end

	self.ps:shift(dx, dy)
end
