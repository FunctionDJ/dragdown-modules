local mysplit = require "mysplit"
local drawFrameData = require "Move Card drawFrameData"
local showHitUniques= require "Move Card showHitUniques"

--- @param getHits function takes hasArticle,result,mode,hitData returns mw html element (table i guess)
--- @param config table config.iasa, config.autocancel, config.hitHeaders
local function createMode(
    hasArticle, mode, motherhits, hitresults, throwresults,
    getHits,
    config
)
	local columnHeaders = {
		tooltip(
			"Startup",
			'Startup or First Active Frame, the time it takes for an attack to become active. For example, a startup value of "10" means the hitbox or relevant property is active on the 10th frame.'
		),
		tooltip("Total Active", "Frames during which the move is active."),
		tooltip("Endlag", "The amount of frames where the move is no longer active."),
	}

    if config.iasa then
        table.insert(columnHeaders, tooltip(
			"IASA",
			"Interruptible as soon as, the effective range of the move. The full animation can sometimes last longer."
		))
    end

    table.insert(columnHeaders, tooltip("Total Duration", "Total animation length."))

	local frame = mw.getCurrentFrame()
	if mode.landingLag or mode.autocancel then
		columnHeaders = {
			tooltip(
				"Startup",
				'Startup or First Active Frame, the time it takes for an attack to become active. For example, a startup value of "10" means the hitbox or relevant property is active on the 10th frame.'
			),
			tooltip("Total Active", "Frames during which the move is active."),
			tooltip("Endlag", "The amount of frames where the move is no longer active."),
			tooltip(
				"Landing Lag",
				"The amount of frames that the character must wait after landing with this move before becoming actionable. ".. frame:preprocess("{{aerial}}") .." landing lag assumes that the move is L-cancelled."
			),
		}

		if config.autocancel then
			table.insert(columnHeaders, tooltip(
				"Autocancel",
				"Animation frames where the character lands with standard landing lag, typically much faster than landing regularly."
			))
		end

		if config.iasa then
			table.insert(columnHeaders, tooltip(
				"IASA",
				"Interruptible as soon as, the effective range of the move. The full animation can sometimes last longer."
			))
		end

		table.insert(columnHeaders, tooltip("Total Duration", "Total animation length."))		
	end

	local headersRow = mw.html.create("tr"):addClass("frame-window-header")
	for k, v in pairs(columnHeaders) do
		local cell = mw.html.create("th"):wikitext(v):done()
		headersRow:node(cell)
	end
	headersRow:done()

	local columnValues = {}

	local startupSum = 0

	columnValues["startup"] = "N/A"
	if mode.startup == nil then
		if mode.totalActive ~= nil then
			local processed_active = mode.totalActive -- "38...1-4"
			if string.find(processed_active, "+") then
				processed_active = mysplit(processed_active, "+")[1]
			end
			columnValues["startup"] = mysplit(mysplit(processed_active, ",")[1], "-")[1]

			local firstSplit = mysplit(processed_active, ",") -- ["38...1-4"]
			local firstAccess = firstSplit[1] -- "38...1-4"
			local secondSplit = mysplit(firstAccess, "-") -- ["38...1", "4"]
			local secondAccess = secondSplit[1] -- "38...1"

			if secondAccess:find("...") then
				mode.startup = mysplit(secondAccess, "...")[1] - 1
			else
				mode.startup = secondAccess - 1
			end
		else
			columnValues["startup"] = "N/A"
		end
	else
		if tonumber(mode.startup) then
			columnValues["startup"] = mode.startup + 1
			startupSum = mode.startup
		else
			columnValues["startup"] = mode.startup
			startupSum = mode.startup
		end
		if string.find(mode.startup, "+") and not string.find(mode.startup, "%[") then
			startupSum = 0
			for i in pairs(mysplit(mode.startup, "+")) do
				startupSum = startupSum + tonumber(mysplit(mode.startup, "+")[i])
			end

			columnValues["startup"] = tostring(startupSum + 1) .. " [" .. columnValues["startup"] .. "]"
		end
	end
	if mode.startupNotes then
		if mode.startupNotes == "SMASH" then
			columnValues["startup"] = columnValues["startup"]
				.. " "
				.. tooltip("ⓘ", "Total Uncharged Startup<br>[Pre-Charge Window + Post-Charge Window]")
		elseif mode.startupNotes == "RAPIDJAB" then
			columnValues["startup"] = columnValues["startup"]
				.. " "
				.. tooltip("ⓘ", "[+Rapid Jab Initial Startup] Rapid Jab Loop Startup")
		else
			columnValues["startup"] = columnValues["startup"] .. " " .. tooltip("ⓘ", mode.startupNotes)
		end
	end

	columnValues["totalActive"] = "N/A"
	if mode.totalActive then
		columnValues["totalActive"] = mode.totalActive
	end
	if mode.totalActiveNotes then
		columnValues["totalActive"] = columnValues["totalActive"] .. " " .. tooltip("ⓘ", mode.totalActiveNotes)
	end
	columnValues["endlag"] = mode.endlag
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
				local compensateValue = 0

				if mw.title.getCurrentTitle().rootText == "PPlus" then
					-- pplus totalDuration is currently bugged, hence this dirty fix
					compensateValue = -1
				end

				columnValues["endlag"] = mode.totalDuration - catch2[#catch2] + compensateValue
				mode.endlag = mode.totalDuration - catch2[#catch2] + compensateValue
			end
		else
			columnValues["endlag"] = "N/A"
			mode.endlag = 0
		end
	end
	if mode.endlag == "..." then
		columnValues["endlag"] = "''" .. columnValues["endlag"] .. "...'' " .. tooltip("ⓘ", "This character enters special fall after.") 
	end
	if mode.endlagNotes then
		columnValues["endlag"] = columnValues["endlag"] .. " " .. tooltip("ⓘ", mode.endlagNotes)
	end
	columnValues["landingLag"] = 'N/A'
	if mode.landingLag and mode.landingLag:sub(-1, -1) == "L" then
		columnValues["landingLag"] = tooltip(
			math.floor(mode.landingLag:sub(0, -2) / 2),
			"When not L-cancelled, this lasts " .. mode.landingLag:sub(0, -2) .. " frames."
		)
		mode.landingLag = math.floor(mode.landingLag:sub(0, -2) / 2)
	else
		columnValues["landingLag"] = mode.landingLag
	end
	if mode.landingLagNotes then
		columnValues["landingLag"] = columnValues["landingLag"] .. " " .. tooltip("ⓘ", mode.landingLagNotes)
	end

	if config.autocancel then
		columnValues["autocancel"] = "N/A"
		if mode.autocancel then
			columnValues["autocancel"] = mode.autocancel
		end
	end

	if mode.totalDuration == nil then
		local td_active = startupSum
		if mode.totalActive ~= nil then
			local _, _, p = mode.totalActive:reverse():find("(%d+)")
			if p ~= nil then
				td_active = p:reverse()
			end
		end
		local td_endlag = 0
		if mode.endlag ~= nil then
			td_endlag = mode.endlag
			if string.find(mode.endlag, "...") then
				td_endlag = nil
			elseif string.find(mode.endlag, "+") then
				td_endlag = 0
				for _, i in ipairs(mysplit(mode.endlag, "+")) do
					td_endlag = td_endlag + tonumber(i)
				end
			end
		end
		if tonumber(td_endlag) and tonumber(td_active) then
			mode.totalDuration = td_active + td_endlag
		end
	end

	if config.iasa then
		columnValues["iasa"] = "N/A"
		if mode.iasa then
			columnValues["iasa"] = mode.iasa
		elseif mode.totalDuration then
			columnValues["iasa"] = mode.totalDuration + 1
		end
	end

	columnValues["totalDuration"] = "N/A"
	if mode.totalDuration then
		columnValues["totalDuration"] = mode.totalDuration
	end
	if mode.totalDurationNotes then
		columnValues["totalDuration"] = columnValues["totalDuration"] .. " " .. tooltip("ⓘ", mode.totalDurationNotes)
	end
	local dataRow = mw.html.create("tr"):addClass("frame-window-data")
	local columnValuesTags = { "startup", "totalActive", "endlag" }

	if config.iasa then
		table.insert(columnValuesTags, "iasa")
	end

	table.insert(columnValuesTags, "totalDuration")

	if mode.landingLag or mode.autocancel then
		columnValuesTags = { "startup", "totalActive", "endlag", "landingLag" }

		if config.autocancel then
			table.insert(columnValuesTags, "autocancel")
		end

		if config.iasa then
			table.insert(columnValuesTags, "iasa")
		end

		table.insert(columnValuesTags, "totalDuration")
	end
	
	for k, v in ipairs(columnValuesTags) do
		local cell = mw.html.create("td")
		if columnValues[v] then
			if v == "endlag" and string.sub(columnValues[v], -3) == "..." then
				cell:tag("i"):wikitext(columnValues[v])
			elseif v == "cancel" then
				for i, v2 in pairs(columnValues[v]) do
					cell:tag("p"):wikitext(v2)
				end
			else
				cell:wikitext(columnValues[v])
			end
		else
			cell:wikitext("N/A")
		end
		cell:done()
		dataRow:node(cell)
	end

	dataRow:done()

	local t = mw.html
		.create("table")
		:addClass("frame-window wikitable ")
		:css("width", "100%")
		:css("text-align", "center")
		:node(headersRow)
		:node(dataRow)

	if mode.notes ~= nil then
		local notesRow = mw.html
			.create("tr")
			:addClass("notes-row")
			:tag("td")
			:css("text-align", "left")
			:attr("colspan", "100%")
			:wikitext("'''Notes:''' " .. mode.notes)
		t:node(notesRow)
	end
	t:done()

	local frameChart = mw.html.create("div"):addClass("frame-chart")

	if(mode.frameChart ~= nil) then
		if(mode.frameChart == 'N/A') then
			frameChart:wikitext("''This frame chart is currently unavailable and will be added at a later time.''"):done()
		else
			frameChart:wikitext(mode.frameChart):done()
		end
	else
		frameChart:wikitext(drawFrameData(mode.startup,mode.totalActive,mode.endlag,mode.landingLag)):done()
	end

	local numbersPanel = mw.html.create("div"):addClass("numbers-panel"):css("overflow-x","auto"):node(t):node(frameChart)
	if mode.hitID ~= nil then
		local headersHitRow = mw.html.create("tr")

		for k, v in pairs(config.hitHeaders) do
			local cell = mw.html.create("th"):wikitext(v):done()
			headersHitRow:node(cell)
		end

		local hitsWindow = mw.html.create("table"):addClass("wikitable hits-window"):node(headersHitRow)

		if hitresults ~= nil then
			for k, v in pairs(hitresults) do
				local hitData = nil

				if mw.title.getCurrentTitle().rootText == "PPlus" then
					hitData = motherhits[hitresults[k].attack .. "_" .. hitresults[k].hit_label]
				else
					hitData = motherhits[k]
				end

				hitsWindow:node(
					getHits(
						hasArticle,
						hitresults[k],
						mode,
						hitData
					)
				)

				local uniqueRow = showHitUniques(
					hasArticle, hitresults[k], hitData.unique
				)

				if uniqueRow then
					hitsWindow:tag("tr"):addClass("unique-row")
						:tag("td"):attr("colspan", 8):css("text-align", "left")
						:wikitext("'''Unique''': " .. uniqueRow):done()
				end
			end
		end
		numbersPanel:node(hitsWindow)
	end
	numbersPanel:done()
	return tostring(numbersPanel)
end

return {
    createMode = createMode
}