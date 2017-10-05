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

local new_default_linear_emitter = {PC.LinearEmitter, {
	{PC.BasicTextureGenerator},
	{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
	{PC.DiskPosGenerator, radius=50.000000},
	{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
	{PC.DiskVelGenerator, max_vel=150.000000, min_vel=50.000000},
	{PC.LifeGenerator, min=1.000000, max=3.000000},
}, duration=-1.000000, startat=0.000000, nb=10.000000, rate=0.030000 }

local new_default_burst_emitter = {PC.BurstEmitter, {
	{PC.BasicTextureGenerator},
	{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
	{PC.DiskPosGenerator, radius=50.000000},
	{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
	{PC.DiskVelGenerator, max_vel=150.000000, min_vel=50.000000},
	{PC.LifeGenerator, min=1.000000, max=3.000000},
}, duration=-1.000000, startat=0.000000, nb=10.000000, rate=0.50000, burst=0.15 }

local new_default_buildup_emitter = {PC.BuildupEmitter, {
	{PC.BasicTextureGenerator},
	{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
	{PC.DiskPosGenerator, radius=50.000000},
	{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
	{PC.DiskVelGenerator, max_vel=150.000000, min_vel=50.000000},
	{PC.LifeGenerator, min=1.000000, max=3.000000},
}, duration=-1.000000, startat=0.000000, nb=10.000000, rate=0.50000, nb_sec=5.000000, rate_sec=-0.150000 }

local new_default_system = {
	max_particles = 100, blend=PC.DefaultBlend, type=PC.RendererPoint,
	texture = "/data/gfx/particle.png",
	emitters = { new_default_linear_emitter },
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
-- [[
	parameters = { size=300.000000, },
	{
		max_particles = 2000, blend=PC.ShinyBlend,
		texture = "/data/gfx/particle.png",
		shader = "particles/glow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=1.000000, duration=10.000000, min=0.300000},
				{PC.CirclePosGenerator, radius="size", width="size/10"},
				{PC.DiskVelGenerator, max_vel=100.000000, min_vel=30.000000},
				{PC.BasicSizeGenerator, max_size="sqrt(size)*4", min_size="sqrt(size)"},
				{PC.BasicRotationGenerator, min_rot=0.000000, max_rot=6.283185},
				{PC.StartStopColorGenerator, min_color_start={1.000000, 0.843137, 0.000000, 1.000000}, max_color_start={1.000000, 0.466667, 0.000000, 1.000000}, min_color_stop={0.000000, 0.525490, 0.270588, 0.000000}, max_color_stop={0.000000, 1.000000, 0.000000, 0.000000}},
			}, startat=0.000000, dormant=false, duration=-1.000000, rate=0.030000, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, events = { stopping = PC.EventSTOP } },
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=3.000000, duration=10.000000, min=0.300000},
				{PC.CirclePosGenerator, radius="size+200", width=20.000000},
				{PC.BasicSizeGenerator, max_size=70.000000, min_size=25.000000},
				{PC.BasicRotationGenerator, min_rot=0.000000, max_rot=6.283185},
				{PC.StartStopColorGenerator, min_color_start={0.000000, 0.000000, 0.890196, 1.000000}, max_color_start={0.498039, 1.000000, 0.831373, 1.000000}, min_color_stop={0.000000, 0.525490, 0.270588, 0.000000}, max_color_stop={0.000000, 1.000000, 0.000000, 0.000000}},
				{PC.OriginPosGenerator},
				{PC.DirectionVelGenerator, max_vel=-300.000000, from={0.000000, 0.000000}, min_vel=-150.000000},
			}, dormant=true, startat=0.000000, duration=0.000000, rate=0.010000, triggers = { die = PC.TriggerWAKEUP }, display_name="dying", nb=500.000000, events = { dying = PC.EventSTART } },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=true},
			{PC.EulerPosUpdater, global_vel={30.000000, -120.000000}, global_acc={0.000000, 0.000000}},
		},
	},
--]]
--[[
	{
		max_particles = 100, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={0.010336, 0.898438, 0.311387, 0.000000}, color_start={0.274297, 0.871094, 0.040645, 1.000000}},
				{PC.BasicSizeGenerator, max_size=1.000000, min_size=1.000000},
				{PC.LifeGenerator, min=1.000000, max=1.000000},
				{PC.LinePosGenerator, base_point={0.000000, -150.000000}, p1={-300.000000, 0.000000}, p2={300.000000, 0.000000}},
			}, startat=0.000000, duration=-1.000000, rate=0.030000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
	{
		display_name = "unnamed (duplicated)",
		max_particles = 1000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={0.949219, 0.876301, 0.088785, 0.000000}, color_start={0.890625, 0.079826, 0.079826, 1.000000}},
				{PC.BasicSizeGenerator, max_size=1.000000, min_size=1.000000},
				{PC.LifeGenerator, min=1.000000, max=1.000000},
				{PC.LinePosGenerator, base_point={0.000000, 150.000000}, p1={-300.000000, 0.000000}, p2={300.000000, 0.000000}},
			}, startat=0.000000, duration=-1.000000, rate=0.030000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_vel={0.000000, 0.000000}, global_acc={0.000000, 0.000000}},
		},
	},
	{
		max_particles = 100000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/linenormal",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.BasicSizeGenerator, max_size=30.000000, min_size=10.000000},
				{PC.LifeGenerator, min=0.500000, max=0.500000},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, source_system2=2.000000, close_tries=0.000000, copy_color=true, strands=1.000000, repeat_times=1.000000, source_system1=1.000000, copy_pos=true},
			}, startat=0.000000, duration=-1.000000, rate=0.300000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
--[[
	parameters = { ty=0.000000, size=300.000000, tx=500.000000 },
	{
		max_particles = 10000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/lineglow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=1.000000, duration=10.000000, min=1.000000},
				{PC.JaggedLinePosGenerator, sway=80.000000, p1={0.000000, 0.000000}, base_point={0.000000, 0.000000}, strands=1.000000, p2={400.000000, 0.000000}},
				{PC.DiskVelGenerator, max_vel=1.000000, min_vel=1.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=10.000000},
				{PC.StartStopColorGenerator, min_color_start={1.000000, 0.843137, 0.000000, 1.000000}, max_color_start={1.000000, 0.466667, 0.000000, 1.000000}, min_color_stop={0.088228, 0.984375, 0.549677, 1.000000}, max_color_stop={0.000000, 1.000000, 0.000000, 1.000000}},
			}, startat=0.000000, duration=-1.000000, rate=2.000000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, hide=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
		},
	},
