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
	"dreamy_mushroom_01_head_01.png",
	"dreamy_mushroom_01_head_02.png",
	"dreamy_mushroom_01_trunk.png",
	"dreamy_mushroom_02_head_01.png",
	"dreamy_mushroom_02_head_02.png",
	"dreamy_mushroom_02_head_03.png",
	"dreamy_mushroom_02_trunk.png",
	"dreamy_mushroom_03_head_01.png",
	"dreamy_mushroom_03_head_02.png",
	"dreamy_mushroom_03_head_03.png",
	"dreamy_mushroom_03_trunk.png",
	"dreamy_mushroom_04_head_01.png",
	"dreamy_mushroom_04_head_02.png",
	"dreamy_mushroom_04_trunk.png",
	"dreamy_mushroom_05_head_01.png",
	"dreamy_mushroom_05_head_02.png",
	"dreamy_mushroom_05_trunk.png",
	"dreamy_mushroom_06_head_01.png",
	"dreamy_mushroom_06_head_02.png",
	"dreamy_mushroom_06_trunk.png",
	"dreamy_mushroom_07_head_01.png",
	"dreamy_mushroom_07_head_02.png",
	"dreamy_mushroom_07_head_03.png",
	"dreamy_mushroom_07_head_04.png",
	"dreamy_mushroom_07_trunk.png",
	"dreamy_mushroom_08_head_01.png",
	"dreamy_mushroom_08_head_02.png",
	"dreamy_mushroom_08_head_03.png",
	"dreamy_mushroom_08_head_04.png",
	"dreamy_mushroom_08_trunk.png",
	"dreamy_mushroom_09_head_01.png",
	"dreamy_mushroom_09_head_02.png",
	"dreamy_mushroom_09_trunk.png",
	"dreamy_mushroom_10_head_01.png",
	"dreamy_mushroom_10_head_02.png",
	"dreamy_mushroom_10_trunk.png",
	"dreamy_mushroom_11_head_01.png",
	"dreamy_mushroom_11_head_02.png",
	"dreamy_mushroom_11_trunk.png",
	"gloomy_mushroom_01_head_01.png",
	"gloomy_mushroom_01_head_02.png",
	"gloomy_mushroom_01_trunk.png",
	"gloomy_mushroom_02_head_01.png",
	"gloomy_mushroom_02_head_02.png",
	"gloomy_mushroom_02_head_03.png",
	"gloomy_mushroom_02_trunk.png",
	"gloomy_mushroom_03_head_01.png",
	"gloomy_mushroom_03_head_02.png",
	"gloomy_mushroom_03_head_03.png",
	"gloomy_mushroom_03_trunk.png",
	"gloomy_mushroom_04_head_01.png",
	"gloomy_mushroom_04_head_02.png",
	"gloomy_mushroom_04_trunk.png",
	"gloomy_mushroom_05_head_01.png",
	"gloomy_mushroom_05_head_02.png",
	"gloomy_mushroom_05_trunk.png",
	"gloomy_mushroom_06_head_01.png",
	"gloomy_mushroom_06_head_02.png",
	"gloomy_mushroom_06_trunk.png",
	"gloomy_mushroom_07_head_01.png",
	"gloomy_mushroom_07_head_02.png",
	"gloomy_mushroom_07_head_03.png",
	"gloomy_mushroom_07_head_04.png",
	"gloomy_mushroom_07_trunk.png",
	"gloomy_mushroom_08_head_01.png",
	"gloomy_mushroom_08_head_02.png",
	"gloomy_mushroom_08_head_03.png",
	"gloomy_mushroom_08_head_04.png",
	"gloomy_mushroom_08_trunk.png",
	"gloomy_underground_floor1.png",
	"gloomy_underground_floor2.png",
	"gloomy_underground_floor3.png",
	"gloomy_underground_floor4.png",
	"gloomy_underground_floor5.png",
	"gloomy_underground_floor6.png",
	"gloomy_underground_floor7.png",
	"gloomy_underground_floor8.png",
	"gloomy_underground_floor.png",
	"slimy_mushroom_01_head_01.png",
	"slimy_mushroom_01_head_02.png",
	"slimy_mushroom_01_trunk.png",
	"slimy_mushroom_02_head_01.png",
	"slimy_mushroom_02_head_02.png",
	"slimy_mushroom_02_head_03.png",
	"slimy_mushroom_02_trunk.png",
	"slimy_mushroom_03_head_01.png",
	"slimy_mushroom_03_head_02.png",
	"slimy_mushroom_03_head_03.png",
	"slimy_mushroom_03_trunk.png",
	"slimy_mushroom_04_head_01.png",
	"slimy_mushroom_04_head_02.png",
	"slimy_mushroom_04_trunk.png",
	"slimy_mushroom_05_head_01.png",
	"slimy_mushroom_05_head_02.png",
	"slimy_mushroom_05_trunk.png",
	"slimy_mushroom_06_head_01.png",
	"slimy_mushroom_06_head_02.png",
	"slimy_mushroom_06_trunk.png",
	"slimy_mushroom_07_head_01.png",
	"slimy_mushroom_07_head_02.png",
	"slimy_mushroom_07_head_03.png",
	"slimy_mushroom_07_head_04.png",
	"slimy_mushroom_07_trunk.png",
	"slimy_mushroom_08_head_01.png",
	"slimy_mushroom_08_head_02.png",
	"slimy_mushroom_08_head_03.png",
	"slimy_mushroom_08_head_04.png",
	"slimy_mushroom_08_trunk.png",
	"small_dreamy_mushroom_01_head_01.png",
	"small_dreamy_mushroom_01_head_02.png",
	"small_dreamy_mushroom_01_trunk.png",
	"small_dreamy_mushroom_02_head_01.png",
	"small_dreamy_mushroom_02_head_02.png",
	"small_dreamy_mushroom_02_head_03.png",
	"small_dreamy_mushroom_02_head_04.png",
	"small_dreamy_mushroom_02_head_05.png",
	"small_dreamy_mushroom_02_head_06.png",
	"small_dreamy_mushroom_02_trunk.png",
	"small_dreamy_mushroom_03_head_01.png",
	"small_dreamy_mushroom_03_head_02.png",
	"small_dreamy_mushroom_03_head_03.png",
	"small_dreamy_mushroom_03_head_04.png",
	"small_dreamy_mushroom_03_head_05.png",
	"small_dreamy_mushroom_03_trunk.png",
	"small_dreamy_mushroom_04_head_01.png",
	"small_dreamy_mushroom_04_head_02.png",
	"small_dreamy_mushroom_04_head_03.png",
	"small_dreamy_mushroom_04_trunk.png",
	"small_gloomy_mushroom_01_head_01.png",
	"small_gloomy_mushroom_01_head_02.png",
	"small_gloomy_mushroom_01_trunk.png",
	"small_gloomy_mushroom_02_head_01.png",
	"small_gloomy_mushroom_02_head_02.png",
	"small_gloomy_mushroom_02_head_03.png",
	"small_gloomy_mushroom_02_head_04.png",
	"small_gloomy_mushroom_02_head_05.png",
	"small_gloomy_mushroom_02_head_06.png",
	"small_gloomy_mushroom_02_trunk.png",
	"small_gloomy_mushroom_03_head_01.png",
	"small_gloomy_mushroom_03_head_02.png",
	"small_gloomy_mushroom_03_head_03.png",
	"small_gloomy_mushroom_03_head_04.png",
	"small_gloomy_mushroom_03_head_05.png",
	"small_gloomy_mushroom_03_trunk.png",
	"small_gloomy_mushroom_04_head_01.png",
	"small_gloomy_mushroom_04_head_02.png",
	"small_gloomy_mushroom_04_head_03.png",
	"small_gloomy_mushroom_04_trunk.png",
	"small_slimy_mushroom_01_head_01.png",
	"small_slimy_mushroom_01_head_02.png",
	"small_slimy_mushroom_01_trunk.png",
	"small_slimy_mushroom_02_head_01.png",
	"small_slimy_mushroom_02_head_02.png",
	"small_slimy_mushroom_02_head_03.png",
	"small_slimy_mushroom_02_head_04.png",
	"small_slimy_mushroom_02_head_05.png",
	"small_slimy_mushroom_02_head_06.png",
	"small_slimy_mushroom_02_trunk.png",
	"small_slimy_mushroom_03_head_01.png",
	"small_slimy_mushroom_03_head_02.png",
	"small_slimy_mushroom_03_head_03.png",
	"small_slimy_mushroom_03_head_04.png",
	"small_slimy_mushroom_03_head_05.png",
	"small_slimy_mushroom_03_trunk.png",
	"small_slimy_mushroom_04_head_01.png",
	"small_slimy_mushroom_04_head_02.png",
	"small_slimy_mushroom_04_head_03.png",
	"small_slimy_mushroom_04_trunk.png",
}

