-- ToME - Tales of Maj'Eyal
-- Copyright (C) 2009 - 2016 Nicolas Casalini
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any latesr version.
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

-- A copy of the AOA dialog, stand-in until the quest structure gets worked on

newChat{ id="welcome",
	text = [[Well met, stranger!
I am Lady Akho, commander of the Temporal Wardens. I was sent here to investigate the space-time anomaly in this region. 
Surely you have encountered some of the temporal distortions? 
	]],
	answers = {
		{"Hello, I am @playername@. #LIGHT_GREEN#*Tell her about the disappearance of your hometown*#WHITE#", jump="catastrophe", },
	}
}

newChat{ id="catastrophe",
	text = [[I see.
I fear your village may have fallen victim to the anomaly. The original time-stream must have been severed. 
Unfortunately, this is happening more and more recently. Something terrible is happening, and we don't understand it yet.
	]],
	answers = {
		{"I want to help you.", jump="zero"},
	}
}

newChat{ id="zero",
	text = [[Yes, your help would be welcome.
This portal here will bring you to Point Zero, our headquarters. Go there and talk to Zemekkys, the Grand Keeper of Reality. He can tell you more. 
I will take a closer look at this place, perhaps it will lead to a better understanding of the catastrophe.
Take care, @playername@! I wish you luck!
	]],
	answers = {
		{"Thank you, Lady Akho!", action = function(self, player)
			self.talked_to = 1
			player:grantQuest("atof+point-zero")
			end
		},
	}
}

newChat{ id = "back",
	text = [[Take care, @playername@! I wish you luck!
	]],
	answers = {
		{"Thank you, Lady Akho!"},
	}
}

if npc.talked_to then
return "back"
else return "welcome" end
