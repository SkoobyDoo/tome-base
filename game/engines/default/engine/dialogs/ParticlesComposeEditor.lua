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
local KeyBind = require "engine.KeyBind"
local FontPackage = require "engine.FontPackage"
local BigNews = require "engine.BigNews"
local Dialog = require "engine.ui.Dialog"
local Checkbox = require "engine.ui.Checkbox"
local Textbox = require "engine.ui.Textbox"
local Numberbox = require "engine.ui.Numberbox"
local Textzone = require "engine.ui.Textzone"
local Dropdown = require "engine.ui.Dropdown"
local NumberSlider = require "engine.ui.NumberSlider"
local Separator = require "engine.ui.Separator"
local ColorPicker = require "engine.ui.ColorPicker"
local DisplayObject = require "engine.ui.DisplayObject"
local ImageList = require "engine.ui.ImageList"
local List = require "engine.ui.List"
local Button = require "engine.ui.Button"
local Shader = require "engine.Shader"
local PC = core.particlescompose

--- Particles editor
-- @classmod engine.dialogs.ParticlesComposeEditor
module(..., package.seeall, class.inherit(Dialog))

local UIDialog

local new_default_emitter = {PC.LinearEmitter, {
	{PC.BasicTextureGenerator},
	{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
	{PC.DiskPosGenerator, radius=50.000000},
	{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
	{PC.DiskVelGenerator, max_vel=150.000000, min_vel=50.000000},
	{PC.LifeGenerator, min=1.000000, max=3.000000},
}, duration=-1.000000, startat=0.000000, nb=10.000000, rate=0.030000 }

local new_default_system = {
	max_particles = 100, blend=PC.DefaultBlend,
	texture = "/data/gfx/particle.png",
	emitters = { new_default_emitter },
	updaters = {
		{PC.BasicTimeUpdater},
		{PC.LinearColorUpdater},
		{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
	},
}

local pdef_history = {}
local pdef_history_pos = 0
local particle_speed = 1
local particle_zoom = 1

local pdef = {
	{
		max_particles = 2000, blend = PC.ShinyBlend,
		texture = "/data/gfx/particle.png", shader = "particles/glow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, duration=10, min=0.3, max=3},
				-- {PC.TrianglePosGenerator, p1={-200, 100}, p2={200, 100}, p3={0, -100}},
				{PC.CirclePosGenerator, radius=300, width=20},
				{PC.DiskVelGenerator, min_vel=30, max_vel=100},
				{PC.BasicSizeGenerator, min_size=10, max_size=50},
				{PC.BasicRotationGenerator, min_rot=0, max_rot=math.pi*2},
				{PC.StartStopColorGenerator, min_color_start=colors_alphaf.GOLD(1), max_color_start=colors_alphaf.ORANGE(1), min_color_stop=colors_alphaf.GREEN(0), max_color_stop=colors_alphaf.LIGHT_GREEN(0)},
			}, rate=0.03, nb=20},
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater},
			{PC.EulerPosUpdater, global_vel={30, -120}},
		},
	},
}

local blendmodes = {
	{name="DefaultBlend", blend=PC.DefaultBlend},
	{name="AdditiveBlend", blend=PC.AdditiveBlend},
	{name="MixedBlend", blend=PC.MixedBlend},
	{name="ShinyBlend", blend=PC.ShinyBlend},
}
local blend_by_id = table.map(function(k, v) return v.blend, v.name end, blendmodes)

local easings = {
	{name="linear"},
	{name="inQuad"},
	{name="outQuad"},
	{name="inOutQuad"},
	{name="inCubic"},
	{name="outCubic"},
	{name="inOutCubic"},
	{name="inQuart"},
	{name="outQuart"},
	{name="inOutQuart"},
	{name="inQuint"},
	{name="outQuint"},
	{name="inOutQuint"},
	{name="inSine"},
	{name="outSine"},
	{name="inOutSine"},
	{name="inExpo"},
	{name="outExpo"},
	{name="inOutExpo"},
	{name="inCirc"},
	{name="outCirc"},
	{name="inOutCirc"},
	{name="inElastic"},
	{name="outElastic"},
	{name="inOutElastic"},
	{name="inBack"},
	{name="outBack"},
	{name="inOutBack"},
	{name="inBounce"},
	{name="outBounce"},
	{name="inOutBounce"},
}

