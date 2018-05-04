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

-- Find a random spot
local x, y = game.state:findEventGrid(level)
if not x then return false end

local id = "fearscape-invasion-"..game.turn

print("[EVENT] Placing event", id, "at", x, y)

local changer = function(id)
	local npcs = mod.class.NPC:loadList{"/data/general/npcs/minor-demon.lua", "/data/general/npcs/major-demon.lua"}
	local objects = mod.class.Object:loadList("/data/general/objects/objects.lua")
	local terrains = mod.class.Grid:loadList({"/data/general/grids/basic.lua", "/data/general/grids/void.lua"}, nil, nil, function(e)
		if e.image then e.image = e.image:gsub("^terrain/floating_rocks", "terrain/red_floating_rocks") end
	end)
	terrains.PORTAL_BACK = mod.class.Grid.new{
		type = "floor", subtype = "floor",
		display = "&", color = colors.BLUE,
		name = "portal back to "..game.zone.name,
		image = "terrain/red_floating_rocks05_01.png",
		add_displays = { mod.class.Grid.new{image="terrain/demon_portal3.png"} },
		change_level = 1,
		change_zone = game.zone.short_name,
		change_level_shift_back = true,
		change_zone_auto_stairs = true,
		change_level_check = function(self)
			game.log("#VIOLET# You escape the Fearscape!")
			-- May delete old zone file here?
			return
		end
	}
	local zone = mod.class.Zone.new(id, {
		name = "orbital fearscape platform",
		level_range = game.zone.actor_adjust_level and {math.floor(game.zone:actor_adjust_level(game.level, game.player)*1.05),
			math.ceil(game.zone:actor_adjust_level(game.level, game.player)*1.15)} or {game.zone.base_level, game.zone.base_level}, -- 5-15% higher levels
		__applied_difficulty = true, -- Difficulty already applied to parent zone
		level_scheme = "player",
		max_level = 1,
		actor_adjust_level = function(zone, level, e) return zone.base_level + e:getRankLevelAdjust() + level.level-1 + rng.range(-1,2) end,
		width = 30, height = 30,
		ambient_music = "World of Ice.ogg",
		reload_lists = false,
		projectile_speed_mod = 0.3,
		persistent = "zone",
		
		no_worldport = game.zone.no_worldport,
		min_material_level = util.getval(game.zone.min_material_level),
		max_material_level = util.getval(game.zone.max_material_level),
		effects = {"EFF_ZONE_AURA_FEARSCAPE"},
		generator =  {
			map = {
				class = "engine.generator.map.Cavern",
				zoom = 4,
				min_floor = 400,
				floor = "FLOATING_ROCKS",
				wall = "OUTERSPACE",
				down = "PORTAL_BACK",
				force_last_stair = true,
			},
			actor = {
				class = "mod.class.generator.actor.Random",
				nb_npc = {12, 12},
				guardian = {random_elite={life_rating=function(v) return v * 1.5 + 4 end, name_scheme="#rng# the Invader", on_die=function(self) world:gainAchievement("EVENT_FEARSCAPE", game:getPlayer(true)) end,
				nb_rares=(rng.percent(resolvers.current_level-50) and 5 or 4),
				nb_classes=(rng.percent(resolvers.current_level-50) and 2 or 1)
				}}
			},
			object = {
				class = "engine.generator.object.Random",
				filters = {{type="gem"}},
				nb_object = {6, 9},
			},
			trap = {
				class = "engine.generator.trap.Random",
				nb_trap = {6, 9},
			},
		},
		post_process = function(level)
			local Map = require "engine.Map"
			level.background_particle = require("engine.Particles").new("starfield", 1, {width=Map.viewport.width, height=Map.viewport.height, speed=2000})
		end,
		background = function(level, x, y, nb_keyframes)
			local Map = require "engine.Map"
			local parx, pary = level.map.mx / (level.map.w - Map.viewport.mwidth), level.map.my / (level.map.h - Map.viewport.mheight)
			if level.background_particle then
				level.background_particle.ps:toScreen(x, y, true, 1)
			end

			if not level.tmpdata.planet_renderer then
				local StellarBody = require "mod.class.StellarBody"
				local planettex = core.loader.png("/data/gfx/shockbolt/stars/eyal.png")
				local cloudtex = core.loader.png("/data/gfx/shockbolt/stars/clouds.png")
				local planet = StellarBody.makePlanet(planettex, cloudtex, {160/255, 160/255, 200/255, 0.5}, 600, {planet_time_scale=900000, clouds_time_scale=700000, rotate_angle=math.rad(22), light_angle=math.pi})
				level.tmpdata.planet_renderer = core.renderer.renderer("static"):add(planet)
			end
			level.tmpdata.planet_renderer:toScreen():translate(x + 350 - parx * 60, y + 350 - pary * 60)
		end,
		npc_list = npcs,
		grid_list = terrains,
		object_list = objects,
		trap_list = mod.class.Trap:loadList("/data/general/traps/elemental.lua"),
	})
	return zone
