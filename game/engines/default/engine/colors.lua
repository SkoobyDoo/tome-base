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

---  Implements string->Color functionality, and allows the definition of colors  
-- Defines numerous colors by default
-- @script engine.colors

if core.colors then core.colors.reset() end
colors = {}
colors_simple = {}
colors_simple1 = {}
colors_alphaf = {}
colors_alphafs = {}

--- Define Color
-- @string name
-- @int r foreground red
-- @int g foreground green
-- @int b foreground blue
-- @int br background red
-- @int bg background green
-- @int bb background blue
function defineColor(name, r, g, b, br, bg, bb)
	colors[name] = {r=r, g=g, b=b, br=br, bg=bg, bb=bb}
	colors_simple[name] = {r, g, b}
	local r1, g1, b1 = r/255, g/255, b/255
	colors_simple1[name] = {r1, g1, b1, 1}
	colors_alphaf[name] = function(a) return {r1, g1, b1, a} end
	colors_alphafs[name] = function(a) return r1, g1, b1, a end
	if core.colors then core.colors.define256(name, r, g, b, 255) end
end

--- color -> foreground table
-- @param[type=table] c color
-- @return {r, g, b}
function colors.simple(c) return {c.r, c.g, c.b} end
--- Does: color{r,g,b} / 255
-- @param[type=table] c color
-- @number[opt=1] a transparency
function colors.simple1(c, a) return {c.r/255, c.g/255, c.b/255, a or 1} end

--- color -> foreground arguments
-- @param[type=table] c
-- @return r
-- @return g
-- @return b
function colors.unpack(c) return c.r, c.g, c.b end

--- color -> foreground arguments
-- @param[type=table] c
-- @return r
-- @return g
-- @return b
function colors.unpack1(c, a) return c.r/255, c.g/255, c.b/255, a or 1 end

--- hex -> color
-- @usage colors.hex1("FFBBCC")
-- @string hex RRGGBB format hex string, 00->FF
-- @return {r, g, b}
function colors.hex1(hex)
	local r, g, b = tonumber("0x"..hex:sub(1, 2)), tonumber("0x"..hex:sub(3, 4)), tonumber("0x"..hex:sub(5, 6))
	return {r / 255, g / 255, b / 255}
end

--- hex -> color
-- @usage colors.hex1unpack("FFBBCC")
-- @string hex RRGGBB format hex string, 00->FF
-- @return r
-- @return g
-- @return b
function colors.hex1unpack(hex)
	return tonumber("0x"..hex:sub(1, 2)) / 255, tonumber("0x"..hex:sub(3, 4)) / 255, tonumber("0x"..hex:sub(5, 6)) / 255
end

--- hex -> color with alpha
-- @usage colors.hex1alpha("FFBBCC88")
-- @string hex RRGGBB format hex string, 00->FF
-- @return {r, g, b, a}
function colors.hex1alpha(hex)
	local r, g, b, a = tonumber("0x"..hex:sub(1, 2)), tonumber("0x"..hex:sub(3, 4)), tonumber("0x"..hex:sub(5, 6)), tonumber("0x"..hex:sub(7, 8)) or 255
	return {r / 255, g / 255, b / 255, a / 255}
end

--- hex -> color with alpha
-- @usage colors.hex1alpha("FFBBCC88")
-- @string hex RRGGBB format hex string, 00->FF
-- @return r
-- @return g
-- @return b
-- @return a
function colors.hex1alphaunpack(hex)
	return tonumber("0x"..hex:sub(1, 2)) / 255, tonumber("0x"..hex:sub(3, 4)) / 255, tonumber("0x"..hex:sub(5, 6)) / 255, (tonumber("0x"..hex:sub(7, 8)) or 255) / 255
end

--- Tries to detect the format (.r.g.b or []) and the range (255 or 1) and normalize it to a [] format of range 1
-- Note that if you try to use a very light grey like 1,1,1 in a 255 color range, it'll be confused for bright white
-- @return r
-- @return g
-- @return b
-- @return a
function colors.smart1unpack(color)
	if type(color) == "string" then
		if colors[color] then return colors.unpack1(colors[color])
		else return colors.hex1alphaunpack(color)
		end
	end
	if color[1] then
		if math.max(color[1], color[2], color[3]) > 1 then
			return color[1] / 255, color[2] / 255, color[3] / 255, (color[4] or 255) / 255
		else
			return color[1], color[2], color[3], color[4] or 1
		end
	elseif color.r then
		if math.max(color.r, color.g, color.b) > 1 then
			return color.r / 255, color.g / 255, color.b / 255, (color.a or 255) / 255
		else
			return color.r, color.g, color.b, color.a or 1
		end
	else
		table.print(color)
		error("Color is neither .r.g.b or [] format")
	end
