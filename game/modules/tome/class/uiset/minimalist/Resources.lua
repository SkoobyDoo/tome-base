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
local UI = require "engine.ui.Base"
local MiniContainer = require "mod.class.uiset.minimalist.MiniContainer"
local ActorResource = require "engine.interface.ActorResource"
local Shader = require "engine.Shader"
local FontPackage = require "engine.FontPackage"

--- Player frame for Minimalist ui
module(..., package.seeall, class.inherit(MiniContainer))

-- DGDGDGDG this should be moved into the resources definitions no ? yes !
_M.shader_params = {default = {name = "resources", require_shader=4, delay_load=false, speed=1000, distort={1.5,1.5}},
	air={name = "resources", require_shader=4, delay_load=false, color={0x92/255, 0xe5, 0xe8}, speed=100, amp=0.8, distort={2,2.5}},
	life={name = "resources", require_shader=4, delay_load=false, color={0xc0/255, 0, 0}, speed=1000, distort={1.5,1.5}},
	shield={name = "resources", require_shader=4, delay_load=false, color={0.5, 0.5, 0.5}, speed=5000, a=0.5, distort={0.5,0.5}},
	stamina={name = "resources", require_shader=4, delay_load=false, color={0xff/255, 0xcc/255, 0x80/255}, speed=700, distort={1,1.4}},
	mana={name = "resources", require_shader=4, delay_load=false, color={106/255, 146/255, 222/255}, speed=1000, distort={0.4,0.4}},
	soul={name = "resources", require_shader=4, delay_load=false, color={128/255, 128/255, 128/255}, speed=1200, distort={0.4,-0.4}},
	equilibrium={name = "resources2", require_shader=4, delay_load=false, color1={0x00/255, 0xff/255, 0x74/255}, color2={0x80/255, 0x9f/255, 0x44/255}, amp=0.8, speed=20000, distort={0.3,0.25}},
	paradox={name = "resources2", require_shader=4, delay_load=false, color1={0x2f/255, 0xa0/255, 0xb4/255}, color2={0x8f/255, 0x80/255, 0x44/255}, amp=0.8, speed=20000, distort={0.1,0.25}},
	positive={name = "resources", require_shader=4, delay_load=false, color={colors.GOLD.r/255, colors.GOLD.g/255, colors.GOLD.b/255}, speed=1000, distort={1.6,0.2}},
	negative={name = "resources", require_shader=4, delay_load=false, color={colors.DARK_GREY.r/255, colors.DARK_GREY.g/255, colors.DARK_GREY.b/255}, speed=1000, distort={1.6,-0.2}},
	vim={name = "resources", require_shader=4, delay_load=false, color={210/255, 180/255, 140/255}, speed=1000, distort={0.4,0.4}},
	hate={name = "resources", require_shader=4, delay_load=false, color={0xF5/255, 0x3C/255, 0xBE/255}, speed=1000, distort={0.4,0.4}},
	psi={name = "resources", require_shader=4, delay_load=false, color={colors.BLUE.r/255, colors.BLUE.g/255, colors.BLUE.b/255}, speed=2000, distort={0.4,0.4}},
	feedback={name = "resources", require_shader=4, delay_load=false, color={colors.YELLOW.r/255, colors.YELLOW.g/255, colors.YELLOW.b/255}, speed=2000, distort={0.4,0.4}},
}

