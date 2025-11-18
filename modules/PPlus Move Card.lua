---@diagnostic disable: need-check-nil, lowercase-global
local p = {}
local mArguments
local utils = require("Move Card Utils")
local tabber = require("Tabber").renderTabber
local tooltip = require("Tooltip")
local cargo = mw.ext.cargo
local weightObject = cargo.query("PPlus_CharacterData", "chara, Weight", { orderBy = "Weight" })

local modeConfig = {
  hitHeaders = {
			tooltip(
				"Hit / Hitbox",
				"Which hit timing (such as early or late), or hitbox (such as sweetspot or sourspot) of this move that the data to the right is referring to."
			),
			tooltip("Damage", "The raw damage percent value of the listed move/hit."),
			tooltip("Active Frames", "Which frames a move is active and can affect opponents."),
			tooltip(
				"BKB",
				"Base knockback - this determines the general strength of knockback the move will deal across all percents."
			),
			tooltip(
				"KBG",
				"Knockback growth - this determines how much knockback generally increases at higher percents."
			),
			tooltip(
				"WDSK",
				"Fixed knockback - when not 0, moves will deal weight-dependent set knockback."
			),
			tooltip("Angle", "The angle at which the move sends the target."),
			tooltip(
				"Tumble",
				"The pre-hit percent that this hit tumbles and knocks down at, from the lightest to the heaviest character. N/A means that the hit can never tumble.<br>If the move is weight dependent set knockback, a maximum weight for tumbling will be displayed instead. Characters with this weight or lower will enter tumble."
			),
			tooltip(
				"Shield Safety",
				"The frame advantage after a move connects on shield. If a move ends prematurely with landing lag like an aerial, the shield safety assumes that the character lands immediately after performing the hit."
			),
		}
}

local function readModes(chara, attack)
	return cargo.query(
		"PPlus_MoveMode",
		"chara, attack, attackID, mode, startup, startupNotes, totalActive, "
		.."totalActiveNotes, endlag, endlagNotes, cancel, cancelNotes, landingLag, "
		.."landingLagNotes, totalDuration, totalDurationNotes,iasa,autocancel,"
		.."autocancelNotes,hitID,hitSubactionID,hitName,hitActive,customShieldSafety,"
		.."uniqueField,frameChart, articleID, notes",
		{
			where = 'PPlus_MoveMode.chara="' .. chara .. '" and PPlus_MoveMode.attack="' .. attack .. '"',
			orderBy = "_ID",
		}
	)
end

local getImagesWikitext = require("GetImagesWikitext")

