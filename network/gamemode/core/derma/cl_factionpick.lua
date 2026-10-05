local PANEL = {}

function PANEL:Init()
	if (IsValid(NETWORK.gui.factionPick)) then
		NETWORK.gui.factionPick:Remove()
	end

	NETWORK.gui.factionPick = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.alpha = 0
	self.startTime = CurTime()
	self.tiles = {}
	self.selected = nil

	self:BuildTiles()
end

function PANEL:BuildTiles()
	local client = LocalPlayer()
	local open, locked = {}, {}

	for _, id in ipairs(NETWORK.factions.order) do
		local faction = NETWORK.factions.Get(id)

		if (!faction or faction.bHidden) then
			continue
		end

		local bAllowed = faction.bDefault or
			(client.HasWhitelist and client:HasWhitelist(id))

		local entry = {id = id, faction = faction, bAllowed = bAllowed}

		if (bAllowed) then
			open[#open + 1] = entry
		else
			locked[#locked + 1] = entry
		end
	end

	local list = {}

	for _, entry in ipairs(open) do
		list[#list + 1] = entry
	end

	for _, entry in ipairs(locked) do
		list[#list + 1] = entry
	end

	for index, entry in ipairs(list) do
		local tile = self:Add("DButton")

		tile:SetText("")
		tile.entry = entry
		tile.index = index
		tile.hover = 0

		tile.DoClick = function()
			if (!entry.bAllowed) then
				return NETWORK.gui.Notify(L("createFactionLocked"),
					NETWORK.theme.warning)
			end

			self.selected = entry.id

			NETWORK.sound.Click()
		end

		tile.Paint = function(panel, width, height)
			self:PaintTile(panel, width, height, entry, index)
		end

		self.tiles[#self.tiles + 1] = tile
	end

	if (#open == 1 and #locked == 0) then
		self.selected = open[1].id

		timer.Simple(0, function()
			if (IsValid(self)) then
				self:Accept()
			end
		end)
	end
end

function PANEL:PaintTile(panel, width, height, entry, index)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local faction = entry.faction
	local color = faction.color or theme.accent
	local alpha = util.EaseOut(self.alpha)

	local reveal = math.Clamp((CurTime() - self.startTime - 0.12 -
		index * 0.07) / 0.35, 0, 1)

	reveal = util.EaseOut(reveal) * alpha

	if (reveal < 0.01) then
		return
	end

	local bOn = self.selected == entry.id
	local bHover = panel:IsHovered() and entry.bAllowed

	panel.hover = util.Approach(panel.hover, bHover and 1 or 0, 8)

	local lit = math.max(panel.hover, bOn and 1 or 0)
	local offset = math.Round((1 - reveal) * Sc(24))

	surface.SetDrawColor(8, 10, 12, (200 + 40 * lit) * reveal)
	surface.DrawRect(0, offset, width, height)

	if (lit > 0.01) then
		util.DrawVGradient(0, offset, width, math.Round(height * 0.55),
			ColorAlpha(color, 34 * lit * reveal), ColorAlpha(color, 0))
	end

	surface.SetDrawColor(color.r, color.g, color.b,
		(bOn and 235 or (40 + 120 * lit)) * reveal)
	surface.DrawRect(0, offset, width, math.max(Sc(3), 2))

	local textAlpha = (entry.bAllowed and 1 or 0.5) * reveal

	local y = offset + Sc(34)

	util.DrawTextSpaced(util.Upper(entry.bAllowed and L("createFactionOpen") or
		L("createFactionNeedWhitelist")), "nwMenuMeta", Sc(30), y,
		ColorAlpha(entry.bAllowed and color or theme.textFaint, 220 * textAlpha),
		Sc(3), TEXT_ALIGN_CENTER)

	y = y + Sc(26)

	draw.SimpleText(L(faction.name), "nwTermTitle", Sc(30), y,
		ColorAlpha(theme.text, 250 * textAlpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	y = y + Sc(38)

	local description = faction.description and L(faction.description) or ""

	for _, line in ipairs(util.WrapText(description, "nwMenuSub",
		width - Sc(60), 6)) do
		draw.SimpleText(line, "nwMenuSub", Sc(30), y,
			ColorAlpha(theme.textDim, 225 * textAlpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP)

		y = y + Sc(19)
	end

	if (bOn) then
		draw.SimpleText(util.Upper(L("createFactionChosen")), "nwMenuMeta",
			Sc(30), offset + height - Sc(30), ColorAlpha(color, 245 * reveal),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local count = #self.tiles

	if (count == 0) then
		return
	end

	local top = Sc(150)
	local bottom = Sc(110)
	local gap = 1
	local tileWidth = math.floor((width - gap * (count - 1)) / count)

	for index, tile in ipairs(self.tiles) do
		tile:SetSize(tileWidth, height - top - bottom)
		tile:SetPos((index - 1) * (tileWidth + gap), top)
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 5)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:Accept()
	if (!self.selected) then
		return
	end

	local id = self.selected

	self.bClosing = true

	if (self.OnPicked) then
		self:OnPicked(id)
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = util.EaseOut(self.alpha)

	surface.SetDrawColor(4, 5, 7, 244 * alpha)
	surface.DrawRect(0, 0, width, height)

	NETWORK.gui.PaintSteps(width, Sc(54), 1, alpha)

	util.DrawTextSpaced(util.Upper(L("createPickFaction")), "nwTermTitle",
		width * 0.5, Sc(110), ColorAlpha(theme.text, 250 * alpha), Sc(4),
		TEXT_ALIGN_CENTER)

	local bReady = self.selected != nil
	local hint = bReady and L("createFactionReady",
		L(NETWORK.factions.Get(self.selected).name)) or L("createFactionPick")

	draw.SimpleText(hint, "nwMenuSub", width * 0.5, height - Sc(62),
		ColorAlpha(bReady and theme.text or theme.textFaint, 235 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self.bClosing = true

		if (self.OnCancelled) then
			self:OnCancelled()
		end
	elseif (key == KEY_ENTER) then
		self:Accept()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.factionPick == self) then
		NETWORK.gui.factionPick = nil
	end
end

vgui.Register("nwFactionPick", PANEL, "EditablePanel")

function NETWORK.gui.PaintSteps(width, y, current, alpha)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util

	local steps = {L("createStepFaction"), L("createStepName"),
		L("createStepLook"), L("createStepGear")}

	surface.SetFont("nwMenuSub")

	local totalWidth = 0
	local widths = {}

	for index, label in ipairs(steps) do
		widths[index] = surface.GetTextSize(label) + Sc(34)
		totalWidth = totalWidth + widths[index]
	end

	local x = math.Round((width - totalWidth) * 0.5)

	for index, label in ipairs(steps) do
		local bOn = index == current
		local bDone = index < current
		local color = bOn and theme.text or (bDone and theme.accent or theme.textFaint)

		local circle = Sc(19)

		surface.SetDrawColor(color.r, color.g, color.b,
			(bOn and 200 or 90) * alpha)
		surface.DrawOutlinedRect(x, y - circle * 0.5, circle, circle, 1)

		draw.SimpleText(bDone and "✓" or index, "nwMenuMeta",
			x + circle * 0.5, y, ColorAlpha(color, 235 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(label, "nwMenuSub", x + circle + Sc(8), y,
			ColorAlpha(color, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		x = x + widths[index]
	end
end
