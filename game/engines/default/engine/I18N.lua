-- TE4 - T-Engine 4
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

--- Can be used to make a module internationalizable
-- @classmod engine.I18N
module(..., package.seeall, class.make)

local locales = {}
local cur_locale_name = "en_US"
local cur_locale = {}
local cur_unlocalized = {}

_G._t = function(s, debugadd)
	if config.settings.cheat and not cur_locale[s] then
		debugadd = debugadd or 0
		local info = {}
		while not info.source do
			info = debug.getinfo(2 + debugadd)
			debugadd = debugadd + 1
		end
		cur_unlocalized[info.source] = cur_unlocalized[info.source] or {}
		cur_unlocalized[info.source][s] = true
	end
	return cur_locale[s] or s
end

function _M:loadLocale(file)
	if not fs.exists(file) then print("[I18N] Warning, localization file does not exists:", file) return end
	local lc = nil
	local env = setmetatable({
		locale = function(s) lc = s; locales[lc] = locales[lc] or {} end,
		section = function(s) end, -- Not used ingame
		t = function(src, dst) self:t(lc, src, dst) end,
	}, {__index=getfenv(2)})
	local f, err = util.loadfilemods(file, env)
	if not f and err then error(err) end
	f()
end

function _M:setLocale(lc)
	cur_locale_name = lc
	cur_locale = locales[lc] or {}
end

function _M:t(lc, src, dst)
	locales[lc] = locales[lc] or {}
	locales[lc][src] = dst
end

function _M:dumpUnknowns()
	local f = fs.open("/i18n_unknown_"..cur_locale_name..".lua", "w")
	f:write(('locale "%s"\n\n\n'):format(cur_locale_name))

	local slist = table.keys(cur_unlocalized)
	table.sort(slist)
	for _, section in ipairs(slist) do
		f:write('------------------------------------------------\n')
		f:write(('section %q\n\n'):format(section))

		local list = table.keys(cur_unlocalized[section])
		table.sort(list)
		for _, s in ipairs(list) do
			f:write(('t(%q, "")\n'):format(s))
		end
		f:write('\n\n')
	end
	f:close()
end
