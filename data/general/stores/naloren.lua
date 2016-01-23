-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
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

newEntity{
	define_as = "PORT_TRIDENTS",
	name = "trident smith",
	display = '3', color=colors.UMBER,
	store = {
		purse = 25,
		empty_before_restock = false,
		filters = {
			{type="weapon", subtype="trident", id=true, tome_drops="store", special_rarity="trident_rarity"},
		},
	},
}

newEntity{
	define_as = "PORT_WEAPONS",
	name = "weapon smith",
	display = '3', color=colors.UMBER,
	store = {
		purse = 25,
		empty_before_restock = false,
		filters = {
			{type="weapon", subtype="waraxe", id=true, tome_drops="store"},
			{type="weapon", subtype="battleaxe", id=true, tome_drops="store"},
			{type="weapon", subtype="longsword", id=true, tome_drops="store"},
			{type="weapon", subtype="greatsword", id=true, tome_drops="store"},
			{type="weapon", subtype="mace", id=true, tome_drops="store"},
			{type="weapon", subtype="greatmaul", id=true, tome_drops="store"},
			{type="weapon", subtype="dagger", id=true, tome_drops="store"},
		},
	},
}