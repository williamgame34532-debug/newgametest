local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self:SetTall(Sc(46))
	self:SetFont("nwField")
	self:SetTextColor(NETWORK.theme.text)
	self:SetCursorColor(NETWORK.theme.accent)
	self:SetHighlightColor(NETWORK.theme.accentDeep)
	self:SetPaintBackground(false)
	self:SetDrawLanguageID(false)
	self:SetUpdateOnType(true)

	self.placeholder = ""
	self.bMultilineField = false
	self.padding = Sc(14)
	self.focus = 0
	self.error = 0
	self.limit = 0

	self:SetTextInset(self.padding, 0)
end

function PANEL:SetPlaceholder(text)
	self.placeholder = text
end

function PANEL:SetLimit(limit)
	self.limit = limit

	self:SetMaximumCharCount(limit)
end

function PANEL:GetLength()
	return NETWORK.util.Length(self:GetText())
end

function PANEL:SetErrorState(bError)
	self.bError = tobool(bError)
end

function PANEL:SetMultilineField(bMultiline)
	local Sc = NETWORK.util.Scale

	self.bMultilineField = tobool(bMultiline)

	self:SetMultiline(bMultiline)
	self:SetVerticalScrollbarEnabled(bMultiline)

	if (bMultiline) then
		self:SetTextInset(self.padding, Sc(12))
	else
		self:SetTextInset(self.padding, 0)
	end
end

function PANEL:Think()
	local util = NETWORK.util

	self.focus = util.Approach(self.focus, self:HasFocus() and 1 or 0, 9)
	self.error = util.Approach(self.error, self.bError and 1 or 0, 8)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local focus = util.EaseInOut(self.focus)
	local error = self.error
	local accent = Color(
		Lerp(error, theme.accent.r, theme.danger.r),
		Lerp(error, theme.accent.g, theme.danger.g),
		Lerp(error, theme.accent.b, theme.danger.b)
	)

	surface.SetDrawColor(theme.plate.r, theme.plate.g, theme.plate.b, 140 + 60 * focus)
	surface.DrawRect(0, 0, width, height)

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 16 + 22 * focus)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	local lineWidth = math.Round(width * (0.999 * focus))

	surface.SetDrawColor(theme.line.r, theme.line.g, theme.line.b, 30 + 40 * error)
	surface.DrawRect(0, height - math.max(Sc(2), 1), width, math.max(Sc(2), 1))

	surface.SetDrawColor(accent.r, accent.g, accent.b, 235)
	surface.DrawRect(math.Round((width - lineWidth) * 0.5), height - math.max(Sc(2), 1), lineWidth,
		math.max(Sc(2), 1))

	if (self:GetText() == "" and self.placeholder != "") then
		draw.SimpleText(self.placeholder, "nwField", self.padding,
			self.bMultilineField and Sc(16) or math.Round(height * 0.5),
			ColorAlpha(theme.textFaint, 210), TEXT_ALIGN_LEFT,
			self.bMultilineField and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
	end

	if (self.limit > 0) then
		local counter = self:GetLength() .. " / " .. self.limit

		draw.SimpleText(counter, "nwHudSmall", width - Sc(12), height - Sc(12),
			ColorAlpha(theme.textFaint, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
	end

	self:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
end

vgui.Register("nwTextEntry", PANEL, "DTextEntry")
