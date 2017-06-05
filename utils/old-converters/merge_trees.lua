local gd = require "gd"

function table.print(src, offset, ret)
	if type(src) ~= "table" then print("table.print has no table:", src) return end
	offset = offset or ""
	for k, e in pairs(src) do
		-- Deep copy subtables, but not objects!
		if type(e) == "table" and not e.__ATOMIC and not e.__CLASSNAME then
			print(("%s[%s] = {"):format(offset, tostring(k)))
			table.print(e, offset.."  ")
			print(("%s}"):format(offset))
		else
			print(("%s[%s] = %s"):format(offset, tostring(k), tostring(e)))
		end
	end
end

local treesfiles = {
	"burned_tree_01_foliage_ash_01.png",
	"burned_tree_01_foliage_ash_02.png",
	"burned_tree_01_foliage.png",
	"burned_tree_01_foliage_winter.png",
	"burned_tree_01_shadow.png",
	"burned_tree_01_trunk_ash_01.png",
	"burned_tree_01_trunk.png",
	"burned_tree_02_foliage_ash_01.png",
	"burned_tree_02_foliage_ash_02.png",
	"burned_tree_02_foliage.png",
	"burned_tree_02_foliage_winter.png",
	"burned_tree_02_shadow.png",
	"burned_tree_02_trunk_ash_01.png",
	"burned_tree_02_trunk.png",
	"burned_tree_03_foliage_ash_01.png",
	"burned_tree_03_foliage_ash_02.png",
	"burned_tree_03_foliage.png",
	"burned_tree_03_foliage_winter.png",
	"burned_tree_03_shadow.png",
	"burned_tree_03_trunk_ash_01.png",
	"burned_tree_03_trunk.png",
	"cypress_foliage_01.png",
	"cypress_foliage_02.png",
	"cypress_foliage_03.png",
	"cypress_foliage_04.png",
	"cypress_foliage_winter_01.png",
	"cypress_foliage_winter_02.png",
	"cypress_shadow.png",
	"cypress_trunk.png",
	"elm_foliage_autumn.png",
	"elm_foliage_bare.png",
	"elm_foliage_spring.png",
	"elm_foliage_summer.png",
	"elm_foliage_winter.png",
	"elm_shadow.png",
	"elm_trunk.png",
	"elventree_03_foliage_autumn.png",
	"elventree_03_foliage_bare.png",
	"elventree_03_foliage_spring_01.png",
	"elventree_03_foliage_spring_02.png",
	"elventree_03_foliage_spring_03.png",
	"elventree_03_foliage_spring_04.png",
	"elventree_03_foliage_summer.png",
	"elventree_03_foliage_winter.png",
	"elventree_03_shadow.png",
	"elventree_03_trunk.png",
	"elventree_foliage_autumn.png",
	"elventree_foliage_bare.png",
	"elventree_foliage_spring.png",
	"elventree_foliage_summer.png",
	"elventree_foliage_winter.png",
	"elventree_shadow.png",
	"elventree_trunk.png",
	"fat_elventree_foliage_autumn_01.png",
	"fat_elventree_foliage_autumn_02.png",
	"fat_elventree_foliage_bare.png",
	"fat_elventree_foliage_spring_01.png",
	"fat_elventree_foliage_spring_02.png",
	"fat_elventree_foliage_spring_03.png",
	"fat_elventree_foliage_summer_01.png",
	"fat_elventree_foliage_summer_02.png",
	"fat_elventree_foliage_winter.png",
	"fat_elventree_shadow.png",
	"fat_elventree_trunk.png",
	"gnarled_tree_foliage_bare.png",
	"gnarled_tree_shadow.png",
	"gnarled_tree_trunk.png",
	"light_pine_foliage_01.png",
	"light_pine_foliage_02.png",
	"light_pine_foliage_03.png",
	"light_pine_foliage_04.png",
	"light_pine_shadow.png",
	"light_pine_trunk.png",
	"light_small_narrow_pine_foliage_01.png",
	"light_small_narrow_pine_foliage_02.png",
	"light_small_narrow_pine_foliage_03.png",
	"light_small_narrow_pine_foliage_04.png",
	"light_small_narrow_pine_shadow.png",
	"light_small_narrow_pine_trunk.png",
	"light_small_wider_pine_foliage_01.png",
	"light_small_wider_pine_foliage_02.png",
	"light_small_wider_pine_foliage_03.png",
	"light_small_wider_pine_foliage_04.png",
	"light_small_wider_pine_shadow.png",
	"light_small_wider_pine_trunk.png",
	"narrow_cypress_foliage_01.png",
	"narrow_cypress_foliage_02.png",
	"narrow_cypress_foliage_03.png",
	"narrow_cypress_foliage_04.png",
	"narrow_cypress_foliage_winter_01.png",
	"narrow_cypress_foliage_winter_02.png",
	"narrow_cypress_shadow.png",
	"narrow_cypress_trunk.png",
	"oak_foliage_autumn_01.png",
	"oak_foliage_autumn_02.png",
	"oak_foliage_autumn_03.png",
	"oak_foliage_autumn_04.png",
	"oak_foliage_bare_01.png",
	"oak_foliage_bare_02.png",
	"oak_foliage_bare_03.png",
	"oak_foliage_spring_01.png",
	"oak_foliage_spring_02.png",
	"oak_foliage_spring_03.png",
	"oak_foliage_summer_01.png",
	"oak_foliage_summer_02.png",
	"oak_foliage_summer_03.png",
	"oak_foliage_summer_04.png",
	"oak_foliage_winter_01.png",
	"oak_foliage_winter_02.png",
	"oak_foliage_winter_03.png",
	"oak_shadow.png",
	"oak_trunk_01.png",
	"oak_trunk_02.png",
	"oldforest_tree_01_foliage_autumn_01.png",
	"oldforest_tree_01_foliage_autumn_02.png",
	"oldforest_tree_01_foliage_autumn_03.png",
	"oldforest_tree_01_foliage_autumn_04.png",
	"oldforest_tree_01_foliage_bare_01.png",
	"oldforest_tree_01_foliage_bare_02.png",
	"oldforest_tree_01_foliage_bare_03.png",
	"oldforest_tree_01_foliage_bare_04.png",
	"oldforest_tree_01_foliage_spring_01.png",
	"oldforest_tree_01_foliage_spring_02.png",
	"oldforest_tree_01_foliage_spring_03.png",
	"oldforest_tree_01_foliage_spring_04.png",
	"oldforest_tree_01_foliage_summer_01.png",
	"oldforest_tree_01_foliage_summer_02.png",
	"oldforest_tree_01_foliage_summer_03.png",
	"oldforest_tree_01_foliage_summer_04.png",
	"oldforest_tree_01_foliage_winter_01.png",
	"oldforest_tree_01_foliage_winter_02.png",
	"oldforest_tree_01_foliage_winter_03.png",
	"oldforest_tree_01_foliage_winter_04.png",
	"oldforest_tree_01_shadow.png",
	"oldforest_tree_01_trunk_01.png",
	"oldforest_tree_01_trunk_02.png",
	"oldforest_tree_01_trunk_03.png",
	"oldforest_tree_02_foliage_autumn_01.png",
	"oldforest_tree_02_foliage_autumn_02.png",
	"oldforest_tree_02_foliage_autumn_03.png",
	"oldforest_tree_02_foliage_autumn_04.png",
	"oldforest_tree_02_foliage_bare_01.png",
	"oldforest_tree_02_foliage_bare_02.png",
	"oldforest_tree_02_foliage_bare_03.png",
	"oldforest_tree_02_foliage_bare_04.png",
	"oldforest_tree_02_foliage_spring_01.png",
	"oldforest_tree_02_foliage_spring_02.png",
	"oldforest_tree_02_foliage_spring_03.png",
	"oldforest_tree_02_foliage_spring_04.png",
	"oldforest_tree_02_foliage_summer_01.png",
	"oldforest_tree_02_foliage_summer_02.png",
	"oldforest_tree_02_foliage_summer_03.png",
	"oldforest_tree_02_foliage_summer_04.png",
	"oldforest_tree_02_foliage_winter_01.png",
	"oldforest_tree_02_foliage_winter_02.png",
	"oldforest_tree_02_foliage_winter_03.png",
	"oldforest_tree_02_foliage_winter_04.png",
	"oldforest_tree_02_shadow.png",
	"oldforest_tree_02_trunk_01.png",
	"oldforest_tree_02_trunk_02.png",
	"oldforest_tree_02_trunk_03.png",
	"oldforest_tree_03_foliage_autumn_01.png",
	"oldforest_tree_03_foliage_autumn_02.png",
	"oldforest_tree_03_foliage_autumn_03.png",
	"oldforest_tree_03_foliage_autumn_04.png",
	"oldforest_tree_03_foliage_bare_01.png",
	"oldforest_tree_03_foliage_bare_02.png",
	"oldforest_tree_03_foliage_bare_03.png",
	"oldforest_tree_03_foliage_bare_04.png",
	"oldforest_tree_03_foliage_spring_01.png",
	"oldforest_tree_03_foliage_spring_02.png",
	"oldforest_tree_03_foliage_spring_03.png",
	"oldforest_tree_03_foliage_spring_04.png",
	"oldforest_tree_03_foliage_summer_01.png",
	"oldforest_tree_03_foliage_summer_02.png",
	"oldforest_tree_03_foliage_summer_03.png",
	"oldforest_tree_03_foliage_summer_04.png",
	"oldforest_tree_03_foliage_winter_01.png",
	"oldforest_tree_03_foliage_winter_02.png",
	"oldforest_tree_03_foliage_winter_03.png",
	"oldforest_tree_03_foliage_winter_04.png",
	"oldforest_tree_03_shadow.png",
	"oldforest_tree_03_trunk_01.png",
	"oldforest_tree_03_trunk_02.png",
	"oldforest_tree_03_trunk_03.png",
	"pine_foliage_01.png",
	"pine_foliage_02.png",
	"pine_foliage_03.png",
	"pine_foliage_04.png",
	"pine_foliage_winter_01.png",
	"pine_foliage_winter_02.png",
	"pine_shadow.png",
	"pine_trunk.png",
	"small_burned_tree_01_shadow.png",
	"small_burned_tree_01_trunk_ash_01.png",
	"small_burned_tree_01_trunk_ash_02.png",
	"small_burned_tree_01_trunk.png",
	"small_burned_tree_01_trunk_winter.png",
	"small_burned_tree_02_foliage_ash_01.png",
	"small_burned_tree_02_foliage_ash_02.png",
	"small_burned_tree_02_foliage.png",
	"small_burned_tree_02_foliage_winter.png",
	"small_burned_tree_02_shadow.png",
	"small_burned_tree_02_trunk.png",
	"small_burned_tree_03_foliage_ash_01.png",
	"small_burned_tree_03_foliage_ash_02.png",
	"small_burned_tree_03_foliage.png",
	"small_burned_tree_03_foliage_winter.png",
	"small_burned_tree_03_shadow.png",
	"small_burned_tree_03_trunk.png",
	"small_cypress_foliage_01.png",
	"small_cypress_foliage_02.png",
	"small_cypress_foliage_03.png",
	"small_cypress_foliage_04.png",
	"small_cypress_foliage_winter_01.png",
	"small_cypress_foliage_winter_02.png",
	"small_cypress_shadow.png",
	"small_cypress_trunk.png",
	"small_elm_foliage_autumn.png",
	"small_elm_foliage_bare.png",
	"small_elm_foliage_spring.png",
	"small_elm_foliage_summer.png",
	"small_elm_foliage_winter.png",
	"small_elm_shadow.png",
	"small_elm_trunk.png",
	"small_narrow_pine_foliage_01.png",
	"small_narrow_pine_foliage_02.png",
	"small_narrow_pine_foliage_03.png",
	"small_narrow_pine_foliage_04.png",
	"small_narrow_pine_foliage_winter_01.png",
	"small_narrow_pine_foliage_winter_02.png",
	"small_narrow_pine_shadow.png",
	"small_narrow_pine_trunk.png",
	"small_oak_foliage_autumn_01.png",
	"small_oak_foliage_autumn_02.png",
	"small_oak_foliage_autumn_03.png",
	"small_oak_foliage_autumn_04.png",
	"small_oak_foliage_bare_01.png",
	"small_oak_foliage_bare_03.png",
	"small_oak_foliage_spring_01.png",
	"small_oak_foliage_spring_03.png",
	"small_oak_foliage_summer_01-0.png",
	"small_oak_foliage_summer_01-1.png",
	"small_oak_foliage_summer_01.png",
	"small_oak_foliage_summer_02.png",
	"small_oak_foliage_summer_03.png",
	"small_oak_foliage_summer_04.png",
	"small_oak_foliage_winter_01.png",
	"small_oak_foliage_winter_03.png",
	"small_oak_shadow.png",
	"small_oak_trunk_01.png",
	"small_oak_trunk_02.png",
	"small_oldforest_tree_01_foliage_autumn_01.png",
	"small_oldforest_tree_01_foliage_autumn_02.png",
	"small_oldforest_tree_01_foliage_autumn_03.png",
	"small_oldforest_tree_01_foliage_autumn_04.png",
	"small_oldforest_tree_01_foliage_bare_01.png",
	"small_oldforest_tree_01_foliage_bare_02.png",
	"small_oldforest_tree_01_foliage_bare_03.png",
	"small_oldforest_tree_01_foliage_bare_04.png",
	"small_oldforest_tree_01_foliage_spring_01.png",
	"small_oldforest_tree_01_foliage_spring_02.png",
	"small_oldforest_tree_01_foliage_spring_03.png",
	"small_oldforest_tree_01_foliage_spring_04.png",
	"small_oldforest_tree_01_foliage_summer_01.png",
	"small_oldforest_tree_01_foliage_summer_02.png",
	"small_oldforest_tree_01_foliage_summer_03.png",
	"small_oldforest_tree_01_foliage_summer_04.png",
	"small_oldforest_tree_01_foliage_winter_01.png",
	"small_oldforest_tree_01_foliage_winter_02.png",
	"small_oldforest_tree_01_foliage_winter_03.png",
	"small_oldforest_tree_01_foliage_winter_04.png",
	"small_oldforest_tree_01_shadow.png",
	"small_oldforest_tree_01_trunk_01.png",
	"small_oldforest_tree_01_trunk_02.png",
	"small_oldforest_tree_01_trunk_03.png",
	"small_oldforest_tree_02_foliage_autumn_01.png",
	"small_oldforest_tree_02_foliage_autumn_02.png",
	"small_oldforest_tree_02_foliage_autumn_03.png",
	"small_oldforest_tree_02_foliage_autumn_04.png",
	"small_oldforest_tree_02_foliage_bare_01.png",
	"small_oldforest_tree_02_foliage_bare_02.png",
	"small_oldforest_tree_02_foliage_bare_03.png",
	"small_oldforest_tree_02_foliage_bare_04.png",
	"small_oldforest_tree_02_foliage_spring_01.png",
	"small_oldforest_tree_02_foliage_spring_02.png",
	"small_oldforest_tree_02_foliage_spring_03.png",
	"small_oldforest_tree_02_foliage_spring_04.png",
	"small_oldforest_tree_02_foliage_summer_01.png",
	"small_oldforest_tree_02_foliage_summer_02.png",
	"small_oldforest_tree_02_foliage_summer_03.png",
	"small_oldforest_tree_02_foliage_summer_04.png",
	"small_oldforest_tree_02_foliage_winter_01.png",
	"small_oldforest_tree_02_foliage_winter_02.png",
	"small_oldforest_tree_02_foliage_winter_03.png",
	"small_oldforest_tree_02_foliage_winter_04.png",
	"small_oldforest_tree_02_shadow.png",
	"small_oldforest_tree_02_trunk_01.png",
	"small_oldforest_tree_02_trunk_02.png",
	"small_oldforest_tree_02_trunk_03.png",
	"small_oldforest_tree_03_foliage_autumn_01.png",
	"small_oldforest_tree_03_foliage_autumn_02.png",
	"small_oldforest_tree_03_foliage_autumn_03.png",
	"small_oldforest_tree_03_foliage_autumn_04.png",
	"small_oldforest_tree_03_foliage_bare_01.png",
	"small_oldforest_tree_03_foliage_bare_02.png",
	"small_oldforest_tree_03_foliage_bare_03.png",
	"small_oldforest_tree_03_foliage_bare_04.png",
	"small_oldforest_tree_03_foliage_spring_01.png",
	"small_oldforest_tree_03_foliage_spring_02.png",
	"small_oldforest_tree_03_foliage_spring_03.png",
	"small_oldforest_tree_03_foliage_spring_04.png",
	"small_oldforest_tree_03_foliage_summer_01.png",
	"small_oldforest_tree_03_foliage_summer_02.png",
	"small_oldforest_tree_03_foliage_summer_03.png",
	"small_oldforest_tree_03_foliage_summer_04.png",
	"small_oldforest_tree_03_foliage_winter_01.png",
	"small_oldforest_tree_03_foliage_winter_02.png",
	"small_oldforest_tree_03_foliage_winter_03.png",
	"small_oldforest_tree_03_foliage_winter_04.png",
	"small_oldforest_tree_03_shadow.png",
	"small_oldforest_tree_03_trunk_01.png",
	"small_oldforest_tree_03_trunk_02.png",
	"small_oldforest_tree_03_trunk_03.png",
	"small_wider_pine_foliage_01.png",
	"small_wider_pine_foliage_02.png",
	"small_wider_pine_foliage_03.png",
	"small_wider_pine_foliage_04.png",
	"small_wider_pine_foliage_winter_01.png",
	"small_wider_pine_foliage_winter_02.png",
	"small_wider_pine_shadow.png",
	"small_wider_pine_trunk.png",
	"small_willow_foliage_autumn.png",
	"small_willow_foliage_bare.png",
	"small_willow_foliage_spring.png",
	"small_willow_foliage_summer.png",
	"small_willow_foliage_winter.png",
	"small_willow_moss_foliage_autumn.png",
	"small_willow_moss_foliage_bare.png",
	"small_willow_moss_foliage_spring.png",
	"small_willow_moss_foliage_summer.png",
	"small_willow_moss_foliage_winter.png",
	"small_willow_moss_roots_mist.png",
	"small_willow_moss_trunk.png",
	"small_willow_moss_waterripples.png",
	"small_willow_roots_mist.png",
	"small_willow_shadow.png",
	"small_willow_trunk.png",
	"small_willow_waterripples.png",
	"tiny_cypress_foliage_01.png",
	"tiny_cypress_foliage_02.png",
	"tiny_cypress_foliage_03.png",
	"tiny_cypress_foliage_04.png",
	"tiny_cypress_foliage_winter_01.png",
	"tiny_cypress_foliage_winter_02.png",
	"tiny_cypress_shadow.png",
	"tiny_cypress_trunk.png",
	"willow_foliage_autumn.png",
	"willow_foliage_bare.png",
	"willow_foliage_moss_autumn.png",
	"willow_foliage_spring.png",
	"willow_foliage_summer.png",
	"willow_foliage_winter.png",
	"willow_moss_foliage_bare.png",
	"willow_moss_foliage_spring.png",
	"willow_moss_foliage_summer.png",
	"willow_moss_foliage_winter.png",
	"willow_moss_roots_mist.png",
	"willow_moss_trunk.png",
	"willow_moss_waterripples.png",
	"willow_roots_mist.png",
	"willow_shadow.png",
	"willow_trunk.png",
	"willow_waterripples.png",
}

