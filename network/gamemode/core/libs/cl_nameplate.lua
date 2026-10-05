NETWORK.nameplate = NETWORK.nameplate or {}

NETWORK.nameplate.downRange = 160

NETWORK.nameplate.distance = 340
NETWORK.nameplate.fadeStart = 240
NETWORK.nameplate.height = 5
NETWORK.nameplate.iconSize = 15
NETWORK.nameplate.traceRate = 0.15

NETWORK.nameplate.instant = 190

NETWORK.nameplate.descriptionLines = 6
NETWORK.nameplate.nearLines = 16
NETWORK.nameplate.descWidth = 380
NETWORK.nameplate.nearWidth = 560

NETWORK.nameplate.nearRange = 120

NETWORK.nameplate.openTime = 0.2
NETWORK.nameplate.closeTime = 0.15

local enabled = CreateClientConVar("network_nameplates", "1", true, false,
	"Показывать имена персонажей рядом")

local alphas = {}
local visible = {}
local nextTrace = 0
local icons = {}
local unfolds = {}
local fades = {}

local truncated = {}
local truncatedCount = 0

local DESC_FONTS = {"nwTagDescItalic", "nwTagDescBold", "nwTagDescItalic"}

local function Fit(text, font, maximum)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= maximum) then
		return text
	end

	local key = font .. "|" .. maximum .. "|" .. text
	local cached = truncated[key]

	if (!cached) then

		if (truncatedCount > 256) then
			truncated = {}
			truncatedCount = 0
		end

		cached = NETWORK.util.TruncateWidth(text, font, maximum)
		truncated[key] = cached
		truncatedCount = truncatedCount + 1
	end

	return cached
end

function NETWORK.nameplate.GetIcon(path)
	if (!path or path == "") then
		return
	end

	if (icons[path] == nil) then
		icons[path] = Material(path, "smooth")
	end

	local icon = icons[path]

	return (icon and !icon:IsError()) and icon or nil
end

function NETWORK.nameplate.GetAnchor(target)

	if (target == LocalPlayer() and NETWORK.thirdperson and
		!NETWORK.thirdperson.IsEnabled()) then
		return target:GetPos() + Vector(0, 0, target:OBBMaxs().z + 8)
	end

	local fallback = target:GetPos() + Vector(0, 0, target:OBBMaxs().z + 8)
	local bone = target:LookupBone("ValveBiped.Bip01_Head1")

	if (bone) then
		local matrix = target:GetBoneMatrix(bone)

		if (matrix) then
			local head = matrix:GetTranslation()

			if (head:DistToSqr(fallback) < 96 * 96) then
				return head + Vector(0, 0, 12)
			end
		end
	end

	return fallback
end

function NETWORK.nameplate.GetLeaderPoint(target, x, y, width, height)
	local points = {}
	local bone = target:LookupBone("ValveBiped.Bip01_Spine2")
	local matrix = bone and target:GetBoneMatrix(bone)

	points[1] = matrix and matrix:GetTranslation() or target:LocalToWorld(target:OBBCenter())
	points[2] = NETWORK.nameplate.GetAnchor(target) - Vector(0, 0, 12)

	for _, point in ipairs(points) do
		local screen = point:ToScreen()

		if (screen.visible and !(screen.x > x and screen.x < x + width and
			screen.y > y and screen.y < y + height)) then
			return math.Round(screen.x), math.Round(screen.y)
		end
	end
end

function NETWORK.nameplate.IsHidden(target)
	if (!IsValid(target)) then
		return true
	end

	if (target:GetNoDraw() or target:IsDormant()) then
		return true
	end

	local color = target:GetColor()

	if (color and color.a <= 16) then
		return true
	end

	local mode = target:GetRenderMode()

	if (mode == RENDERMODE_NONE) then
		return true
	end

	return false
end

local function IsLookedAt(client, target, eyePos)
	local aim = client:GetAimVector()
	local points = {
		target:EyePos(),
		target:WorldSpaceCenter(),
		target:GetPos() + Vector(0, 0, 8)
	}

	for _, point in ipairs(points) do
		local direction = point - eyePos
		local distance = direction:Length()

		if (distance < 1) then
			return true
		end

		direction:Normalize()

		if (direction:Dot(aim) >= 0.97) then
			return true
		end
	end

	return false
end

