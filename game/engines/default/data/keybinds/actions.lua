-- TE4 - T-Engine 4
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

defineAction{
	default = { "uni:<", "uni:>" },
	type = "CHANGE_LEVEL",
	group = "actions",
	name = "Go to next/previous level",
}

defineAction{
	default = { "sym:=p:false:false:false:false", "sym:=g:false:true:false:false", "sym:PAD_DPDOWN:false:false:false:false" },
	type = "LEVELUP",
	group = "actions",
	name = "Levelup window",
}
defineAction{
	default = { "sym:=m:false:false:false:false", nil, "sym:PAD_DPUP:false:false:false:false" },
	type = "USE_TALENTS",
	group = "actions",
	name = "Use talents",
}

defineAction{
	default = { "sym:=j:false:false:false:false", "sym:_q:true:false:false:false", "sym:PAD_DPRIGHT:false:true:false:false" },
	type = "SHOW_QUESTS",
	group = "actions",
	name = "Show quests",
}

defineAction{
	default = { "sym:=r:false:false:false:false", "sym:=r:false:true:false:false", "sym:PAD_LEFTSHOULDER:false:false:false:false" },
	type = "REST",
	group = "actions",
	name = "Rest for a while",
}

defineAction{
	default = { "sym:_s:true:false:false:false" },
	type = "SAVE_GAME",
	group = "actions",
	name = "Save game",
}

defineAction{
	default = { "sym:_x:true:false:false:false" },
	type = "QUIT_GAME",
	group = "actions",
	name = "Quit game",
}

defineAction{
	default = { "sym:_t:false:true:false:false" },
	type = "TACTICAL_DISPLAY",
	group = "actions",
	name = "Tactical display on/off",
}

defineAction{
	default = { "sym:=l:false:false:false:false", nil, "sym:PAD_RIGHTSTICK:false:false:false:false" },
	type = "LOOK_AROUND",
	group = "actions",
	name = "Look around",
}

defineAction{
	default = { "sym:_TAB:false:false:false:false" },
	type = "TOGGLE_MINIMAP",
	group = "actions",
	name = "Toggle minimap",
}

defineAction{
	default = { "sym:=t:true:false:false:false" },
	type = "SHOW_TIME",
	group = "actions",
	name = "Show game calendar",
}

defineAction{
	default = { "sym:=c:false:false:false:false", "sym:=c:false:true:false:false", "sym:PAD_DPRIGHT:false:false:false:false" },
	type = "SHOW_CHARACTER_SHEET",
	group = "actions",
	name = "Show character sheet",
}

defineAction{
	default = { "sym:_s:false:false:true:false" },
	type = "SWITCH_GFX",
	group = "actions",
	name = "Switch graphical modes",
}

defineAction{
	default = { "sym:_RETURN:false:false:false:false", "sym:_KP_ENTER:false:false:false:false", "sym:PAD_A:false:false:false:false" },
	type = "ACCEPT",
	group = "actions",
	name = "Accept action",
}

defineAction{
	default = { "sym:_ESCAPE:false:false:false:false", nil, "sym:PAD_BACK:false:false:false:false" },
	type = "EXIT",
	group = "actions",
	name = "Exit menu",
}

defineAction{
	default = { nil, nil, "sym:PAD_B:false:false:false:false" },
	type = "EXIT_DIALOG",
	group = "actions",
	name = "Exit dialog",
}

defineAction{
	default = { "sym:_LGUI:false:false:false:true", "sym:_RGUI:false:false:false:true", "sym:PAD_RIGHTSHOULDER:false:false:false:false" },
	type = "MAPMENU",
	group = "actions",
	name = "Map contextual menu",
}