local function mysplit(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	if inputstr == nil then
		return nil
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

local function calcTumblePercent(bkb, kbg, weight, dmg, crouch)
	local tumbleThreshold = 80
	local crouchThreshold = 120
	local realTumbleThreshold = tumbleThreshold
	if crouch then
		realTumbleThreshold = crouchThreshold
	end

	if kbg == 0 then
		if bkb > realTumbleThreshold then
			return 0
		else
			return "N/A"
		end
	else
		return math.max(
			0,
			math.ceil(
				((((realTumbleThreshold - bkb) / (kbg / 100)) - 18) / ((200 / (weight + 100)) * 1.4)) / (dmg * 0.05 + 0.1)
			) - dmg
		)
	end
end

local function calcWDSKWeight(wdsk, bkb, kbg, crouch)
	local tumbleThreshold = 80
	local crouchThreshold = 120
	local realTumbleThreshold = tumbleThreshold
	if crouch then
		realTumbleThreshold = crouchThreshold
	end
	
	if kbg == 0 then
		return math.floor((1 / ((80 - bkb)/ -18)) * ((((wdsk * 10 * 0.05) + 1) * 1.4)) * 200 - 100)
	else
		return math.floor((1 / ((80 - bkb)/(kbg * 0.01) - 18)) * ((((wdsk * 10 * 0.05) + 1) * 1.4)) * 200 - 100)
	end
end

local function calcSimpleTumble(result)
	local d = tonumber(result.damage)
	local bkb = tonumber(result.bkb)
	local kbg = tonumber(result.kbg)
	local wdsk = tonumber(result.wdsk)

	local minWeight = 64 -- Puff Weight
	local maxWeight = 113 -- Bowser Weight

	if wdsk ~= 0 then
		if calcWDSKWeight(wdsk, bkb, kbg, false) < minWeight then
			return "Never"
		else 
			return "Weight: " .. calcWDSKWeight(wdsk, bkb, kbg, false)	
		end
		
	elseif calcTumblePercent(bkb, kbg, minWeight, d, false) == "N/A" then
		return "N/A"
	elseif calcTumblePercent(bkb, kbg, minWeight, d, false) == calcTumblePercent(bkb, kbg, maxWeight, d, false) then
		return calcTumblePercent(bkb, kbg, minWeight, d, false)
			.. "%"
	else
		return calcTumblePercent(bkb, kbg, minWeight, d, false)
			.. " - "
			.. calcTumblePercent(bkb, kbg, maxWeight, d, false)
			.. "%"
	end
end

local function calcFullTumble(result, crouch, throw, name)
	local d, bkb, kbg = result.Damage, result.BaseKnockback, tonumber(result.KnockbackScaling)
	local angle = tonumber(result.KnockbackAngle)
	local flipper = result.KnockbackAngleMode

	local row = mw.html.create("tr")

	local percents = {}

	local lWeight = weightObject

	if result.ForceTumble == "True" then
		row:tag("td"):wikitext(name)
		row:tag("td"):wikitext("This hit forces tumble."):attr("colspan", #lWeight + 1)
		row:done()
		return tostring(row)
	end

	if result.bIgnoresWeight == "True" or throw or kbg == 0 then
		row:tag("td"):wikitext(name)
		row:tag("td")
			:wikitext(calcTumblePercent(bkb, kbg, 100, d, crouch, angle, flipper) .. "%")
			:attr("colspan", #lWeight + 1)
		row:done()
		return tostring(row)
	else
		for k, v in ipairs(lWeight) do
			table.insert(percents, (calcTumblePercent(bkb, kbg, v.Weight, d, crouch, angle, flipper)))
		end
		-- Armoured Etalus Weight
		table.insert(percents, (calcTumblePercent(bkb, kbg, 150, d, crouch, angle, flipper)))
	end
	row:tag("td"):wikitext(name)
	row:tag("td"):wikitext(percents[1] .. " - " .. percents[#percents - 1] .. "%")
	for k, v in ipairs(percents) do
		if v ~= "N/A" then
			row:tag("td"):wikitext(v .. "%")
		else
			row:tag("td"):wikitext(v)
		end
	end
	row:done()
	return tostring(row)
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

local function calcShieldSafety(result, mode, active, custom)
	if
		mode.attackID == "Bthrow"
		or mode.attackID == "Uthrow"
		or mode.attackID == "Dthrow"
		or mode.attackID == "Fthrow"
		or mode.attackID == "Grab"
		or mode.attackID == "Pummel"
	then
		return "N/A"
	end

	if custom == "N/A" then
		return "N/A"
	end
	if mode.endlag == "..." then
		return "N/A"
	end
	if custom ~= nil and custom ~= "JAB" and custom ~= "-" then
		return custom
	end
	
	if tonumber(mode.totalDuration) then
		local stun = math.floor(result.damage * 0.447 + 1.99)
		
		if active:sub(-1, -1) == "+" and tonumber(active:sub(1, #active-1)) and tonumber(mode.totalActive) then  -- PROJECTILES
			local endlag = mode.totalDuration - tonumber(active:sub(1, #active-1))
			if mode.iasa then
				endlag = mode.iasa - tonumber(active:sub(1, #active-1))
			end
			local hitLag = math.floor(result.damage * 0.3333334 + 3)
			return string.format("At worst: %+d", hitLag + stun - endlag)
		end
		
		local active1 = mysplit(active, ", ")
		active1 = active1[#active1]
		local active2 = mysplit(active1, "-")
		local first = mode.totalDuration - active2[1] -- problem: active2[1] = "...1"
		local second = mode.totalDuration - active2[#active2]
		if mode.iasa then
			first = mode.iasa - active2[1]
			second = mode.iasa - active2[#active2]
		end

		if mode.landingLag ~= nil then
			local realLandingLag = mode.landingLag
			if tonumber(mode.landingLag) == nil and  mode.landingLag:sub(-1, -1) == "L" then
				realLandingLag = math.floor(mode.landingLag:sub(0, -2) / 2)
			end

			return string.format("%+d", stun - realLandingLag)

		else
			if first == second then
				return string.format("%+d", stun - first)
			else
				return string.format("%+d to %+d", stun - first, stun - second)
			end
		end
	else
		return "N/A"
	end
end


local function showHitUniques(hasArticle, result, unique)
	local listOfUniques = {}

	if unique ~= nil then
		local uniquesList = mysplit(unique, "\\")
		for k, v in pairs(uniquesList) do
			table.insert(listOfUniques, v)
		end
	end

	if tonumber(result.shield_damage)  ~= 0 then
		table.insert(listOfUniques, "Shield Damage: " .. result.shield_damage)
	end
	
	if tonumber(result.hitlag_mult) ~= 1 then
		table.insert(listOfUniques, tooltip("Hitlag","Applies to only the defender.") .. ": " .. result.hitlag_mult )
	end
	
	if tonumber(result.sdi_mult) ~= 1 then
		table.insert(listOfUniques, "SDI: " .. result.sdi_mult )
	end
	
	if result.hitbox_effect == "Electric" then
		table.insert(listOfUniques, result.hitbox_effect)
	end
	
	if result.ground == "False" and result.aerial ~= "False" then
		table.insert(listOfUniques, "Airborne Only")
	end
	if result.ground ~= "False" and result.aerial == "False"  then
		table.insert(listOfUniques, "Grounded Only")
	end
	if result.clang == "False" then
		table.insert(listOfUniques, "Transcendent")
	end
	if result.can_be_shielded  == "False" then
		table.insert(listOfUniques, "Unshieldable")
	end
	if result.can_be_reflected  == "True" then
		table.insert(listOfUniques, "Reflectable")
	end
	if result.can_be_absorbed  == "True" then
		table.insert(listOfUniques, "Absorbable")
	end

	if #listOfUniques <= 0 then
		return nil
	else
		return table.concat(listOfUniques, ", ")
	end
	return
end

local function getArticles(articleData)
	local fields =
		"ArticleName,bIsProjectile,bRotateWithVelocity,bInheritOwnerChargeValue,bIsAttachedToOwner,ParryReaction,HasHitReaction,GotHitReaction,bCanBeHitByOwner,bCanDetectOwner,GroundCollisionResponse,WallCollisionResponse,CeilingCollisionResponse,ShouldGetOutOfGroundOnSpawn"

	local hitRow = mw.html.create("tr")
	for k, v in ipairs(mysplit(fields, ",")) do
		local assignedValue = firstToUpper(articleData[v])
		if assignedValue == nil then
			assignedValue = "N/A"
		end
		local cell = mw.html.create("td"):wikitext(assignedValue):done()
		hitRow:node(cell)
	end

	hitRow:done()
	return hitRow
end

local function getHits(hasArticle, result, mode, hitData)
	--chara, attackID, hitID, hitMoveID, hitName, hitActive, customShieldSafety, uniques
	local hitRow = mw.html.create("tr"):addClass("hit-row")
	if(tonumber(hitData.name)) then
		hitRow:tag("td"):wikitext(result.seq_hit_set)
	else
		hitRow:tag("td"):wikitext(hitData.name)
	end
	hitRow:tag("td"):wikitext(result.damage .. "%")
		:tag("td"):wikitext(hitData.active)
		:tag("td"):wikitext(result.bkb)
		:tag("td"):wikitext(result.kbg)
		:tag("td"):wikitext(result.wdsk)
		:tag("td"):wikitext(makeAngleDisplay(result.trajectory, result.angle_flipping))
		:tag("td"):wikitext(calcSimpleTumble(result))
		-- :tag("td"):wikitext("T")
		:tag("td"):wikitext(calcShieldSafety(result, mode, hitData.active, hitData.shield))
		:done()
	return hitRow
end

local function getThrows(result, mode, hitData)
	local hitRow = mw.html.create("tr")
	hitRow
		:tag("td")
		:wikitext(hitData.name)
		:tag("td")
		:wikitext(result.Damage .. "%")
		:tag("td")
		:wikitext(hitData.active)
		:tag("td")
		:wikitext(string.format("%.1f", result.BaseKnockback) .. " + " .. result.KnockbackScaling)
		:tag("td")
		:wikitext(utils.makeAngleDisplay(result.KnockbackAngle))
		:tag("td")
		:wikitext(calcSimpleTumble(result))
		:tag("td")
		:wikitext("N/A")
		:tag("td")
		:wikitext(showThrowUniques(result, hitData.unique))
		:done()
	return hitRow
end

local function getAdvHits(result, mode, hitData, articleData)
	--chara, attackID, hitID, hitMoveID, hitName, hitActive, customShieldSafety, uniques

	local columns = "name,hitlag_mult,shield_stun,shield_damage,shield_kb,shield_hitlag,sdi_mult,hitbox_effect,ground,aerial,clang,angle_flipping,hits_fighters,waddle_dee,sse,saturn,wall_hit,stage_misc_hit,bomb,can_be_shielded,can_be_reflected,can_be_absorbed,remain_grabbed,enabled,ignore_invincibility,freeze_frame_disable,flinchless"

	local hitRow = mw.html.create("tr")
	for k, v in ipairs(mysplit(columns, ",")) do
		local assignedValue = ""
		if v == "hitlag_mult" then
			assignedValue = math.floor(result.damage * 0.3333334 + 3)
			if hitbox_effect == 'Electric' then
				assignedValue = math.floor(assignedValue * 1.5)	
			end
			assignedValue = math.floor(assignedValue * result.hitlag_mult)
		elseif v == "sdi_mult" then
			assignedValue = result.sdi_mult .. "×"
		elseif v == "shield_stun" then
			assignedValue = math.floor(result.damage * 0.447 + 1.99)
		elseif v == "shield_damage" then
			assignedValue = result.damage
		elseif v == "shield_kb" then
			assignedValue = "Shield KB?"
		elseif v == "name" then
			assignedValue = hitData.name
		else
			assignedValue = result[v]
		end
		local cell = mw.html.create("td"):wikitext(assignedValue):done()
		hitRow:node(cell)
	end

	hitRow:done()
	return hitRow
end

local function getAdvThrows(result, mode, hitData)
	local fields = "HitstunMultiplier,bTechable,ForceTumble,HitstunAnimationStateOverride,ReleaseOffset"

	local hitRow = mw.html.create("tr")
	hitRow:node(mw.html.create("td"):wikitext(hitData.name))

	for k, v in ipairs(mysplit(fields, ",")) do
		local assignedValue = ""
		if v == "HitstunMultiplier" then
			assignedValue = result[v] .. "×"
		else
			assignedValue = result[v]
		end
		local cell = mw.html.create("td"):wikitext(assignedValue):done()
		hitRow:node(cell)
	end

	hitRow:done()
	return hitRow
end



local function createAdvMode(mode, articleList, motherhits, hitresults, throwresults)
	local finalreturn = mw.html.create("div")
	
	if hitresults ~= nil and #(hitresults) ~= 0 then
		local nerdHeader = mw.html
			.create("div")
			:addClass("toccolours mw-collapsible")
			:css("width", "100%")
			:css("overflow", "auto")
			:css("margin", "1em 0")
			:done()
		local nerdTitle = mw.html
			.create("div")
			:css("font-weight", "bold")
			:css("line-height", "1.6")
			:wikitext("'''Hits: Advanced Data'''")
			:done()
		local c1 = mw.html.create("div"):addClass("mw-collapsible-content")

		local columnHeaders = {
			"Hit / Hitbox ",
			"Hitlag",
			"Shield Stun",
			"Shield Damage",
			"Shield Knockback",
			"Shield Hitlag",
			"SDI Multiplier",
			"Hitbox Effect",
			"Hits Grounded?",
			"Hits Airborne?",
			"Clanks?",
			"Angle Flipping",
			"Hits Characters",
			tooltip("Hits Dees", "Includes Waddle Dees, Waddle Doos, and Pikmin."),
			tooltip("Hits SSE Enemies", "Subspace Emissary. Irrelevant to competitive play."),
			tooltip("Hits Saturn", "Hits Mr Saturn, Snake C4, and Grenade."),
			"Hits Wall, Floor, Ceilings",
			"Hits Other Stage Elements",
			tooltip("Hits Bombs", "Hits Link and Toon Link's bomb, as well as Bo-Bombs."),
			"Can Be Shielded?",
			"Can Be Reflected?",
			"Can Be Absorbed?",
			"Remain Grabbed?",
			"Enabled?",
			"Ignores Invincibility?",
			"Disables Hitlag?",
			"Flinchless?",
		}

		local headersRow = mw.html.create("tr"):addClass("adv-hits-list-header")
		for k, v in pairs(columnHeaders) do
			local cell = mw.html.create("th"):wikitext(v):done()
			headersRow:node(cell)
		end
		headersRow:done()
		local hitsWindow = mw.html.create("table"):addClass("hits-window wikitable"):node(headersRow)

		for k, v in ipairs(hitresults) do
			hitsWindow:node(getAdvHits(hitresults[k], mode, motherhits[hitresults[k].attack .. "_" .. hitresults[k].hit_label], articleList))
			-- tumbleTable:node(calcFullTumble(hitresults[k], false, false, motherhits[hitresults[k].moveID .. hitresults[k].nameID].name))
			-- CCTable:node(calcFullTumble(hitresults[k], true, false, motherhits[hitresults[k].moveID .. hitresults[k].nameID].name))
		end
		c1:node(hitsWindow):done()
		nerdHeader:node(nerdTitle):node(c1)
		finalreturn:node(nerdHeader)
	end

	
	finalreturn:done()

	return tostring(finalreturn)
end



local function getCardHTML(chara, attack, desc, advDesc)
	-- Lazy Load automated frame chart generator
	-- local autoChart = require('FrameChart').autoChart
	-- Outer Container of the card
	local card = mw.html.create("div"):addClass("attack-container")

	-- Images
	local acquiredImages = utils.getImageGallery(chara, attack)
	local tabberData
	if acquiredImages ~= '<div class="attack-gallery-image"></div>' then
		tabberData = tabber({
			label1 = "Images",
			content1 = utils.getImageGallery(chara, attack),
			-- label2 = "Hitboxes",
			-- content2 = getHitboxGallery(chara, attack),
		})
	else
		local container = mw.html.create("div"):addClass("attack-gallery-image")
		container:wikitext(
			table.concat(
				getImagesWikitext({
					{
						file = "PPlus_" .. chara .. "_" .. attack .. "_0.png",
						caption = "NOTE: This is an incomplete card, with data modes planning to be uploaded in the future.",
					},
				})
			)
		)

		tabberData = tabber({
			label1 = "Images",
			content1 = tostring(container),
			-- label2 = "Hitboxes",
			-- content2 = getHitboxGallery(chara, attack),
		})
	end

	local imageDiv = mw.html.create("div"):addClass("attack-gallery"):wikitext(tabberData):done()

	local paletteSwap = mw.html.create("div"):addClass("data-palette"):done()

	local description =
		mw.html.create("div"):addClass("move-description"):wikitext("\n"):wikitext(desc):wikitext("\n"):allDone()

	local nerdHeader = mw.html
		.create("div")
		:addClass("mw-collapsible mw-collapsed")
		:css("width", "100%")
		:css("overflow", "auto")
		:css("margin", "1em 0")
		:attr("data-expandtext", "Show Stats for Nerds")
		:attr("data-collapsetext", "Hide Stats for Nerds")
		:done()
	local nerdSection =
		mw.html.create("div"):addClass("mw-collapsible-content"):node(mw.html.create("br"):css("clear", "both"))

	nerdSection:node(mw.html.create("div"):wikitext(advDesc))

	local tableData = readModes(chara, attack)
	if #tableData > 1 then
		local object = {}
		local advObject = {}
		for i in pairs(tableData) do
			local mode = tableData[i]
			local hits = {}
			local hit_results = nil
			local throw_results = nil
			if mode.hitID ~= nil then
				local idList = mysplit(mode.hitID, ";")
				local hitMoves = mysplit(mode.hitSubactionID, ";")
				local names = mysplit(mode.hitName, ";")
				local actives = mysplit(mode.hitActive, ";")
				local shieldSafetyList = mysplit(mode.customShieldSafety, ";")
				local uniquesList = mysplit(mode.uniqueField, ";")
				for k in ipairs(idList) do
					local attack = mode.attackID
					if hitMoves ~= nil then
						attack = hitMoves[k]
					end
					local v = idList[k]
					hits[attack .. "_" .. v] = {}
					hits[attack .. "_" .. v]["hitID"] = idList[k]
					hits[attack .. "_" .. v]["move"] = attack
					hits[attack .. "_" .. v]["name"] = idList[k]
					if names ~= nil then
						hits[attack .. "_" .. v]["name"] = names[k]
					end
					hits[attack .. "_" .. v]["active"] = actives[k]
					hits[attack .. "_" .. v]["shield"] = nil
					if shieldSafetyList ~= nil then
						hits[attack .. "_" .. v]["shield"] = shieldSafetyList[k]
					end
					hits[attack .. "_" .. v]["unique"] = nil
					if uniquesList ~= nil and uniquesList[k] ~= "-" then
						hits[attack .. "_" .. v]["unique"] = uniquesList[k]
					end
				end

				local tables = "PPlus_HitData"
				local fields =
					"chara,attack,hit_label,seq_hit_set,damage,trajectory,wdsk,kbg,bkb,shield_damage,hitlag_mult,sdi_mult,hitbox_effect,sound,ground,aerial,clang,special_hit,angle_flipping,hits_fighters,waddle_dee,sse,saturn,wall_hit,stage_misc_hit,bomb,can_be_shielded,can_be_reflected,can_be_absorbed,remain_grabbed,enabled,ignore_invincibility,freeze_frame_disable,flinchless"

				local whereField = 'chara="' .. mode.chara .. '" and ('
				local whereList = {}
				for k, v in pairs(hits) do
					table.insert(whereList, '(attack = "' .. v["move"] .. '" and hit_label = "' .. v["hitID"] .. '")')
				end
				local whereField = whereField .. table.concat(whereList, " or ") .. ")"
				local args = { where = whereField, orderBy = "_ID" }
				hit_results = cargo.query(tables, fields, args)
				-- hitsWindow:wikitext(dump(args))

				local whereList = {}
				for k, v in pairs(hits) do
					table.insert(whereList, '(attack = "' .. v["move"] .. '")')
				end
				if #whereList > 0 then
					local tables = "PPlus_ThrowData"
					local fields =
						"chara, attack, sequence_num, throw_use, hitbox_effect, damage, trajectory, wdsk, kbg, bkb, grab_target, throw_i_frames"

					local whereField = 'chara="' .. mode.chara .. '" and ('
					whereField = whereField .. table.concat(whereList, " or ") .. ")"
					local args = { where = whereField, orderBy = "_ID" }
					throw_results = cargo.query(tables, fields, args)
				end

				-- if mode.articleID ~= nil then
				-- 	local tables = "PPlus_Articles"
				-- 	local fields =
				-- 		"chara,moveID,ArticleName,bIsProjectile,bRotateWithVelocity,bInheritOwnerChargeValue,bIsAttachedToOwner,ParryReaction,HasHitReaction,GotHitReaction,bCanBeHitByOwner,bCanDetectOwner,GroundCollisionResponse,WallCollisionResponse,CeilingCollisionResponse,ShouldGetOutOfGroundOnSpawn"

				-- 	local whereField = 'chara="' .. chara .. '" and ('
				-- 	local whereList = {}
				-- 	for _, v in pairs(mysplit(mode.articleID, ";")) do
				-- 		table.insert(whereList, '(moveID = "' .. v .. '")')
				-- 	end
				-- 	local whereField = whereField .. table.concat(whereList, " or ") .. ")"
				-- 	local args = { where = whereField, orderBy = "ArticleName" }
				-- 	articleList = cargo.query(tables, fields, args)
				-- end
			end
			object["label" .. i] = tableData[i].mode
			object["content" .. i] = createMode(mode.articleID ~= nil, tableData[i], hits, hit_results, throw_results)
			-- object["content" .. i] = createMode(tableData[i], hits, hit_results, throw_results)
			advObject["label" .. i] = tableData[i].mode
			advObject["content" .. i] = createAdvMode(tableData[i], articleList, hits, hit_results, throw_results)
		end
		local t = tabber(object)
		local t2 = tabber(advObject)
		paletteSwap:node(t):addClass("move-mode-tabs"):done()
		nerdSection:node(t2):addClass("move-mode-tabs"):done()
		-- There should be a tabber element both in the frame window and also the advanced element one
	else
		local mode = tableData[1]
		local hits = {}
		local hit_results = nil
		local throw_results = nil
		local articleList = nil
		if mode then
			if mode.hitID ~= nil then
				local idList = mysplit(mode.hitID, ";")
				local hitMoves = mysplit(mode.hitSubactionID, ";")
				local names = mysplit(mode.hitName, ";")
				local actives = mysplit(mode.hitActive, ";")
				local shieldSafetyList = mysplit(mode.customShieldSafety, ";")
				local uniquesList = mysplit(mode.uniqueField, ";")
				for k in ipairs(idList) do
					local attack = mode.attackID
					if hitMoves ~= nil then
						attack = hitMoves[k]
					end
					local v = idList[k]
					hits[attack .. "_" .. v] = {}
					hits[attack .. "_" .. v]["hitID"] = idList[k]
					hits[attack .. "_" .. v]["move"] = attack
					hits[attack .. "_" .. v]["name"] = idList[k]
					if names ~= nil then
						hits[attack .. "_" .. v]["name"] = names[k]
					end
					hits[attack .. "_" .. v]["active"] = actives[k]
					hits[attack .. "_" .. v]["shield"] = nil
					if shieldSafetyList ~= nil then
						hits[attack .. "_" .. v]["shield"] = shieldSafetyList[k]
					end
					hits[attack .. "_" .. v]["unique"] = nil
					if uniquesList ~= nil and uniquesList[k] ~= "-" then
						hits[attack .. "_" .. v]["unique"] = uniquesList[k]
					end
				end

				local tables = "PPlus_HitData"
				local fields =
					"chara,attack,hit_label,seq_hit_set,damage,trajectory,wdsk,kbg,bkb,shield_damage,hitlag_mult,sdi_mult,hitbox_effect,sound,ground,aerial,clang,special_hit,angle_flipping,hits_fighters,waddle_dee,sse,saturn,wall_hit,stage_misc_hit,bomb,can_be_shielded,can_be_reflected,can_be_absorbed,remain_grabbed,enabled,ignore_invincibility,freeze_frame_disable,flinchless"

				local whereField = 'chara="' .. chara .. '" and ('
				local whereList = {}
				for k, v in pairs(hits) do
					table.insert(whereList, '(attack = "' .. v["move"] .. '" and hit_label = "' .. v["hitID"] .. '")')
				end
				local whereField = whereField .. table.concat(whereList, " or ") .. ")"
				local args = { where = whereField, orderBy = "_ID" }
				hit_results = cargo.query(tables, fields, args)

				local tables = "PPlus_ThrowData"
				local fields =
					"chara, attack, sequence_num, throw_use, hitbox_effect, damage, trajectory, wdsk, kbg, bkb, grab_target, throw_i_frames"

				local whereField = 'chara="' .. chara .. '" and ('
				local whereList = {}
				for k, v in pairs(hits) do
					table.insert(whereList, '(attack = "' .. v["move"] .. '")')
				end
				local whereField = whereField .. table.concat(whereList, " or ") .. ")"
				local args = { where = whereField, orderBy = "_ID" }
				throw_results = cargo.query(tables, fields, args)

				-- if mode.articleID ~= nil then
				-- 	local tables = "PPlus_Articles"
				-- 	local fields =
				-- 		"chara,moveID,ArticleName,bIsProjectile,bRotateWithVelocity,bInheritOwnerChargeValue,bIsAttachedToOwner,ParryReaction,HasHitReaction,GotHitReaction,bCanBeHitByOwner,bCanDetectOwner,GroundCollisionResponse,WallCollisionResponse,CeilingCollisionResponse,ShouldGetOutOfGroundOnSpawn"

				-- 	local whereField = 'chara="' .. chara .. '" and ('
				-- 	local whereList = {}
				-- 	for _, v in pairs(mysplit(mode.articleID, ";")) do
				-- 		table.insert(whereList, '(moveID = "' .. v .. '")')
				-- 	end
				-- 	local whereField = whereField .. table.concat(whereList, " or ") .. ")"
				-- 	local args = { where = whereField, orderBy = "ArticleName" }
				-- 	articleList = cargo.query(tables, fields, args)
				-- end
			end
			-- paletteSwap:wikitext(dump())
			paletteSwap:node(createMode(mode.articleID ~= nil, tableData[1], hits, hit_results, throw_results)):done()
			nerdSection:node(createAdvMode(tableData[1], articleList, hits, hit_results, throw_results)):done()
		end
	end

	--Attack Info Container
	nerdHeader:node(nerdSection):done()
	local content =
		mw.html.create("div"):addClass("attack-info"):node(paletteSwap):node(description):node(nerdHeader):done()

	card:node(imageDiv):node(content):done()
	return tostring(card)
end

function p.main(frame)
	mArguments = require("Arguments")
	local args = mArguments.getArgs(frame)
	return p._main(args)
end

function p._main(args)
	local chara = args["chara"]
	local attack = args["attack"]
	local desc = args["desc"]
	if args["desc"] == nil then
		desc = args["description"]
	end
	if desc == "" or desc == nil then
		desc =
			"<small>''This move card is missing a move description. The following bullet points should all be one paragraph or more and be included:''\n* Brief 1-2 sentences stating the basic function and utility of the move. Ex: ''\"Excellent anti-air, combo-starter, and combo-extender. The move starts behind before sweeping to the front.\"''\n* Explaining the reward and usefulness of the move and how it functions in her gameplan. Point out non-obvious use cases when relevant.\n* Explaining the shortcomings of the move, i.e. unsafe on shield, susceptible to CC, stubby, slow, etc.\n* Explaining when and where to use the move. Can differentiate between if it's good in neutral, punish, against fastfallers, floaties, etc.\nIf there's something you want to debate leaving it in or out, err on the side of leaving it in. For more details, read [[User:Lynnifer/Brief_Style_Guide#Move_Cards|here]].\n</small>"
	end
	local advDesc = args["advDesc"]

	if not chara then
		chara = mw.title.getCurrentTitle().subpageText
	end
	local html = getCardHTML(chara, attack, desc, advDesc)
	return tostring(html)
		.. mw.getCurrentFrame():extensionTag({
			name = "templatestyles",
			args = { src = "Template:MoveCard/shared/styles.css" },
		})
end

return p