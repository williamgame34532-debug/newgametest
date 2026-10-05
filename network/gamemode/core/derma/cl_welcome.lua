local ICONS = {
	"icon16/user.png", "icon16/shield.png", "icon16/star.png", "icon16/heart.png",
	"icon16/information.png", "icon16/error.png", "icon16/lightbulb.png",
	"icon16/comment.png", "icon16/group.png", "icon16/world.png", "icon16/lock.png",
	"icon16/wrench.png", "icon16/box.png", "icon16/coins.png"
}

local PANEL = {}

function PANEL:Init()
	local ScDefault = NETWORK.util.Scale

	self.frameWidth = ScDefault(760)
	self.frameHeight = ScDefault(520)
	self.frameX = ScDefault(200)
	self.frameY = ScDefault(120)
	self.headerHeight = ScDefault(52)
	local Sc = NETWORK.util.Scale

	NETWORK.gui.welcome = self

	self.alpha = 0
	self.reveal = 0
	self.bClosing = false
	self.bEditing = false

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
end

function PANEL:OnRemove()
	if (NETWORK.gui.welcome == self) then
		NETWORK.gui.welcome = nil
	end
end

function PANEL:Setup(data)
	self.data = data

	self:InvalidateLayout(true)
end

function PANEL:BuildEditor()
	local Sc = NETWORK.util.Scale

	if (IsValid(self.editor)) then
		self.editor:Remove()
	end

	self.bEditing = true

	self.editor = self:Add("DTextEntry")
	self.editor:SetFont("nwChat")
	self.editor:SetMultiline(true)
	self.editor:SetPaintBackground(false)
	self.editor:SetTextColor(NETWORK.theme.text)
	self.editor:SetCursorColor(NETWORK.theme.accent)
	self.editor:SetValue(self.data.body or "")
	self.editor.Paint = function(panel, width, height)
		surface.SetDrawColor(9, 24, 32, 220)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(NETWORK.theme.accent.r, NETWORK.theme.accent.g,
			NETWORK.theme.accent.b, 90)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
			NETWORK.theme.accent)
	end

	self.titleEntry = self:Add("DTextEntry")
	self.titleEntry:SetFont("nwTab")
	self.titleEntry:SetPaintBackground(false)
	self.titleEntry:SetTextColor(NETWORK.theme.text)
	self.titleEntry:SetValue(self.data.title or "")
	self.titleEntry.Paint = self.editor.Paint

	self.styleButtons = {}

	local function AddStyle(label, wrapper, font)
		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		button.Paint = function(panel, width, height)
			surface.SetDrawColor(9, 24, 32, (200 + 40 * panel.hover))
			surface.DrawRect(0, 0, width, height)

			surface.SetDrawColor(NETWORK.theme.accent.r, NETWORK.theme.accent.g,
				NETWORK.theme.accent.b, 120 + 90 * panel.hover)
			surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

			draw.SimpleText(label, font, math.Round(width * 0.5), math.Round(height * 0.5),
				NETWORK.theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			local text = self.editor:GetValue() or ""
			local caret = self.editor.GetCaretPos and self.editor:GetCaretPos() or #text

			caret = math.Clamp(caret, 0, #text)

			local before = string.sub(text, 1, caret)
			local after = string.sub(text, caret + 1)

			self.editor:SetText(before .. wrapper .. wrapper .. after)
			self.editor:RequestFocus()

			if (self.editor.SetCaretPos) then
				self.editor:SetCaretPos(caret + #wrapper)
			end
		end

		self.styleButtons[#self.styleButtons + 1] = button
	end

	AddStyle("B", "**", "nwChatBold")
	AddStyle("I", "*", "nwChatItalic")

	self.iconButton = self:Add("DButton")
	self.iconButton:SetText("")
	self.iconButton:SetCursor("hand")
	self.iconButton.Paint = function(panel, width, height)
		surface.SetDrawColor(9, 24, 32, 220)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(NETWORK.theme.accent.r, NETWORK.theme.accent.g,
			NETWORK.theme.accent.b, 130)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		local material = NETWORK.util.GetMaterial(self.data.icon or ICONS[1])

		if (!material:IsError()) then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(material)
			surface.DrawTexturedRect(math.Round(width * 0.5) - Sc(8),
				math.Round(height * 0.5) - Sc(8), Sc(16), Sc(16))
		end
	end
	self.iconButton.DoClick = function()
		NETWORK.sound.Click()

		local menu = DermaMenu()

		for _, icon in ipairs(ICONS) do
			menu:AddOption(string.match(icon, "([^/]+)%.png$"), function()
				self.data.icon = icon
			end):SetImage(icon)
		end

		menu:Open()
	end

	self.saveButton = self:Add("nwActionButton")
	self.saveButton:SetPrimary(true)
	self.saveButton:SetLabel(L("welcomeSave"))
	self.saveButton.DoClick = function()
		net.Start("nwWelcomeSave")
			NETWORK.util.WriteTable({
				title = self.titleEntry:GetValue(),
				body = self.editor:GetValue(),
				icon = self.data.icon
			})
		net.SendToServer()

		self.data.title = self.titleEntry:GetValue()
		self.data.body = self.editor:GetValue()
		self.bEditing = false

		self.editor:Remove()
		self.titleEntry:Remove()
		self.saveButton:Remove()
		self.iconButton:Remove()

		for _, button in ipairs(self.styleButtons) do
			button:Remove()
		end

		self.styleButtons = {}

		NETWORK.gui.Notify(L("welcomeSaved"), NETWORK.theme.accentSoft)
	end

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.frameWidth = math.min(Sc(760), width - Sc(200))
	self.frameHeight = math.min(Sc(520), height - Sc(160))
	self.frameX = math.Round((width - self.frameWidth) * 0.5)
	self.frameY = math.Round((height - self.frameHeight) * 0.5)
	self.headerHeight = Sc(52)

	if (!self.bEditing) then
		return
	end

	local innerX = self.frameX + Sc(28)
	local innerY = self.frameY + self.headerHeight + Sc(20)

	self.titleEntry:SetPos(innerX, innerY)
	self.titleEntry:SetSize(self.frameWidth - Sc(56), Sc(34))

	for index, button in ipairs(self.styleButtons) do
		button:SetSize(Sc(34), Sc(28))
		button:SetPos(innerX + (index - 1) * Sc(38), innerY + Sc(44))
	end

	self.iconButton:SetSize(Sc(34), Sc(28))
	self.iconButton:SetPos(innerX + #self.styleButtons * Sc(38), innerY + Sc(44))

	self.editor:SetPos(innerX, innerY + Sc(80))
	self.editor:SetSize(self.frameWidth - Sc(56),
		self.frameHeight - self.headerHeight - Sc(160))

	self.saveButton:SetSize(Sc(200), Sc(38))
	self.saveButton:SetPos(innerX, self.frameY + self.frameHeight - Sc(52))
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 10)
	self.reveal = NETWORK.util.Approach(self.reveal, self.bClosing and 0 or 1, 6)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()

		if (NETWORK.gui.OpenTitleCard) then
			NETWORK.gui.OpenTitleCard()
		end
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE and !self.bEditing) then
		self:Close()
	end
end

function PANEL:OnMousePressed(code)
	local Sc = NETWORK.util.Scale
	local x, y = self:CursorPos()

	if (code != MOUSE_LEFT or y > self.frameY + self.headerHeight or
		y < self.frameY) then
		return
	end

	if (x >= self.frameX + self.frameWidth - Sc(46)) then
		NETWORK.sound.Click()

		self:Close()

		return
	end

	if (LocalPlayer():IsAdmin() and !self.bEditing and
		x >= self.frameX + self.frameWidth - Sc(112)) then
		NETWORK.sound.Click()

		self:BuildEditor()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha
	local reveal = util.EaseInOut(self.reveal)
	local frameHeight = math.Round(self.frameHeight * reveal)
	local x = self.frameX
	local y = math.Round(height * 0.5 - frameHeight * 0.5)

	surface.SetDrawColor(0, 0, 0, 170 * alpha)
	surface.DrawRect(0, 0, width, height)

	util.DrawPanel(x, y, self.frameWidth, frameHeight, alpha, {bBrackets = true})

	if (reveal < 0.9) then
		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 250 * alpha)
		surface.DrawRect(x, y, self.frameWidth, math.max(Sc(2), 2))
		surface.DrawRect(x, y + frameHeight - math.max(Sc(2), 2), self.frameWidth,
			math.max(Sc(2), 2))

		return
	end

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b, 235 * alpha)
	surface.DrawRect(x, y, self.frameWidth, self.headerHeight)

	util.DrawScanlines(x, y, self.frameWidth, self.headerHeight, 30 * alpha)

	local material = util.GetMaterial(self.data.icon or ICONS[1])

	if (!material:IsError()) then
		surface.SetDrawColor(10, 24, 34, 250 * alpha)
		surface.SetMaterial(material)
		surface.DrawTexturedRect(x + Sc(20), y + math.Round(self.headerHeight * 0.5) - Sc(8),
			Sc(16), Sc(16))
	end

	util.DrawTextSpaced(util.Upper(self.data.title or ""), "nwTab", x + Sc(48),
		y + math.Round(self.headerHeight * 0.5), Color(8, 20, 28, 252 * alpha), Sc(5),
		TEXT_ALIGN_CENTER)

	draw.SimpleText("×", "nwTab", x + self.frameWidth - Sc(24),
		y + math.Round(self.headerHeight * 0.5), Color(8, 20, 28, 250 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if (LocalPlayer():IsAdmin() and !self.bEditing) then
		draw.SimpleText(L("welcomeEdit"), "nwHudSmall", x + self.frameWidth - Sc(56),
			y + math.Round(self.headerHeight * 0.5), Color(8, 20, 28, 240 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	if (self.bEditing) then
		return
	end

	local cursorY = y + self.headerHeight + Sc(34)

	for _, paragraph in ipairs(string.Explode("\\n", self.data.body or "")) do
		if (paragraph == "") then
			cursorY = cursorY + Sc(12)

			continue
		end

		for _, line in ipairs(util.WrapText(paragraph, "nwChat",
			self.frameWidth - Sc(72), 20)) do
			local bBold = string.find(line, "%*%*")
			local clean = string.gsub(string.gsub(line, "%*%*", ""), "%*", "")

			draw.SimpleText(clean, bBold and "nwChatBold" or "nwChat", x + Sc(36),
				cursorY, ColorAlpha(bBold and theme.text or theme.textDim, 248 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			cursorY = cursorY + Sc(24)
		end
	end
end

vgui.Register("nwWelcome", PANEL, "EditablePanel")

net.Receive("nwWelcome", function()
	local data = NETWORK.util.ReadTable()

	if (IsValid(NETWORK.gui.welcome)) then
		NETWORK.gui.welcome:Remove()
	end

	local panel = vgui.Create("nwWelcome")

	panel:Setup(data)
end)
