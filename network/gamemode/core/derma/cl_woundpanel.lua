local PART = {}

function PART:Init()
	self.hover = 0
	self.list = "wound"
	self.index = 0

	NETWORK.gui.itemSlots[self] = true
end

function PART:OnRemove()
	NETWORK.gui.itemSlots[self] = nil
end

function PART:Setup(data)
	self.data = data
	self.slot = data.id
end

function PART:GetSource()
	return {list = "wound", index = 0, slot = self.slot}
end

function PART:GetItem()
end

function PART:GetDropState()
	local drag = NETWORK.gui.drag

	if (!drag) then
		return
	end

	return NETWORK.gui.CanDropInto(drag, self)
end

function PART:Think()
	self.hover = NETWORK.util.Approach(self.hover, self:IsHovered() and 1 or 0, 12)
end

function PART:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme.inv
	local value = NETWORK.wound.Get(LocalPlayer(), self.slot)
	local condition = math.Round(NETWORK.wound.max - value)
	local key, color = NETWORK.wound.GetSeverity(value)
	local hover = util.EaseInOut(self.hover)
	local drop = self:GetDropState()

	NETWORK.gui.DrawPlate(0, 0, width, height, 1, nil, {
		base = theme.cell,
		baseAlpha = 215 + 30 * hover,
		shade = 110,
		outlineAlpha = 180 + 40 * hover
	})

	local fraction = condition / NETWORK.wound.max

	draw.RoundedBox(Sc(3), 0, 0, math.Round(width * fraction), height,
		ColorAlpha(color, 30))

	draw.RoundedBox(Sc(3), Sc(6), Sc(8), math.max(Sc(3), 2), height - Sc(16),
		ColorAlpha(color, 235))

	draw.SimpleText(L(self.data.name), "nwChatSmall", Sc(16), Sc(15),
		ColorAlpha(theme.text, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(L(key), "nwHudSmall", Sc(16), Sc(31),
		ColorAlpha(color, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(condition .. "%", "nwField", width - Sc(12),
		math.Round(height * 0.5), ColorAlpha(color, 245), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (drop != nil) then
		local state = drop and Color(96, 232, 138) or Color(232, 92, 92)
		local pulse = 0.7 + math.sin(RealTime() * 7) * 0.3

		draw.RoundedBox(Sc(3), 0, 0, width, height, ColorAlpha(state, 60 * pulse))

		surface.SetDrawColor(state.r, state.g, state.b, 255 * pulse)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(3), 2))
	end
end

vgui.Register("nwWoundPart", PART, "DPanel")

local PANEL = {}

function PANEL:Init()
	self.parts = {}

	for _, data in ipairs(NETWORK.wound.parts) do
		local part = self:Add("nwWoundPart")

		part:Setup(data)

		self.parts[#self.parts + 1] = part
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local rowHeight = Sc(46)
	local y = Sc(34)

	for _, part in ipairs(self.parts) do
		part:SetSize(width, rowHeight - Sc(4))
		part:SetPos(0, y)

		y = y + rowHeight
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local palette = NETWORK.theme.inv
	local caption = NETWORK.util.Upper(L("woundTitle"))
	local middle = Sc(12)
	local glyphSize = Sc(12)

	NETWORK.gui.DrawGlyph("person", 0, middle - math.Round(glyphSize * 0.5), glyphSize,
		ColorAlpha(palette.accent, 240))

	surface.SetFont("nwInvHeader")

	local textWidth = surface.GetTextSize(caption)

	draw.SimpleText(caption, "nwInvHeader", glyphSize + Sc(8), middle, ColorAlpha(palette.text, 250),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(palette.line.r, palette.line.g, palette.line.b, 140)
	surface.DrawRect(glyphSize + textWidth + Sc(20), middle, math.max(width - glyphSize - textWidth - Sc(20), 0), 1)
end

vgui.Register("nwWoundPanel", PANEL, "DPanel")
