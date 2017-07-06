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
local DisplayObject = require "engine.ui.DisplayObject"
local List = require "engine.ui.List"
local Button = require "engine.ui.Button"
local PC = core.particlescompose

--- Particles editor
-- @classmod engine.dialogs.ParticlesComposeEditor
module(..., package.seeall, class.inherit(Dialog))

local UIDialog

local pdef = {
	{
		max_particles = 100, blend = PC.AdditiveBlend,
		texture = "/data/gfx/particle_boom_anim.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, min=0.3, max=1.2},
				{PC.DiskPosGenerator, radius=100},
				{PC.BasicSizeGenerator, min_size=8, max_size=32},
				{PC.BasicRotationGenerator, min_rot=0, max_rot=math.pi*2},
				{PC.FixedColorGenerator, color_start=colors_alphaf.WHITE(1), color_stop=colors_alphaf.WHITE(1)},
			}, rate=1/30, nb=20},
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater},
			{PC.AnimatedTextureUpdater, repeat_over_life=1, splitx=5, splity=5, firstframe=0, lastframe=22},
			{PC.EulerPosUpdater}--, global_vel={-20, 70}},
		},
	},
	{
		max_particles = 2000, blend = PC.AdditiveBlend,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, min=0.3, max=3},
				-- {PC.TrianglePosGenerator, p1={-200, 100}, p2={200, 100}, p3={0, -100}},
				{PC.CirclePosGenerator, radius=300, width=20},
				{PC.DiskVelGenerator, min_vel=30, max_vel=100},
				{PC.BasicSizeGenerator, min_size=10, max_size=50},
				{PC.BasicRotationGenerator, min_rot=0, max_rot=math.pi*2},
				{PC.StartStopColorGenerator, min_color_start=colors_alphaf.GOLD(1), max_color_start=colors_alphaf.ORANGE(1), min_color_stop=colors_alphaf.GREEN(0), max_color_stop=colors_alphaf.LIGHT_GREEN(0)},
			}, rate=1/30, nb=20},
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

local specific_uis = {
	emitters = {
		[PC.LinearEmitter] = {name="LinearEmitter", fields={
			{type="number", id="rate", text="Emit events triggers/second: ", min=0.00001, max=60, default=30},
			{type="number", id="rate", text="Emit events triggers/second: ", min=0.00001, max=60, default=30},
			{type="invisible", id=2, default={}},
		}},
	},
	generators = {
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
	},
	updaters = {
		[PC.LinearColorUpdater] = {name="LinearColorUpdater", fields={}},
		[PC.BasicTimeUpdater] = {name="BasicTimeUpdater", fields={}},
		[PC.AnimatedTextureUpdater] = {name="AnimatedTextureUpdater", fields={
			{type="number", id="splitx", text="Texture Columns: ", min=1, max=100, default=1},
			{type="number", id="splity", text="Texture Lines: ", min=1, max=100, default=1, line=true},
			{type="number", id="firstframe", text="First frame: ", min=0, max=10000, default=0},
			{type="number", id="lastframe", text="Last frame: ", min=0, max=10000, default=0, line=true},
			{type="number", id="repeat_over_life", text="Repeat over lifetime: ", min=0, max=10000, default=1},
		}},
		[PC.EulerPosUpdater] = {name="EulerPosUpdater", fields={
			{type="point", id="global_vel", text="Global Velocity: ", min=-10000, max=10000, default={0, 0}},
			{type="point", id="global_acc", text="Global Acceleration: ", min=-10000, max=10000, default={0, 0}},
		}},
	},
	systems = {
		[1] = {name="System", fields={
			{id=1, default=nil},
			{id="max_particles", default=100},
			{id="blend", default=PC.AdditiveBlend},
			{id="emitters", default={}},
			{id="updaters", default={}},
		}},
	}
}

