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

level.data.on_enter_list.conclave_vault = function()
	if game.level.data.conclave_vault_added then return end
	if game:getPlayer(true).level < 18 then return end

	local spot = game.level:pickSpot{type="world-encounter", subtype="conclave-vault"}
	if not spot then return end

	game.level.data.conclave_vault_added = true
	local g = game.level.map(spot.x, spot.y, engine.Map.TERRAIN):cloneFull()
	g.name = "Door to an abandonned vault"
	g.display='>' g.color_r=100 g.color_g=0 g.color_b=255 g.notice = true
	g.change_level=1 g.change_zone="conclave-vault" g.glow=true
	g.add_displays = g.add_displays or {}
	g.add_displays[#g.add_displays+1] = mod.class.Grid.new{image="terrain/dungeon_entrance02.png", z=5}
	g:altered()
	g:initGlow()
	game.zone:addEntity(game.level, g, "terrain", spot.x, spot.y)
	print("[WORLDMAP] conclave vault at", spot.x, spot.y)
	require("engine.ui.Dialog"):simplePopup("WRITE ME", "YES INDEED")
end

return true
