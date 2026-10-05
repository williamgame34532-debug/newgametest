local ACCENT = Color(72, 196, 236)
local DIM = Color(52, 104, 128)
local TEXT = Color(208, 232, 242)
local BASE = Color(4, 14, 20)

local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.title = ""
	self.hint = ""
	self.mode = "text"

	self:SetSize(math.min(Sc(560), math.Round(ScrW() * 0.86)),
		math.min(Sc(240), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.entry = self:Add("DTextEntry")
	self.entry:SetFont("nwTermBody")
	self.entry:SetPaintBackground(false)
	self.entry:SetDrawLanguageID(false)
	self.entry:SetTextColor(TEXT)
	self.entry:SetCursorColor(ACCENT)
	self.entry:RequestFocus()
	self.entry.OnEnter = function()
		self:Confirm()
	end
	self.entry.Paint = function(panel, width, height)
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 12)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b,
			panel:IsEditing() and 210 or 90)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		panel:DrawTextEntryText(TEXT, ACCENT, ACCENT)
	end

	self.confirm = self:AddButton(L("cmbConfirm"), function()
		self:Confirm()
	end, ACCENT)

	self.cancel = self:AddButton(L("menuBack"), function()
		self:Close()
	end, DIM)
end

function PANEL:AddButton(label, callback, color)
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.DoClick = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.select)

		callback()
	end
	button.OnCursorEntered = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.hover)
	end
	button.Paint = function(panel, width, height)
		local hover = panel:IsHovered() and 1 or 0

		surface.SetDrawColor(color.r, color.g, color.b, 14 + 30 * hover)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(color.r, color.g, color.b, 130 + 90 * hover)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		draw.SimpleText(NETWORK.util.Upper(label), "nwHudSmall",
			math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(TEXT, 240 + 15 * hover), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return button
end

function PANEL:Setup(data)
	local Sc = NETWORK.util.Scale

	self.title = data.title or ""
	self.hint = data.hint or ""
	self.mode = data.mode or "text"
	self.callback = data.callback
	self.minimum = data.minimum or -100
	self.maximum = data.maximum or 100

	self.entry:SetValue(tostring(data.value or ""))
	self.entry:SetMultiline(self.mode == "note")

	if (self.mode == "number") then

		self.steps = {}

		for _, amount in ipairs(data.steps or {-25, -10, -5, 5, 10, 25}) do
			self.steps[#self.steps + 1] = self:AddButton(
				(amount > 0 and "+" or "") .. amount, function()
					local current = tonumber(self.entry:GetValue()) or 0

					self.entry:SetValue(tostring(math.Clamp(current + amount,
						self.minimum, self.maximum)))
				end, amount > 0 and Color(108, 220, 150) or Color(228, 86, 80))
		end
	end

	self:SetTall(self.mode == "note" and Sc(300) or
		(self.mode == "number" and Sc(280) or Sc(220)))
	self:Center()
	self:InvalidateLayout(true)
end

function PANEL:Confirm()
	local value = self.entry:GetValue()

	if (self.mode == "number") then
		value = math.Clamp(math.Round(tonumber(value) or 0), self.minimum,
			self.maximum)

		if (value == 0) then
			return
		end
	elseif (string.Trim(value) == "") then
		return
	end

	if (self.callback) then
		self.callback(value)
	end

	self:Close()
end

function PANEL:Close()
	surface.PlaySound(NETWORK.cmbterm.sounds.back)

	self:Remove()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local margin = Sc(26)
	local entryHeight = self.mode == "note" and Sc(110) or Sc(40)

	self.entry:SetPos(margin, Sc(96))
	self.entry:SetSize(width - margin * 2, entryHeight)

	local cursor = Sc(96) + entryHeight + Sc(16)

	if (self.steps) then
		local count = #self.steps
		local stepWidth = math.floor((width - margin * 2 - Sc(8) * (count - 1)) /
			count)

		for index, button in ipairs(self.steps) do
			button:SetSize(stepWidth, Sc(34))
			button:SetPos(margin + (index - 1) * (stepWidth + Sc(8)), cursor)
		end

		cursor = cursor + Sc(46)
	end

	local buttonWidth = math.floor((width - margin * 2 - Sc(10)) * 0.5)

	self.confirm:SetSize(buttonWidth, Sc(40))
	self.confirm:SetPos(margin, height - Sc(56))

	self.cancel:SetSize(buttonWidth, Sc(40))
	self.cancel:SetPos(margin + buttonWidth + Sc(10), height - Sc(56))
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local alpha = self.alpha
	local slide = math.Round((1 - alpha) * Sc(14))

	surface.SetDrawColor(BASE.r, BASE.g, BASE.b, 244 * alpha)
	surface.DrawRect(0, slide, width, height)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 8 * alpha)

	for line = 0, height - 1, Sc(40) do
		surface.DrawRect(0, slide + line, width, 1)
	end

	util.DrawScanlines(0, slide, width, height, 22 * alpha, math.max(Sc(3), 3))

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 120 * alpha)
	surface.DrawOutlinedRect(0, slide, width, height, 1)

	local size = Sc(20)
	local thickness = math.max(Sc(2), 2)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 230 * alpha)

	surface.DrawRect(0, slide, size, thickness)
	surface.DrawRect(0, slide, thickness, size)
	surface.DrawRect(width - size, slide, size, thickness)
	surface.DrawRect(width - thickness, slide, thickness, size)
	surface.DrawRect(0, slide + height - size, thickness, size)
	surface.DrawRect(0, slide + height - thickness, size, thickness)
	surface.DrawRect(width - size, slide + height - thickness, size, thickness)
	surface.DrawRect(width - thickness, slide + height - size, thickness, size)

	util.DrawTextSpaced(util.Upper(self.title), "nwTermButton", Sc(26),
		slide + Sc(40), ColorAlpha(ACCENT, 252 * alpha), Sc(4), TEXT_ALIGN_CENTER)

	if (self.hint != "") then
		draw.SimpleText(self.hint, "nwHudSmall", Sc(26), slide + Sc(66),
			ColorAlpha(DIM, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 70 * alpha)
	surface.DrawRect(Sc(26), slide + Sc(82), width - Sc(52), 1)
end

vgui.Register("nwTermPrompt", PANEL, "EditablePanel")

function NETWORK.gui.TerminalPrompt(data)
	local panel = vgui.Create("nwTermPrompt")

	panel:Setup(data)

	return panel
end
