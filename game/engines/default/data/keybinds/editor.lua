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

defineAction{
	default = { "sym:=n:true:false:false:false" },
	type = "FILE_NEW",
	group = "editor",
	name = "New file",
}

defineAction{
	default = { "sym:=s:true:false:false:false" },
	type = "FILE_SAVE",
	group = "editor",
	name = "Save file",
}

defineAction{
	default = { "sym:=l:true:false:false:false" },
	type = "FILE_LOAD",
	group = "editor",
	name = "Load file",
}

defineAction{
	default = { "sym:=m:true:false:false:false" },
	type = "FILE_MERGE",
	group = "editor",
	name = "Merge file",
}

defineAction{
	default = { "sym:=z:true:false:false:false" },
	type = "EDITOR_UNDO",
	group = "editor",
	name = "Undo",
}

defineAction{
	default = { "sym:=y:true:false:false:false" },
	type = "EDITOR_REDO",
	group = "editor",
	name = "Redo",
}