local matches = { "shadow", "waterripples", "roots_mist", "trunk", "head" }
local bases = { {"trunk"}, {""} }

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

	for trunk, trunkdata in pairs(files[1]) do
		for trunkid = 1, trunkdata[2] do
			local trunk = trunk:format(trunkid)
			if files[2] then for foilage, foilagedata in pairs(files[2]) do
				local mw, mh
				for i = foilagedata[1], foilagedata[2] do
					local foilage = foilage:format(i)
					local final = "terrain/mushrooms-joined/"..id.."_"..trunk.."_"..foilage..".png"
					local trunk = "terrain/mushrooms/"..id.."_"..trunk..".png"
					local foilage = "terrain/mushrooms/"..id.."_"..foilage..".png"
					-- print("===!!!", foilage)
					local src = gd.createFromPng(foilage)
					mw, mh = src:sizeXY()
					print(("composite -gravity South %s %s %s"):format(trunk, foilage, final))
				end
				local range = ''
				if foilagedata[1] < foilagedata[2] then range = ('%d, %d, '):format(foilagedata[1], foilagedata[2]) end
				io.stderr:write('	{"'..id..'_'..trunk..'_'..foilage..'", '..range..'tall='..(mh > 64 and -1 or 0)..'},\n')
			end else
				-- print("===BAD", trunkid, id)
			end
		end
	end

	-- im:png("terrain/trees-joined/"..id..idx..".png")
	idx = idx + 1
end
