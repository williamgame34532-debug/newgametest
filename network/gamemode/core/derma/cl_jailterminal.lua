local PANEL = {}

local ACCENT = Color(72, 196, 236)
local DIM = Color(52, 104, 128)
local TEXT = Color(208, 232, 242)
local GREEN = Color(108, 220, 150)
local WARN = Color(232, 190, 96)
local BAD = Color(228, 86, 80)
local BASE = Color(4, 14, 20)

function PANEL:Init()
	NETWORK.gui.jail = self

	self.open = 0
	self.boot = 0
	self.bootTime = 4
	self.alpha = 0
	self.page = "boot"
	self.term = NETWORK.jail.termDefault
	self.reason = ""
	self.selected = nil
	self.controls = {}

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.background = Material(NETWORK.cmbterm.background, "smooth")
	self.logo = Material(NETWORK.cmbterm.logo, "smooth")

	self.close = self:Add("DButton")

	self.close:SetText("")
	self.close:SetCursor("hand")
	self.close.DoClick = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.back)

		self:Close()
	end
	self.close.Paint = function(panel, width, height)
		local Sc = NETWORK.util.Scale
		local colour = panel:IsHovered() and BAD or ACCENT
		local inset = Sc(12)
		local thickness = math.max(Sc(2), 2)

		NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
			thickness, colour)
		NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
			thickness, colour)
	end
end

function PANEL:Setup(entity, bootTime)
	self.entity = entity
	self.bootTime = bootTime or 4
end

function PANEL:OnRemove()
	NETWORK.gui.jail = nil
end

function PANEL:Close()
	NETWORK.jail.Send("close")

	NETWORK.gui.CloseJail()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_F11) then
		NETWORK.cmbterm.fullscreen = !NETWORK.cmbterm.fullscreen

		cookie.Set("nwTermFullscreenV2", NETWORK.cmbterm.fullscreen and "1" or "0")

		self:InvalidateLayout(true)

		if (self.page != "boot") then
			self:BuildControls()
		end

		return
	end

	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

function PANEL:GetFrameWidth()
	return NETWORK.cmbterm.fullscreen and ScrW() or math.Round(ScrW() * 0.8)
end

function PANEL:GetFrameHeight()
	return NETWORK.cmbterm.fullscreen and ScrH() or math.Round(ScrH() * 0.82)
end

function PANEL:GetFrameX()
	return math.Round((ScrW() - self:GetFrameWidth()) * 0.5)
end

function PANEL:GetFrameY()
	return math.Round((ScrH() - self:GetFrameHeight()) * 0.5)
end

function PANEL:GetListWidth()
	return math.Round(NETWORK.util.Scale(330))
end

function PANEL:GetContentX()
	return self:GetFrameX() + self:GetListWidth()
end

function PANEL:PerformLayout()
	local Sc = NETWORK.util.Scale

	if (!IsValid(self.close)) then
		return
	end

	self.close:SetSize(Sc(44), Sc(44))
	self.close:SetPos(self:GetFrameX() + self:GetFrameWidth() - Sc(56),
		self:GetFrameY() + Sc(16))
	self.close:SetVisible(self.page != "boot")
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 6)
	self.open = NETWORK.util.Approach(self.open, 1, 2.2)

	if (IsValid(self.close)) then
		self.close:SetVisible(self.page != "boot")
	end

	if (self.page != "boot") then
		return
	end

	self.boot = self.boot + FrameTime()

	if (self.boot >= self.bootTime and self.open > 0.98) then
		self.page = "console"

		self:BuildControls()
	end
end

function PANEL:Select(index)
	if (self.selected == index) then
		return
	end

	self.selected = index

	surface.PlaySound(NETWORK.cmbterm.sounds.select)

	self:BuildControls()
end

function PANEL:OnData()
	if (self.selected and !NETWORK.jail.Find(self.selected)) then
		self.selected = nil

		self:BuildControls()
	end
end

function PANEL:ClearControls()
	for _, panel in ipairs(self.controls) do
		if (IsValid(panel)) then
			panel:Remove()
		end
	end

	self.controls = {}
end

