local M = NETWORK.medical

local FRACTURE = Color(178, 118, 232)

local shapes = {
	head = {0.41, 0.02, 0.18, 0.13, true},
	chest = {0.33, 0.165, 0.34, 0.2},
	stomach = {0.35, 0.37, 0.30, 0.15},
	armLeft = {0.16, 0.17, 0.14, 0.34},
	armRight = {0.70, 0.17, 0.14, 0.34},
	legLeft = {0.355, 0.535, 0.135, 0.44},
	legRight = {0.51, 0.535, 0.135, 0.44}
}

local function PartState(entry)
	local theme = NETWORK.theme

	if (!entry) then
		return theme.textFaint, 0
	end

	if (entry.bleed != "" and !entry.tq) then
		if (entry.bleed == "artery" or entry.bleed == "major") then
			return theme.danger, entry.bleed == "artery" and 1 or 0.5
		end

		return theme.warning, 0.3
	end

	if (entry.fracture == 1) then
		return FRACTURE, 0
	end

	if (entry.wound > 0) then
		local _, color = NETWORK.wound.GetSeverity(entry.wound)

		return color, 0
	end

	return Color(120, 128, 136), 0
end

local BODY = {}

function BODY:Init()
	self.hovered = nil
	self:SetCursor("hand")
end

function BODY:GetBoxRect(id)
	local shape = shapes[id]
	local width, height = self:GetSize()
	local scale = math.min(width / 0.9, height)
	local offsetX = math.Round((width - scale) * 0.5)

	return offsetX + math.Round(shape[1] * scale), math.Round(shape[2] * height),
		math.Round(shape[3] * scale), math.Round(shape[4] * height), shape[5]
end

function BODY:PartAt(x, y)
	local silhouette = NETWORK.medical.body

	if (silhouette.IsAvailable()) then
		local bx, by, bw, bh = silhouette.GetRect(0, 0, self:GetSize())

		return silhouette.PartAt(x, y, bx, by, bw, bh)
	end

	for id in pairs(shapes) do
		local px, py, pw, ph = self:GetBoxRect(id)

		if (x >= px and y >= py and x <= px + pw and y <= py + ph) then
			return id
		end
	end
end

function BODY:Think()
	if (!self:IsHovered()) then
		self.hovered = nil

		return
	end

	self.hovered = self:PartAt(self:CursorPos())
end

function BODY:OnMousePressed(code)
	if (code != MOUSE_LEFT) then
		return
	end

	local id = self:PartAt(self:CursorPos())
	local owner = self:GetParent()

	if (!id or !IsValid(owner)) then
		return
	end

	surface.PlaySound("buttons/lightswitch2.wav")

	owner.selected = owner.selected == id and nil or id
end

