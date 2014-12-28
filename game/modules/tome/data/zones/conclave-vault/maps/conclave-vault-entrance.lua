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

startx = 15
starty = 8
endx = 0
endy = 8

-- defineTile section
defineTile("#", "HARDWALL")
defineTile("*", "GUARDING_DOOR")
defineTile("<", "FLAT_UP6")
defineTile("O", "FLOOR", nil, "OGRE_SENTRY2")
defineTile("o", "FLOOR", nil, "OGRE_SENTRY")
defineTile(">", "FLAT_DOWN4")
defineTile(".", "FLOOR")

-- addSpot section

-- addZone section

-- ASCII map section
return [[
################
################
################
################
################
################
########.O######
########..######
>..............<
########..######
########.o######
################
################
################
################
################]]