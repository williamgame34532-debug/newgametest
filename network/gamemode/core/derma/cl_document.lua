local PAPER = Color(232, 226, 206)
local PAPER_DARK = Color(196, 184, 152)
local INK = Color(40, 40, 46)
local INK_DIM = Color(104, 104, 108)

local GRAIN = {}

for index = 1, 900 do
	GRAIN[index] = {(index * 0.7548776662) % 1, (index * 0.5698402910) % 1, index % 3}
end

local bPaperFonts

local function EnsurePaperFonts()
	if (bPaperFonts) then
		return
	end

	bPaperFonts = true

	surface.CreateFont("nwDocType", {font = NETWORK.fonts.mono or "Courier New", size = math.max(math.Round(
		NETWORK.util.Scale(16)), 11), weight = 600, extended = true, antialias = true})
	surface.CreateFont("nwDocTypeSmall", {font = NETWORK.fonts.mono or "Courier New", size = math.max(math.Round(
		NETWORK.util.Scale(13)), 10), weight = 500, extended = true, antialias = true})
	surface.CreateFont("nwDocTypeTitle", {font = NETWORK.fonts.mono or "Courier New", size = math.max(math.Round(
		NETWORK.util.Scale(24)), 14), weight = 700, extended = true, antialias = true})
end

local function DrawPaperSheet(panel, x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	util.DrawSoftLight(x + math.floor(width * 0.5) + Sc(6), y + math.floor(height * 0.5) + Sc(12),
		width * 1.25, height * 1.2, Color(0, 0, 0), 170 * alpha)

	surface.SetDrawColor(PAPER.r, PAPER.g, PAPER.b, 255 * alpha)
	surface.DrawRect(x, y, width, height)

	util.DrawHGradient(x, y, math.floor(width * 0.3), height, ColorAlpha(PAPER_DARK, 70 * alpha),
		ColorAlpha(PAPER_DARK, 0))
	util.DrawHGradient(x + width - math.floor(width * 0.3), y, math.floor(width * 0.3), height,
		ColorAlpha(PAPER_DARK, 0), ColorAlpha(PAPER_DARK, 70 * alpha))
	util.DrawVGradient(x, y + height - math.floor(height * 0.25), width, math.floor(height * 0.25),
		ColorAlpha(PAPER_DARK, 0), ColorAlpha(PAPER_DARK, 60 * alpha))

	local screenX, screenY = panel:LocalToScreen(x, y)

	render.SetScissorRect(screenX, screenY, screenX + width, screenY + height, true)

	for _, grain in ipairs(GRAIN) do
		local shade = grain[3]

		surface.SetDrawColor(shade == 0 and 120 or 255, shade == 0 and 100 or 255,
			shade == 0 and 70 or 240, (shade == 0 and 22 or 34) * alpha)
		surface.DrawRect(x + math.floor(grain[1] * width), y + math.floor(grain[2] * height),
			shade == 2 and 2 or 1, 1)
	end

	for _, fraction in ipairs({0.34, 0.67}) do
		local foldY = y + math.floor(height * fraction)

		surface.SetDrawColor(PAPER_DARK.r, PAPER_DARK.g, PAPER_DARK.b, 90 * alpha)
		surface.DrawRect(x, foldY, width, 1)
		surface.SetDrawColor(255, 255, 255, 60 * alpha)
		surface.DrawRect(x, foldY + 1, width, 1)
		util.DrawVGradient(x, foldY - Sc(6), width, Sc(6), ColorAlpha(PAPER_DARK, 0),
			ColorAlpha(PAPER_DARK, 40 * alpha))
	end

	surface.SetDrawColor(PAPER_DARK.r, PAPER_DARK.g, PAPER_DARK.b, 26 * alpha)

	for lineY = y + Sc(120), y + height - Sc(70), Sc(21) do
		surface.DrawRect(x + Sc(30), lineY, width - Sc(60), 1)
	end

	local util2 = NETWORK.util

	util2.DrawSoftLight(x + math.floor(width * 0.78), y + math.floor(height * 0.22), Sc(120), Sc(120),
		Color(120, 90, 40), 26 * alpha)
	util2.DrawRing(x + math.floor(width * 0.78), y + math.floor(height * 0.22), Sc(38), Sc(5),
		Color(120, 90, 40, 22 * alpha), 48, 1)
	util2.DrawSoftLight(x + math.floor(width * 0.18), y + math.floor(height * 0.82), Sc(70), Sc(50),
		Color(90, 70, 40), 30 * alpha)

	draw.NoTexture()
	surface.SetDrawColor(0, 0, 0, 255 * alpha)

	local tooth = Sc(9)
	local edgeX = x

	while (edgeX < x + width) do
		local depth = Sc(2) + ((math.floor(edgeX / tooth) * 7) % 5)

		surface.DrawPoly({{x = edgeX, y = y}, {x = edgeX + tooth, y = y},
			{x = edgeX + tooth * 0.5, y = y + depth}})

		edgeX = edgeX + tooth
	end

	local corner = Sc(22)

	draw.NoTexture()
	surface.SetDrawColor(120, 100, 70, 40 * alpha)
	surface.DrawPoly({{x = x, y = y}, {x = x + corner, y = y}, {x = x, y = y + corner}})
	surface.DrawPoly({{x = x + width, y = y}, {x = x + width, y = y + corner},
		{x = x + width - corner, y = y}})

	surface.SetDrawColor(60, 50, 40, 255 * alpha)
	surface.DrawPoly({{x = x + width - corner, y = y + height}, {x = x + width, y = y + height - corner},
		{x = x + width, y = y + height}})
	surface.SetDrawColor(PAPER_DARK.r, PAPER_DARK.g, PAPER_DARK.b, 255 * alpha)
	surface.DrawPoly({{x = x + width - corner, y = y + height}, {x = x + width, y = y + height - corner},
		{x = x + width - corner, y = y + height - corner}})

	render.SetScissorRect(0, 0, 0, 0, false)
end
local STAMP = Color(58, 108, 150)

local VIEW = {}

function VIEW:Init()
	NETWORK.gui.documentView = self

	self.alpha = 0
	self.bClosing = false

	self:SetSize(ScrW(), ScrH())
	self:MakePopup()

	surface.PlaySound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) ..
		".wav")