function PANEL:AddButton(x, y, width, height, label, callback, getState)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button:SetPos(x, y)
	button:SetSize(width, height)

	button.Paint = function(panel, buttonWidth, buttonHeight)
		local state = getState and getState() or "idle"
		local hovered = panel:IsHovered() and state != "off"
		local colour = ACCENT

		if (state == "on") then
			colour = GREEN
		elseif (state == "off") then
			colour = DIM
		end

		surface.SetDrawColor(colour.r, colour.g, colour.b,
			(hovered and 30 or (state == "on" and 20 or 8)) * self.alpha)
		surface.DrawRect(0, 0, buttonWidth, buttonHeight)

		surface.SetDrawColor(colour.r, colour.g, colour.b,
			(hovered and 250 or 150) * self.alpha)
		surface.DrawOutlinedRect(0, 0, buttonWidth, buttonHeight, 1)

		surface.DrawRect(0, 0, math.max(Sc(2), 2), buttonHeight)

		draw.SimpleText(NETWORK.util.Upper(label()), "nwHudSmall", Sc(12),
			math.Round(buttonHeight * 0.5),
			ColorAlpha(state == "off" and DIM or TEXT, 250 * self.alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	button.DoClick = function()
		if (getState and getState() == "off") then
			return surface.PlaySound("buttons/button10.wav")
		end

		surface.PlaySound(NETWORK.cmbterm.sounds.select)

		callback()
	end

	self.controls[#self.controls + 1] = button

	return button
end

function PANEL:BuildControls()
	local Sc = NETWORK.util.Scale

	self:ClearControls()

	if (self.page != "console" or !self.selected) then
		return
	end

	local entry = NETWORK.jail.Find(self.selected)

	if (!entry) then
		return
	end

	local x = self:GetContentX() + Sc(24)
	local y = self:GetFrameY() + Sc(400)
	local width = self:GetFrameWidth() - self:GetListWidth() - Sc(48)
	local columnWidth = math.Round((width - Sc(12)) * 0.5)

	for index, key in ipairs(NETWORK.jail.reasons) do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)

		self:AddButton(x + column * (columnWidth + Sc(12)), y + row * Sc(34),
			columnWidth, Sc(28), function()
				return L(key)
			end, function()
				self.reason = L(key)

				if (IsValid(self.entry)) then
					self.entry:SetText(self.reason)
				end
			end, function()
				return self.reason == L(key) and "on" or "idle"
			end)
	end

	local fieldY = y + Sc(118)

	self.entry = self:Add("DTextEntry")

	self.entry:SetPos(x, fieldY)
	self.entry:SetSize(width, Sc(32))
	self.entry:SetFont("nwField")
	self.entry:SetText(self.reason)
	self.entry:SetUpdateOnType(true)
	self.entry:SetDrawLanguageID(false)
	self.entry.Paint = function(panel, entryWidth, entryHeight)
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 120 * self.alpha)
		surface.DrawOutlinedRect(0, 0, entryWidth, entryHeight, 1)

		if (panel:GetText() == "") then
			draw.SimpleText(L("jailReasonHint"), "nwHudSmall", NETWORK.util.Scale(10),
				math.Round(entryHeight * 0.5), ColorAlpha(DIM, 250 * self.alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(TEXT, ACCENT, TEXT)
	end
	self.entry.OnChange = function(panel)
		self.reason = string.sub(panel:GetText(), 1, NETWORK.jail.reasonMax)
	end

	self.controls[#self.controls + 1] = self.entry

	local termY = fieldY + Sc(58)
	local termWidth = Sc(74)

	for index, term in ipairs(NETWORK.jail.terms) do
		self:AddButton(x + (index - 1) * (termWidth + Sc(8)), termY, termWidth,
			Sc(30), function()
				return term .. " " .. L("jailMinutesShort")
			end, function()
				self.term = term
			end, function()
				return self.term == term and "on" or "idle"
			end)
	end

	local actionY = termY + Sc(50)

	self:AddButton(x, actionY, Sc(300), Sc(40), function()
		return L("jailConfirm")
	end, function()
		NETWORK.jail.Send("jail", self.selected, self.term, self.reason)
	end, function()
		if (NETWORK.jail.data.points < 1 or
			NETWORK.util.Sanitise(self.reason, NETWORK.jail.reasonMax) == "") then
			return "off"
		end

		return "idle"
	end)

	if (entry.remaining) then
		self:AddButton(x + Sc(312), actionY, Sc(220), Sc(40), function()
			return L("jailRelease")
		end, function()
			NETWORK.jail.Send("release", self.selected)
		end)
	end
end

function PANEL:GetRowRect(index)
	local Sc = NETWORK.util.Scale

	return self:GetFrameX() + Sc(20), self:GetFrameY() + Sc(96) + (index - 1) * Sc(58),
		self:GetListWidth() - Sc(36), Sc(52)
end

function PANEL:OnMousePressed(code)
	if (code != MOUSE_LEFT or self.page != "console") then
		return
	end

	local cursorX, cursorY = self:CursorPos()

	for index, entry in ipairs(NETWORK.jail.data.list) do
		local x, y, width, height = self:GetRowRect(index)

		if (cursorX >= x and cursorX <= x + width and cursorY >= y and
			cursorY <= y + height) then
			return self:Select(entry.index)
		end
	end
end

function PANEL:GetModelPanel(model)
	if (IsValid(self.model) and self.model.nwModel == model) then
		return self.model
	end

	if (IsValid(self.model)) then
		self.model:Remove()
	end

	local panel = self:Add("DModelPanel")

	panel.nwModel = model

	panel:SetModel(model)
	panel:SetFOV(32)
	panel:SetMouseInputEnabled(false)
	panel.LayoutEntity = function(_, entity)
		entity:SetAngles(Angle(0, 32, 0))
	end

	local entity = panel:GetEntity()

	if (IsValid(entity)) then

		local mins, maxs = entity:GetRenderBounds()
		local center = (mins + maxs) * 0.5

		center.z = maxs.z * 0.8

		panel:SetLookAt(center)
		panel:SetCamPos(center + Vector(38, 16, 4))
	end

	self.model = panel

	return panel
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local alpha = self.alpha

	surface.SetDrawColor(0, 0, 0, 225 * alpha)
	surface.DrawRect(0, 0, width, height)

	local eased = NETWORK.util.EaseOut(self.open)
	local frameWidth = math.Round(self:GetFrameWidth() * (0.9 + 0.1 * eased))
	local frameHeight = math.Round(self:GetFrameHeight() * math.max(eased, 0.01))
	local x = math.Round(ScrW() * 0.5 - frameWidth * 0.5)
	local y = math.Round(ScrH() * 0.5 - frameHeight * 0.5)

	if (frameHeight < 2) then
		return
	end

	NETWORK.cmbterm.DrawBackdrop(self, x, y, frameWidth, frameHeight, alpha, "alliance",
		NETWORK.cmbterm.palettes.alliance)

	local size = Sc(26)
	local thickness = math.max(Sc(2), 2)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 220 * alpha)

	surface.DrawRect(x, y, size, thickness)
	surface.DrawRect(x, y, thickness, size)
	surface.DrawRect(x + frameWidth - size, y, size, thickness)
	surface.DrawRect(x + frameWidth - thickness, y, thickness, size)
	surface.DrawRect(x, y + frameHeight - size, thickness, size)
	surface.DrawRect(x, y + frameHeight - thickness, size, thickness)
	surface.DrawRect(x + frameWidth - size, y + frameHeight - thickness, size, thickness)
	surface.DrawRect(x + frameWidth - thickness, y + frameHeight - size, thickness, size)

	NETWORK.util.DrawScanlines(x, y, frameWidth, frameHeight, 22 * alpha, math.max(Sc(3), 3))

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 120 * alpha)
	surface.DrawOutlinedRect(x, y, frameWidth, frameHeight, 1)

	if (self.open < 0.99) then
		surface.SetDrawColor(200, 240, 255, 255 * alpha)
		surface.DrawRect(x, y, frameWidth, math.max(Sc(2), 2))
		surface.DrawRect(x, y + frameHeight - math.max(Sc(2), 2), frameWidth,
			math.max(Sc(2), 2))

		return
	end

	if (self.page == "boot") then
		return self:PaintBoot(x, y, frameWidth, frameHeight, ACCENT, alpha)
	end

	self:PaintConsole(x, y, frameWidth, frameHeight, alpha)
end

function PANEL:PaintBoot(x, y, width, height, colour, alpha)
	NETWORK.cmbterm.DrawBoot(self, x, y, width, height, alpha, self.boot, self.bootTime,
		"jail", colour, self.logo)
end

function PANEL:PaintConsole(x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()
	local listWidth = self:GetListWidth()

	util.DrawTextSpaced(util.Upper(L("jailTitle")), "nwTab", x + Sc(20), y + Sc(34),
		ColorAlpha(TEXT, 250 * alpha), Sc(6), TEXT_ALIGN_CENTER)

	draw.SimpleText(client:GetCharacterName(), "nwHudSmall", x + Sc(22), y + Sc(58),
		ColorAlpha(DIM, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 90 * alpha)
	surface.DrawRect(x + Sc(20), y + Sc(74), width - Sc(40), 1)
	surface.DrawRect(x + listWidth, y + Sc(74), 1, height - Sc(94))

	local cells = NETWORK.jail.data.points

	draw.SimpleText(L(cells > 0 and "jailCells" or "jailNoCellsShort", cells),
		"nwHudSmall", x + width - Sc(70), y + Sc(58),
		ColorAlpha(cells > 0 and DIM or BAD, 250 * alpha), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	self:PaintList(x, y, alpha)
	self:PaintSubject(x, y, width, height, alpha)
end

function PANEL:PaintList(x, y, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local list = NETWORK.jail.data.list

	util.DrawTextSpaced(util.Upper(L("jailNearby")), "nwHudSmall", x + Sc(20),
		y + Sc(86), ColorAlpha(ACCENT, 230 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	if (#list == 0) then
		draw.SimpleText(L("jailEmpty"), "nwHudSmall", x + Sc(20), y + Sc(120),
			ColorAlpha(DIM, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	local cursorX, cursorY = self:CursorPos()

	for index, entry in ipairs(list) do
		local rowX, rowY, rowWidth, rowHeight = self:GetRowRect(index)
		local bActive = self.selected == entry.index
		local hovered = cursorX >= rowX and cursorX <= rowX + rowWidth and
			cursorY >= rowY and cursorY <= rowY + rowHeight

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b,
			(bActive and 26 or (hovered and 14 or 0)) * alpha)
		surface.DrawRect(rowX, rowY, rowWidth, rowHeight)

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b,
			(bActive and 250 or 90) * alpha)
		surface.DrawRect(rowX, rowY, math.max(Sc(2), 2), rowHeight)

		draw.SimpleText(util.Truncate(entry.name, 24), "nwHud", rowX + Sc(12),
			rowY + Sc(16), ColorAlpha(TEXT, 250 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(L("jailCID") .. " " .. (entry.cid or "?"), "nwHudSmall",
			rowX + Sc(12), rowY + Sc(36), ColorAlpha(DIM, 245 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(math.Round(entry.distance / 16) .. " " .. L("jailMetres"),
			"nwHudSmall", rowX + rowWidth - Sc(10), rowY + Sc(36),
			ColorAlpha(DIM, 235 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		if (entry.remaining) then
			draw.SimpleText(entry.remaining .. " " .. L("jailMinutesShort"),
				"nwHudSmall", rowX + rowWidth - Sc(10), rowY + Sc(16),
				ColorAlpha(WARN, 250 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
end

function PANEL:PaintSubject(x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local contentX = self:GetContentX() + Sc(24)
	local entry = self.selected and NETWORK.jail.Find(self.selected)

	if (!entry) then
		if (IsValid(self.model)) then
			self.model:SetVisible(false)
		end

		draw.SimpleText(L("jailPick"), "nwField", contentX, y + Sc(120),
			ColorAlpha(DIM, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	local panel = self:GetModelPanel(entry.model or "models/police.mdl")

	panel:SetVisible(true)
	panel:SetPos(contentX, y + Sc(96))
	panel:SetSize(Sc(190), Sc(250))

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 90 * alpha)
	surface.DrawOutlinedRect(contentX, y + Sc(96), Sc(190), Sc(250), 1)

	local textX = contentX + Sc(210)

	util.DrawTextSpaced(util.Upper(entry.name), "nwHud", textX, y + Sc(112),
		ColorAlpha(TEXT, 252 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	draw.SimpleText(L("jailCID") .. " " .. (entry.cid or "?"), "nwHudSmall", textX,
		y + Sc(140), ColorAlpha(DIM, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(entry.faction or "", "nwHudSmall", textX, y + Sc(160),
		ColorAlpha(DIM, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (entry.remaining) then
		draw.SimpleText(L("jailHeld", entry.remaining), "nwHudSmall", textX,
			y + Sc(190), ColorAlpha(WARN, 250 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(util.Truncate(entry.reason or "", 40), "nwHudSmall", textX,
			y + Sc(210), ColorAlpha(DIM, 250 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	util.DrawTextSpaced(util.Upper(L("jailCharge")), "nwHudSmall", contentX,
		y + Sc(380), ColorAlpha(ACCENT, 230 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	util.DrawTextSpaced(util.Upper(L("jailTerm")), "nwHudSmall", contentX,
		y + Sc(556), ColorAlpha(ACCENT, 230 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	if (NETWORK.jail.data.points < 1) then
		draw.SimpleText(L("jailNoPoints"), "nwHudSmall", contentX, y + Sc(660),
			ColorAlpha(BAD, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwJailTerminal", PANEL, "EditablePanel")

function NETWORK.gui.OpenJail(entity, bootTime)
	NETWORK.gui.CloseWindows()

	local panel = vgui.Create("nwJailTerminal")

	panel:Setup(entity, bootTime)

	return panel
end

function NETWORK.gui.CloseJail()
	if (IsValid(NETWORK.gui.jail)) then
		NETWORK.gui.jail:Remove()
	end

	NETWORK.gui.jail = nil
end