local specific_uis = {
	emitters = {
		[PC.LinearEmitter] = {name="LinearEmitter", category="emitter", addnew=new_default_emitter, fields={
			{type="number", id="rate", text="Triggers every seconds: ", min=0.016, max=600, default=0.033},
			{type="number", id="nb", text="Particles per trigger: ", min=0, max=100000, default=30, line=true},
			{type="number", id="startat", text="Start at second: ", min=0, max=600, default=0},
			{type="number", id="duration", text="Work for seconds (-1 for infinite): ", min=-1, max=600, default=-1},
			{type="invisible", id=2, default={}},
		}},
	},
	generators = {
		[PC.LifeGenerator] = {name="LifeGenerator", category="life", fields={
			{type="number", id="min", text="Min seconds: ", min=0.00001, max=600, default=1},
			{type="number", id="max", text="Max seconds: ", min=0.00001, max=600, default=3},
		}},
		[PC.BasicTextureGenerator] = {name="BasicTextureGenerator", category="texture", fields={}},
		[PC.OriginPosGenerator] = {name="OriginPosGenerator", category="position", fields={}},
		[PC.DiskPosGenerator] = {name="DiskPosGenerator", category="position", fields={
			{type="number", id="radius", text="Radius: ", min=0, max=10000, default=150},
		}},
		[PC.CirclePosGenerator] = {name="CirclePosGenerator", category="position", fields={
			{type="number", id="radius", text="Radius: ", min=0, max=10000, default=150},
			{type="number", id="width", text="Width: ", min=0, max=10000, default=20},
		}},
		[PC.TrianglePosGenerator] = {name="TrianglePosGenerator", category="position", fields={
			{type="point", id="p1", text="P1: ", min=-10000, max=10000, default={0, 0}},
			{type="point", id="p2", text="P2: ", min=-10000, max=10000, default={100, 100}},
			{type="point", id="p3", text="P3: ", min=-10000, max=10000, default={-100, 100}},
		}},
		[PC.DiskVelGenerator] = {name="DiskVelGenerator", category="movement", fields={
			{type="number", id="min_vel", text="Min velocity: ", min=0, max=1000, default=50},
			{type="number", id="max_vel", text="Max velocity: ", min=0, max=1000, default=150},
		}},
		[PC.DirectionVelGenerator] = {name="DirectionVelGenerator", category="movement", fields={
			{type="point", id="from", text="From: ", min=-10000, max=10000, default={0, 0}},
			{type="number", id="min_vel", text="Min velocity: ", min=0, max=1000, default=50},
			{type="number", id="max_vel", text="Max velocity: ", min=0, max=1000, default=150},
		}},
		[PC.BasicSizeGenerator] = {name="BasicSizeGenerator", category="size", fields={
			{type="number", id="min_size", text="Min size: ", min=0.00001, max=1000, default=10},
			{type="number", id="max_size", text="Max size: ", min=0.00001, max=1000, default=30},
		}},
		[PC.StartStopSizeGenerator] = {name="StartStopSizeGenerator", category="size", fields={
			{type="number", id="min_start_size", text="Min start: ", min=0.00001, max=1000, default=10},
			{type="number", id="max_start_size", text="Max start: ", min=0.00001, max=1000, default=30},
			{type="number", id="min_stop_size", text="Min stop: ", min=0.00001, max=1000, default=1},
			{type="number", id="max_stop_size", text="Max stop: ", min=0.00001, max=1000, default=3},
		}},
		[PC.BasicRotationGenerator] = {name="BasicRotationGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation: ", min=0, max=360, default=0, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
			{type="number", id="max_rot", text="Max rotation: ", min=0, max=360, default=360, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
		}},
		[PC.RotationByVelGenerator] = {name="RotationByVelGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation: ", min=0, max=360, default=0, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
			{type="number", id="max_rot", text="Max rotation: ", min=0, max=360, default=0, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
		}},
		[PC.BasicRotationVelGenerator] = {name="BasicRotationVelGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation velocity: ", min=0, max=36000, default=0, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
			{type="number", id="max_rot", text="Max rotation velocity: ", min=0, max=36000, default=360, from=function(v) return math.rad(v) end, to=function(v) return math.deg(v) end},
		}},
		[PC.StartStopColorGenerator] = {name="StartStopColorGenerator", category="color", fields={
			{type="color", id="min_color_start", text="Min start color: ", default=colors_alphaf.GOLD(1)},
			{type="color", id="max_color_start", text="Max start color: ", default=colors_alphaf.ORANGE(1)},
			{type="color", id="min_color_stop", text="Min stop color: ", default=colors_alphaf.GREEN(0)},
			{type="color", id="max_color_stop", text="Max stop color: ", default=colors_alphaf.LIGHT_GREEN(0)},
		}},
		[PC.FixedColorGenerator	] = {name="FixedColorGenerator", category="color", fields={
			{type="color", id="color_start", text="Start color: ", default=colors_alphaf.GOLD(1)},
			{type="color", id="color_stop", text="Stop color: ", default=colors_alphaf.LIGHT_GREEN(0)},
		}},
		[PC.CopyGenerator] = {name="CopyGenerator", category="special", fields={
			{type="number", id="source_system", text="Source system ID: ", min=1, max=100, default=1},
			{type="bool", id="copy_pos", text="Copy position: ", default=true},
			{type="bool", id="copy_color", text="Copy color: ", default=true},
		}},
	},
	updaters = {
		[PC.BasicTimeUpdater] = {name="BasicTimeUpdater", category="life", fields={}},
		[PC.AnimatedTextureUpdater] = {name="AnimatedTextureUpdater", category="texture", fields={
			{type="number", id="splitx", text="Texture Columns: ", min=1, max=100, default=1},
			{type="number", id="splity", text="Texture Lines: ", min=1, max=100, default=1, line=true},
			{type="number", id="firstframe", text="First frame: ", min=0, max=10000, default=0},
			{type="number", id="lastframe", text="Last frame: ", min=0, max=10000, default=0, line=true},
			{type="number", id="repeat_over_life", text="Repeat over lifetime: ", min=0, max=10000, default=1},
		}},
		[PC.EulerPosUpdater] = {name="EulerPosUpdater", category="position & movement", fields={
			{type="point", id="global_vel", text="Global Velocity: ", min=-10000, max=10000, default={0, 0}},
			{type="point", id="global_acc", text="Global Acceleration: ", min=-10000, max=10000, default={0, 0}},
		}},
		[PC.EasingPosUpdater] = {name="EasingPosUpdater", category="position & movement", fields={
			{type="select", id="easing", text="Easing method: ", list=easings, default="outQuad"},
		}},
		[PC.NoisePosUpdater] = {name="NoisePosUpdater", category="position & movement", fields={
			{type="file", id="noise", text="Noise: ", dir="/data/gfx/particles_textures/noises/", filter="%.png$", default="/data/gfx/particles_textures/noises/turbulent.png", line=true},
			{type="point", id="amplitude", text="Movement amplitude: ", min=-10000, max=10000, default={500, 500}},
			{type="number", id="traversal_speed", text="Noise traversal speed: ", min=0, max=10000, default=1},
		}},
		[PC.LinearColorUpdater] = {name="LinearColorUpdater", category="color", fields={
			{type="bool", id="bilinear", text="Bilinear (from start to stop to start): ", default=false},
		}},
		[PC.EasingColorUpdater] = {name="EasingColorUpdater", category="color", fields={
			{type="bool", id="bilinear", text="Bilinear (from start to stop to start): ", default=false, line=true},
			{type="select", id="easing", text="Easing method: ", list=easings, default="outQuad"},
		}},
		[PC.LinearSizeUpdater] = {name="LinearSizeUpdater", category="size", fields={}},
		[PC.EasingSizeUpdater] = {name="EasingSizeUpdater", category="size", fields={
			{type="select", id="easing", text="Easing method: ", list=easings, default="outQuad"},
		}},
		[PC.LinearRotationUpdater] = {name="LinearRotationUpdater", category="rotation", fields={}},
		[PC.EasingRotationUpdater] = {name="EasingRotationUpdater", category="rotation", fields={
			{type="select", id="easing", text="Easing method: ", list=easings, default="outQuad"},
		}},
	},
	systems = {
		[1] = {name="System", category="system", addnew=new_default_system, fields={
			{id=1, default=nil},
			{id="max_particles", default=100},
			{id="blend", default=PC.AdditiveBlend},
			{id="texture", default="/data/gfx/particle.png"},
			{id="emitters", default={}},
			{id="updaters", default={}},
		}},
	}
}

