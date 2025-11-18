local mysplit = require "mysplit"
---@diagnostic disable: lowercase-global

local function drawFrame(frames, frameType)
	local output = ""
	for i = 1, tonumber(frames) do
		local frameDataHtml = mw.html.create("div")
		frameDataHtml:addClass("frame-data frame-data-" .. frameType)
		frameDataHtml:done()
		output = output .. tostring(frameDataHtml)
	end
	return output
end

local function drawFrameData(s1, s2, s3, s4)
	currentFrame = 0

	html = mw.html.create("div")
	html:addClass("frameChart")

	-- Startup of move, substract 1 if startupIsFirstActive
	local totalStartup = 0
	local startup = {}
	if s1 == nil then
	elseif tonumber(s1) ~= nil then
		startup[1] = tonumber(s1)
		totalStartup = startup[1]
	elseif string.find(s1, "+") and not string.find(s1, "%[") then
		for _, v in ipairs(mysplit(s1, "+")) do
			table.insert(startup, v)
			totalStartup = totalStartup + v
		end
	elseif string.find(s1, "+") and string.find(s1, "%[") then
		-- for _, v in ipairs(mysplit(mysplit(s1, "[+")[2], " ]")) do
		-- 	table.insert(startup, v)
		-- 	totalStartup = totalStartup + v
		-- end
	end

	-- Active of move

	active = {}
	first_active_frame = totalStartup + 1
	counter = 1
	if s2 and s2 ~= "N/A" then
		-- s2 = "38...1-4"
		csplit = mysplit(s2, ",")
		ATL = #csplit
		for i = 1, ATL do
			hyphen = #(mysplit(csplit[i], "-"))
			startFrame = mysplit(csplit[i], "-")[1]

			if startFrame:find("...") then
				startFrame = mysplit(startFrame, "...")[1]
			end

			endFrame = mysplit(csplit[i], "-")[hyphen]

			-- error: comparing number with nil
			if tonumber(startFrame) > first_active_frame + 1 then
				active[counter] = -1 * (tonumber(startFrame) - first_active_frame - 1)
				counter = counter + 1
			end
			active[counter] = endFrame - startFrame + 1
			counter = counter + 1
			first_active_frame = tonumber(endFrame)
		end
	end

	local totalEndlag = 0
	local endlag = {}
	processedEndlag = s3
	if processedEndlag ~= nil then
		if string.sub(processedEndlag, -3) == "..." then
			processedEndlag = string.sub(processedEndlag, 1, -4)
		end
		if tonumber(processedEndlag) ~= nil then
			endlag[1] = processedEndlag
			totalEndlag = tonumber(endlag[1])
		elseif string.find(processedEndlag, "+") then
			for i = 1, #(mysplit(processedEndlag, "+")) do
				endlag[i] = mysplit(processedEndlag, "+")[i]
				-- if ('...')
				totalEndlag = totalEndlag + endlag[i]
			end
		end
	end
	-- Special Recovery of move
	local landingLag = s4
	if tonumber(landingLag) == nil then
		landingLag = 0
	end

	-- if active ~= nil then
	-- 	html:tag('div'):addClass('frameChart-FAF'):wikitext(active[1]):done()
	-- end

	-- Create container for frame data
	frameChartDataHtml = mw.html.create("div")
	frameChartDataHtml:addClass("frameChart-data")

	alt = false
	for i = 1, #startup do
		if not alt then
			frameChartDataHtml:wikitext(drawFrame(startup[i], "startup"))
		else
			frameChartDataHtml:wikitext(drawFrame(startup[i], "startup-alt"))
		end
		alt = not alt
	end

	-- Option for inputting multihits, works for moves with 1+ gaps in the active frames
	alt = false
	for i = 1, #active do
		if active[i] < 0 then
			frameChartDataHtml:wikitext(drawFrame(active[i] * -1, "inactive"))
			alt = false
		elseif not alt then
			frameChartDataHtml:wikitext(drawFrame(active[i], "active"))
			alt = not alt
		else
			frameChartDataHtml:wikitext(drawFrame(active[i], "active-alt"))
			alt = not alt
		end
	end
	alt = false
	for i = 1, #endlag do
		if not alt then
			frameChartDataHtml:wikitext(drawFrame(endlag[i], "endlag"))
		else
			frameChartDataHtml:wikitext(drawFrame(endlag[i], "endlag-alt"))
		end
		alt = not alt
	end
	frameChartDataHtml:wikitext(drawFrame(landingLag, "landingLag"))

	local fdtotal = mw.html.create("div"):addClass("frame-data-total")
	fdtotal:node(mw.html.create("span"):addClass("frame-data-total-label"):wikitext("First Active Frame:"))

	if s2 ~= nil then
		fdtotal:node(mw.html.create("span"):addClass("frame-data-total-value"):wikitext(totalStartup + 1))
	else
		fdtotal:node(mw.html.create("span"):addClass("frame-data-total-value"):wikitext("N/A"))
	end
	fdtotal:done()
	html:node(frameChartDataHtml)
	html:node(fdtotal):done()

	return tostring(html)
		.. mw.getCurrentFrame():extensionTag({
			name = "templatestyles",
			args = { src = "Module:FrameChart/styles.css" },
		})
end

return drawFrameData