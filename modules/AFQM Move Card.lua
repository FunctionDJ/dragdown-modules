local p = {}
local mArguments
local cargo = mw.ext.cargo
local tabber = require("Tabber").renderTabber
local tooltip = require("Tooltip")
local utils = require("Move Card Utils")
local mysplit = require("mysplit")
local createMode = require("Move Card CreateMode").createMode
local GetImagesWikitext = require("GetImagesWikitext")

local function readModes(chara, attack)
	local game = mw.title.getCurrentTitle().rootText

	return mw.ext.cargo.query(
		game.."_MoveMode",
		"chara,attack,attackID,mode,image,hitbox,caption,hitboxCaption,notes,startup,startupNotes,totalActive,totalActiveNotes,endlag,endlagNotes,cancel,cancelNotes,landingLag,landingLagNotes,iasa,autocancel,autocancelNotes,totalDuration,totalDurationNotes,frameChart,hitID,hitMoveID,hitName,hitActive,uniqueField,articleID",
		{
			where = game..'_MoveMode.chara="' .. chara .. '" and '..game..'_MoveMode.attack="' .. attack .. '"',
			orderBy = "_ID",
		}
	)
end

local function getHits(hasArticle, result, mode, hitData)
	--chara, attackID, hitID, hitMoveID, hitName, hitActive,  uniques
	local hitRow = mw.html.create("tr"):addClass("hit-row")
	hitRow:tag("td"):wikitext(hitData.name)
	hitRow:tag("td"):wikitext(result.dmg .. "%")
		:tag("td"):wikitext(hitData.active)
		:tag("td"):wikitext(result.bkb )
		:tag("td"):wikitext(result.kbs )
		:tag("td"):wikitext(result.hitlag )
		:tag("td"):wikitext(utils.makeAngleDisplay(result.angle))
		:done()
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
			"Name",
			"Unique Notes",
		}

		local headersRow = mw.html.create("tr"):addClass("adv-hits-list-header")
		for k, v in pairs(columnHeaders) do
			local cell = mw.html.create("th"):wikitext(v):done()
			headersRow:node(cell)
		end
		headersRow:done()
		local hitsWindow = mw.html.create("table"):addClass("hits-window wikitable"):node(headersRow)

		for k, v in ipairs(hitresults) do
			hitsWindow:node(p.getAdvHits(hitresults[k], mode, motherhits[hitresults[k]], articleList))
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
				GetImagesWikitext({
					{
						file = "AFQM_" .. chara .. "_" .. attack .. "_0.png",
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
	local queues = {}
	for i in pairs(tableData) do
		local mode = tableData[i]
		local hits = {}
		local hit_results = nil
		local throw_results = nil
		if mode.hitID ~= nil then
			local idList = mysplit(mode.hitID, ";")
			local hitMoves = mysplit(mode.hitMoveID, ";")
			local names = mysplit(mode.hitName, ";")
			local actives = mysplit(mode.hitActive, ";")
			local uniquesList = mysplit(mode.uniqueField, ";")
			for k in ipairs(idList) do
				local attack = mode.attack
				if hitMoves ~= nil then
					attack = hitMoves[k]
				end
				hits[k] = {}
				hits[k]["hitID"] = idList[k]
				hits[k]["move"] = attack
				hits[k]["name"] = idList[k]
				if names ~= nil then
					hits[k]["name"] = names[k]
				end
				hits[k]["active"] = actives[k]
				hits[k]["shield"] = nil
				hits[k]["unique"] = nil
				if uniquesList ~= nil and uniquesList[k] ~= "-" then
					hits[k]["unique"] = uniquesList[k]
				end
			end

			local tables = "AFQM_HitData"
			local fields = "chara,attack,hit_id,dmg,bkb,kbs,hitlag,angle"
			local whereField = 'chara="' .. mode.chara .. '" and ('
			local whereList = {}
			for k, v in pairs(hits) do
				table.insert(whereList, '(attack = "' .. v["move"] .. '" and hit_id = "' .. v["hitID"] .. '")')
			end
			local whereField = whereField .. table.concat(whereList, " or ") .. ")"
			local args = { where = whereField, orderBy = "_ID" }
			hit_results = cargo.query(tables, fields, args)
		end
		queues[mode] = {mode = mode, hits = hits, hit_results = hit_results, articles = articles}
	end

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
				"Hitlag",
				"Hitlag - amount of freeze frames."
			),
			tooltip("Angle", "The angle at which the move sends the target."),
		}
	}

	if #tableData > 1 then
		local object = {}
		local advObject = {}
		for i, _ in ipairs(tableData) do
			object["label" .. i] = tableData[i].mode
			object["content" .. i] = createMode(false, queues[tableData[i]].mode, queues[tableData[i]].hits, queues[tableData[i]].hit_results, nil, getHits, modeConfig)
			-- object["content" .. i] = createMode(tableData[i], hits, hit_results, throw_results)
			-- advObject["label" .. i] = tableData[i].mode
			-- advObject["content" .. i] = createAdvMode(queues[tableData[i]].mode, queues[tableData[i]].articles, queues[tableData[i]].hits, queues[tableData[i]].hit_results, queues[tableData[i]].throw_results)
		end
		local t = tabber(object)
		-- local t2 = tabber(advObject)
		paletteSwap:node(t):addClass("move-mode-tabs"):done()
		-- nerdSection:node(t2):addClass("move-mode-tabs"):done()
		-- There should be a tabber element both in the frame window and also the advanced element one
	else
		if(queues[tableData[1]]) then
			paletteSwap:node(createMode(false, queues[tableData[1]].mode, queues[tableData[1]].hits, queues[tableData[1]].hit_results, nil, getHits, modeConfig)):done()
			-- nerdSection:node(createAdvMode(queues[tableData[1]].mode, queues[tableData[1]].articles, queues[tableData[1]].hits, queues[tableData[1]].hit_results, queues[tableData[1]].throw_results)):done()
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
	local desc = args["desc"] or args["description"]
	
	if desc == "" or desc == nil then
		desc =
			"<small>''This move card is missing a move description. The following bullet points should all be one paragraph or more and be included:''\n* Brief 1-2 sentences stating the basic function and utility of the move. Ex: ''\"Excellent anti-air, combo-starter, and combo-extender. The move starts behind before sweeping to the front.\"''\n* Explaining the reward and usefulness of the move and how it functions in her gameplan. Point out non-obvious use cases when relevant.\n* Explaining the shortcomings of the move, i.e. unsafe on shield, stubby, slow, etc.\n* Explaining when and where to use the move. Can differentiate between if it's good in neutral, punish, against fastfallers, floaties, etc.\nIf there's something you want to debate leaving it in or out, err on the side of leaving it in. For more details, read [[User:Lynnifer/Brief_Style_Guide#Move_Cards|here]].\n</small>"
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