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
local Dialog = require "engine.ui.Dialog"
local Checkbox = require "engine.ui.Checkbox"
local Textbox = require "engine.ui.Textbox"
local Numberbox = require "engine.ui.Numberbox"
local Textzone = require "engine.ui.Textzone"
local Dropdown = require "engine.ui.Dropdown"
local Separator = require "engine.ui.Separator"
local ColorPicker = require "engine.ui.ColorPicker"
local List = require "engine.ui.List"
local PC = core.particlescompose

--- Particles editor
-- @classmod engine.dialogs.ParticlesComposeEditor
module(..., package.seeall, class.inherit(Dialog))

local texp1 = core.loader.png("/data/gfx/particle.png")
local texboom = core.loader.png("/data/gfx/particle_boom_anim.png")
local pdef = {
	{
		max_particles = 1, blend = PC.AdditiveBlend,
		texture = texboom,
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, min=0.3, max=3},
				{PC.DiskPosGenerator, radius=0},
				{PC.BasicSizeGenerator, min_size=64, max_size=64},
				{PC.BasicRotationGenerator, min_rot=0, max_rot=math.pi*2},
				{PC.FixedColorGenerator, color_start=colors_alphaf.WHITE(1), color_stop=colors_alphaf.WHITE(1)},
			}, rate=1/30, nb=20},
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater},
			{PC.AnimatedTextureUpdater, repeat_over_life=2, splitx=5, splity=5, firstframe=0, lastframe=22},
			-- {PC.EulerPosUpdater}--, global_vel={30, -120}},
		},
	},
}
-- local pdef = {
-- 	{
-- 		max_particles = 2000, blend = PC.AdditiveBlend,
-- 		texture = texp1,
-- 		emitters = {
-- 			{PC.LinearEmitter, {
-- 				{PC.BasicTextureGenerator},
-- 				{PC.LifeGenerator, min=0.3, max=3},
-- 				{PC.TrianglePosGenerator, p1={-200, 100}, p2={200, 100}, p3={0, -100}},
-- 				-- {PC.CirclePosGenerator, radius=300, width=50},
-- 				{PC.DiskVelGenerator, min_vel=30, max_vel=100},
-- 				{PC.BasicSizeGenerator, min_size=10, max_size=50},
-- 				{PC.BasicRotationGenerator, min_rot=0, max_rot=math.pi*2},
-- 				{PC.StartStopColorGenerator, min_color_start=colors_alphaf.GOLD(1), max_color_start=colors_alphaf.ORANGE(1), min_color_stop=colors_alphaf.GREEN(0), max_color_stop=colors_alphaf.LIGHT_GREEN(0)},
-- 			}, rate=1/30, nb=20},
-- 		},
-- 		updaters = {
-- 			{PC.BasicTimeUpdater},
-- 			{PC.LinearColorUpdater},
-- 			-- {PC.AnimatedTextureUpdater, repeat_over_life=1, splitx=5, splity=5, firstframe=0, lastframe=22},
-- 			{PC.EulerPosUpdater}--, global_vel={30, -120}},
-- 		},
-- 	},
-- }

local blendmodes = {
	{name="DefaultBlend", blend=PC.DefaultBlend},
	{name="AdditiveBlend", blend=PC.AdditiveBlend},
	{name="MixedBlend", blend=PC.MixedBlend},
	{name="ShinyBlend", blend=PC.ShinyBlend},
}