end

function VIEW:Setup(view, shownBy)
	self.view = view or {}
	self.shownBy = shownBy != "" and shownBy or nil

	if (NETWORK.factions.CanCheckDocuments(LocalPlayer()) and
		self.view.serial != "") then
		local Sc = NETWORK.util.Scale
		local button = self:Add("nwInvButton")

		button:SetSize(Sc(240), Sc(38))
		button:Setup(L("docVerify"), "shield", true)
		button.DoClick = function()
			net.Start("nwDocVerify")
				net.WriteString(self.view.serial)
			net.SendToServer()
		end

		self.verify = button
	end

	if (self.view.kind == "idcard") then
		local Sc = NETWORK.util.Scale
		local fields = {
			{L("docFieldHolder"), self.view.holder or ""},
			{L("docFieldCID"), "#" .. (self.view.cid or "")},
			{L("docFieldSerial"), self.view.serial or ""},
			{L("docFieldIssued"), self.view.issued or ""}
		}

		self.copyButtons = {}

		for index, field in ipairs(fields) do
			local button = self:Add("nwInvButton")

			button:SetSize(Sc(122), Sc(34))
			button:Setup(field[1], "list", false)
			button.DoClick = function()
				SetClipboardText(field[2])
				NETWORK.gui.Notify(L("docCopied", field[1]), NETWORK.theme.positive)
			end

			self.copyButtons[index] = button
		end

		local all = self:Add("nwInvButton")

		all:SetSize(Sc(520), Sc(36))
		all:Setup(L("docCopyAll"), "stack", true)
		all.DoClick = function()
			local lines = {}

			for _, field in ipairs(fields) do
				lines[#lines + 1] = field[1] .. ": " .. field[2]
			end

			SetClipboardText(table.concat(lines, "\n"))
			NETWORK.gui.Notify(L("docCopied", L("docCopyAllShort")), NETWORK.theme.positive)
		end

		self.copyAll = all
	end
end

function VIEW:GetCard()
	local Sc = NETWORK.util.Scale

	if (self.view and self.view.kind == "idcard") then
		local width = Sc(520)

		return math.Round((ScrW() - width) * 0.5), math.Round(ScrH() * 0.5 - Sc(170)),
			width, Sc(340)
	end

	local width = math.min(Sc(560), ScrW() - Sc(40))
	local height = math.min(Sc(700), ScrH() - Sc(120))

	return math.Round((ScrW() - width) * 0.5), math.Round((ScrH() - height) * 0.5) - Sc(20),
		width, height
end

function VIEW:PerformLayout()
	local Sc = NETWORK.util.Scale
	local x, y, width, height = self:GetCard()
	local buttonY = y + height + Sc(16)

	if (self.copyButtons) then
		local gap = Sc(10)
		local rowWidth = #self.copyButtons * Sc(122) + (#self.copyButtons - 1) * gap
		local startX = x + math.Round((width - rowWidth) * 0.5)

		for index, button in ipairs(self.copyButtons) do
			button:SetPos(startX + (index - 1) * (Sc(122) + gap), buttonY)
		end

		self.copyAll:SetPos(x, buttonY + Sc(44))

		buttonY = buttonY + Sc(92)
	end

	if (IsValid(self.verify)) then
		self.verify:SetPos(x + math.Round((width - self.verify:GetWide()) * 0.5), buttonY)
	end
end

function VIEW:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function VIEW:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1,
		self.bClosing and 14 or 9)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function VIEW:OnRemove()
	if (NETWORK.gui.documentView == self) then
		NETWORK.gui.documentView = nil
	end
