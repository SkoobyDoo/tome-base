-- ToME - Tales of Maj'Eyal
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

require "engine.class"
local Dialog = require "engine.ui.Dialog"
local Textzone = require "engine.ui.Textzone"
local ActorFrame = require "engine.ui.ActorFrame"
local List = require "engine.ui.List"

module(..., package.seeall, class.inherit(Dialog))

function _M:init(player, slot)
	self.true_actor = player
	self.true_object = player:getInven(slot)[1]
	self.actor = player:cloneFull()
	self.actor.x, self.actor.y = nil, nil
	self.actor:removeAllMOs()
	self.object = self.actor:getInven(slot)[1]

	local oname = self.object:getName{do_color=true, no_add_name=true}
	Dialog.init(self, "Shimmer object: "..oname, 680, 500)

	self:generateList()

	self.c_list = List.new{scrollbar=true, width=300, height=self.ih - 5, list=self.list, fct=function(item) self:use(item) end, select=function(item) self:select(item) end}
	local donatortext = ""
	if not profile:isDonator(1) then donatortext = "\n#{italic}##CRIMSON#This cosmetic feature is only available to donators/buyers. You can only preview.#WHITE##{normal}#" end
	local help = Textzone.new{width=math.floor(self.iw - self.c_list.w - 20), height=self.ih, no_color_bleed=true, auto_height=true, text="You can alter "..oname.." to look like another item of the same type/slot.\n#{bold}#This is a purely cosmetic change.#{normal}#"..donatortext}
	local actorframe = ActorFrame.new{actor=self.actor, w=128, h=128}

	self:loadUI{
		{left=0, top=0, ui=self.c_list},
		{right=0, top=0, ui=help},
		{right=(help.w - actorframe.w) / 2, vcenter=0, ui=actorframe},
	}
	self:setupUI(false, true)

	self.key:addBinds{
		EXIT = function()
			game:unregisterDialog(self)
		end,
	}
end

function _M:use(item)
	if not item then end
	game:unregisterDialog(self)

	if profile:isDonator(1) then
		self.true_object.shimmer_moddable = item.moddables
		self.true_actor:updateModdableTile()
	else
		Dialog:yesnoPopup("Donator Cosmetic Feature", "This cosmetic feature is only available to donators/buyers.", function(ret) if ret then
			game:registerDialog(require("mod.dialogs.Donation").new("shimmer ingame"))
		end end, "Donate", "Cancel")
	end
end

function _M:select(item)
	if not item then end
	self.object.shimmer_moddable = item.moddables
	self.actor:updateModdableTile()
end

function _M:generateList()
	local unlocked = world.unlocked_shimmers and world.unlocked_shimmers[self.object.slot] or {}
	local list = {}

	list[#list+1] = {
		moddables = {},
		name = "#GREY#[Invisible]",
		sortname = "--",
	}

	for name, data in pairs(unlocked) do
		if self.object.type == data.type and self.object.subtype == data.subtype then
			local d = {
				moddables = table.clone(data.moddables, true),
				name = name,
				sortname = name:removeColorCodes(),
			}
			d.moddables.name = name
			list[#list+1] = d
		end
	end
	table.sort(list, "sortname")

	self.list = list
end
