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

defineTile(".", "JUNGLE_GRASS")
defineTile("t", "JUNGLE_TREE")
defineTile("#", "HARDWALL")
defineTile("~", "DEEP_OCEAN_WATER")
defineTile(",", "SAND")
defineTile("_", "OLD_FLOOR")
defineTile("<", "HARBOR_UP")


defineTile("1", "HARDWALL", nil, nil, "LIGHT_ARMOR_STORE")
defineTile("2", "HARDWALL", nil, nil, "HEAVY_ARMOR_STORE")
defineTile("3", "HARDWALL", nil, nil, "TRIDENT_STORE")
defineTile("4", "HARDWALL", nil, nil, "WEAPON_STORE")
defineTile("5", "HARDWALL", nil, nil, "HERBALIST")
defineTile("6", "HARDWALL", nil, nil, "RUNES")

return [[
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~_~~~~~~~~~~~~~~_~~~~~~~~~~
~~~~~~~~~~_~~~~~~~~~~~~~~_~~~~~~~~~~
~~~~~~~~~~_~~~~~~~~~~~~~~_~~~~~~~~~~
~~~~~~~~~~_~~~~~~~~~~~~~~_~~~~~~~~~~
~~~~~~~~~~_~~~~~~~~~~~~~~_~~~~~~~~~~
~~~~~~~~~~_~~~~~~~~~~~~~~_~~~~~~~~~~
~~~~~~,,_____,,~~~~~~,,_____,,~~~~~~
,,,,,,,_______,,,,,,,,_______,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,###,,,,,,,,,,,,,,,,,###,,,,,,,,,
,,,,###,,,,,,,,###,,,,,,###,,,,,,,,,
,,,,#2#,,,,,,,,###,,,,,,#4#,,,,,,,,,
,,,,,,,,,,,,,,,#1#,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,###,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,###,,,,,,,,,###,,,,,,,,,,,,
,,,,,,,,,#3#,,,,,,,,,###,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,#6#,,,,,,,,,,,,
,,,,,,,,,,,,,,###,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,###,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,#5#,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,
<,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,]]