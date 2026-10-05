local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.buttons = {}

	self:SetSize(Sc(320), Sc(210))
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
end

function PANEL:AddAction(label, primary, callback)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")

	button.keyLabel = primary and string.upper(input.LookupBinding("+use", true) or "E")
		or "ESC"

	button.DoClick = function()
		NETWORK.sound.Click()

		callback()
	end
	button.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local color = primary and self.color or theme.textFaint
		local hover = panel:IsHovered() and 1 or 0

		local accent = primary and NETWORK.theme.accent or theme.textFaint
		local radius = math.max(Sc(6), 4)

		if (primary) then
			draw.RoundedBox(radius, 0, 0, width, height,
				ColorAlpha(accent, (36 + 20 * hover) * self.alpha))

			surface.SetDrawColor(accent.r, accent.g, accent.b, 120 * self.alpha)
			surface.DrawOutlinedRect(0, 0, width, height, 1)
		elseif (hover > 0) then
			draw.RoundedBox(radius, 0, 0, width, height,
				Color(255, 255, 255, 12 * self.alpha))
		end

		draw.RoundedBox(math.max(Sc(4), 3), Sc(10), math.Round((height - Sc(22)) * 0.5),
			Sc(22), Sc(22), Color(255, 255, 255, 14 * self.alpha))

		draw.SimpleText(primary and "✋" or "·", "nwHudSmall", Sc(10) + Sc(11),
			math.Round(height * 0.5), ColorAlpha(theme.text, 220 * self.alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(label, "nwField", Sc(42), math.Round(height * 0.5),
			ColorAlpha(primary and theme.text or theme.textDim, 245 * self.alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (panel.keyLabel) then
			surface.SetFont("nwHudSmall")

			local keyWidth = surface.GetTextSize(panel.keyLabel) + Sc(12)

			surface.SetDrawColor(255, 255, 255, 40 * self.alpha)
			surface.DrawOutlinedRect(width - keyWidth - Sc(10),
				math.Round((height - Sc(20)) * 0.5), keyWidth, Sc(20), 1)

			draw.SimpleText(panel.keyLabel, "nwHudSmall", width - Sc(10) - keyWidth * 0.5,
				math.Round(height * 0.5), ColorAlpha(theme.textFaint, 230 * self.alpha),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	self.buttons[#self.buttons + 1] = button

	return button
end

function PANEL:Setup(entity)
	local Sc = NETWORK.util.Scale

	self.entity = entity
	self.item = entity:GetItem()

	if (!self.item) then
		self:Remove()

		return
	end

	local rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(self.item))

	self.color = rarity.color
	self.name = NETWORK.item.GetName(self.item)
	self.lines = NETWORK.util.WrapText(NETWORK.item.GetDescription(self.item),
		"nwTipBody", Sc(280), 3)

	self:AddAction(L("itemPickUp"), true, function()
		net.Start("nwItemTake")
			net.WriteEntity(self.entity)
		net.SendToServer()

		self:Remove()
	end)

	self:AddAction(L("menuBack"), false, function()
		self:Remove()
	end)

	self:SetTall(Sc(96) + #self.lines * Sc(21) + #self.buttons * Sc(40))
	self:Center()
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local y = height - Sc(20) - #self.buttons * Sc(40)

	for _, button in ipairs(self.buttons) do
		button:SetPos(Sc(18), y)
		button:SetSize(width - Sc(36), Sc(34))

		y = y + Sc(40)
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 14)

	local client = LocalPlayer()

	if (!IsValid(self.entity) or !IsValid(client) or !client:Alive() or
		client:GetPos():Distance(self.entity:GetPos()) > NETWORK.worldItem.range + 24) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local color = self.color
	local alpha = self.alpha
	local cut = Sc(14)

	local radius = math.max(Sc(10), 6)

	draw.RoundedBox(radius, Sc(3), Sc(5), width, height, Color(0, 0, 0, 90 * alpha))
	draw.RoundedBox(radius, 0, 0, width, height, Color(14, 16, 20, 244 * alpha))

	surface.SetDrawColor(255, 255, 255, 20 * alpha)
	surface.DrawOutlinedRect(0, 0, width, height, 1)

	draw.SimpleText(self.name, "nwTipTitle", Sc(18), Sc(22), ColorAlpha(color, 252 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 16 * alpha)
	surface.DrawRect(Sc(18), Sc(44), width - Sc(36), 1)

	local y = Sc(62)

	for i = 1, #self.lines do
		draw.SimpleText(self.lines[i], "nwTipBody", Sc(18), y,
			Color(176, 203, 213, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + Sc(21)
	end
end

vgui.Register("nwPickupMenu", PANEL, "EditablePanel")

function NETWORK.gui.OpenPickupMenu(entity)
	if (IsValid(NETWORK.gui.pickup)) then
		NETWORK.gui.pickup:Remove()
	end

	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwPickupMenu")

	panel:Setup(entity)

	NETWORK.gui.pickup = panel

	return panel
end