function _M:init(minimalist, w, h)
	local bar_shadow_t = self:texLoader("resources/shadow.png")
	local bar_back_t = self:texLoader("resources/back.png")
	local bar_fill_t = self:texLoader("resources/fill.png")
	local font_r = FontPackage:get("resources_normal", true)
	local small_font_r = FontPackage:get("resources_small", true)

	self.rw, self.rh = bar_back_t.w, bar_back_t.h
	self.fw, self.fh = bar_fill_t.w, bar_fill_t.h

	MiniContainer.init(self, minimalist)

	self.do_container = core.renderer.renderer("dynamic"):setRendererName("Resources MiniContainer")

	self.resources_defs = {}
	self.frames = {}

	local base_defs = table.clone(ActorResource.resources_def)

	-- Insert life
	table.insert(base_defs, 2, {
		name = "Life",
		short_name = "life",
		regen_prop = "life_regen",
		invert_values = false,
		description = "Life is good to have.",
		color = {0xc0/255, 0, 0},
		display = { get_values = function(player) return player.life, 0, player.max_life, player.life_regen end, },
	})

	-- Shield, let's try with it in its own, may be actually better
	table.insert(base_defs, 3, {
		name = "Shielding",
		short_name = "life_armored",
		regen_prop = "lolnope",
		invert_values = false,
		description = "Shielding protects your life.",
		color = {0.5, 0.5, 0.5},
		display = {
			shown = function(player)
				local shield, max_shield = 0, 0
				if player:attr("time_shield") then shield = shield + player.time_shield_absorb max_shield = max_shield + player.time_shield_absorb_max end
				if player:attr("damage_shield") then shield = shield + player.damage_shield_absorb max_shield = max_shield + player.damage_shield_absorb_max end
				if player:attr("displacement_shield") then shield = shield + player.displacement_shield max_shield = max_shield + player.displacement_shield_max end
				return shield > 0
			end,
			get_values = function(player)
				local shield, max_shield = 0, 0
				if player:attr("time_shield") then shield = shield + player.time_shield_absorb max_shield = max_shield + player.time_shield_absorb_max end
				if player:attr("damage_shield") then shield = shield + player.damage_shield_absorb max_shield = max_shield + player.damage_shield_absorb_max end
				if player:attr("displacement_shield") then shield = shield + player.displacement_shield max_shield = max_shield + player.displacement_shield_max end
				return shield, 0, max_shield, 0
			end,
		},
	})

	-- Insert Psionic Feedback
	table.insert(base_defs, {
		name = "Psionic Feedback",
		short_name = "feedback",
		regen_prop = "lolnope",
		invert_values = false,
		description = "Psionic feedback.",
		color = colors.YELLOW,
		display = {
			shown = function(player) return player.psionic_feedback_max and player:knowTalent(player.T_FEEDBACK_POOL) end,
			get_values = function(player) return player:getFeedback(), 0, player:getMaxFeedback(), -player:getFeedbackDecay() end,
		},
		Minimalist = {
			images = {front = "resources/front_psi.png", front_dark = "resources/front_psi_dark.png"},
		},
	})

	-- Insert FortressEnergy
	table.insert(base_defs, {
		name = "Fortress Energy",
		short_name = "fortress",
		regen_prop = "lolnope",
		invert_values = false,
		description = "Fortress Energy.",
		color = {0x39/255, 0xd5/255, 0x35/255},
		display = {
			shown = function(player) return player.is_fortress end,
			status_text = function(player)
				local q = player:hasQuest("shertul-fortress")
				return ("%d"):format(q and q.shertul_energy)
			end,
			highlight = function() return true end,
			percent_compute = function(player, vc, vn, vm, vr) return 1 end,
			get_values = function(player) local q = player:hasQuest("shertul-fortress") return q and q.shertul_energy or 0, 0, 10000, 0 end,
		},
		Minimalist = {
			images = {front = "resources/front_psi.png", front_dark = "resources/front_psi_dark.png"},
		},
	})

	-- Insert Ammo
	table.insert(base_defs, {
		name = "Arrows", short_name = "arrow", regen_prop = "lolnope", description = "Ammo.",
		display = {
			simple = true,
			shown = function(player) local quiver = player:getInven("QUIVER") return quiver and quiver[1] and quiver[1].subtype == "arrow" end,
			get_values = function(player) local quiver = player:getInven("QUIVER") local ammo = quiver and quiver[1] if ammo then return ammo.combat.shots_left, 0, ammo.combat.capacity, 0	else return 0, 0, 0, 0 end end,
		},
		Minimalist = { simple = {front = "resources/ammo_arrow.png", shadow = "resources/ammo_shadow_arrow.png"} },
	})
	table.insert(base_defs, {
		name = "Shots", short_name = "shot", regen_prop = "lolnope", description = "Ammo.",
		display = {
			simple = true,
			shown = function(player) local quiver = player:getInven("QUIVER") return quiver and quiver[1] and quiver[1].subtype == "shot" end,
			get_values = function(player) local quiver = player:getInven("QUIVER") local ammo = quiver and quiver[1] if ammo then return ammo.combat.shots_left, 0, ammo.combat.capacity, 0	else return 0, 0, 0, 0 end end,
		},
		Minimalist = { simple = {front = "resources/ammo_shot.png", shadow = "resources/ammo_shadow_shot.png"} },
	})
	table.insert(base_defs, {
		name = "Gems", short_name = "gem", regen_prop = "lolnope", description = "Ammo.",
		display = {
			simple = true,
			status_text = function(player, vc)
				return ("%d"):format(vc)
			end,
			shown = function(player) local quiver = player:getInven("QUIVER") return quiver and quiver[1] and quiver[1].type == "alchemist-gem" end,
			get_values = function(player) local quiver = player:getInven("QUIVER") local ammo = quiver and quiver[1] if ammo then return ammo:getNumber(), 0, ammo:getNumber(), 0 else return 0, 0, 0, 0 end end,
		},
		Minimalist = { simple = {front = "resources/ammo_alchemist-gem.png", shadow = "resources/ammo_shadow_alchemist-gem.png"} },
	})

	-- Addons can add other "fake" entries
	self:triggerHook{"UISet:Minimalist:Resources", base_defs=base_defs}

	-- Insert Savefile (always at the end)
	table.insert(base_defs, {
		name = "Saving",
		short_name = "save",
		regen_prop = "lolnope",
		invert_values = false,
		description = "Game is being saved...",
		color = colors.YELLOW,
		display = {
			shown = function(player) return savefile_pipe.saving end,
			get_values = function(player) return savefile_pipe.current_nb, 0, savefile_pipe.total_nb, 0 end,
			status_text = function(player, vc, vn, vm) return ("Saving... %d%%"):format(util.bound(vc / vm * 100, 0, 100)) end,
		},
		Minimalist = {
			images = {front = "resources/front.png", front_dark = "resources/front_dark.png"},
		},
	})

	for res, res_def in ipairs(base_defs) do if not res_def.hidden_resource then
		local rname = res_def.short_name
		local res_gfx = table.clone(res_def.minimalist_gfx) or {color = {}, shader = {}} -- use the graphics defined with the resource, if possible

		-- set up color
		local res_color = res_def.color
		if type(res_color) == "string" then res_color = res_color:gsub("^#", ""):gsub("#$", "") end		
		res_gfx.color = colors.smart1(res_color or "WHITE")
		res_gfx.color[4] = res_gfx.color[4] or 1

		res_def.display = res_def.display or {}
		res_def.display.highlight_pct = res_def.display.highlight_pct or 0.8

		-- generate default tooltip if needed
		res_gfx.tooltip = _M["TOOLTIP_"..rname:upper()] or ([[#GOLD#%s#LAST#
%s]]):format(res_def.name, res_def.description or "no description")

		local rc = core.renderer.container()
		res_gfx.container = rc

		if res_def.display.simple then
			local d = table.get(res_def, "Minimalist", "simple")
			local shadow, front = self:imageLoader(d.shadow), self:imageLoader(d.front)
			rc:add(shadow)
			rc:add(front)
			res_gfx.valtext = core.renderer.text(font_r):shadow(1, 1)
			rc:add(res_gfx.valtext)
			res_gfx.fill = core.renderer.container():translate(31, 16) -- Only to not bork later logic
		else
			-- load graphic images
			local res_imgs = table.merge({front = "resources/front_"..rname..".png", front_dark = "resources/front_"..rname.."_dark.png"}, table.get(res_def, "Minimalist", "images") or {})
			local sbase, bbase = "/data/gfx/"..UI.ui.."-ui/minimalist/", "/data/gfx/ui/"
			for typ, file in pairs(res_imgs) do
				res_gfx[typ] = self:imageLoader(file)
				res_gfx[typ.."_file"] = file
			end

			local shad_params = table.clone(_M.shader_params[rname] or _M.shader_params.default)
			shad_params.color = table.clone(shad_params.color or res_gfx.color)
			shad_params.color[4] = nil
			res_gfx.shader = Shader.new(shad_params.name, shad_params)
			
			rc:add(core.renderer.fromTextureTable(bar_shadow_t, -6, 8))
			rc:add(core.renderer.fromTextureTable(bar_back_t, 0, 0))
			res_gfx.fill = core.renderer.fromTextureTable(bar_fill_t, 0, 0):translate(49, 10)
			if res_gfx.shader.shad then res_gfx.fill:shader(res_gfx.shader.shad)
			else res_gfx.fill:color(unpack(res_gfx.color))
			end
			rc:add(res_gfx.fill)
			rc:add(res_gfx.front:shown(true))
			rc:add(res_gfx.front_dark:shown(false))
			res_gfx.regentext = core.renderer.text(small_font_r):shadow(1, 1)
			rc:add(res_gfx.regentext)
			res_gfx.valtext = core.renderer.text(font_r):shadow(1, 1)
			rc:add(res_gfx.valtext)
		end

		res_gfx.old = {}
		res_gfx.name = rname
		res_gfx.def = res_def
		self.resources_defs[#self.resources_defs+1] = res_gfx

		-- Setup the mouse zone, we update its position later on
		-- DGDGDGDG this somehow borks when moving the UI around ,wtf
		-- self.mouse:registerZone(0, 0, self.rw, self.rh, self:tooltipAll(function() end, res_gfx.tooltip), nil, rname, true, 1)
	end end
end

function _M:getName()
	return "Resources"
end

function _M:getMoveHandleLocation()
	return self.w - self.move_handle_w, 0
end

function _M:getDefaultGeometry()
	local th = 60
	if config.settings.tome.hotkey_icons then th = (19 + config.settings.tome.hotkey_icons_size) * config.settings.tome.hotkey_icons_rows end
	local x = 0
	local y = 150
	local w = self.rw
	local h = self.rh
	return x, y, w, h
end

function _M:getDefaultOrientation()
	return "left"
end

function _M:onSnapChange()
	self.force_reordering = true
end

function _M:move(x, y)
	MiniContainer.move(self, x, y)
	self.force_reordering = true
end

function _M:resize(w, h)
	MiniContainer.resize(self, w, h)
	self.force_reordering = true
end

function _M:toggleFrame()
	self.configs.hide_frame = not self.configs.hide_frame
	for _, res_gfx in ipairs(self.resources_defs) do res_gfx.old = {} end
	self.uiset:saveSettings()
end

function _M:lock(v)
	MiniContainer.lock(self, v)
	if v then
		self.force_reordering = true
	end
end

function _M:forceOrientation(what)
	self.configs.force_orientation = what
	self:onSnapChange()
	self.uiset:saveSettings()
end

function _M:loadConfig(config)
	MiniContainer.loadConfig(self, config)
	self:onSnapChange()
end

function _M:toggleResource(rname)
	local player = self:getPlayer()
	player["_hide_resource_"..rname] = not player["_hide_resource_"..rname]
end

function _M:editMenu()
	local player = self:getPlayer()
	local list = {
		{ name = "Toggle frame", fct=function() self:toggleFrame() end },
		{ name = "Force orientation: natural", fct=function() self:forceOrientation("natural") end },
		{ name = "Force orientation: horizontal", fct=function() self:forceOrientation("horizontal") end },
		{ name = "Force orientation: vertical", fct=function() self:forceOrientation("vertical") end },
	}
	for _, res_gfx in ipairs(self.resources_defs) do
		local res_def = res_gfx.def
		if (not res_def.talent or player:knowTalent(res_def.talent)) and (not res_def.display.shown or res_def.display.shown(player)) then
			table.insert(list, { name="Toggle resource: #GOLD#"..res_gfx.def.name, fct=function() self:toggleResource(res_gfx.name) end })
		end
	end
	return list
end

function _M:getPlayer()
	return game:getPlayer()
end

function _M:update(nb_keyframes)
	local player = self:getPlayer()
	if not player then return end

	local reordering = self.force_reordering
	self.force_reordering = nil

	for _, res_gfx in ipairs(self.resources_defs) do
		local res_def = res_gfx.def
		local rname = res_gfx.name
		if (not res_def.talent or player:knowTalent(res_def.talent)) and (not res_def.display.shown or res_def.display.shown(player)) and not player["_hide_resource_"..rname] then
			-- Display it if new
			if not res_gfx.shown then
				self.do_container:add(res_gfx.container)
				res_gfx.shown = true reordering = true
			end

			-- Compute percent and scale fillbar
			local vc, vn, vm, vr
			if res_def.display.get_values then vc, vn, vm, vr = res_def.display.get_values(player)
			else vc, vn, vm, vr = player[res_def.getFunction](player), player[res_def.getMinFunction](player), player[res_def.getMaxFunction](player), player[res_def.regen_prop]
			end

			if not res_def.display.simple then
				local p = 1 -- proportion of resource bar to display
				if res_gfx.percent_compute then p = res_gfx.percent_compute(player, vc, vn, vm, vr)
				elseif vn and vm then p = math.min(1, math.max(0, vc/vm)) end
				if p ~= res_gfx.old.p then
					res_gfx.fill:tween(7, "scale_x", nil, p)
					res_gfx.old.p = p
				end

				-- Choose which front to use, highlighted or not
				if not self.configs.hide_frame then
					local is_highlight = false
					if res_def.display.highlight then if util.getval(res_def.display.highlight, player, vc, vn, vm, vr) then is_highlight = true end
					elseif vm and vc >= vm * res_def.display.highlight_pct then is_highlight = true end
					if is_highlight ~= res_gfx.old.highlight then
						res_gfx.front:shown(is_highlight)
						res_gfx.front_dark:shown(not is_highlight)
						res_gfx.old.highlight = is_highlight
					end
				else
					if res_gfx.old.highlight ~= "masked" then
						res_gfx.front:shown(false)
						res_gfx.front_dark:shown(false)
						res_gfx.old.highlight = "masked"
					end
				end
			end

			-- Update text
			if vc ~= res_gfx.old.vc or vn ~= res_gfx.old.vn or vm ~= res_gfx.old.vm then
				local status_text = util.getval(res_def.display.status_text, player, vc, vn, vm) or ("%d/%d"):format(vc, vm)
				-- status_text = (status_text):format() -- fully resolve format codes (%%)
				res_gfx.valtext:text(status_text)
				local x, y = res_gfx.fill:getTranslate()
				local w, h = res_gfx.valtext:getStats()
				res_gfx.valtext:translate(x + 15, y + math.floor((self.fh - h) / 2))
				res_gfx.old.vc = vc res_gfx.old.vn = vn res_gfx.old.vm = vm

				-- Update shader
				if res_def.display.shader_update and res_gfx.shader and res_gfx.shader.shad then res_def.display.shader_update(player, res_gfx.shader) end
			end

			-- Update regen text
			if not res_def.display.simple then
				if vr ~= res_gfx.old.vr then
					if vr == 0 then
						res_gfx.regentext:shown(false)
					else
						local status_text = string.limit_decimals(vr, 3, "+")
						res_gfx.regentext:text(status_text)
						local x, y = res_gfx.fill:getTranslate()
						local w, h = res_gfx.regentext:getStats()
						res_gfx.regentext:translate(x + self.fw - w - 19, y + math.floor((self.fh - h) / 2)):shown(true)
					end
					res_gfx.old.vr = vr

					-- Update shader
					if res_def.display.shader_update and res_gfx.shader and res_gfx.shader.shad then res_def.display.shader_update(player, res_gfx.shader) end
				end
			end
		else
			-- Disappear if was shown
			if res_gfx.shown then
				self.do_container:remove(res_gfx.container)
				res_gfx.shown = false reordering = true
			end
		end
	end

	-- Some bars appeared or disappeared, recompute positions for all
	if reordering then
		local down = true
		local what = self.configs.force_orientation
		if not what or what == "natural" then if self.orientation == "down" or self.orientation == "up" then down = false else down = true end
		elseif what == "horizontal" then down = false
		elseif what == "vertical" then down = true
		end

		local x, y = 0, 0
		for _, res_gfx in ipairs(self.resources_defs) do
			if res_gfx.shown then
				res_gfx.container:translate(x, y)
				if self.locked then 
					-- self.mouse:enableZone(res_gfx.name, true)
					-- self.mouse:updateZone(res_gfx.name, x, y, self.rw, self.rh, nil, 1)
				end
				if down then
					y = y + self.rh
					if (y + self.rh) * self.scale > game.h - self.y then
						y = 0
						x = x + self.rw
					end
				else
					x = x + self.rw
					if (x + self.rw) * self.scale > game.w - self.x then
						x = 0
						y = y + self.rh
					end
				end
			else
				if self.locked then 
					-- self.mouse:enableZone(res_gfx.name, false)
				end
			end
		end
		-- self.mouse_zone_w = x + self.rw * self.scale
		-- self.mouse_zone_h = y + self.rh * self.scale
	end
end