local matches = { "shadow", "waterripples", "roots_mist", "trunk", "foliage" }
local bases = { {"shadow", "waterripples", "roots_mist"}, {"trunk"}, {""} }

local treesdef = {}
for i = #treesfiles, 1, -1 do
	local file = treesfiles[i]
	for _, match in ipairs(matches) do
		local _, _, id, what = file:find("^(.*)_("..match..".*).png")
		if id then
			table.remove(treesfiles, i)
			treesdef[id] = treesdef[id] or {}

			local nb = 1
			if what:find("_[0-9]+") then
				local _, _, before, n = what:find("(.*)_0*([0-9]+)")
				if n then
					what = before.."_%02d"
					nb = tonumber(n)
				end
			end

			for idx, baselist in ipairs(bases) do
				local found = false
				for _, base in ipairs(baselist) do
					if what:find("^"..base) then
						treesdef[id][idx] = treesdef[id][idx] or {}
						-- if idx == 1 then
						-- 	treesdef[id][idx] = what
						if idx >= 1 then
							if treesdef[id][idx][what] then
								treesdef[id][idx][what][2] = math.max(nb, treesdef[id][idx][what][2])
							else
								treesdef[id][idx][what] = {1, nb}
							end
						end
						found = true
						break
					end
				end
				if found then break end
			end
			-- if not found then treesdef[id][3] = {what, 1, nb} end
			-- print("* found", id, what)
			break
		end
	end
