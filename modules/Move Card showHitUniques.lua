local mysplit = require "mysplit"
local function showHitUniques(hasArticle, result, unique)
	local game = mw.title.getCurrentTitle().rootText

	local listOfUniques = {}

	if unique ~= nil then
		local uniquesList = mysplit(unique, "\\")
		for k, v in pairs(uniquesList) do
			table.insert(listOfUniques, v)
		end
	end

    if game ~= "AFQM" then
        if tonumber(result.DirectionalInfluenceMultiplier ) ~= 1 then
            table.insert(listOfUniques, "DI: " .. result.DirectionalInfluenceMultiplier .. '×')
        end
        
        if tonumber(result.SmashDirectionalInfluenceMultiplier ) ~= 1 then
            table.insert(listOfUniques, "DI: " .. result.SmashDirectionalInfluenceMultiplier .. '×'  )
        end
        
        if tonumber(result.HitStunMinimum ) ~= 1 then
            table.insert(listOfUniques, "Min Hitstun: " .. result.HitStunMinimum)
        end
        if tonumber(result.HitStunMultiplier  ) ~= 1 then
            table.insert(listOfUniques, "Hitstun: " .. result.HitStunMultiplier  .. '×'  )
        end
    end
	
	if #listOfUniques <= 0 then
		return nil
	else
		return table.concat(listOfUniques, ", ")
	end
end

return showHitUniques