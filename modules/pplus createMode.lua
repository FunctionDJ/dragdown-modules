-- this is the only code from PPlus Move Card's createMode code that i couldn't
-- integrate into `Move Card CreateMode.lua` yet.

if mode.endlag == nil or mode.endlag == "..." then
		if mode.totalActive and tonumber(mode.totalDuration) then
			local catch = mysplit(mode.totalActive, ",")
			local catch2 = mysplit(catch[#catch], "-")
			if mode.iasa ~= nil then
				columnValues["endlag"] = mode.iasa - 1 - catch2[#catch2]
				if mode.endlag then
					columnValues["endlag"] = columnValues["endlag"] ..mode.endlag
				end
				mode.endlag = mode.iasa - 1 - catch2[#catch2]
			else
				columnValues["endlag"] = mode.totalDuration - catch2[#catch2]


				if mode.endlag then
					columnValues["endlag"] = columnValues["endlag"] ..mode.endlag
				end
				mode.endlag = mode.totalDuration - catch2[#catch2]
			end
		else
			columnValues["endlag"] = "N/A"
			mode.endlag = 0
		end
	end