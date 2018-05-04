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
local Dialog = require "engine.ui.Dialog"
local Shader = require "engine.Shader"
local FontPackage = require "engine.FontPackage"

module(..., package.seeall, class.inherit(Dialog))

__show_only = true

local title_font = core.display.newFont(FontPackage:getFont("default"), 32, true)
local text_font = core.display.newFont(FontPackage:getFont("default"), 28, true)
local aura = {
	Shader.new("awesomeaura", {flameScale=0.6, time_factor=8000}),
	Shader.new("awesomeaura", {flameScale=0.6, time_factor=8000}),
--	Shader.new("crystalineaura", {time_factor=8000}),
}
local aura_texture = {
	core.loader.png("/data/gfx/flame_credits.png"),
	core.loader.png("/data/gfx/spikes_credits.png"),
}
local fallback_colors = {
	colors.GOLD,
	colors.FIREBRICK,
}
local outline = Shader.new("textoutline", {})

local credits = {
	{img="/data/gfx/background/tome-logo.png", offset_x=30},
	{"by"},
	{img="/data/gfx/background/netcore-logo.png"},
	false,
	{"Project Lead", title=1},
	{"Nicolas 'DarkGod' Casalini"},
	false,
	false,

	{"Lead Coder", title=2},
	{"Nicolas 'DarkGod' Casalini"},
	false,
	false,

	{"World Builders", title=1},
	{"Aaron 'Sage Acrin' Vandegrift"},
	{"Alexander '0player' Sedov"},
	{"Chris 'Shibari' Davidson"},
	{"Doctornull"},
	{"Em 'Susramanian' Jay"},
	{"Eric 'Edge2054' Wykoff"},
	{"Evan 'Fortescue' Williams"},
	{"Hetdegon"},
	{"John 'Benli' Truchard"},
	{"Nicolas 'DarkGod' Casalini"},
	{"Ben 'Razakai' Pope"},
	{"StarKeep"},
	{"Simon 'HousePet' Curtis"},
	{"Shoob"},
	{"Taylor 'PureQuestion' Miller"},
	{"Thomas 'Tomisgo' Cretan"},
	false,
	false,

	{"Graphic Artists", title=2},
	{"Assen 'Rexorcorum' Kanev"},
	{"Matt 'Amagad' Hill"},
	{"Jeffrey 'Jotwebe' Buschhorn"},
	{"Raymond 'Shockbolt' Gaustadnes"},
	{"Richard 'Swoosh So Fast' Pallo"},
	false,
	false,

	{"Expert Shaders Design", title=1},
	{"Alex 'Suslik' Sannikov"},
	false,
	false,

	{"Soundtracks", title=2},
	{"Anne van Schothorst"},
	{"Carlos Saura"},
	{"Matti Paalanen - 'Celestial Aeon Project'"},
	false,
	false,

	{"Sound Designer", title=1},
	{"Kenneth 'Elvisman2001' Toomey"},
--	{"Ryan Sim"},
	false,
	false,

	{"Lore Creation and Writing", title=2},
	{"Burb Lulls"},
	{"Darren Grey"},
	{"David Mott"},
	{"Gwai"},
	{"Nicolas 'DarkGod' Casalini"},
	{"Ron Billingsley"},
	false,
	false,

	{"Code Helpers", title=1},
	{"Antagonist"},
	{"Graziel"},
	{"Grayswandir"},
	{"John 'Hachem Muche' Viles"},
	{"Jules 'Quicksilver' Bean"},
	{"Madmonk"},
	{"Mark 'Marson' Carpente"},
	{"Neil Stevens"},
	{"Samuel 'Effigy' Wegner"},
	{"Sebastian 'Sebsebeleb' Vråle"},
	{"Shani"},
	{"Shibari"},
	{"Tiger Eye"},
	{"Yufra"},
	false,
	false,

	{"Community Managers", title=2},
	{"Bradley 'AuraOfTheDawn' Kersey"},
	{"Faeryan"},
	{"Erik 'Lord Xandor' Tillford"},
	{"Michael 'Dekar' Olscher"},
	{"Rob 'stuntofthelitter' Stites"},
	{"Reenen 'Canderel' Laurie"},
	{"Sheila"},
	{"The Revanchist"},
	{"Yottle"},
	false,
	false,

	{"Text Editors", title=1},
	{"Brian Jeffears"},
	{"Greg Wooledge"},
	{"Ralph Versteegen"},
	false,
	false,

	{"The Community", title=2},
	{"A huge global thank to all members"},
	{"of the community, for being supportive,"},
	{"fun and full of great ideas."},
	{"You rock gals and guys!"},
	false,
	false,

	{"Others", title=1},
	{"J.R.R Tolkien - making the world an interesting place"},
	{"Lua Creators - making the world a better place"},
	{"Lua - http://lua.org/"},
	{"LibSDL - http://libsdl.org/"},
	{"OpenGL - http://www.opengl.org/"},
	{"OpenAL - http://kcat.strangesoft.net/openal.html"},
	{"zlib - http://www.zlib.net/"},
	{"LuaJIT - http://luajit.org/"},
	{"lpeg - http://www.inf.puc-rio.br/~roberto/lpeg/"},
	{"LuaSocket - http://w3.impa.br/~diego/software/luasocket/"},
	{"Physfs - https://icculus.org/physfs/"},
	{"CEF3 - http://code.google.com/p/chromiumembedded/"},
	{"Font: Droid - http://www.droidfonts.com/"},
	{"Font: Vera - http://www.gnome.org/fonts/"},
	{"Font: INSULA, USENET: http://www.dafont.com/fr/apostrophic-labs.d128"},
	{"Font: SVBasicManual: http://www.dafont.com/fr/johan-winge.d757"},
	{"Font FSEX300: http://www.fixedsysexcelsior.com/"},
	{"Font: square: http://strlen.com/square"},
	{"Font: Salsa: http://www.google.com/fonts/specimen/Salsa"},
}

function _M:init()
	Dialog.init(self, "", game.w, game.h, nil, nil, nil, nil, false)

	self:loadUI{}
	self:setupUI(false, false)

	self.key:addBinds{
		EXIT = function() game:unregisterDialog(self) end,
	}

	self:triggerHook{"Boot:credits", credits=credits}

	self.credit_container = core.renderer.renderer("static"):translate(game.w / 2, 0)
	local y = 0
	for i, credit in ipairs(credits) do
		local item, w, h = self:makeEntry(credit)
		self.credit_container:add(item:translate(-w/2, y))
		y = y + h
	end
	y = y + game.h / 2
	self.renderer:clear():add(self.credit_container)
	self.credit_container:tween(30 * 7 * y / game.h, "y", nil, -y, nil, function() game:unregisterDialog(self) end)
end

function _M:makeLogo(img, offx)
	local i, w, h = core.renderer.image(img, offx, 0)
	return i, w, h
end

function _M:makeEntry(credit)
	if not credit then return core.renderer.container(), 0, 32 end

	if credit.img then return self:makeLogo(credit.img, credit.offset_x) end

	local txt
	if credit.title then
		local txt = core.renderer.text(title_font):textColor(colors.smart1unpack(fallback_colors[credit.title])):outline(1):text(credit[1])--:shader(aura[1].shad):texture(aura_texture[1], 1)
		local w, h = txt:getStats()
		return txt, w, h
	else
		local txt = core.renderer.text(text_font):outline(1):text(credit[1])
		local w, h = txt:getStats()
		return txt, w, h
	end
end