local function GetTargetAlpha(client, target, eyePos, bTrace)
	local key = target:EntIndex()
	local top = NETWORK.nameplate.GetAnchor(target)
	local distance = eyePos:Distance(top)

	if (distance > NETWORK.nameplate.distance or
		!IsLookedAt(client, target, eyePos)) then
		visible[key] = false

		return 0, top
	end

	if (true) then

		local bSeen = false

		for _, point in ipairs({target:EyePos(), target:WorldSpaceCenter()}) do
			local trace = util.TraceLine({
				start = eyePos,
				endpos = point,
				filter = {client, target},
				mask = MASK_VISIBLE
			})

			if (!trace.Hit) then
				bSeen = true

				break
			end
		end

		visible[key] = bSeen
	end

	if (!visible[key]) then
		return 0, top
	end

	local fade = NETWORK.nameplate.fadeStart

	if (distance <= fade) then
		return 1, top
	end

	return 1 - (distance - fade) / math.max(NETWORK.nameplate.distance - fade, 1), top
end

function NETWORK.nameplate.GetDownedTarget()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity)) then
		return
	end

	if (client:GetPos():Distance(trace.HitPos) > NETWORK.nameplate.downRange) then
		return
	end

	if (entity:IsPlayer()) then

		if (NETWORK.nameplate.IsHidden(entity)) then
			return
		end

		if (entity != client and IsValid(entity:GetNWEntity("nwRagdollEntity", NULL))) then
			return entity
		end

		return
	end

	for _, target in ipairs(player.GetAll()) do
		if (target:GetNWEntity("nwRagdoll", NULL) == entity or
			target:GetNWEntity("nwRagdollEntity", NULL) == entity) then

			if (target == client) then
				return
			end

			return target, !target:Alive(), entity
		end
	end

	if (entity:GetNWBool("nwCorpse", false)) then
		if (entity:GetNWEntity("nwCorpseOwner", NULL) == client) then
			return
		end

		return nil, true, entity
	end
end

function NETWORK.nameplate.GetCorpseName(corpse)
	local client = LocalPlayer()
	local owner = corpse:GetNWEntity("nwCorpseOwner", NULL)

	if (IsValid(owner) and owner:IsPlayer() and client:IsRecognised(owner)) then
		return corpse:GetNWString("nwCorpseName", "")
	end

	local faction = NETWORK.factions.Get(corpse:GetNWString("nwCorpseFaction", ""))

	if (faction and faction.unknownName) then
		return L(faction.unknownName)
	end

	return L("plateUnknownBody")
end