function BODY:PaintBoxes(width, height)
	local Sc = NETWORK.util.Scale
	local owner = self:GetParent()
	local data = owner.data or {}
	local alpha = owner.alpha or 1
	local byID = {}

	for _, entry in ipairs(data.parts or {}) do
		byID[entry.id] = entry
	end

	for id in pairs(shapes) do
		local x, y, w, h, bRound = self:GetBoxRect(id)
		local entry = byID[id]
		local color, urgency = PartState(entry)
		local bSelected = owner.selected == id
		local bHovered = self.hovered == id
		local radius = bRound and math.floor(math.min(w, h) * 0.5) or math.max(Sc(6), 3)
		local pulse = urgency > 0 and
			(0.55 + math.abs(math.sin(RealTime() * (2 + urgency * 3))) * 0.45) or 1

		draw.RoundedBox(radius, x, y, w, h, Color(14, 15, 18, 235 * alpha))

		if (bRound) then
			draw.RoundedBox(radius, x, y, w, h,
				ColorAlpha(color, (bSelected and 120 or 70) * alpha * pulse))
		else
			NETWORK.util.DrawVGradient(x + 1, y + 1, w - 2, h - 2,
				ColorAlpha(color, (bSelected and 150 or 95) * alpha * pulse),
				ColorAlpha(color, 18 * alpha))
		end

		if (bSelected or bHovered) then
			NETWORK.util.DrawRoundedOutline(x, y, w, h, radius,
				ColorAlpha(bSelected and NETWORK.theme.hover or NETWORK.theme.accentSoft,
				(bSelected and 250 or 140) * alpha), math.max(Sc(2), 1))
		end

		if (entry and entry.tq) then
			surface.SetDrawColor(NETWORK.theme.warning.r, NETWORK.theme.warning.g,
				NETWORK.theme.warning.b, 245 * alpha)
			surface.DrawRect(x - Sc(2), y + Sc(6), w + Sc(4), math.max(Sc(4), 3))
		end

		if (entry and entry.fracture == 2) then
			surface.SetDrawColor(210, 190, 150, 220 * alpha)
			surface.DrawRect(x + Sc(3), y + Sc(10), math.max(Sc(2), 2), h - Sc(20))
			surface.DrawRect(x + w - Sc(5), y + Sc(10), math.max(Sc(2), 2), h - Sc(20))
		elseif (entry and entry.fracture == 1) then
			local middleY = y + math.Round(h * 0.5)

			NETWORK.util.DrawThickLine(x + Sc(3), middleY - Sc(5), x + math.Round(w * 0.5),
				middleY + Sc(5), math.max(Sc(2), 2), ColorAlpha(FRACTURE, 250 * alpha))
			NETWORK.util.DrawThickLine(x + math.Round(w * 0.5), middleY + Sc(5),
				x + w - Sc(3), middleY - Sc(5), math.max(Sc(2), 2),
				ColorAlpha(FRACTURE, 250 * alpha))
		end
	end

	if (data.bPneumo) then
		local x, y, w, h = self:GetBoxRect("chest")
		local pulse = 0.5 + math.abs(math.sin(RealTime() * 1.4)) * 0.5

		NETWORK.util.DrawRoundedOutline(x - Sc(4), y - Sc(4), w + Sc(8), h + Sc(8),
			math.max(Sc(8), 4), Color(120, 180, 255, 200 * alpha * pulse),
			math.max(Sc(2), 1))
	end
end

function BODY:Paint(width, height)
	local silhouette = NETWORK.medical.body

	if (!silhouette.IsAvailable()) then
		return self:PaintBoxes(width, height)
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local owner = self:GetParent()
	local data = owner.data or {}
	local alpha = owner.alpha or 1
	local bx, by, bw, bh = silhouette.GetRect(0, 0, width, height)
	local byID = {}
	local colors = {}

	for _, entry in ipairs(data.parts or {}) do
		byID[entry.id] = entry

		local bInjured = entry.wound > 0 or entry.fracture > 0 or entry.bleed != ""

		if (bInjured) then
			local color, urgency = PartState(entry)
			local pulse = urgency > 0 and
				(0.6 + math.abs(math.sin(RealTime() * (2 + urgency * 3))) * 0.4) or 0.9

			colors[entry.id] = ColorAlpha(color, 235 * pulse)
		end
	end

	silhouette.Draw(bx, by, bw, bh, colors, alpha)

	for _, id in ipairs({self.hovered, owner.selected}) do
		local material = id and silhouette.GetMaterial(id)

		if (material) then
			local bSelected = id == owner.selected

			surface.SetMaterial(material)
			surface.SetDrawColor(theme.hover.r, theme.hover.g, theme.hover.b,
				(bSelected and 110 or 55) * alpha)
			surface.DrawTexturedRect(bx, by, bw, bh)
			draw.NoTexture()
		end
	end

	local line = math.max(Sc(2), 2)

	for id, entry in pairs(byID) do
		local ax, ay = silhouette.GetAnchor(id, bx, by, bw, bh)

		if (entry.tq) then
			local band = math.Round(bw * 0.2)

			draw.RoundedBox(line, ax - math.Round(band * 0.5), ay - math.Round(bh * 0.09),
				band, math.max(Sc(4), 3), ColorAlpha(theme.warning, 250 * alpha))
		end

		if (entry.fracture == 1) then
			local arm = math.Round(bw * 0.07)

			NETWORK.util.DrawThickLine(ax - arm, ay - arm, ax, ay + arm, line,
				ColorAlpha(Color(255, 255, 255), 240 * alpha))
			NETWORK.util.DrawThickLine(ax, ay + arm, ax + arm, ay - arm, line,
				ColorAlpha(Color(255, 255, 255), 240 * alpha))
		elseif (entry.fracture == 2) then
			local tall = math.Round(bh * 0.1)
			local gap = math.Round(bw * 0.06)

			surface.SetDrawColor(210, 190, 150, 235 * alpha)
			surface.DrawRect(ax - gap, ay - math.Round(tall * 0.5), line, tall)
			surface.DrawRect(ax + gap - line, ay - math.Round(tall * 0.5), line, tall)
		end
	end

	if (data.bPneumo) then
		local ax, ay = silhouette.GetAnchor("chest", bx, by, bw, bh)
		local pulse = 0.5 + math.abs(math.sin(RealTime() * 1.4)) * 0.5

		NETWORK.util.DrawArc(ax, ay, math.Round(bw * 0.24), line, 1,
			Color(120, 180, 255, 210 * alpha * pulse), 64)
	end
