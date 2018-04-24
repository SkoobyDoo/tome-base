-- ToME - Tales of Maj'Eyal
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

local UI = {}

local font = FontPackage:get("default")
local font_h = font:lineSkip()
local container = core.renderer.renderer()
local frame = UIBase:makeFrameDO("ui/tooltip/", nil, nil, 250, 7 + 6 * font_h, nil, true)
container:add(frame.container:color(1, 1, 1, 0.7))

local text_score = core.renderer.text(font) container:add(text_score:translate(0, font_h * 0))
local text_wave = core.renderer.text(font) container:add(text_wave:translate(0, font_h * 1))
local text_bonus = core.renderer.text(font) container:add(text_bonus:translate(0, font_h * 2))
local text_rank = core.renderer.text(font) container:add(text_rank:translate(0, font_h * 3))
local alltexts = {text_score, text_wave, text_bonus, text_rank}

function UI:onSetup()
	return container
end

function UI:onUpdate()
	if not game.level or not game.level.arena then return end
	local arena = game.level.arena

	if arena.score ~= self.old_score then
		if arena.score > world.arena.scores[1].score then
			text_score:textColor(1, 1, 0.4, 1):text(("Score[1st]: %d"):format(arena.score))
		else
			text_score:textColor(1, 1, 1, 1):text(("Score: %d"):format(arena.score))
		end
		self.old_score = arena.score
	end

	if arena.event ~= self.old_event or arena.currentWave ~= self.old_wave then
		local _event = ""
		if arena.event > 0 then
			if arena.event == 1 then _event = "[MiniBoss]"
			elseif arena.event == 2 then _event = "[Boss]"
			elseif arena.event == 3 then _event = "[Final]"
			end
		end
		if arena.currentWave > world.arena.bestWave then
			text_wave:textColor(1, 1, 0.4, 1):text(("Wave(TOP) %d %s"):format(arena.currentWave, _event))
		elseif arena.currentWave > world.arena.lastScore.wave then
			text_wave:textColor(0.4, 0.4, 1, 1):text(("Wave %d %s"):format(arena.currentWave, _event))
		else
			text_wave:textColor(1, 1, 1, 1):text(("Wave %d %s"):format(arena.currentWave, _event))
		end
		self.old_wave = arena.currentWave
		self.old_event = arena.event
	end

	if arena.bonus ~= self.old_bonus or arena.bonusMultiplier ~= self.old_bonusMultiplier or arena.pinch ~= self.old_pinch then
		if arena.pinch == true then
			text_bonus:textColor(1, 0.2, 0.2, 1):text(("Bonus: %d (x%.1f)"):format(arena.bonus, arena.bonusMultiplier))
		else
			text_bonus:textColor(1, 1, 1, 1):text(("Bonus: %d (x%.1f)"):format(arena.bonus, arena.bonusMultiplier))
		end
		self.old_bonus = arena.bonus
		self.old_bonusMultiplier = arena.bonusMultiplier
		self.old_pinch = arena.pinch
	end

	-- local display = arena.display or {}
	-- if display[1] ~= self.old_display1 or display[2] ~= self.old_display2 then
		if arena.display then
			text_rank:textColor(1, 0, 1, 1):text(arena.display[1].."\n VS\n"..arena.display[2])
		else
			text_rank:textColor(1, 1, 1, 1):text("Rank: "..arena.printRank(arena.rank, arena.ranks))
		end
	-- 	self.old_display1 = display[1]
	-- 	self.old_display2 = display[2]
	-- end

	local w, h = 0, 0
	for _, text in ipairs(alltexts) do
		local tw, th = text:getStats()
		w = math.max(w, tw)
		h = h + th
	end
	if w ~= self.old_w or h ~= self.old_h then
		frame:resize(nil, nil, w, h)
		self.old_w = w
		self.old_h = h
	end
end

return UI
