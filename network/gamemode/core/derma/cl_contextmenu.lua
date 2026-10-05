local ICON_GLYPHS = {
	["icon16/user.png"] = "person",
	["icon16/page_copy.png"] = "list",
	["icon16/textfield.png"] = "list",
	["icon16/tag_blue.png"] = "list",
	["icon16/award_star_gold_1.png"] = "shield",
	["icon16/user_delete.png"] = "minus",
	["icon16/cross.png"] = "minus",
	["icon16/delete.png"] = "minus"
}

local OPTION = {}

OPTION.__index = OPTION

function OPTION:SetIcon(path)
	self.glyph = self.glyph or ICON_GLYPHS[path] or "dot"

	return self
end

function OPTION:SetGlyph(glyph)
	self.glyph = glyph

	return self
end

function OPTION:SetDisabled(reason)
	self.disabledReason = reason or ""
	self.bDisabled = true

	return self
end

function OPTION:SetKey(label)
	self.keyLabel = label

	return self
end

function OPTION:SetDanger(bDanger)
	self.bDanger = bDanger == true

	return self
end

local MENU = {}

function MENU:Init()
	self.options = {}
	self.alpha = 0
	self.born = RealTime()
	self.accent = NETWORK.theme.hover

	self:SetDrawOnTop(true)
end

