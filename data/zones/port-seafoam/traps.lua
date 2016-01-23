-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2015 Nicolas Casalini
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

load("/data/general/traps/store.lua")

newEntity{ base = "BASE_STORE", define_as = "HEAVY_ARMOR_STORE",
	name="Finest Heavy Plates",
	display='2', color=colors.UMBER,
	resolvers.store("HEAVY_ARMOR", "allied-kingdoms", "store/shop_door.png", "store/shop_sign_hormond_sons.png"),
}

newEntity{ base = "BASE_STORE", define_as = "LIGHT_ARMOR_STORE",
	name="Sarisa's Sturdy Leatherwork",
	display='2', color=colors.UMBER,
	resolvers.store("LIGHT_ARMOR", "allied-kingdoms", "store/shop_door.png", "store/shop_sign_rilas_leather.png"),
}

newEntity{ base = "BASE_STORE", define_as = "HERBALIST",
	name="Shoreside Herbs and Infusions",
	display='4', color=colors.LIGHT_GREEN,
	resolvers.store("POTION", "allied-kingdoms", "store/shop_door.png", "store/shop_sign_saras_herbal_infusions.png"),
}

newEntity{ base = "BASE_STORE", define_as = "RUNES",
	name="Runemaster Vharn",
	display='5', color=colors.LIGHT_RED,
	resolvers.store("SCROLL", "allied-kingdoms", "store/shop_door.png", "store/shop_sign_runemaster.png"),
}

-- give this one a matching icon
newEntity{ base = "BASE_STORE", define_as = "TRIDENT_STORE",
	name="Toran's Terrific Tridents",
	display='3', color=colors.UMBER,
	resolvers.store("PORT_TRIDENTS", "allied-kingdoms", "store/shop_door.png", "store/shop_sign_vortals_trees.png"),
	resolvers.chatfeature("naloren-weapon-store", "allied-kingdoms"),
}

newEntity{ base = "BASE_STORE", define_as = "WEAPON_STORE",
	name = "Ranek's Armory",
	display='3', color=colors.UMBER,
	resolvers.store("PORT_WEAPONS", "allied-kingdoms", "store/shop_door.png", "store/shop_sign_vortals_trees.png"),
	resolvers.chatfeature("naloren-weapon-store", "allied-kingdoms"),
}