function _M:addNew(kind, into)
	PC.gcTextures()
	local list = {}
	for id, t in pairs(specific_uis[kind]) do
		t.id = id
		list[#list+1] = t
	end
	table.sort(list, "name")
	self:listPopup("New "..kind, "Select:", list, 400, 500, function(item) if item then
		local f = {[1]=item.id}
		for _, field in ipairs(item.fields) do
			if type(field.default) == "table" then f[field.id] = table.clone(field.default, true)
			else f[field.id] = field.default end
		end
		table.insert(into, f)
		self:makeUI()
		self:regenParticle()
	end end)
end

function _M:processSpecificUI(ui, add, kind, spe, delete)
	local spe_def = specific_uis[kind][spe[1]]
	if not spe_def then error("unknown def for: "..tostring(spe[1])) end
	add(Checkbox.new{title="#{bold}##GOLD#"..spe_def.name, default=true, fct=function()end, on_change=function(v) if not v then delete() end end})
	local adds = {}
	for i, field in ipairs(spe_def.fields) do
		field.from = field.from or function(v) return v end
		field.to = field.to or function(v) return v end
		if not spe[field.id] then spe[field.id] = table.clone(field.default, true) end
		if field.type == "number" then
			adds[#adds+1] = Numberbox.new{title=field.text, number=field.to(spe[field.id]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "point" then
			adds[#adds+1] = Numberbox.new{title=field.text, number=field.to(spe[field.id][1]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id][1] = field.from(p) self:regenParticle() end, fct=function()end}
			adds[#adds+1] = Numberbox.new{title="x", number=field.to(spe[field.id][2]), min=field.min, max=field.max, chars=6, on_change=function(p) spe[field.id][2] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "color" then
			adds[#adds+1] = Textzone.new{text=(i==1 and "    " or "")..field.text, auto_width=1, auto_height=1}
			adds[#adds+1] = ColorPicker.new{color=spe[field.id], width=20, height=20, fct=function(p) spe[field.id] = p self:regenParticle() end}
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
		add(Textzone.new{text="Texture: ", auto_width=1, auto_height=1}, Dropdown.new{width=200, default={"blend", system.blend}, fct=function(item) system.blend = item.blend self:regenParticle() self:makeUI() end, on_select=function(item)end, list=blendmodes, nb_items=#blendmodes})
		
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
			add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("generators", emitter[2]) end}, Textzone.new{text=" add generator", auto_width=1, auto_height=1, fct=function() self:addNew("emitters", emitter[2]) end})
		end
		tab = 20
		add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("emitters", system.emitters) end}, Textzone.new{text=" add emitter", auto_width=1, auto_height=1, fct=function() self:addNew("emitters", system.emitters) end})
		
		self:makeTitle(add, tab, "#{bold}##AQUAMARINE#----== Updaters ==----", false)
		tab = 40
		for id_updater, updater in ipairs(system.updaters) do
			local id = id_updater
			self:processSpecificUI(ui, add, "updaters", updater, function() table.remove(system.updaters, id) self:makeUI() self:regenParticle() end)
		end
		add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("updaters", system.updaters) end}, Textzone.new{text=" add updater", auto_width=1, auto_height=1, fct=function() self:addNew("updaters", system.updaters) end})
	end
	add(DisplayObject.new{DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("systems", def) end}, Textzone.new{text=" add system", auto_width=1, auto_height=1, fct=function() self:addNew("systems", def) end})
	
	self:loadUI(ui)
	self:setupUI(false, false)
	self:setScroll(old_scroll)

	self.mouse:registerZone(0, 0, game.w, game.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if mx < game.w - 550 then self.p:shift(mx, my, true)
		else self.p:shift((game.w - 550) / 2, game.h / 2, true) end

		self.uidialog:mouseEvent(button, mx, my, xrel, yrel, bx, by, event)

		return false
	end)
end

function _M:setBG(kind)
	local w, h = game.w, game.h
	self.bg:clear()
	if kind == "transparent" then
		-- nothing
	elseif kind == "tome1" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome.png"))
	elseif kind == "tome2" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome2.png"))
	elseif kind == "tome3" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome3.png"))
	elseif type(kind) == "table" then
		self.bg:add(core.renderer.colorQuad(0, 0, w, h, unpack(kind)))
	end
end

function _M:init()
	self.allow_scroll = true
	Dialog.init(self, _t"Particles Editor", 500, game.h * 0.9, game.w - 550)
	self.__showup = false
	self.absolute = true

	self.uidialog = UIDialog.new(self)

	self.p = PC.new(pdef)
	self.p:shift((game.w - 550) / 2, game.h / 2, true)

	self.plus_t = self:getAtlasTexture("ui/plus.png")
	self.bg = core.renderer.renderer()

	self:makeUI(pdef)

	self.key:setupRebootKeys()
	self.key:addBinds{
		EXIT = function() end,
	}
end

function _M:regenParticle()
	self.p = PC.new(pdef)
	self.p:shift((game.w - 550) / 2, game.h / 2)
	collectgarbage("collect")
end

function _M:toScreen(x, y, nb_keyframes)
	self.bg:toScreen()
	self.p:toScreen(0, 0, nb_keyframes)

	self.uidialog:toScreen(0, 0, nb_keyframes)

	Dialog.toScreen(self, x, y, nb_keyframes)
end

function _M:use(item)
	item.fct()
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

	local bgt = Button.new{text="Transparent background", fct=function() master:setBG("transparent") end}
	local bgb = Button.new{text="Color background", fct=function() cp:popup() end}
	local bg1 = Button.new{text="Background1", fct=function() master:setBG("tome1") end}
	local bg2 = Button.new{text="Background2", fct=function() master:setBG("tome2") end}
	local bg3 = Button.new{text="Background3", fct=function() master:setBG("tome3") end}
	self:loadUI{
		{absolute=true, left=0, bottom=0, ui=bgt},
		{absolute=true, left=bgt.w, bottom=0, ui=bgb},
		{absolute=true, left=bgt.w+bgb.w, bottom=0, ui=bg1},
		{absolute=true, left=bgt.w+bgb.w+bg1.w, bottom=0, ui=bg2},
		{absolute=true, left=bgt.w+bgb.w+bg1.w+bg2.w, bottom=0, ui=bg3},
	}
	self:setupUI(false, false)
end