local emitters_by_id = table.map(function(k, v) return k, v.name end, specific_uis.emitters)
local generators_by_id = table.map(function(k, v) return k, v.name end, specific_uis.generators)
local updaters_by_id = table.map(function(k, v) return k, v.name end, specific_uis.updaters)


function _M:addNew(kind, into)
	-- PC.gcTextures()
	local list = {}
	for id, t in pairs(specific_uis[kind]) do
		local t = table.clone(t, true)
		t.id = id
		list[#list+1] = t
	end
	table.sort(list, function(a, b) if a.category == b.category then return a.name < b.name else return a.category < b.category end end)

	local function exec(item) if item and not item.fake then
		local f = {[1]=item.id}
		if not item.addnew then
			for _, field in ipairs(item.fields) do
				if type(field.default) == "table" then f[field.id] = table.clone(field.default, true)
				else f[field.id] = field.default end
			end
		else
			f = table.clone(item.addnew, true)
		end
		table.insert(into, f)
		self:makeUI()
		self:regenParticle()
	end end

	if #list == 1 then
		exec(list[1])
	else
		local last_cat = nil
		local i = 1
		while i < #list do
			local t = list[i]
			if t.category ~= last_cat and not t.fake then
				table.insert(list, i, {name="#LIGHT_BLUE#-------- "..t.category, fake=true})
			end
			i = i + 1
			last_cat = t.category
		end

		self:listPopup("New "..kind, "Select:", list, 400, 500, exec)
	end
end

function _M:processSpecificUI(ui, add, kind, spe, delete)
	local spe_def = specific_uis[kind][spe[1]]
	if not spe_def then error("unknown def for: "..tostring(spe[1])) end
	add(Checkbox.new{title="#{bold}##GOLD#"..spe_def.name, default=true, fct=function()end, on_change=function(v) if not v then delete() end end})
	local adds = {}
	for i, field in ipairs(spe_def.fields) do
		field.from = field.from or function(v) return v end
		field.to = field.to or function(v) return v end
		if field.type == "number" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = Numberbox.new{title=field.text, number=field.to(spe[field.id]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "bool" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = Checkbox.new{title=field.text, default=field.to(spe[field.id]), on_change=function(p) spe[field.id] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "point" then
			if not spe[field.id] then spe[field.id] = table.clone(field.default, true) end
			adds[#adds+1] = Numberbox.new{title=field.text, number=field.to(spe[field.id][1]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id][1] = field.from(p) self:regenParticle() end, fct=function()end}
			adds[#adds+1] = Numberbox.new{title="x", number=field.to(spe[field.id][2]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id][2] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "color" then
			if not spe[field.id] then spe[field.id] = table.clone(field.default, true) end
			adds[#adds+1] = Textzone.new{text=(i==1 and "    " or "")..field.text, auto_width=1, auto_height=1}
			adds[#adds+1] = ColorPicker.new{color=spe[field.id], width=20, height=20, fct=function(p) spe[field.id] = p self:regenParticle() end}
		elseif field.type == "select" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = Textzone.new{text=(i==1 and "    " or "")..field.text, auto_width=1, auto_height=1}
			adds[#adds+1] = Dropdown.new{width=200, default={"name", spe[field.id]}, fct=function(item) spe[field.id] = item.name self:regenParticle() self:makeUI() end, on_select=function(item)end, list=easings, nb_items=math.min(#easings, 30)}
		elseif field.type == "file" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = Textzone.new{text=(i==1 and "    " or "")..field.text..tostring(spe[field.id]), auto_width=1, auto_height=1, fct=function() self:selectFile(spe, field) end}
		end
		if field.line then add(unpack(adds)) adds={} end
	end
	add(unpack(adds))
	add(8)
end

function _M:makeTitle(add, tab, text, important)
	local b = Button.new{text=text, fct=function()end, width=self.iw - tab - 10, use_frame=important and "ui/heading" or "ui/selector"}

	if important then
		add(Checkbox.new{title="", default=true, fct=function()end, on_change=function(v) if not v then important() end end}, b)
	else
		add(b)
	end
end

function _M:makeUI()
	local old_scroll = self.scrollbar and self.scrollbar.pos or 0
	local def = pdef
	local ui = {}
	local y = 0
	local tab = 0
	local lastc = nil
	local function add(...)
		local args = {...}
		if type(args[1]) == "number" then y = y + args[1] return args[1] end
		local max_h = 0
		for i, c in ipairs(args) do if c.h > max_h then max_h = c.h end end
		local x = tab
		for i, c in ipairs(args) do
			ui[#ui+1] = {left=x, top=y + (max_h - c.h) / 2, ui=c}
			x = x + c.w
		end
		y = y + max_h
		return max_h
	end
	for id_system, system in ipairs(def) do
		local id = id_system
		tab = 0
		self:makeTitle(add, tab, "#{bold}##OLIVE_DRAB#----------======System "..id_system.."======----------", 	function() table.remove(def, id) self:makeUI() self:regenParticle() end)
		tab = 20
		add(
			Textzone.new{text="Max: ", auto_width=1, auto_height=1}, Numberbox.new{number=system.max_particles, min=1, max=100000, chars=6, on_change=function(p) system.max_particles = p self:regenParticle() end, fct=function()end},
			Textzone.new{text="Blend: ", auto_width=1, auto_height=1}, Dropdown.new{width=200, default={"blend", system.blend}, fct=function(item) system.blend = item.blend self:regenParticle() self:makeUI() end, on_select=function(item)end, list=blendmodes, nb_items=#blendmodes}
		)
		add(0)
		add(Textzone.new{text="Texture: "..system.texture, auto_width=1, auto_height=1, fct=function() self:selectTexture(system) end})
		add(Textzone.new{text="Shader: "..(system.shader or "--"), auto_width=1, auto_height=1, fct=function() self:selectShader(system) end})
		add(8)
		
		for id_emitter, emitter in ipairs(system.emitters) do
			local id = id_emitter
			tab = 20
			self:makeTitle(add, tab, "#{bold}##CRIMSON#----== Emitter "..id.." ==----", false)
			tab = 40
			self:processSpecificUI(ui, add, "emitters", emitter, function() table.remove(system.emitters, id) self:makeUI() self:regenParticle() end)
			add(Separator.new{dir="vertical", size=self.iw * 0.5})

			for id_generator, generator in ipairs(emitter[2]) do
				local id = id_generator
				self:processSpecificUI(ui, add, "generators", generator, function() table.remove(emitter[2], id) self:makeUI() self:regenParticle() end)
			end
			add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("generators", emitter[2]) end}, Textzone.new{text="add generator", auto_width=1, auto_height=1, fct=function() self:addNew("generators", emitter[2]) end})
		end
		tab = 20
		add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("emitters", system.emitters) end}, Textzone.new{text="add emitter", auto_width=1, auto_height=1, fct=function() self:addNew("emitters", system.emitters) end})
		
		self:makeTitle(add, tab, "#{bold}##AQUAMARINE#----== Updaters ==----", false)
		tab = 40
		for id_updater, updater in ipairs(system.updaters) do
			local id = id_updater
			self:processSpecificUI(ui, add, "updaters", updater, function() table.remove(system.updaters, id) self:makeUI() self:regenParticle() end)
		end
		add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("updaters", system.updaters) end}, Textzone.new{text="add updater", auto_width=1, auto_height=1, fct=function() self:addNew("updaters", system.updaters) end})
	end
	tab = 0
	add(8)
	add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("systems", def) end}, Textzone.new{text="add system", auto_width=1, auto_height=1, fct=function() self:addNew("systems", def) end})
	
	self:loadUI(ui)
	self:setupUI(false, false)
	self:setScroll(old_scroll)

	self.mouse:registerZone(0, 0, game.w, game.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if mx < game.w - 550 then
			if event == "button" and button == "wheelup" then
				particle_zoom = util.bound(particle_zoom + 0.05, 0.1, 10)
				self.p.ps:zoom(particle_zoom)
				self:shift(mx, my)
				return true
			elseif event == "button" and button == "wheeldown" then
				particle_zoom = util.bound(particle_zoom - 0.05, 0.1, 10)
				self.p.ps:zoom(particle_zoom)
				self:shift(mx, my)
				return true
			elseif event == "button" and button == "middle" then
				particle_zoom = 1
				self.p.ps:zoom(particle_zoom)
				self:shift(mx, my)
				return true
			end
		end

		if mx < game.w - 550 then self:shift(mx, my)
		else self:shift((game.w - 550) / 2, game.h / 2) end

		self.uidialog:mouseEvent(button, mx, my, xrel, yrel, bx, by, event)

		return false
	end)
end

function _M:selectTexture(system)
	local d = Dialog.new("Select Texture", game.w * 0.6, game.h * 0.6)

	local list = {}

	for i, file in ipairs(fs.list("/data/gfx/particles_textures/")) do if file:find("%.png$") then
		list[#list+1] = "/data/gfx/particles_textures/"..file
	end end 

	local clist = ImageList.new{width=self.iw, height=self.ih, tile_w=128, tile_h=128, force_size=true, padding=10, scrollbar=true, root_loader=true, list=list, fct=function(item)
		game:unregisterDialog(d)
		system.texture = item.data
		self:makeUI()
		self:regenParticle()
	end}

	d:loadUI{
		{left=0, top=0, ui=clist}
	}
	d:setupUI(false, false)
	d.key:addBinds{EXIT = function() game:unregisterDialog(d) end}
	game:registerDialog(d)
end

function _M:selectShader(system)
	local d = Dialog.new("Select Shader", game.w * 0.6, game.h * 0.6)

	local list = {{name = "--", path=nil}}

	for i, file in ipairs(fs.list("/data/gfx/shaders/particles/")) do if file:find("%.lua$") then
		list[#list+1] = {name=file, path="particles/"..file:gsub("%.lua$", "")}
	end end 

	local clist = List.new{width=self.iw, height=self.ih, scrollbar=true, list=list, fct=function(item)
		game:unregisterDialog(d)
		system.shader = item.path
		self:makeUI()
		self:regenParticle()
	end}

	d:loadUI{
		{left=0, top=0, ui=clist}
	}
	d:setupUI(false, false)
	d.key:addBinds{EXIT = function() game:unregisterDialog(d) end}
	game:registerDialog(d)
end

function _M:selectFile(spe, field)
	local d = Dialog.new("Select "..field.id, game.w * 0.6, game.h * 0.6)

	local list = {{name = "--", path=nil}}

	for i, file in ipairs(fs.list(field.dir)) do if file:find(field.filter) then
		list[#list+1] = {name=file, path=field.dir..file}
	end end 

	local clist = List.new{width=self.iw, height=self.ih, scrollbar=true, list=list, fct=function(item)
		game:unregisterDialog(d)
		spe[field.id] = item.path
		self:makeUI()
		self:regenParticle()
	end}

	d:loadUI{
		{left=0, top=0, ui=clist}
	}
	d:setupUI(false, false)
	d.key:addBinds{EXIT = function() game:unregisterDialog(d) end}
	game:registerDialog(d)
end

function _M:setBG(kind)
	local w, h = game.w, game.h
	self.bg:clear()
	if kind == "transparent" then
		-- nothing
	elseif kind == "tome1" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome.png"):shader(self.normal_shader))
	elseif kind == "tome2" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome2.png"):shader(self.normal_shader))
	elseif kind == "tome3" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome3.png"):shader(self.normal_shader))
	elseif type(kind) == "table" then
		self.bg:add(core.renderer.colorQuad(0, 0, w, h, unpack(kind)):shader(self.normal_shader))
	end
end

function _M:init()
	self.allow_scroll = true
	Dialog.init(self, _t"Particles Editor", 500, game.h * 0.9, game.w - 550)
	self.__showup = false
	self.absolute = true
	self.old_shift_x, self.old_shift_y = (game.w - 550) / 2, game.h / 2

	self.bignews = BigNews.new(FontPackage:getFont("bignews"))
	self.bignews:setTextOutline(0.7)

	self.uidialog = UIDialog.new(self)

	-- fs.setWritePath("/home/cvs/t-engine4/game/modules/demo/data/gfx/particles/")
	-- local f = fs.open("/test.pc", "w")
	-- self.uidialog:saveDef(function(indent, str) f:write(string.rep("\t", indent)..str) end)
	-- f:close()
	-- os.crash()

	self.plus_t = self:getAtlasTexture("ui/plus.png")

	self.normal_shader = Shader.new("particles/normal")
	PC.defaultShader(self.normal_shader)
	self.bg = core.renderer.renderer()

	self:makeUI(pdef)

	self.key:setupRebootKeys()
	self.key:addBinds{
		EXIT = function() end,
		FILE_NEW = function() print("FILE_NEW") pdef = {} pdef_history={} pdef_history_pos=0 self:makeUI() self:regenParticle(true) end,
		FILE_LOAD = function() print("FILE_LOAD") self.uidialog:load(self) end,
		FILE_MERGE = function() print("FILE_MERGE") self.uidialog:merge(self) end,
		FILE_SAVE = function() print("FILE_SAVE") self.uidialog:save() end,		
		EDITOR_UNDO = function() print("EDITOR_UNDO") self:undo() end,
		EDITOR_REDO = function() print("EDITOR_REDO") self:redo() end,
	}


	-- self.glow_shader = Shader.new("rendering/glow")
	-- PC.defaultShader(self.glow_shader)
	self.particle_renderer = core.renderer.renderer()

	local w, h = game.w, game.h
	self.fbomain = core.renderer.target(nil, nil, 2, true)
	self.fbomain:setAutoRender(self.particle_renderer)

	local blur_shader = Shader.new("rendering/blur") blur_shader:setUniform("texSize", {w, h})
	local main_shader = Shader.new("rendering/main_fbo") main_shader:setUniform("texSize", {w, h})
	local finalquad = core.renderer.targetDisplay(self.fbomain, 0, 0)
	local downsampling = 4
	local bloomquad = core.renderer.targetDisplay(self.fbomain, 1, 0, w/downsampling/downsampling, h/downsampling/downsampling)
	local bloomr = core.renderer.renderer("static"):setRendererName("game.bloomr"):add(bloomquad):premultipliedAlpha(true)
	local fbobloomview = core.renderer.view():ortho(w/downsampling, h/downsampling, false)
	self.fbobloom = core.renderer.target(w/downsampling, h/downsampling, 1, true):setAutoRender(bloomr):view(fbobloomview)--:translate(0,-h)
	self.fbobloom:blurMode(14, downsampling, blur_shader)
	if false then -- true to see only the bloom texture
		-- finalquad:textureTarget(self.fbobloom, 0, 0):shader(main_shader)
		self.fborenderer = core.renderer.renderer("static"):setRendererName("game.fborenderer"):add(self.fbobloom)--:premultipliedAlpha(true)
	else
		finalquad:textureTarget(self.fbobloom, 0, 1):shader(main_shader)
		self.fborenderer = core.renderer.renderer("static"):setRendererName("game.fborenderer"):add(finalquad)--:premultipliedAlpha(true)
	end

	self:regenParticle()
end

function _M:regenParticle(nosave)
	if not self.particle_renderer then return end
	if not nosave then
		for i = pdef_history_pos + 1, #pdef_history do pdef_history[i] = nil end
		table.insert(pdef_history, table.clone(pdef, true))
		pdef_history_pos = #pdef_history
	end

	-- table.print(pdef)
	self.p = {ps=PC.new(pdef, particle_speed, particle_zoom)}
	self.pdo = self.p.ps:getDO(self.p)
	self:shift(self.old_shift_x, self.old_shift_y)
	self.p_date = core.game.getTime()

	self.particle_renderer:clear():add(self.bg):add(self.pdo)

	collectgarbage("collect")
end

function _M:shift(x, y)
	self.old_shift_x, self.old_shift_y = x, y
	self.p.ps:shift(x, y, true)
end

function _M:toScreen(x, y, nb_keyframes)
	if self.p.ps:dead() then self:regenParticle(true) end

	self.bg:toScreen()
	if self.fbobloom then
		self.fbomain:compute()
		self.fbobloom:compute()
	end
	self.fborenderer:toScreen()
	-- self.p:toScreen(0, 0, nb_keyframes)

	self.uidialog:toScreen(0, 0, nb_keyframes)

	Dialog.toScreen(self, x, y, nb_keyframes)

	self.bignews:display(nb_keyframes)
end

function _M:keyEvent(...)
	self.uidialog:keyEvent(...)
	Dialog.keyEvent(self, ...)
end

function _M:undo()
	if pdef_history_pos == 0 then return end
	pdef = table.clone(pdef_history[pdef_history_pos], true)
	pdef_history_pos = pdef_history_pos - 1
	self:makeUI()
	self:regenParticle(true)
end



----------------------------------------------------------------------
-- UIDialog, absolute positions
----------------------------------------------------------------------
UIDialog = class.inherit(Dialog){}

function UIDialog:init(master)
	self.ui = "invisible"
	Dialog.init(self, "", game.w, game.h)
	self.__showup = false
	self.absolute = true

	local cp =ColorPicker.new{color={0, 0, 0, 1}, width=20, height=20, fct=function(p) master:setBG(p) end}

	local new = Button.new{text="New", fct=function() Dialog:yesnoPopup("Clear particles?", "All data will be lost.", function(ret) if ret then pdef={} PC.gcTextures() master:makeUI() master:regenParticle() end end) end}
	local load = Button.new{text="Load", fct=function() self:load(master) end}
	local merge = Button.new{text="Merge", fct=function() self:merge(master) end}
	local save = Button.new{text="Save", fct=function() self:save() end}

	local bgt = Button.new{text="Transparent background", fct=function() master:setBG("transparent") end}
	local bgb = Button.new{text="Color background", fct=function() cp:popup() end}
	local bg1 = Button.new{text="Background1", fct=function() master:setBG("tome1") end}
	local bg2 = Button.new{text="Background2", fct=function() master:setBG("tome2") end}
	local bg3 = Button.new{text="Background3", fct=function() master:setBG("tome3") end}

	local speed = NumberSlider.new{title="Play at speed: ", step=10, min=10, max=1000, value=100, size=300, on_change=function(v)
		particle_speed = util.bound(v / 100, 0.1, 10)
		if master.p then master.p.ps:speed(particle_speed) end
	end}

	self.master = master
	self.particles_count = core.renderer.text(self.font_mono):translate(700, 0):outline(1)
	self.particles_count_renderer = core.renderer.renderer():add(self.particles_count)

	self:loadUI{
		{absolute=true, left=0, top=0, ui=new},
		{absolute=true, left=new.w, top=0, ui=load},
		{absolute=true, left=new.w+load.w, top=0, ui=merge},
		{absolute=true, left=new.w+load.w+merge.w, top=0, ui=save},

		{absolute=true, left=0, bottom=0, ui=bgt},
		{absolute=true, left=bgt.w, bottom=0, ui=bgb},
		{absolute=true, left=bgt.w+bgb.w, bottom=0, ui=bg1},
		{absolute=true, left=bgt.w+bgb.w+bg1.w, bottom=0, ui=bg2},
		{absolute=true, left=bgt.w+bgb.w+bg1.w+bg2.w, bottom=0, ui=bg3},
		
		{absolute=true, left=bgt.w+bgb.w+bg1.w+bg2.w+bg3.w+10, bottom=0, ui=speed},
	}
	self:setupUI(false, false)
end

function UIDialog:load(master)
	local d = Dialog.new("Load particle effects from /data/gfx/particles/", game.w * 0.6, game.h * 0.6)

	local list = {}
	for i, file in ipairs(fs.list("/data/gfx/particles/")) do if file:find("%.pc$") then
		list[#list+1] = {name=file, path="/data/gfx/particles/"..file}
	end end 

	local clist = List.new{scrollbar=true, width=d.iw, height=d.ih, list=list, fct=function(item)
		game:unregisterDialog(d)
		-- PC.gcTextures()
		pdef_history={} pdef_history_pos=0
		local ok, f = pcall(loadfile, item.path)
		if not ok then Dialog:simplePopup("Error loading particle file", f) return end
		setfenv(f, {math=math, colors_alphaf=colors_alphaf, PC=PC})
		local ok, data = pcall(f)
		if not ok then Dialog:simplePopup("Error loading particle file", data) return end
		pdef = data
		master:makeUI()
		master:regenParticle()
	end}

	d:loadUI{
		{left=0, top=0, ui=clist}
	}
	d:setupUI(false, false)
	d.key:addBinds{EXIT = function() game:unregisterDialog(d) end}
	game:registerDialog(d)
end

function UIDialog:merge(master)
	local d = Dialog.new("Load particle effects from /data/gfx/particles/", game.w * 0.6, game.h * 0.6)

	local list = {}
	for i, file in ipairs(fs.list("/data/gfx/particles/")) do if file:find("%.pc$") then
		list[#list+1] = {name=file, path="/data/gfx/particles/"..file}
	end end 

	local clist = List.new{scrollbar=true, width=d.iw, height=d.ih, list=list, fct=function(item)
		game:unregisterDialog(d)
		local ok, f = pcall(loadfile, item.path)
		if not ok then Dialog:simplePopup("Error loading particle file", f) return end
		setfenv(f, {math=math, colors_alphaf=colors_alphaf, PC=PC})
		local ok, data = pcall(f)
		if not ok then Dialog:simplePopup("Error loading particle file", data) return end
		table.append(pdef, data)
		master:makeUI()
		master:regenParticle()
	end}

	d:loadUI{
		{left=0, top=0, ui=clist}
	}
	d:setupUI(false, false)
	d.key:addBinds{EXIT = function() game:unregisterDialog(d) end}
	game:registerDialog(d)
end

function UIDialog:saveDef(w)
	local function getData(up)
		local data = {}
		for k, v in pairs(up) do if type(k) == "string" then
			if type(v) == "number" then
				data[#data+1] = ("%s=%f"):format(k, v)
			elseif type(v) == "boolean" then
				data[#data+1] = ("%s=%s"):format(k, v and "true" or "false")
			elseif type(v) == "string" then
				data[#data+1] = ("%s=%q"):format(k, v)
			elseif type(v) == "table" and #v == 2 then
				data[#data+1] = ("%s={%f, %f}"):format(k, v[1], v[2])
			elseif type(v) == "table" and #v == 3 then
				data[#data+1] = ("%s={%f, %f, %f}"):format(k, v[1], v[2], v[3])
			elseif type(v) == "table" and #v == 4 then
				data[#data+1] = ("%s={%f, %f, %f, %f}"):format(k, v[1], v[2], v[3], v[4])
			else
				error("Unsupported save parameter: "..tostring(v))
			end
		end end
		if #data > 0 then data = ", "..table.concat(data, ", ") else data = "" end
		return data
	end

	w(0, "return {\n")
	for _, system in ipairs(pdef) do
		w(1, "{\n")
		w(2, ("max_particles = %d, blend=PC.%s,\n"):format(system.max_particles, blend_by_id[system.blend]))
		w(2, ("texture = %q,\n"):format(system.texture))
		if system.shader then w(2, ("shader = %q,\n"):format(system.shader)) end
		w(2, "emitters = {\n")
		for _, em in ipairs(system.emitters) do
			local data = getData(em)
			w(3, ("{PC.%s, {\n"):format(emitters_by_id[em[1]]))
			for _, g in ipairs(em[2]) do
				local data = getData(g)
				w(4, ("{PC.%s%s},\n"):format(generators_by_id[g[1]], data))
			end
			w(3, ("}%s },\n"):format(data))
		end
		w(2, "},\n")
		w(2, "updaters = {\n")
		for _, up in ipairs(system.updaters) do
			local data = getData(up)
			w(3, ("{PC.%s%s},\n"):format(updaters_by_id[up[1]], data))
		end
		w(2, "},\n")
		w(1, "},\n")
	end
	w(0, "}\n")
end

function UIDialog:save()
	local d = Dialog.new("Save particle effects to /data/gfx/particles/", 1, 1)

	local function exec(txt)
		local mod = game.__mod_info
		game:unregisterDialog(d)

		local basedir = "/data/gfx/particles/"
		local path
		if mod.team then
			basedir = "/save/"
			path = fs.getRealPath(basedir)
		else
			path = mod.real_path..basedir
		end
		if not path then return end
		local restore = fs.getWritePath()
		fs.setWritePath(path)
		local f = fs.open("/"..txt..".pc", "w")
		self:saveDef(function(indent, str) f:write(string.rep("\t", indent)..str) end)
		f:close()
		fs.setWritePath(restore)
		self.master.bignews:saySimple(60, "#GOLD#Saved to "..tostring(fs.getRealPath(basedir..txt..".pc")))
	end

	local box = Textbox.new{title="Filename (without .pc extension): ", chars=80, text="", fct=function(txt) if #txt > 0 then
		if fs.exists("/data/gfx/particles/"..txt..".pc") then
			Dialog:yesnoPopup("Override", "File already exists, override it?", function(ret) if ret then exec(txt) end end)
		else exec(txt) end
	end end}

	d:loadUI{
		{left=0, top=0, ui=box}
	}
	d:setupUI(true, true)
	d.key:addBinds{EXIT = function() game:unregisterDialog(d) end}
	game:registerDialog(d)
end

function UIDialog:toScreen(x, y, nb_keyframes)
	self.particles_count:text(("Elapsed Time %0.2fs / FPS: %0.1f / Active particles: %d / Zoom: %d%%"):format((core.game.getTime() - self.master.p_date) / 1000, core.display.getFPS(), self.master.p.ps:countAlive(), particle_zoom * 100), true)
	self.particles_count_renderer:toScreen()
	Dialog.toScreen(self, x, y, nb_keyframes)
end