function NETWORK.nameplate.DrawDowned(target, bDead, corpse)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local S = NETWORK.style
	local client = LocalPlayer()
	local bKnown = IsValid(target) and client:IsRecognised(target)
	local shadow = math.max(Sc(2), 1)
	local x = math.Round(ScrW() * 0.5)
	local y = math.Round(ScrH() * 0.5) - Sc(60)

	local hint = "plateBodyHint"
	local hintText = L(hint)

	local name

	if (IsValid(target)) then
		name = bKnown and target:GetCharacterName() or target:GetUnknownName()
	else
		name = NETWORK.nameplate.GetCorpseName(corpse)
	end

	local wounds = {}

	for _, part in ipairs(NETWORK.wound.parts) do
		local value = (IsValid(target) and target == client) and
			NETWORK.wound.Get(client, part.id) or 0

		if (value >= NETWORK.wound.limpAt) then
			wounds[#wounds + 1] = L(part.name)
		end
	end

	local description = (bKnown and IsValid(target)) and
		target:GetCharacterDescription() or ""
	local descLines = description != "" and
		util.WrapText(description, "nwChatSmall", Sc(560), 10) or {}

	if (S and S.Card) then
		surface.SetFont("nwChatSmall")

		local widest = surface.GetTextSize(hintText)

		for _, line in ipairs(descLines) do
			widest = math.max(widest, surface.GetTextSize(line))
		end

		surface.SetFont("nwField")
		widest = math.max(widest, surface.GetTextSize(name or ""))

		local padX = Sc(20)
		local padY = Sc(12)
		local lastY = y + Sc(26) + (#descLines > 0 and (Sc(24) + (#descLines - 1) * Sc(19)) or 0)
		local cardWidth = math.max(widest + padX * 2, Sc(300))
		local cardTop = y - Sc(10) - padY
		local cardHeight = lastY + Sc(12) + padY - cardTop
		local cardX = x - math.Round(cardWidth * 0.5)

		local body = IsValid(corpse) and corpse or target

		if (S.Leader and IsValid(body)) then
			local screen = body:WorldSpaceCenter():ToScreen()

			if (screen.visible) then
				S.Leader(math.Round(screen.x), math.Round(screen.y), cardX, cardTop,
					cardWidth, cardHeight, theme.accent, 0.85)
			end
		end

		S.Card(cardX, cardTop, cardWidth, cardHeight, 1, {blur = false})
	end

	util.DrawSimpleTextShadow(hintText, "nwChatSmall", x, y,
		ColorAlpha(theme.textDim, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

	y = y + Sc(26)

	util.DrawSimpleTextShadow(name, "nwField", x, y, ColorAlpha(theme.accent, 252),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

	y = y + Sc(24)

	if (#descLines == 0) then
		return
	end

	for _, line in ipairs(descLines) do
		util.DrawSimpleTextShadow(line, "nwChatSmall", x, y,
			ColorAlpha(theme.text, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

		y = y + Sc(19)
	end
end

hook.Add("HUDPaint", "nwDownedPlate", function()
	if (NETWORK.hud.IsHidden()) then
		return
	end

	local target, bDead, corpse = NETWORK.nameplate.GetDownedTarget()

	if (IsValid(target) or IsValid(corpse)) then
		NETWORK.nameplate.DrawDowned(target, bDead, corpse)
	end
end)

hook.Add("HUDPaint", "nwNameplates", function()
	if (NETWORK.hud.IsHidden()) then
		return
	end

	if (!enabled:GetBool() or IsValid(NETWORK.gui.menu)) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	if (client:GetMoveType() == MOVETYPE_NOCLIP) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local S = NETWORK.style
	local eyePos = client:EyePos()
	local bTrace = CurTime() >= nextTrace
	local delta = RealFrameTime()

	local bBlurUsed = false

	if (bTrace) then
		nextTrace = CurTime() + NETWORK.nameplate.traceRate
	end

	for _, target in ipairs(player.GetAll()) do
		local key = target:EntIndex()

		if (target == client or !target:Alive() or !target:HasCharacter() or
			target:GetMoveType() == MOVETYPE_NOCLIP or
			NETWORK.nameplate.IsHidden(target)) then
			alphas[key] = 0
			unfolds[key] = 0

			continue
		end

		local goal, top = GetTargetAlpha(client, target, eyePos, bTrace)

		alphas[key] = util.Approach(alphas[key] or 0, goal, 16)

		local alpha = alphas[key]

		local bLooking = goal > 0

		if (bLooking) then
			unfolds[key] = math.min((unfolds[key] or 0) + delta / NETWORK.nameplate.openTime, 1)
			fades[key] = goal
		else
			unfolds[key] = math.max((unfolds[key] or 0) - delta / NETWORK.nameplate.closeTime, 0)
		end

		local unfold = unfolds[key]
		local cardAlpha = math.max(alpha, (fades[key] or 0) * math.Clamp(unfold / 0.5, 0, 1))

		if (unfold <= 0.001 or cardAlpha < 0.02) then
			continue
		end

		local screen = top:ToScreen()

		if (!screen.visible) then
			continue
		end

		local stack = NETWORK.bubble and NETWORK.bubble.GetHeight(target) or 0
		local bKnown = client:IsRecognised(target)
		local name = bKnown and target:GetCharacterName() or target:GetUnknownName()
		local factionID = target:GetCharacterFaction()
		local faction = factionID and NETWORK.factions.Get(factionID)
		local color = faction and faction.color or theme.accent

		if (!bKnown) then
			color = NETWORK.recognition.strangerColor
			faction = nil
		end

		local description = target:GetCharacterDescription() or ""

		local subtitle = ""

		if (bKnown) then
			local classID = target:GetNWString("nwClass", "")
			local classTable = classID != "" and NETWORK.classes and
				NETWORK.classes.Get(classID)

			local factionName = faction and L(faction.name) or ""
			local className = classTable and classTable.name and
				L(classTable.name) or ""

			if (classTable and classTable.bCivilianHud) then
				local citizen = NETWORK.factions.Get("citizen")

				subtitle = className
				color = citizen and citizen.color or color
				faction = citizen or faction
			elseif (factionName != "" and className != "") then
				subtitle = factionName .. "  ·  " .. className
			else
				subtitle = className != "" and className or factionName
			end

			local callsign = target:GetNWString("nwCallsign", "")

			if (callsign != "") then
				name = callsign
			end
		end

		local y = math.Round(ScrH() * 0.57)

		NETWORK.nameplate.lookAlpha = cardAlpha
		NETWORK.nameplate.lookTime = RealTime()

		local icon = NETWORK.nameplate.GetIcon(bKnown and NETWORK.factions.GetIcon(target) or
			NETWORK.recognition.strangerIcon)

		local group = bKnown and NETWORK.group and NETWORK.group.GetOf(target)
		local groupIcon = group and group.icon and
			NETWORK.nameplate.GetIcon(group.icon)
		local groupColor = group and NETWORK.group.GetColor(group) or color

		local wound, woundColor = NETWORK.nameplate.GetWoundText(target)
		local bTied = NETWORK.restraint and NETWORK.restraint.IsTied(target)

		local bNear = eyePos:Distance(target:EyePos()) <=
			NETWORK.nameplate.nearRange
		local descLines = description != "" and util.WrapText(description,
			"nwTagDescItalic", bNear and Sc(NETWORK.nameplate.nearWidth) or
			Sc(NETWORK.nameplate.descWidth),
			bNear and NETWORK.nameplate.nearLines or
			NETWORK.nameplate.descriptionLines) or {}

		local role = subtitle

		if (role != "") then
			role = util.Upper(role)
		end

		local groupName = (group and group.name) and util.Upper(group.name) or nil
		local tiedText = bTied and L("plateTied") or nil

		local TipFont = NETWORK.gui.TipFont
		local nameFont = TipFont and TipFont("name") or "nwTag"
		local chipFont = TipFont and TipFont("cap") or "nwLabelBold"
		local padL = Sc(22)
		local padR = Sc(16)
		local padT = Sc(14)
		local padB = Sc(14)
		local badge = icon and Sc(30) or 0
		local badgeGap = icon and Sc(11) or 0
		local chipPadX = math.max(Sc(7), 4)
		local chipPadY = math.max(Sc(3), 2)
		local chipGap = Sc(6)
		local margin = Sc(12)
		local headerMax = math.min(Sc(NETWORK.nameplate.nearWidth),
			ScrW() - margin * 2 - padL - padR) - badge - badgeGap
		local groupBox = groupIcon and (Sc(8) + Sc(15)) or 0

		name = Fit(name, nameFont, math.max(headerMax - groupBox, Sc(60)))

		surface.SetFont(nameFont)

		local nameWidth, nameHeight = surface.GetTextSize(name)

		surface.SetFont(chipFont)

		local _, chipTextHeight = surface.GetTextSize("A")
		local chipHeight = chipTextHeight + chipPadY * 2

		if (role != "") then
			role = Fit(role, chipFont, math.max(headerMax - chipPadX * 2, Sc(40)))
		end

		surface.SetFont(chipFont)

		local roleWidth = role != "" and (surface.GetTextSize(role) + chipPadX * 2) or 0

		if (groupName) then
			local room = headerMax - roleWidth - (roleWidth > 0 and chipGap or 0) - chipPadX * 2

			groupName = room >= Sc(36) and Fit(groupName, chipFont, room) or nil
		end

		surface.SetFont(chipFont)

		local groupWidth = groupName and (surface.GetTextSize(groupName) + chipPadX * 2) or 0
		local chipsWidth = roleWidth + groupWidth +
			((roleWidth > 0 and groupWidth > 0) and chipGap or 0)
		local bChips = chipsWidth > 0
		local headerHeight = math.max(badge, nameHeight +
			(bChips and (Sc(5) + chipHeight) or 0))
		local widest = badge + badgeGap + math.max(nameWidth + groupBox, chipsWidth)

		local statusIcon = Sc(14)
		local statusGap = Sc(6)
		local statusPad = Sc(6)
		local statusRow = Sc(20)
		local statusSpacing = Sc(4)
		local statuses = {}

		if (tiedText) then
			statuses[#statuses + 1] = {icon = "tied", text = tiedText, color = theme.warning}
		end

		if (wound) then
			statuses[#statuses + 1] = {icon = "wounded", text = wound,
				color = woundColor or Color(226, 86, 78)}
		end

		surface.SetFont("nwTagDesc")

		for _, status in ipairs(statuses) do
			status.width = statusPad * 2 + statusIcon + statusGap +
				surface.GetTextSize(status.text)
			widest = math.max(widest, status.width)
		end

		local descRow = Sc(18)
		local descFonts = DESC_FONTS

		for _, line in ipairs(descLines) do
			widest = math.max(widest, (util.StyledTextSize(line, descFonts)))
		end

		local plateWidth = math.Round(math.Clamp(widest + padL + padR, Sc(300),
			math.max(ScrW() - margin * 2, Sc(300))))
		local cursor = padT + headerHeight
		local statusTop, dividerY, descTop

		if (#statuses > 0) then
			cursor = cursor + Sc(10)
			statusTop = cursor
			cursor = cursor + #statuses * statusRow + (#statuses - 1) * statusSpacing
		end

		if (#descLines > 0) then
			dividerY = cursor + Sc(9)
			cursor = cursor + Sc(19)
			descTop = cursor
			cursor = cursor + #descLines * descRow
		end

		local plateHeight = math.Round(cursor + padB)
		local plateX = math.Round((ScrW() - plateWidth) * 0.5)
		local plateY = y - Sc(20)

		plateX = math.Clamp(plateX, margin, math.max(ScrW() - plateWidth - margin, margin))

		if (plateY + plateHeight > ScrH() - margin) then
			plateY = math.max(ScrH() - margin - plateHeight, margin)
		end

		NETWORK.nameplate.lookBottom = plateY + plateHeight

		local widthPart, heightPart = S.Unfold(unfold)
		local lineHeight = math.max(Sc(2), 2)
		local cardWidth = math.max(math.Round(plateWidth * widthPart), 2)
		local cardX = plateX + math.Round((plateWidth - cardWidth) * 0.5)
		local cardHeight = math.Round(plateHeight * heightPart)

		if (cardHeight < lineHeight * 3) then
			draw.RoundedBox(math.floor(lineHeight * 0.5), cardX, plateY, cardWidth, lineHeight,
				Color(color.r, color.g, color.b, 235 * cardAlpha))

			continue
		end

		local bBlur = bLooking and !bBlurUsed

		if (bBlur) then
			bBlurUsed = true
		end

		local radius = S.Radius("card")

		if (S.Leader) then
			local leaderX, leaderY = NETWORK.nameplate.GetLeaderPoint(target, plateX, plateY,
				plateWidth, plateHeight)

			if (leaderX) then
				S.Leader(leaderX, leaderY, cardX, plateY, cardWidth, cardHeight, color,
					cardAlpha * 0.9, math.Clamp(unfold / 0.6, 0, 1))
			end
		end

		S.Card(cardX, plateY, cardWidth, cardHeight, cardAlpha, {
			accent = color,
			blur = bBlur,
			panel = bBlur and vgui.GetWorldPanel() or nil,
			border = Color(color.r, color.g, color.b, 60)
		})

		if (cardHeight - radius * 2 > 4) then
			draw.RoundedBox(1, cardX + math.max(Sc(7), 4), plateY + radius,
				math.max(Sc(2), 2), cardHeight - radius * 2,
				Color(color.r, color.g, color.b, 235 * cardAlpha))
		end

		local textAlpha = math.Clamp((heightPart - 0.7) / 0.3, 0, 1) * cardAlpha

		if (textAlpha <= 0.01) then
			continue
		end

		S.PushClip(cardX, plateY, cardWidth, cardHeight)

		local left = plateX + padL
		local headerTop = plateY + padT

		if (icon) then
			local badgeY = headerTop + math.Round((headerHeight - badge) * 0.5)
			local badgeRadius = S.Radius("cell")
			local iconSize = Sc(16)
			local iconX = left + math.Round((badge - iconSize) * 0.5)
			local iconY = badgeY + math.Round((badge - iconSize) * 0.5)

			draw.RoundedBox(badgeRadius, left, badgeY, badge, badge,
				Color(color.r, color.g, color.b, 30 * textAlpha))
			util.DrawRoundedBorder(left, badgeY, badge, badge, badgeRadius, 1,
				Color(color.r, color.g, color.b, 90 * textAlpha))

			surface.SetMaterial(icon)
			surface.SetDrawColor(0, 0, 0, 150 * textAlpha)
			surface.DrawTexturedRect(iconX + 1, iconY + 1, iconSize, iconSize)
			surface.SetDrawColor(color.r, color.g, color.b, 245 * textAlpha)
			surface.DrawTexturedRect(iconX, iconY, iconSize, iconSize)
		end

		local textX = left + badge + badgeGap
		local blockHeight = nameHeight + (bChips and (Sc(5) + chipHeight) or 0)
		local nameY = headerTop + math.Round((headerHeight - blockHeight) * 0.5)

		draw.SimpleText(name, nameFont, textX, nameY, ColorAlpha(theme.text, 252 * textAlpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		if (groupIcon) then
			local size = Sc(15)

			surface.SetDrawColor(groupColor.r, groupColor.g, groupColor.b,
				245 * textAlpha)
			surface.SetMaterial(groupIcon)
			surface.DrawTexturedRect(textX + nameWidth + Sc(8),
				nameY + math.Round((nameHeight - size) * 0.5), size, size)
		end

		if (bChips) then
			local chipX = textX
			local chipY = nameY + nameHeight + Sc(5)

			if (role != "") then
				chipX = chipX + S.Chip(role, chipFont, chipX, chipY, color, textAlpha) + chipGap
			end

			if (groupName) then
				S.Chip(groupName, chipFont, chipX, chipY, groupColor, textAlpha)
			end
		end

		if (statusTop) then
			local rowY = plateY + statusTop
			local chipRadius = S.Radius("chip")

			for _, status in ipairs(statuses) do
				local lineColor = status.color
				local statusMaterial = NETWORK.nameplate.GetIcon("framework/status/" ..
					status.icon .. ".png")
				local rowMid = rowY + math.Round(statusRow * 0.5)
				local lineX = left + statusPad

				draw.RoundedBox(chipRadius, left, rowY, status.width, statusRow,
					Color(lineColor.r, lineColor.g, lineColor.b, 26 * textAlpha))

				if (statusMaterial) then
					surface.SetMaterial(statusMaterial)
					surface.SetDrawColor(lineColor.r, lineColor.g, lineColor.b, 245 * textAlpha)
					surface.DrawTexturedRect(lineX, rowMid - math.Round(statusIcon * 0.5),
						statusIcon, statusIcon)
				end

				draw.SimpleText(status.text, "nwTagDesc", lineX + statusIcon + statusGap, rowMid,
					ColorAlpha(lineColor, 245 * textAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				rowY = rowY + statusRow + statusSpacing
			end
		end

		if (descTop) then
			surface.SetDrawColor(255, 255, 255, 16 * textAlpha)
			surface.DrawRect(left, plateY + dividerY, plateWidth - padL - padR, 1)

			local lineY = plateY + descTop
			local descColor = Color(190, 200, 212, 242 * textAlpha)

			for i = 1, #descLines do
				util.DrawStyledText(descLines[i], descFonts, left, lineY + math.Round(descRow * 0.5),
					descColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				lineY = lineY + descRow
			end
		end

		S.PopClip()
	end
end)

function NETWORK.nameplate.GetWoundText(target)
	if (!NETWORK.wound) then
		return
	end

	local worst, amount

	for _, part in ipairs(NETWORK.wound.parts) do
		local value = NETWORK.wound.Get(target, part.id)

		if (value > 0 and (!amount or value > amount)) then
			worst = part
			amount = value
		end
	end

	if (!worst) then
		return
	end

	local label, color = NETWORK.wound.GetSeverity(amount)

	return NETWORK.util.Upper(L(worst.name)) .. " :: " ..
		NETWORK.util.Upper(L(label)), color
end

function NETWORK.nameplate.GetNPCState(entity)
	local id = entity:GetDialogue()

	if (id == "") then
		return
	end

	local data = NETWORK.dialogue.Get(id)

	if (!data) then
		return
	end

	local client = LocalPlayer()

	for _, node in pairs(data.nodes or {}) do
		for _, reply in ipairs(node.replies or {}) do
			if (reply.complete and NETWORK.quest.CanComplete(client, reply.complete)) then
				return "complete"
			end
		end
	end

	for _, node in pairs(data.nodes or {}) do
		for _, reply in ipairs(node.replies or {}) do
			if (reply.quest and !NETWORK.quest.Has(client, reply.quest)) then
				return "offer"
			end
		end
	end

	return "talk"
end

hook.Add("HUDPaint", "nwNPCPlates", function()
	if (!enabled:GetBool() or NETWORK.hud.IsHidden()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local eyePos = client:EyePos()
	local shadow = math.max(Sc(2), 1)

	local list = {}

	for _, class in ipairs({"nw_npc", "nw_trader"}) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			list[#list + 1] = entity
		end
	end

	for _, entity in ipairs(list) do
		local top = NETWORK.nameplate.GetAnchor(entity)
		local distance = eyePos:Distance(top)

		if (distance > NETWORK.nameplate.distance) then
			continue
		end

		if ((entity.nwPlateCheck or 0) < CurTime()) then
			entity.nwPlateCheck = CurTime() + 0.25

			local trace = _G.util.TraceLine({
				start = eyePos,
				endpos = top,
				filter = {client, entity},
				mask = MASK_VISIBLE
			})

			entity.nwPlateHidden = trace.Hit
		end

		if (entity.nwPlateHidden) then
			continue
		end

		local screen = top:ToScreen()

		if (!screen.visible) then
			continue
		end

		local fade = 1 - math.Clamp((distance - NETWORK.nameplate.fadeStart) /
			math.max(NETWORK.nameplate.distance - NETWORK.nameplate.fadeStart, 1), 0, 1)

		if (fade <= 0.02) then
			continue
		end

		local name = util.Upper(entity:GetDisplayName())
		local nameWidth, nameHeight = util.TextSpacedSize(name, "nwTag", Sc(3))
		local x = math.Round(screen.x)
		local y = math.Round(screen.y)
		local state = entity:GetClass() == "nw_trader" and "trade" or
			NETWORK.nameplate.GetNPCState(entity)
		local color = theme.textDim
		local marker

		if (state == "complete") then
			color = Color(120, 220, 140)
			marker = "!"
		elseif (state == "offer") then
			color = Color(240, 200, 90)
			marker = "!"
		elseif (state == "talk") then
			color = theme.accentSoft
			marker = "?"
		elseif (state == "trade") then
			color = Color(240, 200, 90)
			marker = "$"
		end

		local bHint = distance <= 150
		local hint = bHint and util.Upper(state == "trade" and L("npcTrade") or
			L("npcTalk")) or nil

		surface.SetFont("nwTagSub")

		local hintWidth = hint and surface.GetTextSize(hint) or 0
		local plateWidth = math.max(nameWidth, hintWidth) + Sc(30)
		local plateHeight = hint and Sc(44) or Sc(28)
		local plateX = x - math.Round(plateWidth * 0.5)
		local plateY = y - math.Round(plateHeight * 0.42)

		if (NETWORK.style and NETWORK.style.Card) then
			NETWORK.style.Card(plateX, plateY, plateWidth, plateHeight, fade, {
				accent = color,
				blur = false,
				fill = Color(10, 13, 17, 226),
				border = Color(color.r, color.g, color.b, 70)
			})
		end

		util.DrawSimpleTextShadow(math.Round(distance * 0.0254) .. " " ..
			L("questMetres"), "nwHudSmall", x, plateY - Sc(9),
			ColorAlpha(theme.textFaint, 220 * fade), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, shadow)

		if (marker) then
			util.DrawSimpleTextShadow(marker, "nwBrand", x, plateY - Sc(24),
				ColorAlpha(color, 250 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)
		end

		util.DrawTextSpacedShadow(name, "nwTag", x - math.Round(nameWidth * 0.5),
			plateY + (hint and Sc(15) or math.Round(plateHeight * 0.5)),
			ColorAlpha(theme.text, 252 * fade), Sc(3), TEXT_ALIGN_CENTER, shadow)

		if (hint) then
			surface.SetDrawColor(color.r, color.g, color.b, 55 * fade)
			surface.DrawRect(plateX + Sc(12), plateY + Sc(26),
				plateWidth - Sc(24), 1)

			util.DrawSimpleTextShadow(hint, "nwTagSub", x, plateY + Sc(35),
				ColorAlpha(color, 240 * fade), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER, shadow)
		end
	end
end)

hook.Add("EntityRemoved", "nwNameplates", function(entity)
	if (entity:IsPlayer()) then
		alphas[entity:EntIndex()] = nil
		visible[entity:EntIndex()] = nil
		unfolds[entity:EntIndex()] = nil
		fades[entity:EntIndex()] = nil
	end
end)