end

--- Tries to detect the format (.r.g.b or []) and the range (255 or 1) and normalize it to a [] format of range 1
-- Note that if you try to use a very light grey like 1,1,1 in a 255 color range, it'll be confused for bright white
-- @return {r, g, b, a}
function colors.smart1(color)
	return {colors.smart1unpack(color)}
end

function colors.lerp(a, b, x)
	local lerp = util.lerp
	return { lerp(a.r/255, b.r/255, x), lerp(a.g/255, b.g/255, x), lerp(a.b/255, b.b/255, x) }
end

defineColor('BLACK', 0, 0, 0)
defineColor('WHITE', 0xFF, 0xFF, 0xFF)
defineColor('SLATE', 0x8C, 0x8C, 0x8C)
defineColor('ORANGE', 0xFF, 0x77, 0x00)
defineColor('RED', 0xC9, 0x00, 0x00)
defineColor('GREEN', 0x00, 0x86, 0x45)
defineColor('BLUE', 0x00, 0x00, 0xE3)
defineColor('UMBER', 0x8E, 0x45, 0x00)
defineColor('LIGHT_DARK', 0x50, 0x50, 0x50)
defineColor('LIGHT_SLATE', 0xD1, 0xD1, 0xD1)
defineColor('VIOLET', 0xC0, 0x00, 0xAF)
defineColor('YELLOW', 0xFF, 0xFF, 0x00)
defineColor('LIGHT_RED', 0xFF, 0x00, 0x68)
defineColor('LIGHT_GREEN', 0x00, 0xFF, 0x00)
defineColor('LIGHT_BLUE', 0x51, 0xDD, 0xFF)
defineColor('LIGHT_UMBER', 0xD7, 0x8E, 0x45)
defineColor('DARK_UMBER', 0x57, 0x5E, 0x25)

defineColor('DARK_GREY', 67, 67, 67)
defineColor('GREY', 127, 127, 127)

defineColor('AQUAMARINE', 127, 255, 212)
defineColor('CADET_BLUE', 95, 158, 160)
defineColor('STEEL_BLUE', 70, 130, 180)
defineColor('TEAL', 0, 128, 128)
defineColor('LIGHT_STEEL_BLUE', 176, 196, 222)
defineColor('DARK_BLUE', 0x00, 0x00, 0x93)
defineColor('ROYAL_BLUE', 0x00, 0x6C, 0xFF)

defineColor('PINK', 255, 192, 203)
defineColor('GOLD', 255, 215, 0)
defineColor('FIREBRICK', 178, 34, 34)
defineColor('DARK_RED', 100, 0, 0)
defineColor('VERY_DARK_RED', 50, 0, 0)
defineColor('CRIMSON', 220, 20, 60)
defineColor('MOCCASIN', 255, 228, 181)
defineColor('KHAKI', 240, 230, 130)
defineColor('SANDY_BROWN', 244, 164, 96)
defineColor('SALMON', 250, 128, 114)

defineColor('DARK_ORCHID', 153, 50, 204)
defineColor('ORCHID', 218, 112, 214)
defineColor('PURPLE', 128, 0, 139)

defineColor('CHOCOLATE', 210, 105, 30)
defineColor('DARK_KHAKI', 189, 183, 107)
defineColor('TAN', 210, 180, 140)
defineColor('DARK_TAN', 110, 80, 40)

defineColor('HONEYDEW', 240, 255, 240)
defineColor('ANTIQUE_WHITE', 250, 235, 215)
defineColor('OLD_LACE', 253, 245, 230)
defineColor('DARK_SLATE_GRAY', 47, 79, 79)

defineColor('OLIVE_DRAB', 107, 142, 35)
defineColor('DARK_SEA_GREEN', 143, 188, 143)
defineColor('YELLOW_GREEN', 154, 205, 50)
defineColor('DARK_GREEN', 50, 77, 12)
