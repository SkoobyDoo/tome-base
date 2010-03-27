-- Wild Gifts
newTalentType{ type="wild-gift/call", name = "call of the wild", description = "Be at one with nature." }
newTalentType{ type="wild-gift/antimagic", name = "antimagic", description = "The way to combat magic, or even nullify it." }
newTalentType{ type="wild-gift/summon-melee", name = "summoning (melee)", description = "The art of calling creatures to your help." }
newTalentType{ type="wild-gift/summon-distance", name = "summoning (distance)", description = "The art of calling creatures to your help." }
newTalentType{ type="wild-gift/summon-utility", name = "summoning (utility)", description = "The art of calling creatures to your help." }
newTalentType{ type="wild-gift/summon-augmentation", name = "summoning (augmentation)", description = "The art of calling creatures to your help." }
newTalentType{ type="wild-gift/slime", name = "slime aspect", description = "Through dedicated consumption of slime mold juice you have gained an affinity with slime molds." }
newTalentType{ type="wild-gift/sand-drake", name = "sand drake aspect", description = "Take on the defining aspects of a Sand Drake." }
newTalentType{ type="wild-gift/fire-drake", name = "fire drake aspect", description = "Take on the defining aspects of a Fire Drake." }
newTalentType{ type="wild-gift/cold-drake", name = "cold drake aspect", description = "Take on the defining aspects of a Cold Drake." }

-- Generic requires for gifts based on talent level
gifts_req1 = {
	stat = { wil=function(level) return 12 + (level-1) * 2 end },
	level = function(level) return 0 + (level-1)  end,
}
gifts_req2 = {
	stat = { wil=function(level) return 20 + (level-1) * 2 end },
	level = function(level) return 4 + (level-1)  end,
}
gifts_req3 = {
	stat = { wil=function(level) return 28 + (level-1) * 2 end },
	level = function(level) return 8 + (level-1)  end,
}
gifts_req4 = {
	stat = { wil=function(level) return 36 + (level-1) * 2 end },
	level = function(level) return 12 + (level-1)  end,
}
gifts_req5 = {
	stat = { wil=function(level) return 44 + (level-1) * 2 end },
	level = function(level) return 16 + (level-1)  end,
}

load("/data/talents/gifts/call.lua")

load("/data/talents/gifts/slime.lua")

load("/data/talents/gifts/sand-drake.lua")
load("/data/talents/gifts/fire-drake.lua")
load("/data/talents/gifts/cold-drake.lua")

function checkMaxSummon(self)
	local nb = 0
	for _, e in pairs(game.level.entities) do
		if e.summoner and e.summoner == self then nb = nb + 1 end
	end

	local max = math.max(1, math.floor(self:getCun() / 10))
	if nb >= max then
		game.logPlayer(self, "#PINK#You can not summon any more, you have too many summons already (%d). You can increase the limit with higher Cunning.", nb)
		return true
	else
		return false
	end
end

load("/data/talents/gifts/summon-melee.lua")
load("/data/talents/gifts/summon-distance.lua")
load("/data/talents/gifts/summon-utility.lua")
load("/data/talents/gifts/summon-augmentation.lua")
