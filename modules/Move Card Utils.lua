---@diagnostic disable: lowercase-global
local p = {}
local cargo = mw.ext.cargo

local tabber = require("Tabber").renderTabber
local GetImagesWikitext = require("GetImagesWikitext")
local mysplit = require("mysplit")
local tooltip = require("Tooltip")
local createMode = require "Move Card CreateMode".createMode
local inspect = require("inspect").inspect

function p.commonMain(frame)
	local args = require("Arguments").getArgs(frame)
	local readModes = p.getReadModeGetter()
	local html = p.getCardHTML(args, readModes)

	return tostring(html)
		.. mw.getCurrentFrame():extensionTag({
			name = "templatestyles",
			args = { src = "Template:MoveCard/shared/styles.css" },
		})
end

function p.getReadModeGetter()
	local game = mw.title.getCurrentTitle().rootText
	return function (chara, attack)
		return mw.ext.cargo.query(
			game.."_MoveMode",
			"chara, attack, attackID, mode, startup, startupNotes, totalActive, totalActiveNotes, " ..
			"endlag, endlagNotes, cancel, cancelNotes, landingLag, landingLagNotes, totalDuration, " ..
			"totalDurationNotes,iasa,autocancel,autocancelNotes,hitID,hitMoveID,hitName,hitActive," ..
			"customShieldSafety,uniqueField,frameChart, articleID, notes",
			{
				where = game..'_MoveMode.chara="' .. chara .. '" and '..game..'_MoveMode.attack="' .. attack .. '"',
				orderBy = "_ID",
			}
		)
	end
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
		local stun = result.BlockStun
		
		local active1 = mysplit(active, ", ")
		active1 = active1[#active1]
		local active2 = mysplit(active1, "-")
		local first = mode.totalDuration - active2[1]
		local second = mode.totalDuration - active2[#active2]
		if mode.iasa then
			first = mode.iasa - active2[1]
			second = mode.iasa - active2[#active2]
		end

		if mode.landingLag ~= nil then
			local realLandingLag = mode.landingLag

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

function p.makeAngleDisplay(angle, flipper)
	local game = mw.title.getCurrentTitle().rootText

	angle = tonumber(angle)
	local angleColor = mw.html.create("span"):wikitext(angle)
	if angle > 360 then
		angleColor:css("color", "#ff0000")
	elseif angle <= 45 or angle >= 315 then
		angleColor:css("color", "#1ba6ff")
	elseif angle > 225 then
		angleColor:css("color", "#ff6b6b")
	elseif angle > 135 then
		angleColor:css("color", "#de7cd1")
	elseif angle > 45 then
		angleColor:css("color", "#16df53")
	end

	local display = mw.html.create("span")
	local div1 = mw.html.create("div"):css("position", "relative"):css("top", "0"):css("max-width", "256px")

	if angle < 360 then
		div1:tag("div")
			:css("transform", "rotate(-" .. angle .. "deg)")
			:css("z-index", "0")
			:css("position", "absolute")
			:css("top", "0")
			:css("left", "0")
			:css("transform-origin", "center center")
			:wikitext("[[File:"..game.."_AngleComplex_BG.svg|256px|link=]]")
			:done()
			:tag("div")
			:css("z-index", "1")
			:css("position", "relative")
			:css("top", "0")
			:css("left", "0")
			:wikitext("[[File:"..game.."_AngleComplex_MG.svg|256px|link=]]")
			:done()
			:tag("div")
			:css("transform", "rotate(-" .. angle .. "deg)")
			:css("z-index", "2")
			:css("position", "absolute")
			:css("top", "0")
			:css("left", "0")
			:css("transform-origin", "center center")
			:wikitext("[[File:"..game.."_AngleComplex_FG.svg|256px|link=]]")
			:done()
		div1:wikitext("Angle Flipper: " .. flipper)
		div1:done()
		display:node(div1):wikitext("[[File:"..game.."_AngleComplex_Key.svg|256px|link=]]")
		display:done()
	else
		div1:wikitext("Angle Flipper: " .. flipper)
		div1:done()
		display:node(div1)
		display:done()
	end
	return tostring(tooltip(tostring(angleColor), tostring(display)))
end

local function getHits(hasArticle, result, mode, hitData)
	--chara, attackID, hitID, hitMoveID, hitName, hitActive, customShieldSafety, uniques
	local hitRow = mw.html.create("tr"):addClass("hit-row")
	if(tonumber(hitData.name)) then
		hitRow:tag("td"):wikitext(result.hitName)
	else
		hitRow:tag("td"):wikitext(hitData.name)
	end
	hitRow:tag("td"):wikitext(result.Damage .. "%")
		:tag("td"):wikitext(hitData.active)
		:tag("td"):wikitext(result.BaseKnockback )
		:tag("td"):wikitext(result.KnockbackGain )
		:tag("td"):wikitext(result.FixedKnockback )
		:tag("td"):wikitext(p.makeAngleDisplay(result.KnockbackAngle , result.SpecialAngle ))
		-- :tag("td"):wikitext("T")
		:tag("td"):wikitext(calcShieldSafety(result, mode, hitData.active, hitData.shield))
		:done()
	return hitRow
end

function p.getAdvHits(result, mode, hitData, articleData)
	--chara, attackID, hitID, hitMoveID, hitName, hitActive, customShieldSafety, uniques

	local columns = "hitName,SpecialAngle,DirectionalInfluenceMultiplier,SmashDirectionalInfluenceMultiplier,HitStunMinimum,HitStunMultiplier,HitlagBaseOnBlock,HitlagBaseOnHit,InstigatorAdvantageOnBlock,InstigatorAdvantageOnHit,BlockStun,BlockPush,BlockDamage,Priority,PushBackInstigatorOnHit,KnockbackIgnoreDownState,Aerial,Flinchless,ForceSpinOut,Reversible,Unblockable,UntechableIfGrounded,CannotRebound,CanRedirectProjectiles,CanReflectProjectiles,PreventSlimeBurst,SlimeMultiplier,InstigatorPushbackVelocity,UniqueNotes"

	local hitRow = mw.html.create("tr")
	for k, v in ipairs(mysplit(columns, ",")) do
		local assignedValue = ""
		assignedValue = result[v]
		local cell = mw.html.create("td"):wikitext(assignedValue):done()
		hitRow:node(cell)
	end

	hitRow:done()
	return hitRow
end

local modeConfig = {
	iasa = true,
	autocancel = true,
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
				"Shield Safety",
				"The frame advantage after a move connects on shield. If a move ends prematurely with landing lag like an aerial, the shield safety assumes that the character lands immediately after performing the hit."
			)
		}
}

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
			"Special Angle",
			"DI Multiplier",
			"SDI Multiplier",
			"HitStun Minimum",
			"HitStun Multiplier",
			"Hitlag Base On Block",
			"Hitlag Base On Hit",
			"Instigator Advantage On Block",
			"Instigator Advantage On Hit",
			"Block Stun",
			"Block Push",
			"Block Damage",
			"Priority",
			"PushBack Instigator On Hit",
			"Knockback Ignore Down State",
			"Aerial",
			"Flinchless",
			"Force Spin Out",
			"Reversible",
			"Unblockable",
			"Untechable If Grounded",
			"Cannot Rebound",
			"Can Redirect Projectiles",
			"Can Reflect Projectiles",
			"Prevent Slime Burst",
			"Slime Multiplier",
			"Instigator Pushback Velocity",
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

function p.getImageGallery(chara, attack)
	local game = mw.title.getCurrentTitle().rootText
	local tables = game.."_MoveMode, "..game.."_MoveMode__image, "..game.."_MoveMode__caption"
	local fields = "image, caption"
	local args = {
		join = game.."_MoveMode__image._rowID="..game.."_MoveMode._ID, "..game.."_MoveMode__image._rowID="..game.."_MoveMode__caption._rowID, "..game.."_MoveMode__image._position="..game.."_MoveMode__caption._position",
		where = ''..game..'_MoveMode.chara="' .. chara .. '" and '..game..'_MoveMode.attack="' .. attack .. '"',
		orderBy = "_ID",
		groupBy = game.."_MoveMode__image._value",
	}
	local results = cargo.query(tables, fields, args)

	local imageCaptionPairs = {}

	for k, v in pairs(results) do
		local imageList = mysplit(results[k]["image"], "\\")
		local captionList = mysplit(results[k]["caption"], "\\")
		if imageList ~= nil then
			for k, v in pairs(imageList) do
				if captionList == nil then
					table.insert(imageCaptionPairs, { file = imageList[k], caption = "" })
				else
					table.insert(imageCaptionPairs, { file = imageList[k], caption = captionList[k] })
				end
			end
		end
	end
	local container = mw.html.create("div"):addClass("attack-gallery-image")
	container:wikitext(table.concat(GetImagesWikitext(imageCaptionPairs)))

	return tostring(container)
end

local function getHitboxGallery(chara, attack)
	return "Hitboxes are currently unavailable."
end

--- @param readModes function
function p.getCardHTML(args, readModes)
	-- Lazy Load automated frame chart generator
	-- local autoChart = require('FrameChart').autoChart
	-- Outer Container of the card
	local card = mw.html.create("div"):addClass("attack-container")

	local game = mw.title.getCurrentTitle().rootText
	local chara = args.chara or mw.title.getCurrentTitle().subpageText
	local attack = args.attack

	-- Images
	local acquiredImages = p.getImageGallery(chara, attack)
	local tabberData
	if acquiredImages ~= '<div class="attack-gallery-image"></div>' then
		tabberData = tabber({
			label1 = "Images",
			content1 = p.getImageGallery(chara, attack),
			-- label2 = "Hitboxes",
			-- content2 = getHitboxGallery(chara, attack),
		})
	else
		local container = mw.html.create("div"):addClass("attack-gallery-image")
		container:wikitext(
			table.concat(
				GetImagesWikitext({
					{
						file = game.. "_" .. chara .. "_" .. attack .. "_0.png",
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

	local desc = args["desc"]
		or args["description"]
		or "<small>''This move card is missing a move description."
		..
		" The following bullet points should all be one paragraph or more and be included:" ..
		"''\n* Brief 1-2 sentences stating the basic function and utility of the move." ..
		" Ex: ''\"Excellent anti-air, combo-starter, and combo-extender. " ..
		"The move starts behind before sweeping to the front.\"''\n* " ..
		"Explaining the reward and usefulness of the move and how it functions in her gameplan. " ..
		"Point out non-obvious use cases when relevant.\n* Explaining the shortcomings of the move, " ..
		"i.e. unsafe on shield, stubby, slow, etc.\n* Explaining when and where to use the move. " ..
		"Can differentiate between if it's good in neutral, punish, against fastfallers, " ..
		"floaties, etc.\nIf there's something you want to debate leaving it in or out, " ..
		"err on the side of leaving it in. For more details, read " ..
		"[[User:Lynnifer/Brief_Style_Guide#Move_Cards|here]].\n</small>"

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

	local advDesc = args.advDesc

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
			local shieldSafetyList = mysplit(mode.customShieldSafety, ";")
			local uniquesList = mysplit(mode.uniqueField, ";")
			for k in ipairs(idList) do
				local attack = mode.attackID
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
				if shieldSafetyList ~= nil then
					hits[k]["shield"] = shieldSafetyList[k]
				end
				hits[k]["unique"] = nil
				if uniquesList ~= nil and uniquesList[k] ~= "-" then
					hits[k]["unique"] = uniquesList[k]
				end
			end

			local tables = game.."_HitData"
			local fields = "chara,hitName,hitID,Damage,BaseKnockback,KnockbackGain,FixedKnockback,KnockbackAngle,SpecialAngle,DirectionalInfluenceMultiplier,SmashDirectionalInfluenceMultiplier,HitStunMinimum,HitStunMultiplier,HitlagBaseOnBlock,HitlagBaseOnHit,InstigatorAdvantageOnBlock,InstigatorAdvantageOnHit,BlockStun,BlockPush,BlockDamage,Priority,PushBackInstigatorOnHit,KnockbackIgnoreDownState,Aerial,Flinchless,ForceSpinOut,Reversible,Unblockable,UntechableIfGrounded,CannotRebound,CanRedirectProjectiles,CanReflectProjectiles,PreventSlimeBurst,SlimeMultiplier,InstigatorPushbackVelocity,UniqueNotes"
			local whereField = 'chara="' .. mode.chara .. '" and ('
			local whereList = {}
			for k, v in pairs(hits) do
				table.insert(whereList, '(hitID = "' .. v["hitID"] .. '")')
			end
			local whereField = whereField .. table.concat(whereList, " or ") .. ")"
			local args = { where = whereField, orderBy = "_ID" }
			hit_results = cargo.query(tables, fields, args)
			-- hitsWindow:wikitext(dump(args))

			local whereList = {}
			for k, v in pairs(hits) do
				table.insert(whereList, '(attack = "' .. v["move"] .. '")')
			end
		end
		queues[mode] = {mode = mode, hits = hits, hit_results = hit_results, articles = articles}
	end
	if #tableData > 1 then
		local object = {}
		local advObject = {}
		for i in pairs(tableData) do
			object["label" .. i] = queues[tableData[i]].mode
			object["content" .. i] = createMode(false, queues[tableData[i]].mode, queues[tableData[i]].hits, queues[tableData[i]].hit_results, queues[tableData[i]].throw_results, getHits, modeConfig)
			-- object["content" .. i] = createMode(tableData[i], hits, hit_results, throw_results)
			advObject["label" .. i] = tableData[i].mode
			advObject["content" .. i] = createAdvMode(queues[tableData[i]].mode, queues[tableData[i]].articles, queues[tableData[i]].hits, queues[tableData[i]].hit_results, queues[tableData[i]].throw_results)
		end
		local t = tabber(object)
		local t2 = tabber(advObject)
		paletteSwap:node(t):addClass("move-mode-tabs"):done()
		nerdSection:node(t2):addClass("move-mode-tabs"):done()
		-- There should be a tabber element both in the frame window and also the advanced element one
	else
		if(queues[tableData[1]]) then
			paletteSwap:node(createMode(false, queues[tableData[1]].mode, queues[tableData[1]].hits, queues[tableData[1]].hit_results, queues[tableData[1]].throw_results, getHits, modeConfig)):done()
			nerdSection:node(createAdvMode(queues[tableData[1]].mode, queues[tableData[1]].articles, queues[tableData[1]].hits, queues[tableData[1]].hit_results, queues[tableData[1]].throw_results)):done()
		end
	end
	--Attack Info Container
	nerdHeader:node(nerdSection):done()
	local content =
		mw.html.create("div"):addClass("attack-info"):node(paletteSwap):node(description):node(nerdHeader):done()

	card:node(imageDiv):node(content):done()
	return tostring(card)
end

return p