--]]
--[[
	parameters = { ty=0.000000, size=300.000000, tx=500.000000 },
	{
		max_particles = 2000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=0.000010, min_size=0.000010},
				{PC.DiskVelGenerator, max_vel=5.000000, min_vel=5.000000},
				{PC.LifeGenerator, min=0.100000, max=0.100000},
				{PC.CirclePosGenerator, width=20.000000, max_angle=6.283185, base_point={0.000000, 0.000000}, radius=60.000000, min_angle=0.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_vel={0.000000, 0.000000}, global_acc={0.000000, 0.000000}},
		},
	},
	{
		max_particles = 10000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/lineglow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
				{PC.DiskVelGenerator, max_vel=40.000000, min_vel=0.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
				{PC.StartStopColorGenerator, min_color_start={0.000000, 0.938983, 1.000000, 1.000000}, max_color_start={0.000000, 1.000000, 0.898305, 1.000000}, min_color_stop={0.088228, 0.947922, 0.984375, 0.003086}, max_color_stop={0.000000, 0.776271, 1.000000, 0.003086}},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, copy_color=true, source_system1=1.000000, source_system2=1.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, hide=false },
			-- {PC.LinearEmitter, {
			-- 	{PC.BasicTextureGenerator},
			-- 	{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
			-- 	{PC.DiskVelGenerator, max_vel=0.000000, min_vel=40.000000},
			-- 	{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
			-- 	{PC.StartStopColorGenerator, min_color_start={1.000000, 0.142373, 0.000000, 1.000000}, max_color_stop={1.000000, 0.335593, 0.000000, 0.003086}, min_color_stop={0.984375, 0.598576, 0.088228, 0.003086}, max_color_start={1.000000, 0.466667, 0.000000, 1.000000}},
			-- 	{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, source_system1=1.000000, source_system2=1.000000, copy_color=true},
			-- }, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active (duplicated)", nb=20.000000, hide=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=true},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
--[[
	parameters = { ty=0.000000, size=300.000000, tx=500.000000 },
	{
		display_name = "ring source",
		max_particles = 2000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=0.000010, min_size=0.000010},
				{PC.DiskVelGenerator, max_vel=5.000000, min_vel=5.000000},
				{PC.LifeGenerator, min=0.100000, max=0.100000},
				{PC.CirclePosGenerator, width=20.000000, max_angle=6.283185, base_point={0.000000, 0.000000}, radius=150.000000, min_angle=0.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_vel={0.000000, 0.000000}, global_acc={0.000000, 0.000000}},
		},
	},
	{
		display_name = "center source",
		max_particles = 2000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=0.000010, min_size=0.000010},
				{PC.DiskVelGenerator, max_vel=5.000000, min_vel=5.000000},
				{PC.LifeGenerator, min=0.100000, max=0.100000},
				{PC.CirclePosGenerator, width=10.000000, max_angle=6.283185, base_point={0.000000, 0.000000}, radius=80.000000, min_angle=0.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
	{
		display_name = "lightnings",
		max_particles = 10000, blend=PC.AdditiveBlend, type=PC.RendererLine,
		texture = "/data/gfx/particles_textures/line2.png",
		shader = "particles/lineglow",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
				{PC.DiskVelGenerator, max_vel=40.000000, min_vel=0.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
				{PC.StartStopColorGenerator, min_color_start={0.000000, 0.938983, 1.000000, 1.000000}, max_color_start={0.000000, 1.000000, 0.898305, 1.000000}, min_color_stop={0.088228, 0.947922, 0.984375, 0.003086}, max_color_stop={0.000000, 0.776271, 1.000000, 0.003086}},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, source_system1=2.000000, strands=1.000000, copy_color=true, source_system2=1.000000},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active", nb=20.000000, hide=false },
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.LifeGenerator, max=0.300000, duration=10.000000, min=0.300000},
				{PC.DiskVelGenerator, max_vel=40.000000, min_vel=0.000000},
				{PC.BasicSizeGenerator, max_size=10.000000, min_size=1.000000},
				{PC.StartStopColorGenerator, min_color_start={0.788235, 0.000000, 0.000000, 1.000000}, max_color_stop={0.843137, 0.421569, 0.000000, 1.000000}, min_color_stop={1.000000, 0.514469, 0.089628, 1.000000}, max_color_start={0.862745, 0.000000, 0.172549, 1.000000}},
				{PC.JaggedLineBetweenGenerator, sway=80.000000, copy_pos=true, source_system1=2.000000, strands=1.000000, source_system2=1.000000, copy_color=true},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, dormant=false, events = { stopping = PC.EventSTOP }, triggers = { die = PC.TriggerDELETE }, display_name="active (duplicated)", nb=20.000000, hide=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=true},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
--[[
	{
		max_particles = 10000, blend=PC.DefaultBlend, type=PC.RendererPoint,
		texture = "/data/gfx/particle.png",
		emitters = {
			{PC.LinearEmitter, {
				{PC.BasicTextureGenerator},
				{PC.FixedColorGenerator, color_stop={1.000000, 1.000000, 1.000000, 0.000000}, color_start={1.000000, 1.000000, 1.000000, 1.000000}},
				{PC.BasicSizeGenerator, max_size=1.000000, min_size=1.000000},
				{PC.DiskVelGenerator, max_vel=0.000000, min_vel=0.000000},
				{PC.LifeGenerator, min=0.100000, max=1.000000},
				{PC.ImagePosGenerator, base_point={0.000000, 0.000000}},
			}, startat=0.000000, duration=-1.000000, rate=0.010000, nb=10.000000, dormant=false },
		},
		updaters = {
			{PC.BasicTimeUpdater},
			{PC.LinearColorUpdater, bilinear=false},
			{PC.EulerPosUpdater, global_acc={0.000000, 0.000000}, global_vel={0.000000, 0.000000}},
		},
	},
--]]
}

local typemodes = {
	{name="RendererPoint", type=PC.RendererPoint},
	{name="RendererLine", type=PC.RendererLine},
}
local type_by_id = table.map(function(k, v) return v.type, v.name end, typemodes)

local blendmodes = {
	{name="DefaultBlend", blend=PC.DefaultBlend},
	{name="AdditiveBlend", blend=PC.AdditiveBlend},
	{name="MixedBlend", blend=PC.MixedBlend},
	{name="ShinyBlend", blend=PC.ShinyBlend},
}
local blend_by_id = table.map(function(k, v) return v.blend, v.name end, blendmodes)

local triggermodes = {
	{name="Delete", trigger=PC.TriggerDELETE, kind="TriggerDELETE"},
	{name="Wakeup", trigger=PC.TriggerWAKEUP, kind="TriggerWAKEUP"},
	{name="Force emit", trigger=PC.TriggerFORCE, kind="TriggerFORCE"},
}
local trigger_by_id = table.map(function(k, v) return v.trigger, v.name end, triggermodes)
local triggerkind_by_id = table.map(function(k, v) return v.trigger, v.kind end, triggermodes)


local eventmodes = {
	{name="On Start", event=PC.EventSTART, kind="EventSTART"},
	{name="On Emit", event=PC.EventEMIT, kind="EventEMIT"},
	{name="On Stop", event=PC.EventSTOP, kind="EventSTOP"},
}
local event_by_id = table.map(function(k, v) return v.event, v.name end, eventmodes)
local eventkind_by_id = table.map(function(k, v) return v.event, v.kind end, eventmodes)

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
		[PC.LinearEmitter] = {name="LinearEmitter", category="emitter", addnew=new_default_linear_emitter, fields={
			{type="number", id="rate", text="Triggers every seconds: ", min=0, max=600, default=0.033},
			{type="number", id="nb", text="Particles per trigger: ", min=0, max=100000, default=30, line=true},
			{type="number", id="startat", text="Start at second: ", min=0, max=600, default=0},
			{type="number", id="duration", text="Work for seconds (-1 for infinite): ", min=-1, max=600, default=-1, line=true},
			{type="bool", id="dormant", text="Dormant (needs trigger to wakeup)", default=false},
			{type="invisible", id=2, default={}},
		}},
		[PC.BurstEmitter] = {name="BurstEmitter", category="emitter", addnew=new_default_burst_emitter, fields={
			{type="number", id="rate", text="Burst every seconds: ", min=0, max=600, default=0.5},
			{type="number", id="burst", text="Burst for seconds: ", min=0, max=600, default=0.15, line=true},
			{type="number", id="nb", text="Particles per burst: ", min=0, max=100000, default=10, line=true},
			{type="number", id="startat", text="Start at second: ", min=0, max=600, default=0},
			{type="number", id="duration", text="Work for seconds (-1 for infinite): ", min=-1, max=600, default=-1, line=true},
			{type="bool", id="dormant", text="Dormant (needs trigger to wakeup)", default=false},
			{type="invisible", id=2, default={}},
		}},
		[PC.BuildupEmitter] = {name="BuildupEmitter", category="emitter", addnew=new_default_buildup_emitter, fields={
			{type="number", id="rate", text="Triggers every seconds: ", min=0, max=600, default=0.5},
			{type="number", id="rate_sec", text="Triggers/sec increase/sec: ", min=-600, max=600, default=0.15, line=true},
			{type="number", id="nb", text="Particles per trigger: ", min=0, max=100000, default=10},
			{type="number", id="nb_sec", text="Particles/trig increase/sec: ", min=-100000, max=100000, default=5, line=true},
			{type="number", id="startat", text="Start at second: ", min=0, max=600, default=0},
			{type="number", id="duration", text="Work for seconds (-1 for infinite): ", min=-1, max=600, default=-1, line=true},
			{type="bool", id="dormant", text="Dormant (needs trigger to wakeup)", default=false},
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
			{type="point", id="base_point", text="Origin: ", min=-10000, max=10000, default={0, 0}, line=true},
			{type="number", id="radius", text="Radius: ", min=0, max=10000, default=150, line=true},
			{type="number", id="min_angle", text="Min angle: ", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_angle", text="Max angle: ", min=-math.pi*2, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.CirclePosGenerator] = {name="CirclePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin: ", min=-10000, max=10000, default={0, 0}, line=true},
			{type="number", id="radius", text="Radius: ", min=0, max=10000, default=150},
			{type="number", id="width", text="Width: ", min=0, max=10000, default=20, line=true},
			{type="number", id="min_angle", text="Min angle: ", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) print("!!!!", type(v) == "number", tonumber(v), v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_angle", text="Max angle: ", min=-math.pi*2, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.TrianglePosGenerator] = {name="TrianglePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin: ", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p1", text="P1: ", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p2", text="P2: ", min=-10000, max=10000, default={100, 100}, line=true},
			{type="point", id="p3", text="P3: ", min=-10000, max=10000, default={-100, 100}},
		}},
		[PC.LinePosGenerator] = {name="LinePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin: ", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p1", text="P1: ", min=-10000, max=10000, default={0, 0}},
			{type="point", id="p2", text="P2: ", min=-10000, max=10000, default={100, 100}},
		}},
		[PC.JaggedLinePosGenerator] = {name="JaggedLinePosGenerator", category="position", fields={
			{type="point", id="base_point", text="Origin: ", min=-10000, max=10000, default={0, 0}, line=true},
			{type="point", id="p1", text="P1: ", min=-10000, max=10000, default={0, 0}},
			{type="point", id="p2", text="P2: ", min=-10000, max=10000, default={100, 100}, line=true},
			{type="number", id="sway", text="Sway: ", min=0, max=10000, default=80},
			{type="number", id="strands", text="strands: ", min=1, max=10000, default=1},
		}},
		[PC.ImagePosGenerator] = {name="ImagePosGenerator", category="position", fields={
			{type="file", id="image", text="Image: ", dir="/data/gfx/particles_masks/", filter="%.png$", default="/data/gfx/particles_masks/tome.png", line=true},
			{type="point", id="base_point", text="Origin: ", min=-10000, max=10000, default={0, 0}, line=true},
		}},
		[PC.DiskVelGenerator] = {name="DiskVelGenerator", category="movement", fields={
			{type="number", id="min_vel", text="Min velocity: ", min=0, max=1000, default=50},
			{type="number", id="max_vel", text="Max velocity: ", min=0, max=1000, default=150},
		}},
		[PC.DirectionVelGenerator] = {name="DirectionVelGenerator", category="movement", fields={
			{type="point", id="from", text="From: ", min=-10000, max=10000, default={0, 0}, line=true},
			{type="number", id="min_vel", text="Min velocity: ", min=-1000, max=1000, default=50},
			{type="number", id="max_vel", text="Max velocity: ", min=-1000, max=1000, default=150, line=true},
			{type="number", id="min_rot", text="Min rotation: ", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_rot", text="Max rotation: ", min=-math.pi*2, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.SwapPosByVelGenerator] = {name="SwapPosByVelGenerator", category="movement", fields={
		}},
		[PC.BasicSizeGenerator] = {name="BasicSizeGenerator", category="size", fields={
			{type="number", id="min_size", text="Min size: ", min=0.00001, max=1000, default=10},
			{type="number", id="max_size", text="Max size: ", min=0.00001, max=1000, default=30},
		}},
		[PC.StartStopSizeGenerator] = {name="StartStopSizeGenerator", category="size", fields={
			{type="number", id="min_start_size", text="Min start: ", min=0.00001, max=1000, default=10},
			{type="number", id="max_start_size", text="Max start: ", min=0.00001, max=1000, default=30, line=true},
			{type="number", id="min_stop_size", text="Min stop: ", min=0.00001, max=1000, default=1},
			{type="number", id="max_stop_size", text="Max stop: ", min=0.00001, max=1000, default=3},
		}},
		[PC.BasicRotationGenerator] = {name="BasicRotationGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation: ", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_rot", text="Max rotation: ", min=0, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.RotationByVelGenerator] = {name="RotationByVelGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation: ", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return math.deg(v) end},
			{type="number", id="max_rot", text="Max rotation: ", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return math.deg(v) end},
		}},
		[PC.BasicRotationVelGenerator] = {name="BasicRotationVelGenerator", category="rotation", fields={
			{type="number", id="min_rot", text="Min rotation velocity: ", min=0, max=math.pi*2, default=0, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
			{type="number", id="max_rot", text="Max rotation velocity: ", min=0, max=math.pi*2, default=math.pi*2, from=function(v) return (type(v) == "number" or tonumber(v)) and math.rad(v) or v end, to=function(v) return (type(v) == "number" or tonumber(v)) and math.deg(v) or v end},
		}},
		[PC.StartStopColorGenerator] = {name="StartStopColorGenerator", category="color", fields={
			{type="color", id="min_color_start", text="Min start color: ", default=colors_alphaf.GOLD(1)},
			{type="color", id="max_color_start", text="Max start color: ", default=colors_alphaf.ORANGE(1), line=true},
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
		[PC.JaggedLineBetweenGenerator] = {name="JaggedLineBetweenGenerator", category="special", fields={
			{type="number", id="source_system1", text="Source system1 ID: ", min=1, max=100, default=1},
			{type="number", id="source_system2", text="Source system2 ID: ", min=1, max=100, default=1, line=true},
			{type="bool", id="copy_pos", text="Copy position: ", default=true},
			{type="bool", id="copy_color", text="Copy color: ", default=true, line=true},
			{type="number", id="sway", text="Sway: ", min=0, max=10000, default=80},
			{type="number", id="strands", text="Strands: ", min=1, max=10000, default=1, line=true},
			{type="number", id="close_tries", text="Pick closer tries: ", min=0, max=200, default=0},
			{type="number", id="repeat_times", text="Repeat: ", min=1, max=1000, default=1},
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
			{id="type", default=PC.RendererPoint},
			{id="compute_only", default=false},
			{id="texture", default="/data/gfx/particle.png"},
			{id="emitters", default={}},
			{id="updaters", default={}},
		}},
	}
}

local emitters_by_id = table.map(function(k, v) return k, v.name end, specific_uis.emitters)
local generators_by_id = table.map(function(k, v) return k, v.name end, specific_uis.generators)
local updaters_by_id = table.map(function(k, v) return k, v.name end, specific_uis.updaters)

function _M:showTriggers()
	local triggers = {}
	local list = {}

	for id_system, system in ipairs(pdef) do
		for id_emitter, emitter in ipairs(system.emitters) do
			for name, kind in pairs(emitter.triggers or {}) do
				triggers[name] = true
			end
		end
	end

	for name, _ in pairs(triggers) do table.insert(list, {name=name, id=name}) end
	Dialog:listPopup("Trigger", "Select trigger name:", list, 200, 400, function(item) if item then
		self.pdo:trigger(item.id)
		self.last_trigger = item.id
	end end)
end

function _M:addTrigger(spe)
	Dialog:textboxPopup("Trigger", "Name:", 1, 50, function(name) if name then
		Dialog:listPopup("Trigger", "Effect:", table.clone(triggermodes, true), 150, 250, function(item) if item then
			spe.triggers = spe.triggers or {}
			spe.triggers[name] = item.trigger
			self:makeUI()
			self:regenParticle()
		end end)
	end end)
end

function _M:addEvent(spe)
	Dialog:textboxPopup("Event", "Name:", 1, 50, function(name) if name then
		Dialog:listPopup("Event", "When:", table.clone(eventmodes, true), 150, 250, function(item) if item then
			spe.events = spe.events or {}
			spe.events[name] = item.event
			self:makeUI()
			self:regenParticle()
		end end)
	end end)
end

function _M:addParameter()
	local item = {name="Number"}
	-- Dialog:listPopup("Parameter", "Type:", {{name="Number"}, {name="Point"}}, 150, 250, function(item) if item then
		Dialog:textboxPopup("Parameter", "Name:", 1, 50, function(name) if name then
			name = name:gsub("[A-Z]", function(c) return c:lower() end)
			if not name:find("^[a-z][a-z_0-9]*$") then Dialog:simplePopup("Parameter Error", "Name invalid, only letters, numbers and _ allowed and can not being with number.") return end
			Dialog:textboxPopup("Parameter", item.name=="Number" and "Default Value:" or "Default Value (format as '<number>x<number>'): ", 1, 50, function(value) if value then
				if item.name == "Number" then
					value = tonumber(value)
				elseif item.name == "Point" then
					local s = value
					value = nil
					local _, _, x, y = s:find("^([0-9.]+)x([0-9.]+)$")
					if tonumber(x) and tonumber(y) then value = {tonumber(x), tonumber(y)} end
				end
				if value then
					pdef.parameters = pdef.parameters or {}
					pdef.parameters[name] = value
					self:makeUI()
					self:regenParticle()
				end
			end end)
		end end)
	-- end end)
end

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

local function getParametrizedColor(p)
	if not p then return "CRIMSON" end
	local f, err = loadstring("return "..p)
	if not f then print("Param error", err) return "LIGHT_RED" end
	local env = table.clone(pdef.parameters or {}, true)
	setmetatable(env, {__index=math})
	setfenv(f, env)
	local ok, err = pcall(f)
	if not ok then print("Param error", err) return "LIGHT_RED" end
	if type(err) ~= "number" then print("Param return error: not a number") return "YELLOW" end
	return "SALMON"
end

function _M:parametrizedBox(t)
	local on_change = t.on_change
	t.font = self.dfont
	t.orig_title = t.title
	t.text = tostring(t.number)
	t.on_change = function(v, box)
		-- Number, bound it
		if tonumber(v) then
			v = util.bound(tonumber(v), t.min, t.max)
			t.is_parametrized = false
		-- String parameter
		else
			t.is_parametrized = true
		end
		on_change(v)

		if t.is_parametrized then box.title_do:color(colors_alphafs[getParametrizedColor(v)](1))
		else box.title_do:color(1, 1, 1, 1)
		end
	end
	t.chars = 12
	if not tonumber(t.number) then
		t.is_parametrized = true
	end
	local b = Textbox.new(t)
	if t.is_parametrized then b.title_do:color(colors_alphafs[getParametrizedColor(t.number)](1)) end
	return b
end

function _M:processSpecificUI(ui, add, kind, spe, delete)
	local spe_def = specific_uis[kind][spe[1]]
	if not spe_def then error("unknown def for: "..tostring(spe[1])) end
	add(Checkbox.new{font=self.dfont, title="#{bold}##GOLD#"..spe_def.name, default=true, fct=function()end, on_change=function(v) if not v then delete() end end})
	local adds = {}
	for i, field in ipairs(spe_def.fields) do
		field.from = field.from or function(v) return v end
		field.to = field.to or function(v) return v end
		if field.type == "number" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = self:parametrizedBox{title=field.text, number=field.to(spe[field.id]), min=field.to(field.min), max=field.to(field.max), chars=6, on_change=function(p) spe[field.id] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "bool" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = Checkbox.new{font=self.dfont, title=field.text, default=field.to(spe[field.id]), on_change=function(p) spe[field.id] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "point" then
			if not spe[field.id] then spe[field.id] = table.clone(field.default, true) end
			adds[#adds+1] = self:parametrizedBox{title=field.text, number=field.to(spe[field.id][1]), min=field.to(field.min), max=field.to(field.max), chars=6, on_change=function(p) spe[field.id][1] = field.from(p) self:regenParticle() end, fct=function()end}
			adds[#adds+1] = self:parametrizedBox{title="x", number=field.to(spe[field.id][2]), min=field.to(field.min), max=field.to(field.max), chars=6, on_change=function(p) spe[field.id][2] = field.from(p) self:regenParticle() end, fct=function()end}
		elseif field.type == "color" then
			if not spe[field.id] then spe[field.id] = table.clone(field.default, true) end
			adds[#adds+1] = Textzone.new{font=self.dfont, text=(i==1 and "    " or "")..field.text, auto_width=1, auto_height=1}
			adds[#adds+1] = ColorPicker.new{font=self.dfont, color=spe[field.id], width=20, height=20, fct=function(p) spe[field.id] = p self:regenParticle() end}
		elseif field.type == "select" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = Textzone.new{font=self.dfont, text=(i==1 and "    " or "")..field.text, auto_width=1, auto_height=1}
			adds[#adds+1] = Dropdown.new{font=self.dfont, width=200, default={"name", spe[field.id]}, fct=function(item) spe[field.id] = item.name self:regenParticle() self:makeUI() end, on_select=function(item)end, list=easings, nb_items=math.min(#easings, 30)}
		elseif field.type == "file" then
			if not spe[field.id] then spe[field.id] = field.default end
			adds[#adds+1] = Textzone.new{font=self.dfont, text=(i==1 and "    " or "")..field.text..tostring(spe[field.id]), auto_width=1, auto_height=1, fct=function() self:selectFile(spe, field) end}
		end
		if field.line then add(unpack(adds)) adds={} end
	end
	add(unpack(adds))
	add(8)
end

function _M:displayParameter(add, name, value)
	local adds = {Checkbox.new{font=self.dfont, title="", default=true, fct=function()end, on_change=function(v) if not v then pdef.parameters[name] = nil if not next(pdef.parameters) then pdef.parameters = nil end self:regenParticle() self:makeUI() end end}}
	if type(value) == "number" then
		adds[#adds+1] = Numberbox.new{font=self.dfont, title="#{bold}##SALMON#"..name..": ", number=value, min=-100000, max=100000, chars=6, on_change=function(p) pdef.parameters[name] = p self.pdo:params(pdef.parameters) end, fct=function()end}
	elseif type(value) == "table" and #value == 2 then
		adds[#adds+1] = Numberbox.new{font=self.dfont, title="#{bold}##SALMON#"..name..": ", number=value[1], min=-100000, max=100000, chars=6, on_change=function(p) pdef.parameters[name][1] = p self.pdo:params(pdef.parameters) end, fct=function()end}
		adds[#adds+1] = Numberbox.new{font=self.dfont, title="x", number=value[2], min=-100000, max=100000, chars=6, on_change=function(p) pdef.parameters[name][2] = p self:regenParticle() end, fct=function()end}
	end
	add(unpack(adds))
	add(8)
end

function _M:makeTitle(add, tab, text, important, on_click)
	local b = Button.new{font=self.dfont, text=text, all_buttons_fct=true, fct=function(button) if on_click then on_click(button) end end, width=self.iw - tab - 10, use_frame=important and "ui/heading" or "ui/selector"}

	if important then
		add(Checkbox.new{font=self.dfont, title="", default=true, fct=function()end, on_change=function(v) if not v then important() end end}, b)
	else
		add(b)
	end
end

function _M:titleMenu(spe, parent)
	return function(button)
		if button == "left" then
			spe.hide = not spe.hide self:makeUI()
		elseif button == "right" then
			Dialog:listPopup("Options", "", {
				{name="Rename", id="rename"},
				{name="Duplicate", id="clone"},
				{name="Move up", id="up"},
				{name="Move down", id="down"},
			}, 100, 200, function(item) if item then
				if item.id == "rename" then
					Dialog:textboxPopup("Name for this addon's release", "Name", 1, 50, function(name) if name then
						spe.display_name = name self:makeUI()
					end end)
				elseif item.id == "clone" then
					for i, s in ipairs(parent) do if s == spe then
						local c = table.clone(s, true)
						c.display_name = (c.display_name or "unnamed").." (duplicated)"
						table.insert(parent, i + 1, c)
						self:makeUI()
						break
					end end
				elseif item.id == "up" then
					for i, s in ipairs(parent) do if s == spe and i > 1 then
						table.remove(parent, i)
						table.insert(parent, i - 1, s)
						self:makeUI()
						break
					end end
				elseif item.id == "down" then
					for i, s in ipairs(parent) do if s == spe and i < #parent then
						table.remove(parent, i)
						table.insert(parent, i + 1, s)
						self:makeUI()
						break
					end end
				end
			end end)
		end
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

	if def.parameters then
		tab = 0
		self:makeTitle(add, tab, "#{bold}##SALMON#----== Parameters ==----", false)
		for name, value in pairs(def.parameters) do
			self:displayParameter(add, name, value)
		end
	end					
	add(DisplayObject.new{font=self.dfont, DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addParameter() end}, Textzone.new{font=self.dfont, text="add parameter", auto_width=1, auto_height=1, fct=function() self:addParameter() end})
	add(Separator.new{font=self.dfont, dir="vertical", size=self.iw})
	add(10)

	for id_system, system in ipairs(def) do
		local id = id_system
		tab = 0
		self:makeTitle(add, tab, "#{bold}##OLIVE_DRAB#----------====== System "..id_system..": #ANTIQUE_WHITE#"..(system.display_name or "unnamed").."#LAST# ======----------", 	function() table.remove(def, id) self:makeUI() self:regenParticle() end, self:titleMenu(system, def))
		if not system.hide then
			tab = 20
			add(
				Textzone.new{font=self.dfont, text="Max: ", auto_width=1, auto_height=1}, Numberbox.new{font=self.dfont, number=system.max_particles, min=1, max=100000, chars=6, on_change=function(p) system.max_particles = p self:regenParticle() end, fct=function()end},
				Textzone.new{font=self.dfont, text="Blend: ", auto_width=1, auto_height=1}, Dropdown.new{font=self.dfont, width=200, default={"blend", system.blend}, fct=function(item) system.blend = item.blend self:regenParticle() self:makeUI() end, on_select=function(item)end, list=blendmodes, nb_items=#blendmodes}
			)
			add(Textzone.new{font=self.dfont, text="Type: ", auto_width=1, auto_height=1}, Dropdown.new{font=self.dfont, width=200, default={"type", system.type}, fct=function(item) system.type = item.type self:regenParticle() self:makeUI() end, on_select=function(item)end, list=typemodes, nb_items=#typemodes})
			add(0)
			add(Checkbox.new{font=self.dfont, title="Compute Only (Hidden)", default=system.compute_only, on_change=function(p) system.compute_only = p self:regenParticle() end, fct=function()end})
			add(0)
			add(Textzone.new{font=self.dfont, text="Texture: "..system.texture, auto_width=1, auto_height=1, fct=function() self:selectTexture(system) end})
			add(Textzone.new{font=self.dfont, text="Shader: "..(system.shader or "--"), auto_width=1, auto_height=1, fct=function() self:selectShader(system) end})
			add(8)
			
			for id_emitter, emitter in ipairs(system.emitters) do
				local id = id_emitter
				tab = 20
				self:makeTitle(add, tab, "#{bold}##CRIMSON#----== Emitter "..id..": #ANTIQUE_WHITE#"..(emitter.display_name or "unnamed").."#LAST# ==----", false, self:titleMenu(emitter, system.emitters))
				if not emitter.hide then
					tab = 40
					self:processSpecificUI(ui, add, "emitters", emitter, function() table.remove(system.emitters, id) self:makeUI() self:regenParticle() end)
					add(Separator.new{font=self.dfont, dir="vertical", size=self.iw * 0.5})

					for id_generator, generator in ipairs(emitter[2]) do
						local id = id_generator
						self:processSpecificUI(ui, add, "generators", generator, function() table.remove(emitter[2], id) self:makeUI() self:regenParticle() end)
					end
					add(DisplayObject.new{font=self.dfont, DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("generators", emitter[2]) end}, Textzone.new{font=self.dfont, text="add generator", auto_width=1, auto_height=1, fct=function() self:addNew("generators", emitter[2]) end})

					if emitter.triggers then
						tab = 60
						self:makeTitle(add, tab, "#{bold}##OLIVE_DRAB#----== Triggers ==----", false)
						for name, kind in pairs(emitter.triggers) do
							add(Checkbox.new{font=self.dfont, title="#OLIVE_DRAB#"..name.."#LAST# => #{italic}#"..trigger_by_id[kind], default=true, on_change=function(p) emitter.triggers[name] = nil if not next(emitter.triggers) then emitter.triggers = nil end self:makeUI() self:regenParticle() end, fct=function()end})
						end
					end					
					add(DisplayObject.new{font=self.dfont, DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("generators", emitter[2]) end}, Textzone.new{font=self.dfont, text="add trigger", auto_width=1, auto_height=1, fct=function() self:addTrigger(emitter) end})

					if emitter.events then
						tab = 60
						self:makeTitle(add, tab, "#{bold}##DARK_ORCHID#----== Events ==----", false)
						for name, kind in pairs(emitter.events) do
							add(Checkbox.new{font=self.dfont, title="#DARK_ORCHID#"..name.."#LAST# => #{italic}#"..event_by_id[kind], default=true, on_change=function(p) emitter.events[name] = nil if not next(emitter.events) then emitter.events = nil end self:makeUI() self:regenParticle() end, fct=function()end})
						end
					end					
					add(DisplayObject.new{font=self.dfont, DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("generators", emitter[2]) end}, Textzone.new{font=self.dfont, text="add event", auto_width=1, auto_height=1, fct=function() self:addEvent(emitter) end})
				end
			end
			tab = 20
			add(5)
			add(DisplayObject.new{font=self.dfont, DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("emitters", system.emitters) end}, Textzone.new{font=self.dfont, text="add emitter", auto_width=1, auto_height=1, fct=function() self:addNew("emitters", system.emitters) end})
			add(5)
			
			self:makeTitle(add, tab, "#{bold}##AQUAMARINE#----== Updaters ==----", false)
			tab = 40
			for id_updater, updater in ipairs(system.updaters) do
				local id = id_updater
				self:processSpecificUI(ui, add, "updaters", updater, function() table.remove(system.updaters, id) self:makeUI() self:regenParticle() end)
			end
			add(DisplayObject.new{font=self.dfont, DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("updaters", system.updaters) end}, Textzone.new{font=self.dfont, text="add updater", auto_width=1, auto_height=1, fct=function() self:addNew("updaters", system.updaters) end})
		end
		add(8)
	end
	tab = 0
	add(8)
	add(DisplayObject.new{font=self.dfont, DO=core.renderer.fromTextureTable(self.plus_t), width=16, height=16, fct=function() self:addNew("systems", def) end}, Textzone.new{font=self.dfont, text="add system", auto_width=1, auto_height=1, fct=function() self:addNew("systems", def) end})
	
	self:loadUI(ui)
	self:setupUI(false, false)
	self:setScroll(old_scroll)

	self.mouse:registerZone(0, 0, game.w, game.h, function(button, mx, my, xrel, yrel, bx, by, event)
		if mx < game.w - 550 and my >= self.uidialog.margin_top and my <= game.h - self.uidialog.margin_bottom then
			if core.key.modState("ctrl") then
				if event == "button" and button == "wheelup" then
					particle_speed = util.bound(particle_speed + 0.05, 0.1, 10)
					self.pdo:speed(particle_speed)
					return true
				elseif event == "button" and button == "wheeldown" then
					particle_speed = util.bound(particle_speed - 0.05, 0.1, 10)
					self.pdo:speed(particle_speed)
					return true
				elseif event == "button" and button == "middle" then
					particle_speed = 1
					self.pdo:speed(particle_speed)
					return true
				end
			else
				if event == "button" and button == "wheelup" then
					particle_zoom = util.bound(particle_zoom + 0.05, 0.1, 10)
					self.pdo:zoom(particle_zoom)
					self:shift(mx, my)
					return true
				elseif event == "button" and button == "wheeldown" then
					particle_zoom = util.bound(particle_zoom - 0.05, 0.1, 10)
					self.pdo:zoom(particle_zoom)
					self:shift(mx, my)
					return true
				elseif event == "button" and button == "middle" then
					particle_zoom = 1
					self.pdo:zoom(particle_zoom)
					self:shift(mx, my)
					return true
				elseif event == "button" and button == "right" and self.last_trigger then
					self.pdo:trigger(self.last_trigger)
				elseif event == "button" and (button == "left" or button == "right") then
					self:showTriggers()
				end
			end
		end

		if mx < game.w - 550 then 
			if core.key.modState("alt") then 
				local a = math.atan2(my - self.old_shift_y, mx - self.old_shift_x)
				local r = math.sqrt((my - self.old_shift_y)^2 + (mx - self.old_shift_x)^2)
				self.pdo:params{size=r, range=r, angle=a, angled=math.deg(a), tx=mx - self.old_shift_x, ty=my - self.old_shift_y}
			else
				self:shift(mx, my)
			end
		else self:shift((game.w - (self.hide_ui and 0 or 550)) / 2, game.h / 2) end

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

	local clist = ImageList.new{font=self.dfont, width=self.iw, height=self.ih, tile_w=128, tile_h=128, force_size=true, padding=10, scrollbar=true, root_loader=true, list=list, fct=function(item)
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

	local clist = List.new{font=self.dfont, width=self.iw, height=self.ih, scrollbar=true, list=list, fct=function(item)
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

	local clist = List.new{font=self.dfont, width=self.iw, height=self.ih, scrollbar=true, list=list, fct=function(item)
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
		self.bg:add(core.renderer.image("/data/gfx/background/tome.png"):shader(self.bg_shader))
	elseif kind == "tome2" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome2.png"):shader(self.bg_shader))
	elseif kind == "tome3" then
		self.bg:add(core.renderer.image("/data/gfx/background/tome3.png"):shader(self.bg_shader))
	elseif type(kind) == "table" then
		self.bg:add(core.renderer.colorQuad(0, 0, w, h, unpack(kind)):shader(self.normal_shader))
	end
end

function _M:init(no_bloom)
	local id, size = FontPackage:getDefault()
	FontPackage:setDefaultId("default") FontPackage:setDefaultSize("normal")
	self.dfont = FontPackage:get("default")
	FontPackage:setDefaultId(id) FontPackage:setDefaultSize(size)

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

	self.bg_shader = Shader.new("particles/normal", nil, true, "gl2")

	PC.defaultShader("particles/normal")
	self.bg = core.renderer.renderer()

	self:makeUI(pdef)

	self.key:setupRebootKeys()
	self.key:addBinds{
		EXIT = function()
			local list = {
				"resume",
				"keybinds_all",
				"video",
				"sound",
				{"Exit", function() if game.__mod_info.short_name=="particles_editor" then os.exit() else game:unregisterDialog(self) end end},
			}
			local menu = require("engine.dialogs.GameMenu").new(list)
			game:registerDialog(menu)
		end,
		-- LUA_CONSOLE = function() game:registerDialog(require("engine.DebugConsole").new()) end,
		FILE_NEW = function() print("FILE_NEW") self.uidialog:reset() end,
		FILE_LOAD = function() print("FILE_LOAD") self.uidialog:load(self) end,
		FILE_MERGE = function() print("FILE_MERGE") self.uidialog:merge(self) end,
		FILE_SAVE = function() print("FILE_SAVE") self.uidialog:save() end,		
		EDITOR_UNDO = function() print("EDITOR_UNDO") self:undo() end,
		EDITOR_REDO = function() print("EDITOR_REDO") self:redo() end,
	}
	self.key:addCommands{
		_b = function() self:toggleBloom() end,
		_u = function() self:toggleUI() end,
	}

	self.particle_renderer = core.renderer.renderer()

	local w, h = game.w, game.h
	self.fbomain = core.renderer.target(nil, nil, 2, true)
	self.fbomain:setAutoRender(self.particle_renderer)

	self.blur_shader = Shader.new("rendering/blur") self.blur_shader:setUniform("texSize", {w, h})
	local main_shader = Shader.new("rendering/main_fbo") main_shader:setUniform("texSize", {w, h})
	local finalquad = core.renderer.targetDisplay(self.fbomain, 0, 0)
	self.downsampling = 4
	local bloomquad = core.renderer.targetDisplay(self.fbomain, 1, 0, w/self.downsampling/self.downsampling, h/self.downsampling/self.downsampling)
	local bloomr = core.renderer.renderer("static"):setRendererName("game.bloomr"):add(bloomquad):premultipliedAlpha(true)
	local fbobloomview = core.renderer.view():ortho(w/self.downsampling, h/self.downsampling, false)
	self.fbobloom = core.renderer.target(w/self.downsampling, h/self.downsampling, 1, true):setAutoRender(bloomr):view(fbobloomview)--:translate(0,-h)
	self.initial_blooming = true
	if not no_bloom then self:toggleBloom() end
	self.initial_blooming = false
	if false then -- true to see only the bloom texture
		-- finalquad:textureTarget(self.fbobloom, 0, 0):shader(main_shader)
		self.fborenderer = core.renderer.renderer("static"):setRendererName("game.fborenderer"):add(self.fbobloom)--:premultipliedAlpha(true)
	else
		finalquad:textureTarget(self.fbobloom, 0, 1):shader(main_shader)
		self.fborenderer = core.renderer.renderer("static"):setRendererName("game.fborenderer"):add(finalquad)--:premultipliedAlpha(true)
	end

	self:regenParticle()

	local function autosave() self.renderer:tween(30, "wait", function() game:onTickEnd(function() self.uidialog:saveAs("__autosave__", true) autosave() end) end) end
	autosave()
end

function _M:toggleBloom()
	if not self.blooming then
		self.fbobloom:blurMode(14, self.downsampling, self.blur_shader)
		self.blooming = true
	else
		self.fbobloom:removeMode()
		self.blooming = false
	end
	if not self.initial_blooming then
		self.bignews:saySimple(60, "Bloom effect: "..(self.blooming and "#LIGHT_GREEN#Enabled" or "#LIGHT_RED#Disabled"))
	end
end

function _M:toggleUI()
	self.hide_ui = not self.hide_ui
end

function _M:regenParticle(nosave)
	if not self.particle_renderer then return end
	if not nosave then
		for i = pdef_history_pos + 1, #pdef_history do pdef_history[i] = nil end
		table.insert(pdef_history, table.clone(pdef, true))
		pdef_history_pos = #pdef_history
	end

	-- table.print(pdef)
	-- self.pdo = PC.new("/data/gfx/particles/fireflash.pc", {}, particle_speed, particle_zoom, true)
	self.pdo = PC.new(pdef, nil, particle_speed, particle_zoom, true)
	self:shift(self.old_shift_x, self.old_shift_y)
	self.p_date = core.game.getTime()

	self.pdo:onEvents(function(name, times)
		self.bignews:saySimple(30, "Event #GOLD#"..name.."#LAST# triggered #LIGHT_GREEN#"..times.."#LAST# times")
		print("Particle Event", name, times)
	end)

	self.particle_renderer:clear():add(self.bg):add(self.pdo)

	collectgarbage("collect")
end

function _M:shift(x, y)
	self.old_shift_x, self.old_shift_y = x, y
	self.pdo:shift(x, y, true)
end

function _M:toScreen(x, y, nb_keyframes)
	if self.pdo:dead() then
		self.bignews:saySimple(15, "#AQUAMARINE#--END--")
		self:regenParticle(true)
	end

	if self.blooming then
		self.fbomain:compute()
		self.fbobloom:compute()
		self.fborenderer:toScreen()
	else
		self.particle_renderer:toScreen()
	end
	-- self.p:toScreen(0, 0, nb_keyframes)

	if not self.hide_ui then
		self.uidialog:toScreen(0, 0, nb_keyframes)

		Dialog.toScreen(self, x, y, nb_keyframes)

		self.bignews:display(nb_keyframes)
	end
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

	local cp =ColorPicker.new{font=self.dfont, color={0, 0, 0, 1}, width=20, height=20, fct=function(p) master:setBG(p) end}

	local new = Button.new{font=master.dfont, text="New", fct=function() self:reset() end}
	local load = Button.new{font=master.dfont, text="Load", fct=function() self:load(master) end}
	local merge = Button.new{font=master.dfont, text="Merge", fct=function() self:merge(master) end}
	local save = Button.new{font=master.dfont, text="Save", fct=function() self:save() end}

	local bgt = Button.new{font=master.dfont, text="Transparent background", fct=function() master:setBG("transparent") end}
	local bgb = Button.new{font=master.dfont, text="Color background", fct=function() cp:popup() end}
	local bg1 = Button.new{font=master.dfont, text="Background1", fct=function() master:setBG("tome1") end}
	local bg2 = Button.new{font=master.dfont, text="Background2", fct=function() master:setBG("tome2") end}
	local bg3 = Button.new{font=master.dfont, text="Background3", fct=function() master:setBG("tome3") end}

	self.margin_top = new.h + 5
	self.margin_bottom = bgt.h + 5

	self.master = master
	self.particles_count = core.renderer.text(self.font_mono):translate(600, 0):outline(1)
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
	}
	self:setupUI(false, false)
end

function UIDialog:reset()
	Dialog:yesnoPopup("Clear particles?", "All data will be lost.", function(ret) if ret then
		pdef={}
		pdef_history_pos = 0
		pdef_history = {}
		-- PC.gcTextures()
		self.master.current_filename = ""
		self.master:makeUI()
		self.master:regenParticle(true)
	end end)
end

function UIDialog:load(master)
	local d = Dialog.new("Load particle effects from /data/gfx/particles/", game.w * 0.6, game.h * 0.6)

	local list = {}
	for i, file in ipairs(fs.list("/data/gfx/particles/")) do if file:find("%.pc$") then
		list[#list+1] = {name=file, path="/data/gfx/particles/"..file}
	end end 

	local clist = List.new{font=self.dfont, scrollbar=true, width=d.iw, height=d.ih, list=list, fct=function(item)
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
		core.display.setWindowTitle("Particles Editor: "..item.name)
		master.current_filename = item.name:gsub("%.pc$", "")
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

	local clist = List.new{font=self.dfont, scrollbar=true, width=d.iw, height=d.ih, list=list, fct=function(item)
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
	local function getFormat(v)
		if type(v) == "number" then return "%f"
		elseif type(v) == "string" then return "%q"
		else error("Unsupported format: "..tostring(v))
		end
	end
	local function getData(up, simple)
		local data = {}
		for k, v in pairs(up) do
			if type(k) == "string" and k ~= "triggers" and k ~= "events" then
				if type(v) == "number" then
					data[#data+1] = ("%s=%f"):format(k, v)
				elseif type(v) == "boolean" then
					data[#data+1] = ("%s=%s"):format(k, v and "true" or "false")
				elseif type(v) == "string" then
					data[#data+1] = ("%s=%q"):format(k, v)
				elseif type(v) == "table" and #v == 2 then
					data[#data+1] = (("%%s={%s, %s}"):format(getFormat(v[1]), getFormat(v[2]))):format(k, v[1], v[2])
				elseif type(v) == "table" and #v == 3 then
					data[#data+1] = (("%%s={%s, %s, %s}"):format(getFormat(v[1]), getFormat(v[2]), getFormat(v[3]))):format(k, v[1], v[2], v[3])
				elseif type(v) == "table" and #v == 4 then
					data[#data+1] = (("%%s={%s, %s, %s, %s}"):format(getFormat(v[1]), getFormat(v[2]), getFormat(v[3]), getFormat(v[4]))):format(k, v[1], v[2], v[3], v[4])
				elseif type(v) == "table" and #v == 0 and next(v) then
					data[#data+1] = ("%s={%s}"):format(k, getData(v, true))
				else
					error("Unsupported save parameter: "..tostring(v).." for key "..k)
				end
			elseif k == "triggers" and next(v) then
				local tgs = {}
				for name, id in pairs(v) do
					tgs[#tgs+1] = ("%s = PC.%s"):format(name, triggerkind_by_id[id])
				end
				data[#data+1] = "triggers = { "..table.concat(tgs, ", ").." }"
			elseif k == "events" and next(v) then
				local tgs = {}
				for name, id in pairs(v) do
					tgs[#tgs+1] = ("%s = PC.%s"):format(name, eventkind_by_id[id])
				end
				data[#data+1] = "events = { "..table.concat(tgs, ", ").." }"
			end
		end
		if #data > 0 then data = (not simple and ", " or "")..table.concat(data, ", ") else data = "" end
		return data
	end

	w(0, "return {\n")
	if pdef.parameters then
		w(1, ("parameters = { %s },\n"):format(getData(pdef.parameters, true)))
	end
	for _, system in ipairs(pdef) do
		w(1, "{\n")
		if system.display_name then w(2, ("display_name = %q,\n"):format(system.display_name)) end
		w(2, ("max_particles = %d, blend=PC.%s, type=PC.%s, compute_only=%s,\n"):format(system.max_particles, blend_by_id[system.blend], system.type and type_by_id[system.type] or "RendererPoint", system.compute_only and "true" or "false"))
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

function UIDialog:saveAs(txt, silent)
	local mod = game.__mod_info

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
	if not silent then
		self.master.bignews:saySimple(60, "#GOLD#Saved to "..tostring(fs.getRealPath(basedir..txt..".pc")))
		core.display.setWindowTitle("Particles Editor: "..txt)
		self.master.current_filename = txt
	end
end

function UIDialog:save()
	local d = Dialog.new("Save particle effects to /data/gfx/particles/", 1, 1)

	local function exec(txt)
		game:unregisterDialog(d)
		self:saveAs(txt, false)
	end

	local box = Textbox.new{font=self.dfont, title="Filename (without .pc extension): ", chars=80, text=self.master.current_filename or "", fct=function(txt) if #txt > 0 then
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
	local fps, msframe = core.display.getFPS()
	self.particles_count:text(("Elapsed Time %0.2fs / FPS: %0.1f / %d ms/frame / Active particles: %d / Zoom: %d%% / Speed: %d%%"):format((core.game.getTime() - self.master.p_date) / 1000, fps, msframe, self.master.pdo:countAlive(), particle_zoom * 100, particle_speed * 100), true)
	self.particles_count_renderer:toScreen()
	Dialog.toScreen(self, x, y, nb_keyframes)
end