local specific_uis = {
	[PC.LifeGenerator] = {name="LifeGenerator", fields={
		{type="number", id="min", text="Min seconds: ", min=0.00001, max=600, default=1},
		{type="number", id="max", text="Max seconds: ", min=0.00001, max=600, default=3},
	}},
	[PC.BasicTextureGenerator] = {name="BasicTextureGenerator", fields={}},
	[PC.DiskPosGenerator] = {name="DiskPosGenerator", fields={
		{type="number", id="radius", text="Radius: ", min=0, max=10000, default=1},
	}},
	[PC.CirclePosGenerator] = {name="CirclePosGenerator", fields={
		{type="number", id="radius", text="Radius: ", min=0, max=10000, default=1},
		{type="number", id="width", text="Width: ", min=0, max=10000, default=3},
	}},
	[PC.TrianglePosGenerator] = {name="TrianglePosGenerator", fields={
		{type="point", id="p1", text="P1: ", min=-10000, max=10000, default={0, 0}},
		{type="point", id="p2", text="P2: ", min=-10000, max=10000, default={0, 0}},
		{type="point", id="p3", text="P3: ", min=-10000, max=10000, default={0, 0}},
	}},
	[PC.DiskVelGenerator] = {name="DiskVelGenerator", fields={
		{type="number", id="min_vel", text="Min velocity: ", min=0, max=1000, default=1},
		{type="number", id="max_vel", text="Max velocity: ", min=0, max=1000, default=3},
	}},
	[PC.BasicSizeGenerator] = {name="BasicSizeGenerator", fields={
		{type="number", id="min_size", text="Min size: ", min=0.00001, max=1000, default=10},
		{type="number", id="max_size", text="Max size: ", min=0.00001, max=1000, default=30},
	}},
	[PC.BasicRotationGenerator] = {name="BasicRotationGenerator", fields={
		{type="number", id="min_rot", text="Min rotation: ", min=0, max=360, default=0, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
		{type="number", id="max_rot", text="Max rotation: ", min=0, max=360, default=360, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
	}},
	[PC.StartStopColorGenerator] = {name="StartStopColorGenerator", fields={
		{type="color", id="min_color_start", text="Min start color: ", default=colors_alphaf.GOLD(1)},
		{type="color", id="max_color_start", text="Max start color: ", default=colors_alphaf.ORANGE(1)},
		{type="color", id="min_color_stop", text="Min stop color: ", default=colors_alphaf.GREEN(0)},
		{type="color", id="max_color_stop", text="Max stop color: ", default=colors_alphaf.LIGHT_GREEN(0)},
	}},
	[PC.FixedColorGenerator	] = {name="FixedColorGenerator", fields={
		{type="color", id="color_start", text="Start color: ", default=colors_alphaf.GOLD(1)},
		{type="color", id="color_stop", text="Stop color: ", default=colors_alphaf.LIGHT_GREEN(0)},
	}},
}

function _M:processSpecificUI(ui, add, spe, delete)
	local spe_def = specific_uis[spe[1]]
	if not spe_def then error("unknown def for: "..tostring(spe[1])) end
	add(Checkbox.new{title="#{bold}##GOLD#"..spe_def.name, default=true, fct=function()end, on_change=delete})
	local adds = {}
	for i, field in ipairs(spe_def.fields) do
		field.from = field.from or function(v) return v end
		field.to = field.to or function(v) return v end
		if field.type == "number" then
			adds[#adds+1] = Numberbox.new{title=field.text, number=field.to(spe[field.id]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "point" then
			adds[#adds+1] = Numberbox.new{title=field.text, number=field.to(spe[field.id][1]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id][1] = field.from(p) self:regenParticle() end, fct=function()end}
			adds[#adds+1] = Numberbox.new{title="x", number=field.to(spe[field.id][2]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id][2] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "color" then
			adds[#adds+1] = Textzone.new{text=(i==1 and "    " or "")..field.text, auto_width=1, auto_height=1}
			adds[#adds+1] = ColorPicker.new{color=spe[field.id], width=20, height=20, fct=function(p) spe[field.id] = p self:regenParticle() end}
		end
	end
	add(unpack(adds))
	add(8)
end

function _M:makeUI()
	local def = pdef
	local ui = {}
	local y = 0
	local lastc = nil
	local function add(...)
		local args = {...}
		if type(args[1]) == "number" then y = y + args[1] return args[1] end
		local max_h = 0
		for i, c in ipairs(args) do if c.h > max_h then max_h = c.h end end
		for i, c in ipairs(args) do
			ui[#ui+1] = {left=i > 1 and args[i-1] or 0, top=y + (max_h - c.h) / 2, ui=c}
		end
		y = y + max_h
		return max_h
	end
	for id_system, system in ipairs(def) do
		add(Textzone.new{text="#{bold}##OLIVE_DRAB#----------======System "..id_system.."======----------", width=self.iw, center_w=true, auto_height=1})
		add(Textzone.new{text="Max: ", auto_width=1, auto_height=1}, Numberbox.new{number=system.max_particles, min=1, max=100000, chars=6, on_change=function(p) system.max_particles = p self:regenParticle() end, fct=function()end})
		add(Textzone.new{text="Blend: ", auto_width=1, auto_height=1}, Dropdown.new{width=200, default={"blend", system.blend}, fct=function(item) system.blend = item.blend self:regenParticle() self:makeUI() end, on_select=function(item)end, list=blendmodes, nb_items=#blendmodes})
		
		for id_emitter, emitter in ipairs(system.emitters) do
			y = y + 20 y = y - add(Separator.new{dir="vertical", size=self.iw})
			add(Textzone.new{text="#{bold}##CRIMSON#----== Emitter "..id_emitter.." ==----", center_w=true, width=self.iw, auto_height=1}) y = y + 10
			add(
				Textzone.new{text="Emit triggers/second: ", auto_width=1, auto_height=1}, Numberbox.new{number=(1/emitter.rate), min=0.00001, max=60, chars=6, on_change=function(p) emitter.rate = 1/p self:regenParticle() end, fct=function()end},
				Textzone.new{text="Particles per trigger: ", auto_width=1, auto_height=1}, Numberbox.new{number=emitter.nb, min=0, max=100000, chars=6, on_change=function(p) emitter.nb = p self:regenParticle() end, fct=function()end}
			)
			add(Separator.new{dir="vertical", size=self.iw * 0.5})

			for id_generator, generator in ipairs(emitter[2]) do
				local id = id_generator
				self:processSpecificUI(ui, add, generator, function() table.remove(emitter[2], id) self:makeUI() self:regenParticle() end)
			end
		end
		
		y = y + 20 y = y - add(Separator.new{dir="vertical", size=self.iw})
		add(Textzone.new{text="#{bold}##AQUAMARINE#----== Updaters ==----", center_w=true, width=self.iw, auto_height=1}) y = y + 10
	end
	self:loadUI(ui)
	self:setupUI(false, false)
end

function _M:init()
	Dialog.init(self, _t"Particles Editor", 500, game.h * 0.9, game.w - 550)
	self.__showup = false
	self.absolute = true

	self.p = PC.new(pdef)
	self.p:shift((game.w - 550) / 2, game.h / 2, true)

	self:makeUI(pdef)

	self.key:setupRebootKeys()
	self.key:addBinds{
		EXIT = function() end,
	}

	self.mouse:registerZone(0, 0, game.w, game.h, function(button, mx, my)
		if mx < game.w - 550 then self.p:shift(mx, my, true)
		else self.p:shift((game.w - 550) / 2, game.h / 2, true) end
		return false
	end)
end

function _M:regenParticle()
	self.p = PC.new(pdef)
	self.p:shift((game.w - 550) / 2, game.h / 2)
end

function _M:innerDisplay(x, y, nb_keyframes)
	self.p:toScreen(0, 0, nb_keyframes)
end

function _M:use(item)
	item.fct()
end