end
-- print("===")
-- table.print(treesdef)
-- do return end

local idx = 1
for id, files in pairs(treesdef) do
	local w, h = 64, 64 -- data[2].tall and 128 or 64

	-- print("!!!!", id, shadow)
	for shadow, shadowdata in pairs(files[1]) do
		for shadowid = 1, shadowdata[2] do
			local shadow = shadow:format(shadowid)
			for trunk, trunkdata in pairs(files[2]) do
				for trunkid = 1, trunkdata[2] do
					local trunk = trunk:format(trunkid)
					if files[3] then for foilage, foilagedata in pairs(files[3]) do
						local mw, mh
						for i = foilagedata[1], foilagedata[2] do
							local foilage = foilage:format(i)
							local final = "terrain/trees-joined/"..id.."_"..trunk.."_"..foilage..".png"
							local shadow = "terrain/trees/"..id.."_"..shadow..".png"
							local trunk = "terrain/trees/"..id.."_"..trunk..".png"
							local foilage = "terrain/trees/"..id.."_"..foilage..".png"
							-- print("===!!!", foilage)
							local src = gd.createFromPng(foilage)
							mw, mh = src:sizeXY()
							print(("composite -gravity South %s %s tmp.png; composite -gravity South %s tmp.png %s; rm tmp.png"):format(trunk, foilage, shadow, final))
						end
						local range = ''
						if foilagedata[1] < foilagedata[2] then range = ('%d, %d, '):format(foilagedata[1], foilagedata[2]) end
						io.stderr:write('	{"'..id..'_'..trunk..'_'..foilage..'", '..range..'tall='..(mh > 64 and -1 or 0)..'},\n')
					end else
						-- print("===BAD", trunkid, id)
					end
				end
			end
		end
	end

	-- im:png("terrain/trees-joined/"..id..idx..".png")
	idx = idx + 1
end