end

local g = game.level.map(x, y, engine.Map.TERRAIN):cloneFull()
g.name = "fearscape invasion portal"
g.always_remember = true
g.show_tooltip = true
g.display='&' g.color_r=0 g.color_g=0 g.color_b=255 g.notice = true
g.special_minimap = colors.VIOLET
g.change_level=1 g.change_zone=id g.glow=true
g:removeAllMOs()
if engine.Map.tiles.nicer_tiles then
	g.add_displays = g.add_displays or {}
	g.add_displays[#g.add_displays+1] = mod.class.Grid.new{image="terrain/demon_portal3.png"}
end
g.grow = nil g.dig = nil
g.nice_tiler = nil
g:altered()
g:initGlow()
g.special = true
g.real_change = changer
g.break_portal = function(self)
	self.broken = true
	game.log("#VIOLET#The portal is broken!")
	self.name = "broken fearscape invasion portal"
	self.change_level = nil
	self.autoexplore_ignore = true
	self.show_tooltip = false
end
g.change_level_check = function(self)
	self:break_portal()
	game:changeLevel(1, self.real_change(self.change_zone), {temporary_zone_shift=true, direct_switch=true})
	game.player:attr("planetary_orbit", 1)
	return true
end
g.on_move = function(self, x, y, who, act, couldpass)
	if not who or not who.player then return false end
	if self.broken then
		game.log("#VIOLET#The portal is already broken!")
		return false
	end

	require("engine.ui.Dialog"):yesnoPopup("Fearscape Portal", "Do you wish to enter the portal, destroy it, or ignore it (press escape)?", function(ret)
		if ret == "Quit" then
			game.log("#VIOLET#Ignoring the portal...")
			return
		end
		if not ret then
			self:change_level_check()
		else self:break_portal()
		end
	end, "Destroy", "Enter", false, "Quit")
	
	return false
end

game.zone:addEntity(game.level, g, "terrain", x, y)

local respawn = function(self)
	local portal = game.level.map(self.fearscape_portal_x, self.fearscape_portal_y, engine.Map.TERRAIN)
	if not portal or portal.broken then return end

	local npcs = mod.class.NPC:loadList{"/data/general/npcs/major-demon.lua"}
	local m = game.zone:makeEntity(game.level, "actor", {base_list=npcs}, nil, true)
	if not m then return end

	local adjacent = util.adjacentCoords(self.fearscape_portal_x, self.fearscape_portal_y)
	adjacent[5] = {self.fearscape_portal_x, self.fearscape_portal_y}

	repeat
		local grid = rng.tableRemove(adjacent)
		if m:canMove(grid[1], grid[2]) then
			m.fearscape_portal_x = self.fearscape_portal_x
			m.fearscape_portal_y = self.fearscape_portal_y
			m.fearscape_respawn = self.fearscape_respawn
			m.exp_worth = 0
			m.no_drops = true
			m.ingredient_on_death = nil
			m.faction = "fearscape"
			m.on_die = function(self) self:fearscape_respawn() end
			game.zone:addEntity(game.level, m, "actor", grid[1], grid[2])
			game.logSeen(m, "#VIOLET#A demon steps out of the %s!", portal.name)
			break
		end
	until #adjacent <= 0
end

-- Spawn two demons that will keep on being replenished
local base = {fearscape_portal_x=x, fearscape_portal_y=y, fearscape_respawn=respawn}
respawn(base)
respawn(base)

return x, y