end

function VIEW:OnMousePressed()
	local x, y, width, height = self:GetCard()
	local mouseX, mouseY = gui.MousePos()

	if (mouseX < x or mouseY < y or mouseX > x + width or mouseY > y + height) then
		self:Close()
	end
end

function VIEW:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE or key == KEY_E or key == KEY_TAB) then
		self:Close()
	end
end

local function Field(label, value, x, y, width, alpha)
	EnsurePaperFonts()

	local Sc = NETWORK.util.Scale

	draw.SimpleText(NETWORK.util.Upper(label), "nwHudSmall", x, y,
		ColorAlpha(INK_DIM, 255 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	draw.SimpleText(NETWORK.util.TruncateWidth(value != "" and value or "—", "nwDocType", width),
		"nwDocType", x, y + Sc(14), ColorAlpha(INK, 245 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_TOP)

	surface.SetDrawColor(INK_DIM.r, INK_DIM.g, INK_DIM.b, 140 * alpha)

	local dashes = NETWORK.util.GetTexture("framework/pattern/dash4.png")

	if (dashes) then
		NETWORK.util.DrawTiled(dashes, x, y + Sc(38), width + 2, 1)
		draw.NoTexture()
	else
		for dot = 0, width, 4 do
			surface.DrawRect(x + dot, y + Sc(38), 2, 1)
		end
	end
end

local function StateStamp(x, y, width, view, alpha)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local status = view.status or "valid"
	local label, color

	if (status == "revoked") then
		label, color = L("docStateRevoked"), theme.danger
	elseif (status == "expired") then
		label, color = L("docStateExpired"), Color(140, 140, 140)
	elseif (status == "forged") then
		label, color = L("docStateForged"), theme.danger
	else
		label, color = L("docStateValid"), Color(63, 150, 94)
	end

	label = NETWORK.util.Upper(label)

	surface.SetFont("nwHudSmall")

	local textWidth = surface.GetTextSize(label)
	local stampWidth = textWidth + Sc(28)
	local stampHeight = Sc(26)
	local centerX = x + width - Sc(70) - stampWidth * 0.5
	local centerY = y + Sc(4)

	local matrix = Matrix()

	matrix:Translate(Vector(centerX, centerY, 0))
	matrix:Rotate(Angle(0, 7, 0))
	matrix:Translate(Vector(-centerX, -centerY, 0))

	cam.PushModelMatrix(matrix)

	local left = centerX - stampWidth * 0.5
	local top = centerY - stampHeight * 0.5

	surface.SetDrawColor(20, 14, 12, 235 * alpha)
	surface.DrawRect(left, top, stampWidth, stampHeight)

	surface.SetDrawColor(color.r, color.g, color.b, 220 * alpha)
	surface.DrawOutlinedRect(left, top, stampWidth, stampHeight, math.max(Sc(2), 2))

	draw.SimpleText(label, "nwHudSmall", centerX, centerY,
		ColorAlpha(color, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	cam.PopModelMatrix()
end

local function Stamp(centerX, centerY, radius, alpha)
	local Sc = NETWORK.util.Scale
	local color = ColorAlpha(STAMP, 170 * alpha)

	NETWORK.util.DrawRing(centerX, centerY, radius, math.max(Sc(3), 2), color, 64)
	NETWORK.util.DrawRing(centerX, centerY, radius - Sc(8), math.max(Sc(1), 1), color, 64)

	draw.SimpleText("C24", "nwTermTitle", centerX, centerY - Sc(4), color,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(NETWORK.util.Upper(L("docStampText")), "nwHudLabelSmall", centerX,
		centerY + Sc(18), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function VIEW:PaintCard(x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local view = self.view
	local radius = Sc(18)
	local headerHeight = Sc(58)

	draw.RoundedBox(radius, x + Sc(4), y + Sc(10), width, height, Color(0, 0, 0, 130 * alpha))
	draw.RoundedBox(radius, x, y, width, height, Color(210, 217, 224, 255 * alpha))

	util.DrawHGradient(x + radius, y, width - radius * 2, height,
		Color(160, 190, 216, 80 * alpha), Color(255, 255, 255, 0))

	local drift = (RealTime() * 0.15) % 1

	util.DrawSoftLight(math.Round(x + width * drift), math.Round(y + height * 0.6), Sc(260),
		Sc(200), Color(150, 210, 230), 30 * alpha)
	util.DrawSoftLight(math.Round(x + width * (1 - drift)), math.Round(y + height * 0.4),
		Sc(200), Sc(160), Color(210, 170, 230), 18 * alpha)

	draw.RoundedBoxEx(radius, x, y, width, headerHeight, Color(34, 50, 68, 255 * alpha),
		true, true, false, false)
	util.DrawHGradient(x + radius, y, width - radius * 2, headerHeight,
		Color(70, 110, 140, 90 * alpha), Color(34, 50, 68, 0))

	surface.SetDrawColor(150, 200, 230, 200 * alpha)
	surface.DrawRect(x, y + headerHeight - 2, width, 2)

	local logo = NETWORK.util.GetMaterial(NETWORK.cmbterm.logo, "smooth")

	if (logo and !logo:IsError()) then
		surface.SetDrawColor(255, 255, 255, 240 * alpha)
		surface.SetMaterial(logo)
		surface.DrawTexturedRect(x + Sc(16), y + Sc(11), Sc(36), Sc(36))
	end

	draw.SimpleText(NETWORK.util.Upper(L("idCardTitle")), "nwTermBrand", x + Sc(64),
		y + Sc(21), Color(236, 242, 248, 255 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(NETWORK.util.Upper(L("idCardSub")), "nwHudSmall", x + Sc(64),
		y + Sc(41), Color(170, 196, 216, 255 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText("C24", "nwTermNav", x + width - Sc(20), y + Sc(29),
		Color(150, 200, 230, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local photoX, photoY = x + Sc(20), y + headerHeight + Sc(16)
	local photoW, photoH = Sc(116), Sc(146)

	draw.RoundedBox(Sc(10), photoX, photoY, photoW, photoH, Color(158, 170, 182, 255 * alpha))
	util.DrawVGradient(photoX, photoY + math.floor(photoH * 0.5), photoW, math.ceil(photoH * 0.5),
		Color(120, 132, 144, 0), Color(120, 132, 144, 200 * alpha))

	local body = NETWORK.medical and NETWORK.medical.body

	if (body and body.IsAvailable()) then
		local bx, by, bw, bh = body.GetRect(photoX + Sc(8), photoY + Sc(10), photoW - Sc(16),
			photoH * 1.45)

		render.SetScissorRect(0, 0, 0, 0, false)

		local screenX, screenY = self:LocalToScreen(photoX, photoY)

		render.SetScissorRect(screenX, screenY, screenX + photoW, screenY + photoH, true)
		body.Draw(bx, by, bw, bh, nil, alpha, Color(96, 108, 120))
		render.SetScissorRect(0, 0, 0, 0, false)
	else
		NETWORK.gui.DrawGlyph("person", photoX + Sc(20), photoY + Sc(30), photoW - Sc(40),
			Color(110, 122, 134, 255 * alpha))
	end

	local chipX, chipY = photoX + photoW + Sc(20), photoY + Sc(2)
	local chipW, chipH = Sc(42), Sc(32)

	draw.RoundedBox(Sc(6), chipX, chipY, chipW, chipH, Color(206, 176, 104, 255 * alpha))
	surface.SetDrawColor(160, 128, 64, 220 * alpha)
	surface.DrawRect(chipX + math.floor(chipW * 0.5), chipY + Sc(4), 1, chipH - Sc(8))
	surface.DrawRect(chipX + Sc(4), chipY + math.floor(chipH * 0.5), chipW - Sc(8), 1)

	local fieldX = chipX
	local fieldWidth = x + width - fieldX - Sc(20)
	local fieldY = chipY + chipH + Sc(8)

	Field(L("docFieldHolder"), view.holder or "", fieldX, fieldY, fieldWidth, alpha)
	Field(L("docFieldIssued"), view.issued or "", fieldX, fieldY + Sc(46), fieldWidth, alpha)
	Field(L("docFieldSerial"), view.serial or "", fieldX, fieldY + Sc(92), fieldWidth, alpha)

	local code = tostring(view.serial or "") .. tostring(view.cid or "")
	local barX = x + Sc(20)
	local barY = y + height - Sc(46)
	local cursor = barX

	surface.SetDrawColor(INK.r, INK.g, INK.b, 230 * alpha)

	for index = 1, math.min(#code, 18) do
		local byte = string.byte(code, index)

		for bit = 0, 2 do
			local thick = (math.floor(byte / (2 ^ bit)) % 2 == 1) and Sc(3) or Sc(1)

			surface.DrawRect(cursor, barY, thick, Sc(26))

			cursor = cursor + thick + Sc(2)
		end
	end

	draw.SimpleText(NETWORK.util.Upper(L("docFieldCID")), "nwHudSmall", x + width - Sc(20),
		y + height - Sc(58), ColorAlpha(INK_DIM, 255 * alpha), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	draw.SimpleText("#" .. (view.cid or "00000"), "nwMenuClock", x + width - Sc(20),
		y + height - Sc(30), ColorAlpha(INK, 255 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function VIEW:PaintPaper(x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local view = self.view
	local pad = Sc(34)

	EnsurePaperFonts()
	DrawPaperSheet(self, x, y, width, height, alpha)

	local logo = NETWORK.util.GetMaterial(NETWORK.cmbterm.logo, "smooth")

	if (logo and !logo:IsError()) then
		surface.SetDrawColor(INK.r, INK.g, INK.b, 230 * alpha)
		surface.SetMaterial(logo)
		surface.DrawTexturedRect(x + math.Round(width * 0.5) - Sc(22), y + Sc(22), Sc(44), Sc(44))
	end

	draw.SimpleText(NETWORK.util.Upper(L("docHeader")), "nwDocTypeSmall", x + math.Round(width * 0.5),
		y + Sc(80), ColorAlpha(INK_DIM, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(NETWORK.util.Upper(L(view.title or "docTypeNote")), "nwDocTypeTitle",
		x + math.Round(width * 0.5), y + Sc(110), ColorAlpha(INK, 255 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(INK.r, INK.g, INK.b, 160 * alpha)
	surface.DrawRect(x + pad, y + Sc(134), width - pad * 2, math.max(Sc(2), 1))

	local half = math.floor((width - pad * 2 - Sc(20)) * 0.5)
	local fieldY = y + Sc(150)

	Field(L("docFieldHolder"), view.holder or "", x + pad, fieldY, half, alpha)
	Field(L("docFieldCID"), view.cid != "" and ("#" .. view.cid) or "",
		x + pad + half + Sc(20), fieldY, half, alpha)

	fieldY = fieldY + Sc(52)

	Field(L("docFieldIssued"), view.issued or "", x + pad, fieldY, half, alpha)
	Field(L("docFieldExpires"), view.expires != "" and view.expires or L("docNoExpiry"),
		x + pad + half + Sc(20), fieldY, half, alpha)

	fieldY = fieldY + Sc(62)

	local lines = NETWORK.util.WrapText(view.text != "" and view.text or L("docNoText"),
		"nwDocType", width - pad * 2, 14)

	for index, line in ipairs(lines) do
		local lineY = fieldY + (index - 1) * Sc(21)

		if (lineY > y + height - Sc(150)) then
			break
		end

		draw.SimpleText(line, "nwDocType", x + pad, lineY,
			ColorAlpha(INK, (index % 3 == 0 and 215 or 245) * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	local footerY = y + height - Sc(90)

	Field(L("docFieldIssuer"), view.issuer or "", x + pad, footerY, half, alpha)

	draw.SimpleText(L("docFieldSerial") .. ": " .. (view.serial != "" and view.serial or "—"),
		"nwDocTypeSmall", x + pad, y + height - Sc(24), ColorAlpha(INK_DIM, 255 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	Stamp(x + width - pad - Sc(56), footerY + Sc(12), Sc(52), alpha)

	StateStamp(x, y, width, view, alpha)
end

function VIEW:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local alpha = self.alpha

	if (!self.view) then
		return
	end

	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawRect(0, 0, width, height)

	local x, y, cardWidth, cardHeight = self:GetCard()

	y = y + math.Round((1 - NETWORK.util.EaseOut(alpha)) * Sc(30))

	if (self.shownBy) then
		NETWORK.util.DrawSimpleTextShadow(L("docShownBy", self.shownBy), "nwField",
			x + math.Round(cardWidth * 0.5), y - Sc(20),
			ColorAlpha(NETWORK.theme.text, 250 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, math.max(Sc(2), 1))
	end

	if (self.view.kind == "idcard") then
		self:PaintCard(x, y, cardWidth, cardHeight, alpha)
	else
		self:PaintPaper(x, y, cardWidth, cardHeight, alpha)
	end

	NETWORK.util.DrawSimpleTextShadow(L("docCloseHint"), "nwHudSmall",
		math.Round(width * 0.5), height - Sc(40), ColorAlpha(NETWORK.theme.textDim, 230 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
end

vgui.Register("nwDocumentView", VIEW, "EditablePanel")

local function OpenView(view, shownBy)
	if (IsValid(NETWORK.gui.documentView)) then
		NETWORK.gui.documentView:Remove()
	end

	if (IsValid(NETWORK.gui.tabMenu)) then
		NETWORK.gui.tabMenu:Close()
	end

	vgui.Create("nwDocumentView"):Setup(view, shownBy)
end

local REQUEST = {}

function REQUEST:Init()
	NETWORK.gui.docRequest = self

	self.alpha = 0
	self.born = RealTime()

	self:SetSize(NETWORK.util.Scale(360), NETWORK.util.Scale(118))
	self:SetPos(math.Round((ScrW() - self:GetWide()) * 0.5), math.Round(ScrH() * 0.2))
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	surface.PlaySound("buttons/blip1.wav")
end

function REQUEST:Setup(view, shownBy)
	self.view = view
	self.shownBy = shownBy
end

function REQUEST:Accept()
	OpenView(self.view, self.shownBy)
	self:Remove()
end

function REQUEST:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 8)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()

		return
	end

	if (!self.bClosing and RealTime() - self.born > 15) then
		self.bClosing = true
	end

	if (self.bClosing or NETWORK.prompt.IsBlocked()) then
		return
	end

	if (NETWORK.prompt.AcceptDown()) then
		self:Accept()
	elseif (NETWORK.prompt.DeclineDown()) then
		self.bClosing = true
	end
end

function REQUEST:OnRemove()
	if (NETWORK.gui.docRequest == self) then
		NETWORK.gui.docRequest = nil
	end
end

function REQUEST:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = util.EaseOut(self.alpha)
	local y = math.Round((1 - alpha) * -Sc(10))

	NETWORK.gui.DrawBlackGlass(self, 0, y, width, height, alpha, Sc(14))

	util.DrawHGradient(Sc(14), y + 1, math.floor(width * 0.6), Sc(40), ColorAlpha(theme.hover, 30 * alpha),
		ColorAlpha(theme.hover, 0))
	draw.RoundedBox(2, 0, y + Sc(18), math.max(Sc(3), 2), height - Sc(36),
		ColorAlpha(theme.hover, 240 * alpha))

	NETWORK.gui.DrawGlyph("list", Sc(18), y + Sc(18), Sc(18), ColorAlpha(theme.hover, 240 * alpha))
	draw.SimpleText(L("docRequestTitle"), "nwField", Sc(44), y + Sc(27),
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(L("docRequestBody", self.shownBy or "?"), "nwHudSmall", Sc(44), y + Sc(48),
		ColorAlpha(theme.textDim, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local left = math.Clamp(1 - (RealTime() - self.born) / 15, 0, 1)

	draw.RoundedBox(1, Sc(44), y + Sc(64), width - Sc(60), 2, Color(255, 255, 255, 20 * alpha))
	draw.RoundedBox(1, Sc(44), y + Sc(64), math.Round((width - Sc(60)) * left), 2,
		ColorAlpha(theme.hover, 200 * alpha))

	local function Key(x, key, label, color)
		draw.RoundedBox(Sc(5), x, y + Sc(78), Sc(24), Sc(22), ColorAlpha(color, 40 * alpha))
		util.DrawRoundedBorder(x, y + Sc(78), Sc(24), Sc(22), Sc(5), 1, ColorAlpha(color, 200 * alpha))
		draw.SimpleText(key, "nwHudSmall", x + Sc(12), y + Sc(89), ColorAlpha(theme.text, 250 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		draw.SimpleText(label, "nwHudSmall", x + Sc(32), y + Sc(89), ColorAlpha(color, 240 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	Key(Sc(44), NETWORK.prompt.AcceptLabel(), L("docRequestAccept"), theme.positive)
	Key(Sc(190), NETWORK.prompt.DeclineLabel(), L("docRequestDecline"), theme.danger)
end

vgui.Register("nwDocRequest", REQUEST, "DPanel")

net.Receive("nwDocView", function()
	local view = NETWORK.util.ReadTable()
	local shownBy = net.ReadString()

	if (view.kind == "idcard" and shownBy != "") then
		if (IsValid(NETWORK.gui.docRequest)) then
			NETWORK.gui.docRequest:Remove()
		end

		vgui.Create("nwDocRequest"):Setup(view, shownBy)

		return
	end

	OpenView(view, shownBy)
end)

local FORM = {}

function FORM:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.documentForm = self

	self.alpha = 0

	self:SetSize(math.min(Sc(520), ScrW() - Sc(40)), math.min(Sc(560), ScrH() - Sc(40)))
	self:Center()
	self:MakePopup()

	local pad = Sc(22)
	local width = self:GetWide() - pad * 2
	local y = Sc(64)

	local function Label(text, labelY)
		local label = self:Add("DLabel")

		label:SetPos(pad, labelY)
		label:SetSize(width, Sc(16))
		label:SetFont("nwHudSmall")
		label:SetTextColor(NETWORK.theme.textDim)
		label:SetText(NETWORK.util.Upper(text))
	end

	local function Entry(entryY, entryHeight, bMultiline)
		local entry = self:Add("DTextEntry")

		entry:SetPos(pad, entryY)
		entry:SetSize(width, entryHeight)
		entry:SetFont("nwField")
		entry:SetMultiline(bMultiline or false)
		entry:SetDrawLanguageID(false)
		entry:SetPaintBackground(false)
		entry:SetTextColor(NETWORK.theme.text)
		entry:SetCursorColor(NETWORK.theme.hover)
		entry.Paint = function(panel, entryWidth, entryHeight2)
			draw.RoundedBox(Sc(8), 0, 0, entryWidth, entryHeight2,
				Color(255, 255, 255, panel:HasFocus() and 18 or 10))

			panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
				NETWORK.theme.hover)
		end

		return entry
	end

	Label(L("docFieldType"), y)

	self.type = self:Add("DComboBox")
	self.type:SetPos(pad, y + Sc(18))
	self.type:SetSize(width, Sc(34))
	self.type:SetFont("nwField")
	self.type:SetTextColor(NETWORK.theme.text)
	self.type.Paint = function(panel, comboWidth, comboHeight)
		draw.RoundedBox(Sc(8), 0, 0, comboWidth, comboHeight, Color(255, 255, 255, 12))
	end

	for index, data in ipairs(NETWORK.documents.types) do
		self.type:AddChoice(L(data.name), data.id, index == 1)
	end

	y = y + Sc(62)

	Label(L("docFieldHolder"), y)
	self.holder = Entry(y + Sc(18), Sc(34))

	y = y + Sc(62)

	Label(L("docFieldCID"), y)
	self.cid = Entry(y + Sc(18), Sc(34))
	self.cid:SetNumeric(true)

	y = y + Sc(62)

	Label(L("docFieldIssuer"), y)
	self.issuer = Entry(y + Sc(18), Sc(34))

	y = y + Sc(62)

	Label(L("docFieldText"), y)
	self.text = Entry(y + Sc(18), self:GetTall() - y - Sc(18) - Sc(70), true)

	local submit = self:Add("nwInvButton")

	submit:SetPos(pad, self:GetTall() - Sc(54))
	submit:SetSize(math.floor(width * 0.6), Sc(38))
	submit:Setup(L("docForgeSubmit"), "plus", true)
	submit.DoClick = function()
		local _, typeID = self.type:GetSelected()

		net.Start("nwDocForge")
			NETWORK.util.WriteTable({
				type = typeID,
				holder = self.holder:GetValue(),
				cid = self.cid:GetValue(),
				issuer = self.issuer:GetValue(),
				text = self.text:GetValue()
			})
		net.SendToServer()

		self:Remove()
	end

	local cancel = self:Add("nwInvButton")

	cancel:SetPos(pad + math.floor(width * 0.6) + Sc(10), self:GetTall() - Sc(54))
	cancel:SetSize(width - math.floor(width * 0.6) - Sc(10), Sc(38))
	cancel:Setup(L("menuBack"), "back", false)
	cancel.DoClick = function()
		self:Remove()
	end
end

function FORM:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 10)
end

function FORM:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function FORM:OnRemove()
	if (NETWORK.gui.documentForm == self) then
		NETWORK.gui.documentForm = nil
	end
end

function FORM:Paint(width, height)
	local Sc = NETWORK.util.Scale

	NETWORK.gui.DrawBlackGlass(self, 0, 0, width, height, self.alpha, Sc(14))

	draw.SimpleText(NETWORK.util.Upper(L("docForgeTitle")), "nwHudLabel", Sc(22), Sc(24),
		ColorAlpha(NETWORK.theme.text, 250 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(L("docForgeHint"), "nwHudSmall", Sc(22), Sc(44),
		ColorAlpha(NETWORK.theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwDocumentForm", FORM, "EditablePanel")

net.Receive("nwDocForm", function()
	if (IsValid(NETWORK.gui.documentForm)) then
		NETWORK.gui.documentForm:Remove()
	end

	if (IsValid(NETWORK.gui.tabMenu)) then
		NETWORK.gui.tabMenu:Close()
	end

	vgui.Create("nwDocumentForm")
end)