end

vgui.Register("nwMedBody", BODY, "DPanel")

local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.medPanel = self

	self.alpha = 0
	self.bClosing = false
	self.data = {}
	self.selected = nil
	self.itemButtons = {}
	self.itemSignature = ""

	self:SetSize(math.min(Sc(860), ScrW() - Sc(40)), math.min(Sc(580), ScrH() - Sc(40)))
	self:Center()
	self:MakePopup()

	self.body = self:Add("nwMedBody")

	self.items = self:Add("DScrollPanel")
	self.items:GetVBar():SetWide(Sc(4))
	self.items:GetVBar().Paint = function() end
	self.items:GetVBar().btnUp.Paint = function() end
	self.items:GetVBar().btnDown.Paint = function() end
	self.items:GetVBar().btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(math.floor(width * 0.5), 0, 0, width, height,
			ColorAlpha(NETWORK.theme.accentDeep, 200))
	end

	self.closeButton = self:Add("DButton")
	self.closeButton:SetText("")
	self.closeButton:SetCursor("hand")
	self.closeButton.DoClick = function()
		self:Close()
	end
	self.closeButton.Paint = function(panel, width, height)
		local hover = panel:IsHovered() and 1 or 0

		NETWORK.gui.DrawButtonFace(0, 0, width, height, hover, false, self.alpha)

		draw.SimpleText(NETWORK.util.Upper(L("medClose")), "nwTab",
			math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.text, 245 * self.alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

function PANEL:Setup(patient, data)
	self.patient = patient

	self:SetData(data)
end

function PANEL:SetData(data)
	self.data = data or {}
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local pad = Sc(22)
	local top = Sc(78)

	self.body:SetPos(pad, top)
	self.body:SetSize(Sc(220), height - top - Sc(64))

	local itemsWidth = Sc(250)

	self.items:SetPos(width - pad - itemsWidth, top + Sc(24))
	self.items:SetSize(itemsWidth, height - top - Sc(24) - Sc(64))

	self.closeButton:SetSize(Sc(140), Sc(34))
	self.closeButton:SetPos(width - pad - Sc(140), height - Sc(48))
end

function PANEL:GetOwnedTreatments()
	local counts = {}

	for _, item in pairs(NETWORK.inventory.state and NETWORK.inventory.state.items or {}) do
		if (istable(item) and M.IsTreatment(item.id)) then
			counts[item.id] = (counts[item.id] or 0) + (item.amount or 1)
		end
	end

	local list = {}

	for id, count in pairs(counts) do
		list[#list + 1] = {id = id, count = count, order = M.GetTreatment(id).order}
	end

	table.sort(list, function(a, b)
		return a.order < b.order
	end)

	return list
end

function PANEL:RebuildItems()
	local Sc = NETWORK.util.Scale
	local list = self:GetOwnedTreatments()
	local signature = {}

	for _, entry in ipairs(list) do
		signature[#signature + 1] = entry.id .. "=" .. entry.count
	end

	signature = table.concat(signature, ",")

	if (signature == self.itemSignature) then
		return
	end

	self.itemSignature = signature
	self.items:Clear()
	self.itemButtons = {}

	for _, entry in ipairs(list) do
		local base = NETWORK.item.Get(entry.id)
		local treatment = M.GetTreatment(entry.id)
		local button = self.items:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:Dock(TOP)
		button:DockMargin(0, 0, Sc(6), Sc(6))
		button:SetTall(Sc(50))
		button.DoClick = function()
			if (!IsValid(self.patient)) then
				return
			end

			surface.PlaySound("buttons/lightswitch2.wav")

			net.Start("nwMedTreat")
				net.WriteEntity(self.patient)
				net.WriteString(entry.id)
				net.WriteString(self.selected or "")
			net.SendToServer()
		end
		button.Paint = function(panel, width, height)
			local hover = panel:IsHovered() and 1 or 0
			local bFits = self:TreatmentFits(treatment)
			local accent = bFits and NETWORK.theme.hover or NETWORK.theme.accentDeep

			draw.RoundedBox(math.max(Sc(6), 3), 0, 0, width, height,
				Color(18, 19, 22, (200 + 40 * hover) * self.alpha))

			draw.RoundedBox(math.max(Sc(3), 2), 0, Sc(8), math.max(Sc(3), 2),
				height - Sc(16), ColorAlpha(accent, (bFits and 230 or 120) * self.alpha))

			local glyph = Sc(14)

			NETWORK.gui.DrawGlyph(treatment.glyph or "plus", Sc(14),
				math.Round((height - glyph) * 0.5), glyph,
				ColorAlpha(accent, (170 + 80 * hover) * self.alpha))

			draw.SimpleText(base and base.name or entry.id, "nwField", Sc(38), Sc(17),
				ColorAlpha(NETWORK.theme.text, (bFits and 250 or 150) * self.alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(L("medItemMeta", treatment.time, L("medTarget_" ..
				treatment.target)), "nwHudSmall", Sc(38), Sc(35),
				ColorAlpha(NETWORK.theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText("×" .. entry.count, "nwHudValue", width - Sc(12),
				math.Round(height * 0.5), ColorAlpha(NETWORK.theme.textDim,
				220 * self.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		self.itemButtons[#self.itemButtons + 1] = button
	end
end

function PANEL:TreatmentFits(treatment)
	local part = self.selected

	if (!part or treatment.target == "body") then
		return true
	end

	if (treatment.target == "limb") then
		return M.IsLimb(part)
	end

	if (treatment.target == "chest") then
		return part == "chest"
	end

	return true
end

function PANEL:GetAdvice()
	local data = self.data

	if (!data.parts) then
		return
	end

	local bArtery, bBleed, bFracture = false, false, false

	for _, entry in ipairs(data.parts) do
		if (entry.bleed != "" and !entry.tq) then
			bBleed = true

			if (entry.bleed == "artery") then
				bArtery = true
			end
		end

		if (entry.fracture == 1) then
			bFracture = true
		end
	end

	if (bArtery) then
		return "medAdviceArtery", NETWORK.theme.danger
	end

	if (bBleed) then
		return "medAdviceBleed", NETWORK.theme.danger
	end

	if (data.bPneumo) then
		return "medAdviceChest", NETWORK.theme.warning
	end

	if (data.bCritical) then
		return "medAdviceRevive", NETWORK.theme.warning
	end

	if ((data.bloodClass or 1) >= 3 and !data.bTransfusing) then
		return "medAdviceBlood", NETWORK.theme.warning
	end

	if (bFracture) then
		return "medAdviceFracture", NETWORK.theme.warning
	end

	if ((data.bloodClass or 1) >= 2 or (data.health or 100) < 60) then
		return "medAdviceRest", NETWORK.theme.textDim
	end

	return "medAdviceFine", NETWORK.theme.positive
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1,
		self.bClosing and 14 or 10)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()

		return
	end

	if (!self.bClosing and !IsValid(self.patient)) then
		self:Close()

		return
	end

	self:RebuildItems()
end

function PANEL:Close(bFromServer)
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	if (!bFromServer) then
		net.Start("nwMedStop")
		net.SendToServer()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.medPanel == self) then
		NETWORK.gui.medPanel = nil
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE or key == KEY_TAB) then
		self:Close()
	end
end

local function Bar(x, y, width, fraction, color, alpha)
	NETWORK.util.DrawProgressBar(x, y, width, math.max(NETWORK.util.Scale(3), 2), fraction,
		color, alpha)
end

function PANEL:PaintRow(label, value, color, x, y, width, alpha)
	local theme = NETWORK.theme

	draw.SimpleText(NETWORK.util.Upper(label), "nwInvKey", x, y,
		ColorAlpha(theme.textFaint, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	draw.SimpleText(value, "nwInvBody", x, y + NETWORK.util.Scale(14),
		ColorAlpha(color or theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local alpha = self.alpha
	local data = self.data
	local pad = Sc(22)

	local radius = math.max(Sc(10), 6)

	util.DrawBlurRounded(self, 0, 0, width, height, radius, 4 * alpha)

	draw.RoundedBox(radius, 0, 0, width, height, Color(8, 9, 10, 232 * alpha))

	util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
		Color(255, 255, 255, 26 * alpha))

	local stateKey, stateColor = "medStateConscious", theme.positive

	if (data.bCritical) then
		stateKey, stateColor = data.bStable and "medStateCriticalStable" or
			"medStateCritical", data.bStable and theme.warning or theme.danger
	elseif (data.bUnconscious) then
		stateKey, stateColor = "medStateUnconscious", theme.warning
	end

	draw.SimpleText(util.Upper(L(data.bSelf and "medTitleSelf" or "medTitle")),
		"nwInvKey", pad, Sc(24), ColorAlpha(theme.textFaint, 235 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(data.name or "?", "nwInvTitle", pad, Sc(50),
		ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local stateText = L(stateKey)

	if (data.bCritical) then
		stateText = stateText .. "  ·  " .. string.format("%d:%02d",
			math.floor((data.left or 0) / 60), (data.left or 0) % 60)
	end

	surface.SetFont("nwInvKey")

	local stateWidth = surface.GetTextSize(util.Upper(stateText)) + Sc(24)

	draw.RoundedBox(math.max(Sc(6), 3), width - pad - stateWidth, Sc(38), stateWidth,
		Sc(24), ColorAlpha(stateColor, 30 * alpha))
	util.DrawRoundedBorder(width - pad - stateWidth, Sc(38), stateWidth, Sc(24),
		math.max(Sc(6), 3), math.max(Sc(1), 1), ColorAlpha(stateColor, 170 * alpha))

	draw.SimpleText(util.Upper(stateText), "nwInvKey", width - pad - math.Round(stateWidth * 0.5),
		Sc(50), ColorAlpha(stateColor, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(pad, Sc(70), width - pad * 2, 1)

	local infoX = pad + Sc(244)
	local infoWidth = width - infoX - Sc(250) - pad * 2
	local y = Sc(84)
	local classIndex = data.bloodClass or 1
	local classData = M.bloodClasses[classIndex] or M.bloodClasses[1]

	self:PaintRow(L("medRowHealth"), (data.health or 0) .. "%", nil, infoX, y,
		infoWidth, alpha)
	Bar(infoX, y + Sc(38), infoWidth, (data.health or 0) / 100, theme.positive, alpha)

	y = y + Sc(54)

	self:PaintRow(L("medRowBlood"), L(classData.name), classData.color, infoX, y,
		infoWidth, alpha)
	Bar(infoX, y + Sc(38), infoWidth, data.bloodFraction or 1, classData.color, alpha)

	y = y + Sc(54)

	local breath = data.bPneumo and L("medBreathBad") or L("medBreathOk")

	self:PaintRow(L("medRowBreath"), breath, data.bPneumo and theme.danger or nil,
		infoX, y, infoWidth, alpha)

	if (data.bPneumo) then
		Bar(infoX, y + Sc(38), infoWidth, (data.oxygen or 0) / M.oxygenMax,
			Color(120, 180, 255), alpha)
	end

	y = y + Sc(54)

	local pain = data.bNumb and L("medPainNumb") or (data.bPain and L("medPainYes") or
		L("medPainNo"))
	local extra = data.bTransfusing and ("  ·  " .. L("medTagTransfusion")) or ""

	self:PaintRow(L("medRowPain"), pain .. extra, data.bPain and !data.bNumb and
		theme.warning or nil, infoX, y, infoWidth, alpha)

	y = y + Sc(52)

	surface.SetDrawColor(255, 255, 255, 14 * alpha)
	surface.DrawRect(infoX, y, infoWidth, 1)

	y = y + Sc(12)

	if (self.selected) then
		local entry

		for _, part in ipairs(data.parts or {}) do
			if (part.id == self.selected) then
				entry = part

				break
			end
		end

		local partData = NETWORK.wound.GetPart(self.selected)

		draw.SimpleText(util.Upper(partData and L(partData.name) or self.selected),
			"nwInvKey", infoX, y, ColorAlpha(theme.combine, 250 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		y = y + Sc(22)

		if (entry) then
			local woundKey, woundColor = NETWORK.wound.GetSeverity(entry.wound)
			local lines = {{L("medPartWound", L(woundKey)), woundColor}}

			if (entry.bleed != "") then
				local kind = M.bleedKinds[entry.bleed]

				lines[#lines + 1] = {L(entry.tq and "medPartBleedTq" or "medPartBleed",
					L(kind.name)), entry.tq and theme.warning or theme.danger}
			end

			if (entry.fracture > 0) then
				lines[#lines + 1] = {L(entry.fracture == 2 and "medPartSplinted" or
					"medPartFracture"), entry.fracture == 2 and theme.textDim or FRACTURE}
			end

			for _, line in ipairs(lines) do
				draw.SimpleText(line[1], "nwInvBody", infoX, y,
					ColorAlpha(line[2], 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

				y = y + Sc(20)
			end
		end
	else
		draw.SimpleText(L("medSelectHint"), "nwHudSmall", infoX, y,
			ColorAlpha(theme.textFaint, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		y = y + Sc(22)
	end

	local adviceKey, adviceColor = self:GetAdvice()

	if (adviceKey) then
		local lines = util.WrapText(L(adviceKey), "nwInvBody", infoWidth - Sc(24), 3)
		local boxHeight = #lines * Sc(18) + Sc(34)
		local boxY = height - Sc(64) - boxHeight
		local boxRadius = math.max(Sc(6), 3)

		draw.RoundedBox(boxRadius, infoX, boxY, infoWidth, boxHeight, Color(12, 13, 15, 200 * alpha))
		util.DrawRoundedBorder(infoX, boxY, infoWidth, boxHeight, boxRadius, math.max(Sc(1), 1),
			ColorAlpha(adviceColor, 140 * alpha))
		draw.RoundedBox(math.max(Sc(2), 2), infoX + Sc(6), boxY + Sc(8), math.max(Sc(3), 2),
			boxHeight - Sc(16), ColorAlpha(adviceColor, 230 * alpha))

		draw.SimpleText(util.Upper(L("medAdviceTitle")), "nwInvKey", infoX + Sc(16),
			boxY + Sc(8), ColorAlpha(adviceColor, 240 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP)

		for index, line in ipairs(lines) do
			draw.SimpleText(line, "nwInvBody", infoX + Sc(16), boxY + Sc(24) +
				(index - 1) * Sc(18), ColorAlpha(theme.text, 245 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	local itemsX = width - pad - Sc(250)

	draw.SimpleText(util.Upper(L("medItems")), "nwInvKey", itemsX, Sc(90),
		ColorAlpha(theme.textFaint, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (#self.itemButtons == 0) then
		draw.SimpleText(L("medNoItems"), "nwHudSmall", itemsX, Sc(116),
			ColorAlpha(theme.textFaint, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	draw.SimpleText(L("medFooterHint"), "nwHudSmall", pad, height - Sc(31),
		ColorAlpha(theme.textFaint, 225 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwMedPanel", PANEL, "EditablePanel")