function MENU:AddOption(label, callback)
	local option = setmetatable({label = label, callback = callback}, OPTION)

	self.options[#self.options + 1] = option

	return option
end

function MENU:AddSpacer()
	self.options[#self.options + 1] = {bSpacer = true}
end

function MENU:AddSection(label)
	self.options[#self.options + 1] = {bSection = true, label = label}
end

function MENU:SetHeader(title, subtitle)
	self.headerTitle = title
	self.headerSub = subtitle
end

function MENU:GetRowHeight()
	return NETWORK.util.Scale(36)
end

function MENU:Open(x, y)
	local Sc = NETWORK.util.Scale
	local width = Sc(180)

	surface.SetFont("nwField")

	for _, option in ipairs(self.options) do
		if (!option.bSpacer) then
			local extra = Sc(70)

			if (option.disabledReason and option.disabledReason != "") then
				surface.SetFont("nwHudSmall")
				extra = extra + surface.GetTextSize(option.disabledReason) + Sc(16)
				surface.SetFont("nwField")
			elseif (option.keyLabel) then
				extra = extra + Sc(56)
			end

			width = math.max(width, surface.GetTextSize(option.label) + extra)
		end
	end

	if (self.headerTitle) then
		width = math.max(width, surface.GetTextSize(self.headerTitle) + Sc(40))
	end

	local height = Sc(12) + (self.headerTitle and Sc(50) or 0)

	for _, option in ipairs(self.options) do
		height = height + (option.bSpacer and Sc(9) or
			(option.bSection and Sc(24) or self:GetRowHeight()))
	end

	x = x or gui.MouseX()
	y = y or gui.MouseY()

	x = math.Clamp(x, Sc(8), ScrW() - width - Sc(8))
	y = math.Clamp(y, Sc(8), ScrH() - height - Sc(8))

	self:SetSize(width, height)
	self:SetPos(x, y)
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)

	local catcher = vgui.Create("DButton")

	catcher:SetText("")
	catcher:SetSize(ScrW(), ScrH())
	catcher:SetPos(0, 0)
	catcher:MakePopup()
	catcher.Paint = function() end
	catcher.DoClick = function()
		self:Remove()
	end
	catcher.DoRightClick = catcher.DoClick

	self.catcher = catcher

	self:MoveToFront()

	surface.PlaySound("ui/buttonrollover.wav")

	return self
end

function MENU:OnRemove()
	if (IsValid(self.catcher)) then
		self.catcher:Remove()
	end
end

function MENU:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function MENU:GetOptionAt(localY)
	local Sc = NETWORK.util.Scale
	local cursor = Sc(6) + (self.headerTitle and Sc(50) or 0)

	for _, option in ipairs(self.options) do
		local height = option.bSpacer and Sc(9) or
			(option.bSection and Sc(24) or self:GetRowHeight())

		if (!option.bSpacer and !option.bSection and localY >= cursor and
			localY < cursor + height) then
			return option, cursor
		end

		cursor = cursor + height
	end
end

function MENU:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 14)

	for _, option in ipairs(self.options) do
		option.hover = NETWORK.util.Approach(option.hover or 0,
			option == self.hovered and 1 or 0, 16)
	end

	if (self:IsHovered()) then
		local _, localY = self:CursorPos()
		local option = self:GetOptionAt(localY)

		if (option != self.hovered and option) then
			NETWORK.sound.Hover()
		end

		self.hovered = option
	else
		self.hovered = nil
	end
end

function MENU:OnMousePressed(code)
	local _, localY = self:CursorPos()
	local option = self:GetOptionAt(localY)

	if (!option) then
		return
	end

	if (option.bDisabled) then
		surface.PlaySound("buttons/button10.wav")

		return
	end

	NETWORK.sound.Click()

	self:Remove()

	if (option.callback) then
		option.callback()
	end
end

function MENU:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local alpha = NETWORK.util.EaseOut(self.alpha)
	local accent = self.accent
	local cursor = Sc(6)

	local S = NETWORK.style

	if (S and S.Card) then
		S.Card(0, 0, width, height, alpha, {
			radius = S.Radius("card"),
			panel = self,
			shadow = false,
			fill = Color(9, 12, 15, 236)
		})
	else
		NETWORK.gui.DrawBlackGlass(self, 0, 0, width, height, alpha, Sc(10))
	end

	if (self.headerTitle) then
		draw.SimpleText(self.headerTitle, "nwField", Sc(16), Sc(18),
			ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (self.headerSub) then
			draw.SimpleText(self.headerSub, "nwHudSmall", Sc(16), Sc(36),
				ColorAlpha(theme.textFaint, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		surface.SetDrawColor(150, 196, 220, 36 * alpha)
		surface.DrawRect(Sc(12), Sc(50), width - Sc(24), 1)

		cursor = cursor + Sc(50)
	end

	for _, option in ipairs(self.options) do
		if (option.bSection) then
			NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(option.label), "nwInvKey",
				Sc(16), cursor + Sc(12), ColorAlpha(theme.textFaint, 220 * alpha), Sc(2),
				TEXT_ALIGN_CENTER)

			cursor = cursor + Sc(24)

			continue
		end

		if (option.bSpacer) then
			surface.SetDrawColor(150, 196, 220, 36 * alpha)
			surface.DrawRect(Sc(12), cursor + Sc(4), width - Sc(24), 1)

			cursor = cursor + Sc(9)

			continue
		end

		local rowHeight = self:GetRowHeight()
		local hover = NETWORK.util.EaseInOut(option.hover or 0)
		local color = option.bDanger and theme.danger or accent
		local middle = cursor + math.Round(rowHeight * 0.5)

		if (hover > 0.01) then
			local rail = math.max(Sc(3), 2)
			local railHeight = math.Round((rowHeight - Sc(16)) * hover)
			local strength = option.bDisabled and 0.45 or 1

			draw.RoundedBox(math.max(Sc(6), 4), Sc(6), cursor + Sc(2), width - Sc(12),
				rowHeight - Sc(4), ColorAlpha(color, 30 * hover * alpha * strength))

			if (railHeight >= rail) then
				draw.RoundedBox(math.floor(rail * 0.5), Sc(8), middle - math.floor(railHeight * 0.5),
					rail, railHeight, ColorAlpha(color, 235 * hover * alpha * strength))
			end
		end

		local glyph = Sc(15)

		NETWORK.gui.DrawGlyph(option.glyph or "dot", Sc(16), middle - math.floor(glyph * 0.5),
			glyph, ColorAlpha(color, (170 + 85 * hover) * alpha))

		local textAlpha = option.bDisabled and 0.42 or 1

		draw.SimpleText(option.label, "nwField", Sc(16) + glyph + Sc(12), middle,
			ColorAlpha(option.bDanger and theme.danger or theme.text, (225 + 30 * hover) *
			alpha * textAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (option.bDisabled and option.disabledReason != "") then
			draw.SimpleText(option.disabledReason, "nwHudSmall", width - Sc(14), middle,
				ColorAlpha(theme.danger, 210 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		elseif (option.keyLabel) then
			surface.SetFont("nwHudSmall")

			local keyWidth = surface.GetTextSize(option.keyLabel) + Sc(12)

			NETWORK.util.DrawRoundedBorder(width - Sc(14) - keyWidth, middle - Sc(10), keyWidth,
				Sc(20), math.max(Sc(4), 3), 1, Color(255, 255, 255, 40 * alpha))

			draw.SimpleText(option.keyLabel, "nwHudSmall", width - Sc(14) - keyWidth * 0.5,
				middle, ColorAlpha(theme.textFaint, 230 * alpha), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		cursor = cursor + rowHeight
	end
end

vgui.Register("nwContextMenu", MENU, "EditablePanel")

function NETWORK.gui.ContextMenu(accent)
	local menu = vgui.Create("nwContextMenu")

	if (accent) then
		menu.accent = accent
	end

	return menu
end
