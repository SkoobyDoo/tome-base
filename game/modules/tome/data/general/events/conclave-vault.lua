-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2014 Nicolas Casalini
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

local Talents = require("engine.interface.ActorTalents")

local skeletons = mod.class.NPC:loadList("/data/general/npcs/skeleton.lua")
local m = mod.class.NPC:fromBase{ base = skeletons.BASE_NPC_SKELETON,
	name = "Director Hompalan", color=colors.PURPLE,
	desc = [[Only crumbling bones are left of what once was the proud Director Hompalan, chief of this facility.
Now those remains look at you with empty eyes but you can not mistake their intent.]],
	level_range = {10, nil}, exp_worth = 2,
	rank = 3.5,
	autolevel = "warriormage",
	max_life = 100, life_rating = 13,
	open_door = 1,

	ai = "tactical", ai_state = { talent_in=1, ai_move="move_astar", },

	body = { INVEN = 10, MAINHAND=1, OFFHAND=1, BODY=1, QUIVER=1, FINGER=1 },

	resolvers.equip{
		{type="weapon", subtype="longsword", autoreq=true, force_drop=true, forbid_power_source={antimagic=true}, tome_drops="boss"},
		{type="armor", subtype="shield", autoreq=true, force_drop=true, forbid_power_source={antimagic=true}, tome_drops="boss"},
		{type="armor", subtype="light", autoreq=true, force_drop=true, forbid_power_source={antimagic=true}, tome_drops="boss"},
	},
	resolvers.drops{chance=100, nb=1, {defined="DIRECTOR_HOMPALAN_ORDER"} },

	resolvers.talents{
		[Talents.T_WEAPON_COMBAT]={base=1, every=10, max=4},
		[Talents.T_WEAPONS_MASTERY]={base=1, every=10, max=4},
		[Talents.T_ARCANE_COMBAT]={base=2, every=10, max=4},
		[Talents.T_ARCANE_FEED]={base=1, every=10, max=4},
		[Talents.T_ARCANE_DESTRUCTION]={base=1, every=10, max=4},
		[Talents.T_HEAL]={base=1, every=10, max=5},
		[Talents.T_DIRTY_FIGHTING]={base=1, every=10, max=4},
		[Talents.T_FLAME]={base=1, every=10, max=4},
		[Talents.T_EARTHEN_MISSILES]={base=1, every=10, max=4},
		[Talents.T_EARTHEN_BARRIER]={base=1, every=10, max=4},
		[Talents.T_BATTLE_CALL]={base=1, every=10, max=4},
	},
	resolvers.inscriptions(1, {"manasurge rune"}),
	resolvers.inscriptions(2, "rune"),

	resolvers.sustains_at_birth(),

}
m:resolve() m:resolve(nil, true)
game.zone:addEntity(game.level, m, "actor", x, y)

-- level.data.on_enter_list.conclave_vault = function()
-- 	if game.level.data.conclave_vault_added then return end
-- 	if game:getPlayer(true).level < 18 then return end

-- 	local spot = game.level:pickSpot{type="world-encounter", subtype="conclave-vault"}
-- 	if not spot then return end

-- 	game.level.data.conclave_vault_added = true
-- 	local g = game.level.map(spot.x, spot.y, engine.Map.TERRAIN):cloneFull()
-- 	g.name = "Door to an abandonned vault"
-- 	g.display='>' g.color_r=100 g.color_g=0 g.color_b=255 g.notice = true
-- 	g.change_level=1 g.change_zone="conclave-vault" g.glow=true
-- 	g.add_displays = g.add_displays or {}
-- 	g.add_displays[#g.add_displays+1] = mod.class.Grid.new{image="terrain/dungeon_entrance02.png", z=5}
-- 	g:altered()
-- 	g:initGlow()
-- 	game.zone:addEntity(game.level, g, "terrain", spot.x, spot.y)
-- 	print("[WORLDMAP] conclave vault at", spot.x, spot.y)
-- 	require("engine.ui.Dialog"):simplePopup("WRITE ME", "YES INDEED")
-- end

return true
