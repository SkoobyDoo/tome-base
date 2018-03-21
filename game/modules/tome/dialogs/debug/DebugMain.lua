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
require "engine.ui.Dialog"
local List = require "engine.ui.List"
local GetQuantity = require "engine.dialogs.GetQuantity"

module(..., package.seeall, class.inherit(engine.ui.Dialog))

function _M:init()
	self:generateList()
	engine.ui.Dialog.init(self, "Debug/Cheat! It's BADDDD!", 1, 1)

	local list = List.new{width=400, height=500, list=self.list, fct=function(item) self:use(item) end}

	self:loadUI{
		{left=0, top=0, ui=list},
	}
	self:setupUI(true, true)

	self.key:addCommands{ __TEXTINPUT = function(c) if self.list and self.list.chars[c] then self:use(self.list[self.list.chars[c]]) end end}
	self.key:addBinds{ EXIT = function() game:unregisterDialog(self) end, }
end

function _M:on_register()
	game:onTickEnd(function() self.key:unicodeInput(true) end)
end

function _M:use(item)
	if not item then return end
	game:unregisterDialog(self)

	if item.dialog then
		package.loaded["mod.dialogs.debug."..item.dialog] = nil
		local d = require("mod.dialogs.debug."..item.dialog).new(item)
		game:registerDialog(d)
		return
	end

	local act = item.action

	local stop = false
	if act == "godmode" then
		if game.player:hasEffect(game.player.EFF_GODMODE) then
			game.player:removeEffect(game.player.EFF_GODMODE, false, true)
			game.log("#LIGHT_BLUE#God mode OFF")
		else
			game.player:setEffect(game.player.EFF_GODMODE, 1, {})
			game.log("#LIGHT_BLUE#God mode ON")
		end
	elseif act == "demigodmode" then
		if game.player:hasEffect(game.player.EFF_DEMI_GODMODE) then
			game.player:removeEffect(game.player.EFF_DEMI_GODMODE, false, true)
			game.log("#LIGHT_BLUE#Demi-God mode OFF")
		else
			game.player:setEffect(game.player.EFF_DEMI_GODMODE, 1, {})
			game.log("#LIGHT_BLUE#Demi-God mode ON")
		end
	elseif act == "weakdamage" then
		game.player.inc_damage.all = -90
	elseif act == "magic_map" then
		game.log("#LIGHT_BLUE#Revealing Map.")
		game.level.map:liteAll(0, 0, game.level.map.w, game.level.map.h)
		game.level.map:rememberAll(0, 0, game.level.map.w, game.level.map.h)
		for i = 0, game.level.map.w - 1 do
			for j = 0, game.level.map.h - 1 do
				local trap = game.level.map(i, j, game.level.map.TRAP)
				if trap then
					trap:setKnown(game.player, true) trap:identify(true)
					game.level.map:updateMap(i, j)
				end
			end
		end
	elseif act == "change_level" then
		game:registerDialog(GetQuantity.new("Zone: "..game.zone.name, "Level 1-"..game.zone.max_level, game.level.level, game.zone.max_level, function(qty)
			game:changeLevel(qty)
		end), 1)
	elseif act == "shertul-energy" then
		game.player:grantQuest("shertul-fortress")
		game.player:hasQuest("shertul-fortress"):gain_energy(1000)
	elseif act == "all_traps" then
		for _, file in ipairs(fs.list("/data/general/traps/")) do if file:find(".lua$") then
			local list = mod.class.Trap:loadList("/data/general/traps/"..file)
			for i, e in ipairs(list) do
				print("======",e.name,e.rarity)
				if e.rarity then
					local trap = game.zone:finishEntity(game.level, "trap", e)
					trap:setKnown(game.player, true) trap:identify(true)
					local x, y = util.findFreeGrid(game.player.x, game.player.y, 20, true, {[engine.Map.TRAP]=true})
					if x then
						game.zone:addEntity(game.level, trap, "trap", x, y)
					end
				end
			end
		end end
	elseif act == "remove-all" then
		local d = require"engine.ui.Dialog":yesnocancelPopup("Kill or Remove", "Remove all (non-party) creatures or kill them for the player (awards experience and drops loot)?",
			function(remove_all, escape)
				if escape then return end
				local l = {}
				for uid, e in pairs(game.level.entities) do
					if e.__is_actor and not game.party:hasMember(e) then l[#l+1] = e end
				end
				local count = 0
				for i, e in ipairs(l) do
					if remove_all then
						game.log("#GREY#Removing [%s] %s at (%s, %s)", e.uid, e.name, e.x, e.y)
						game.level:removeEntity(e)
					else
						game.log("#GREY#Killing [%s] %s at (%s, %s)", e.uid, e.name, e.x, e.y)
						e:die(game.player, "By Cheating!")
					end
					count = count + 1
				end
				game.log("#LIGHT_BLUE#%s %d creatures.", remove_all and "Removed" or "Killed", count)
			end
		, "Remove", "Kill", "Cancel", false)
	elseif act == "all-ingredients" then
		game.party:giveAllIngredients(100)
		-- Gems count too
		for def, od in pairs(game.zone.object_list) do
			if type(def) == "string" and not od.unique and od.rarity and def:find("^GEM_") then
				local o = game.zone:finishEntity(game.level, "object", od)
				o:identify(true)
				game.player:addObject("INVEN", o)
				game.player:sortInven()
			end
		end
	elseif act == "endgamify" then
		local NPC = require "mod.class.NPC"
		local Chat = require "engine.Chat"
		if game.player.endgamified then return end
		game.player.endgamified = true
		game.player.unused_generics = game.player.unused_generics + 2  -- Derth quest
		game.player:learnTalent(game.player.T_RELENTLESS_PURSUIT, 1)
		game.player:forceLevelup(50)
		game.player.money = 999999

		self:makeEndgameItems()
		self:makeEndgameFixed()

		game.state:goneEast()
		game.player:grantQuest("lost-merchant")
		game.player:setQuestStatus("lost-merchant", engine.Quest.COMPLETED, "saved")

		-- Change the zone name each iteration so the quest id is different
		local old_name = game.zone.short_name
		for i = 1,5 do
			game.zone.short_name = game.zone.short_name..i
			game.player:grantQuest("escort-duty")
			for _, e in pairs(game.level.entities) do
				if e.quest_id then
					-- Make giving the reward their first action so it happens after the dialogs are closed
					e.act = function(self)
						self.on_die = nil
						game.player:setQuestStatus(self.quest_id, engine.Quest.DONE)
						local Chat = require "engine.Chat"
						Chat.new("escort-quest", self, game.player, {npc=self}):invoke()
						self:disappear()
						self:removed()
						game.party:removeMember(self, true)
					end
				end
			end
			game.zone.short_name = old_name
		end
	else
		self:triggerHook{"DebugMain:use", act=act}
	end
end

-- {Rares, Randarts}
local endgame_items = {
	["voratun helm"] = {10,3},
	["voratun gauntlets"] = {5,2},
	["drakeskin leather gloves"] = {5,2},
	["voratun ring"] = {10,3},
	["voratun amulet"] = {5,2},
	["voratun mail armour"] = {5,4},
	["voratun plate armour"] = {5,4},
	["voratun helm"] = {10,3},
	["elven-silk cloak"] = {10,3},
	["dragonbone totem"] = {5,2},
	["voratun torque"] = {5,2},
	["dragonbone wand"] = {5,2},
	["voratun helm"] = {10,3},
	["voratun pickaxe"] = {5,2},
	["dwarven lantern"] = {5,2},
	["pair of drakeskin leather boots"] = {10,3},
	["drakeskin leather belt"] = {10,3},
}

local endgame_class_items = {
	["Anorithil"] = {["dragonbone staff"] = {10,3}, ["elven-silk robe"] = {5,4},},
	["Sun Paladin"] = {	["voratun longsword"] = {10,3},	["voratun greatsword"] = {10,3}, ["voratun shield"] = {10,3} },	
		
	["Cursed"] = {	["voratun longsword"] = {10,3}, ["voratun greatsword"] = {10,3}, ["living mindstar"] = {10,3}},	
	["Doomed"] = {["living mindstar"] = {10,3}},	
	
	["Temporal Warden"] = {["voratun longsword"] = {10,3}, ["voratun dagger"] = {10,3}, ["quiver of dragonbone arrows"] = {10,3}, ["dragonbone longbow"] = {10,3},},
	["Paradox Mage"] = {["dragonbone staff"] = {10,3}, ["elven-silk robe"] = {5,4},},

	["Corruptor"] = {["dragonbone staff"] = {10,3}, ["elven-silk robe"] = {5,4},},
	["Reaver"] = {["dragonbone staff"] = {10,3}, ["elven-silk robe"] = {5,4}, ["voratun longsword"] = {10,3},},

	["Alchemist"] = {["dragonbone staff"] = {10,3}, ["elven-silk robe"] = {5,4},},
	["Archmage"] = {["dragonbone staff"] = {10,3}, ["elven-silk robe"] = {5,4},},
	["Necromancer"] = {["dragonbone staff"] = {10,3}, ["elven-silk robe"] = {5,4},},

	["Mindslayer"] = {["voratun greatsword"] = {10,3}, ["living mindstar"] = {10,3}},
	["Solipsist"] = {["living mindstar"] = {10,3}},

	["Rogue"] = {["voratun longsword"] = {10,3}, ["voratun dagger"] = {10,3}, ["drakeskin leather armour"] = {5,4},},
	["Shadowblade"] = {["voratun longsword"] = {10,3}, ["voratun dagger"] = {10,3}, ["drakeskin leather armour"] = {5,4}, },
	["Skirmisher"] = {["pouch of voratun shots"] = {10,3}, ["drakeskin leather sling"] = {10,3}, ["drakeskin leather armour"] = {5,4},},
	["Marauder"] = {["voratun longsword"] = {10,3}, ["drakeskin leather armour"] = {5,4}, ["voratun dagger"] = {10,3}},

	["Arcane Blade"] = {["dragonbone staff"] = {10,3}, ["voratun longsword"] = {10,3}, ["voratun greatsword"] = {10,3}, ["voratun shield"] = {10,3}, ["voratun dagger"] = {10,3}},
	["Brawler"] = {["drakeskin leather armour"] = {5,4}, },
	["Bulwark"] = {["voratun longsword"] = {10,3}, ["voratun shield"] = {10,3}},
	["Berserker"] = {["voratun greatsword"] = {10,3}},
	["Archer"] = {["quiver of dragonbone arrows"] = {10,3}, ["pouch of voratun shots"] = {10,3}, ["dragonbone longbow"] = {10,3}, ["drakeskin leather sling"] = {10,3}, ["drakeskin leather armour"] = {5,4}, },

	["Summoner"] = {["living mindstar"] = {10,3}},
	["Oozemancer"] = {["living mindstar"] = {10,3}},
	["Wyrmic"] = {["voratun longsword"] = {10,3}, ["voratun greatsword"] = {10,3}, ["voratun shield"] = {10,3}, ["living mindstar"] = {10,3}},
	["Stone Warden"] = {["voratun shield"] = {10,3}},

	["Other"] = {
			["dragonbone staff"] = {10,3}, ["voratun longsword"] = {10,3}, ["dragonbone longbow"] = {10,3}, ["pouch of voratun shots"] = {10,3}, ["drakeskin leather armour"] = {5,4},
			["drakeskin leather sling"] = {10,3}, ["voratun greatsword"] = {10,3}, ["voratun shield"] = {10,3}, ["living mindstar"] = {10,3}, ["voratun dagger"] = {10,3}, 
			["quiver of dragonbone arrows"] = {10,3},
		},  -- We don't know what we want, so create everything
}

-- Fixedarts from quests or things that we can assume experienced players almost always get
local endgame_fixed_artifacts= {"ORB_ELEMENTS", "ORB_UNDEATH", "ORB_DESTRUCTION", "ORB_DRAGON", "RUNE_DISSIPATION", "INFUSION_WILD_GROWTH", "TAINT_PURGING", "RING_OF_BLOOD", "ELIXIR_FOUNDATIONS",
								"SANDQUEEN_HEART", "PUTRESCENT_POTION", "ELIXIR_FOCUS", "MUMMIFIED_EGGSAC", "ORB_MANY_WAYS", "ROD_SPYDRIC_POISON" }
function _M:makeEndgameItems(class, ilvl, filter)
	local class_name = game.player.descriptor.subclass
	local items = table.merge(table.clone(endgame_items), table.clone(endgame_class_items[class_name] or endgame_class_items["Other"]))
	for base, amounts in pairs(items) do
		table.print(amounts)
		for i = 1, amounts[2] do
			local base_object = game.zone:makeEntity(game.level, "object", {name=base, ignore_material_restriction=true, ego_filter={keep_egos=true, ego_chance=-1000}}, nil, true)

			local filter = {base=base_object, material_level = 5, lev=60}
			local item = game.state:generateRandart(filter)
			item.__transmo = true		
			item:identify(true)
			game.zone:addEntity(game.level, item, "object")
			game.player:addObject(game.player:getInven("INVEN"), item)
		end
		-- Create rares
		for i = 1, amounts[1] do
			local base_object = game.zone:makeEntity(game.level, "object", {name=base, ignore_material_restriction=true, ego_filter={keep_egos=true, ego_chance=-1000}}, nil, true)
			local filter = {base=base_object, lev=60, egos=1, material_level = 5, greater_egos_bias = 0, power_points_factor = 3, nb_powers_add = 2, }
			local item = game.state:generateRandart(filter)
			item.unique, item.randart, item.rare = nil, nil, true
			item.__transmo = true		
			item:identify(true)
			game.zone:addEntity(game.level, item, "object")
			game.player:addObject(game.player:getInven("INVEN"), item)
		end

	end
	return 
end

function _M:makeEndgameFixed()
	local Object = require "mod.class.Object"

	local old_list = game.zone.object_list
	local obj_list = table.clone(game.zone.object_list, true)
	obj_list.ignore_loaded = true

	-- protected load of objects from a file
	local function load_file(file, obj_list)
		local ok, ret = xpcall(function()
			Object:loadList(file, false, obj_list, nil, obj_list.__loaded_files)
			end, debug.traceback)
		if not ok then
			game.log("#ORANGE# Create Object: Unable to load all objects from file %s:#GREY#\n %s", file, ret)
		end
	end
	-- load all objects from a base directory
	local function load_objects(base)
		local file
		file = base.."/general/objects/objects.lua"
		if fs.exists(file) then load_file(file, obj_list) end

		file = base.."/general/objects/world-artifacts.lua"
		if fs.exists(file) then load_file(file, obj_list) end

		file = base.."/general/objects/boss-artifacts.lua"
		if fs.exists(file) then load_file(file, obj_list) end

		file = base.."/general/objects/quest-artifacts.lua"
		if fs.exists(file) then load_file(file, obj_list) end
		
		file = base.."/general/objects/brotherhood-artifacts.lua"
		if fs.exists(file) then load_file(file, obj_list) end

		if fs.exists(file) then load_file(file, obj_list) end
		for i, dir in ipairs(fs.list(base.."/zones/")) do
			file = base.."/zones/"..dir.."/objects.lua"
			if dir ~= game.zone.short_name and fs.exists(file) and not dir:find("infinite%-dungeon") and not dir:find("noxious%-caldera") then
				load_file(file, obj_list)
			end
		end
	end
	
	-- load base global and zone objects
	load_objects("/data", "")

	-- load all objects defined by addons (in standard directories)
	for i, dir in ipairs(fs.list("/")) do
		local _, _, addon = dir:find("^data%-(.+)$")
		if addon then
			load_objects("/"..dir)
		end
	end
	game.zone.object_list = obj_list
	for _, name in pairs(endgame_fixed_artifacts) do
			local o = game.zone:makeEntityByName(game.level, "object", name)
			if not o then game.log("Failed to generate "..name) break end
			o:identify(true)
			game.zone:addEntity(game.level, o, "object")
			game.player:addObject(game.player:getInven("INVEN"), o)
	end
	game.zone.object_list = old_list
end
		
-- Ideas:
-- force reload all shops
function _M:generateList()
	local list = {}

	list[#list+1] = {name="Change Zone", dialog="ChangeZone"}
	list[#list+1] = {name="Change Level", action="change_level"}
	list[#list+1] = {name="Reveal all map", action="magic_map"}
	list[#list+1] = {name="Toggle Demi-Godmode", action="demigodmode"}
	list[#list+1] = {name="Toggle Godmode", action="godmode"}
	list[#list+1] = {name="Alter Faction", dialog="AlterFaction"}
	list[#list+1] = {name="Summon a Creature", dialog="SummonCreature"}
	list[#list+1] = {name="Create Items", dialog="CreateItem"}
	list[#list+1] = {name="Create a Trap", dialog="CreateTrap"}
	list[#list+1] = {name="Grant/Alter Quests", dialog="GrantQuest"}
	list[#list+1] = {name="Advance Player", dialog="AdvanceActor"}
	list[#list+1] = {name="Remove or Kill all creatures", action="remove-all"}
	list[#list+1] = {name="Give Sher'tul fortress energy", action="shertul-energy"}
	list[#list+1] = {name="Give all ingredients", action="all-ingredients"}
	list[#list+1] = {name="Weakdamage", action="weakdamage"}
	list[#list+1] = {name="Endgamify", action="endgamify"}
	self:triggerHook{"DebugMain:generate", menu=list}

	local chars = {}
	for i, v in ipairs(list) do
		v.name = self:makeKeyChar(i)..") "..v.name
		chars[self:makeKeyChar(i)] = i
	end
	list.chars = chars

	self.list = list
end
