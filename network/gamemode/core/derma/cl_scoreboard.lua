local ROW = {}

function ROW:Init()
	self:SetText("")
	self:SetCursor("hand")

	self.hover = 0
	self.reveal = 0
	self.born = RealTime()
	self.nextUpdate = 0
end

function ROW:Setup(client, color, index)
	self.client = client
	self.color = color
	self.index = index or 1
	self.characterID = client:GetCharacterID()
	self.born = RealTime() + math.min(index or 0, 20) * 0.02

	self.portrait = self:Add("DModelPanel")
	self.portrait:SetMouseInputEnabled(false)
	self.portrait:SetFOV(30)
	self.portrait:SetAnimated(false)
	self.portrait.LayoutEntity = function() end

	self:Update(true)
end

function ROW:IsKnown()
	local local_ = LocalPlayer()

	return self.client == local_ or local_:IsRecognised(self.client) or local_:IsAdmin()
end

function ROW:Update(bForce)
	local client = self.client

	if (!IsValid(client)) then
		return
	end

	local model = client:GetCharacterModel()

	if (bForce or self.modelPath != model) then
		self.modelPath = model
		self.portrait:SetModel(model)

		local entity = self.portrait:GetEntity()

		if (IsValid(entity)) then
			NETWORK.util.ApplyAppearance(self.portrait, client)

			local head = entity:LookupBone("ValveBiped.Bip01_Head1")

			if (head) then
				local position = entity:GetBonePosition(head)

				self.portrait:SetLookAt(position - Vector(0, 0, 2))
				self.portrait:SetCamPos(position + Vector(38, 0, 2))
			end
		end
	end

	self.bKnown = self:IsKnown()
	self.name = self.bKnown and client:GetCharacterName() or client:GetUnknownName()
	self.description = self.bKnown and client:GetCharacterDescription() or
		L("recogUnknownDesc")

	self:SetZPos((self.bKnown and 0 or 1000) + self.index)

	if (!bForce and NETWORK.gui.tooltip and NETWORK.gui.tooltip.owner == self and
		self:IsHovered()) then
		self:ShowTooltip()
	end
end

function ROW:ShowTooltip()
	if (IsValid(self.client) and NETWORK.gui.BuildPlayerTooltip) then
		NETWORK.gui.SetTooltip(self, NETWORK.gui.BuildPlayerTooltip(self.client))
	end
end

function ROW:IsStale()
	local client = self.client

	return !IsValid(client) or !client:HasCharacter() or
		client:GetCharacterID() != self.characterID
end

function ROW:Think()
	local util = NETWORK.util

	self.hover = util.Approach(self.hover, self:IsHovered() and 1 or 0, 12)
	self.reveal = util.EaseOut(math.Clamp((RealTime() - self.born) / 0.35, 0, 1))

	if (RealTime() >= self.nextUpdate) then
		self.nextUpdate = RealTime() + 1

		self:Update()
	end
end

function ROW:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	if (IsValid(self.portrait)) then
		self.portrait:SetPos(Sc(14), Sc(4))
		self.portrait:SetSize(height - Sc(8), height - Sc(8))
	end
end

function ROW:OnCursorEntered()
	NETWORK.sound.Hover()

	self:ShowTooltip()
end

function ROW:OnCursorExited()
	NETWORK.gui.ClearTooltip(self)
end

function ROW:OpenMenu()
	local client = self.client

	if (!IsValid(client)) then
		return
	end

	NETWORK.gui.ClearTooltip(self)

	local menu = NETWORK.gui.ContextMenu()

	local faction = client:HasCharacter() and
		NETWORK.factions.Get(client:GetCharacterFaction())

	menu:SetHeader(self.bKnown and client:GetCharacterName() or client:Name(),
		(self.bKnown and faction) and L(faction.name) or nil)

	menu:AddSection(L("ctxSectionProfile"))

	if (!client:IsBot()) then
		menu:AddOption(L("playersProfile"), function()
			if (IsValid(client)) then
				client:ShowProfile()
			end
		end):SetIcon("icon16/user.png")
	end

	menu:AddOption(L("playersCopySteam"), function()
		if (IsValid(client)) then
			SetClipboardText(client:IsBot() and tostring(client:EntIndex()) or
				client:SteamID())

			NETWORK.gui.Notify(L("playersCopied"), NETWORK.theme.positive)
		end
	end):SetIcon("icon16/page_copy.png")

	if (LocalPlayer():IsAdmin()) then
		menu:AddSection(L("ctxSectionService"))
	end

	if (self.bKnown and LocalPlayer():IsAdmin()) then
		menu:AddOption(L("playersCopyName"), function()
			if (IsValid(client)) then
				SetClipboardText(client:GetCharacterName())
			end
		end):SetIcon("icon16/textfield.png")
	end

	hook.Run("NetworkScoreboardMenu", client, menu)

	menu:Open()
end

function ROW:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		NETWORK.sound.Click()

		return self:OpenMenu()
	end
end

function ROW:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local reveal = self.reveal

	if (reveal < 0.01 or !IsValid(self.client)) then
		return
	end

	local hover = util.EaseInOut(self.hover)
	local x = math.Round((1 - reveal) * Sc(16))
	local S = NETWORK.style
	local radius = (S and S.Radius) and S.Radius("cell") or math.max(Sc(6), 3)
	local color = self.color

	draw.RoundedBox(radius, x, 0, width - x, height,
		Color(10, 13, 17, (self.index % 2 == 0 and 175 or 205) * reveal))

	if (hover > 0.01) then
		draw.RoundedBox(radius, x, 0, width - x, height,
			Color(255, 255, 255, 12 * hover * reveal))
		util.DrawRoundedBorder(x, 0, width - x, height, radius, 1,
			Color(color.r, color.g, color.b, 150 * hover * reveal))
	end

	local rail = math.max(Sc(3), 2)

	draw.RoundedBox(math.floor(rail * 0.5), x + math.max(Sc(4), 3), Sc(10), rail,
		height - Sc(20), Color(color.r, color.g, color.b, (200 + 55 * hover) * reveal))

	local portrait = height - Sc(8)

	draw.RoundedBox(radius, x + Sc(14), Sc(4), portrait, portrait, Color(0, 0, 0, 150 * reveal))

	if (IsValid(self.portrait)) then
		self.portrait:SetVisible(self.bKnown)
		self.portrait:SetAlpha(math.Round(255 * reveal))
	end

	if (!self.bKnown) then
		draw.SimpleText("?", "nwTitle", x + Sc(14) + math.Round(portrait * 0.5),
			math.Round(height * 0.5), ColorAlpha(theme.textFaint, 200 * reveal),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local textX = x + Sc(14) + portrait + Sc(16)
	local rightX = width - Sc(18)

	local shownName = util.TruncateWidth(self.name or "?", "nwField",
		math.max(math.Round((width - textX) * 0.55), Sc(60)))

	draw.SimpleText(shownName, "nwField", textX,
		math.Round(height * 0.5) - Sc(10),
		ColorAlpha(self.client == LocalPlayer() and theme.hover or theme.text,
		250 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local target = self.client
	local bDown = target.IsDowned and (target:IsDowned() or
		(target.IsUnconscious and target:IsUnconscious())) or !target:Alive()

	if (bDown) then
		surface.SetFont("nwHudSmall")

		local label = util.Upper(L("scoreDowned"))
		local labelWidth = surface.GetTextSize(label) + Sc(12)
		local labelX = x + Sc(14) + portrait + Sc(16)

		draw.RoundedBox(math.max(Sc(4), 3), labelX, Sc(6), labelWidth, Sc(16),
			ColorAlpha(theme.danger, 40 * reveal))

		draw.SimpleText(label, "nwHudSmall", labelX + math.Round(labelWidth * 0.5),
			Sc(14), ColorAlpha(theme.danger, 235 * reveal), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end

	local ping = self.client:Ping()
	local pingColor = ping < 100 and theme.positive or
		(ping < 200 and theme.warning or theme.danger)

	surface.SetFont("nwField")

	local pingText = ping .. " ms"
	local pingWidth = surface.GetTextSize(pingText)
	local maxText = rightX - pingWidth - Sc(30) - textX

	draw.SimpleText(util.TruncateWidth(self.description or "", "nwHudSmall", maxText),
		"nwHudSmall", textX, math.Round(height * 0.5) + Sc(12),
		ColorAlpha(theme.textDim, 225 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local bars = ping < 60 and 4 or (ping < 120 and 3 or (ping < 200 and 2 or 1))
	local barWidth = math.max(Sc(3), 2)

	for bar = 1, 4 do
		local barHeight = Sc(4) + bar * Sc(3)

		surface.SetDrawColor(pingColor.r, pingColor.g, pingColor.b,
			(bar <= bars and 235 or 40) * reveal)
		surface.DrawRect(rightX - (5 - bar) * (barWidth + Sc(2)),
			math.Round(height * 0.5) - Sc(2) - barHeight, barWidth, barHeight)
	end

	local signalWidth = 4 * (barWidth + Sc(2)) + Sc(8)

	if (self.client.IsSpeaking and self.client:IsSpeaking()) then
		local pulse = 0.7 + math.abs(math.sin(RealTime() * 5)) * 0.3
		local dotX = rightX - signalWidth - Sc(64)

		surface.SetFont("nwField")

		local pingWidth = surface.GetTextSize(pingText)

		dotX = rightX - signalWidth - pingWidth - Sc(18)

		NETWORK.util.DrawCircle(dotX, math.Round(height * 0.5) - Sc(10), Sc(4),
			ColorAlpha(theme.positive, 240 * reveal * pulse), 16)
	end

	draw.SimpleText(pingText, "nwField", rightX - signalWidth,
		math.Round(height * 0.5) - Sc(10), ColorAlpha(pingColor, 240 * reveal),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.TruncateWidth(self.client:SteamName(), "nwHudSmall", Sc(220)),
		"nwHudSmall", rightX, math.Round(height * 0.5) + Sc(12),
		ColorAlpha(theme.textFaint, 220 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (self.client:IsAdmin() and self.bKnown and LocalPlayer():IsAdmin()) then
		local badge = util.Upper(L(self.client:IsSuperAdmin() and "playersSuperAdmin" or
			"playersAdmin"))

		surface.SetFont("nwHudLabelSmall")

		local badgeWidth = surface.GetTextSize(badge) + Sc(12)

		surface.SetFont("nwField")

		local nameWidth = surface.GetTextSize(shownName)

		local badgeX = textX + nameWidth + Sc(10)

		draw.RoundedBox(math.max(Sc(3), 2), badgeX, math.Round(height * 0.5) - Sc(18),
			badgeWidth, Sc(16), ColorAlpha(theme.hover, 40 * reveal))
		draw.SimpleText(badge, "nwHudLabelSmall", badgeX + math.Round(badgeWidth * 0.5),
			math.Round(height * 0.5) - Sc(10), ColorAlpha(theme.hover, 240 * reveal),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwScoreboardRow", ROW, "DButton")

local GROUP = {}

function GROUP:Init()
	self.rows = {}
	self.born = RealTime()

	self:DockPadding(0, NETWORK.util.Scale(38), 0, 0)
end

function GROUP:Setup(id)
	local faction = NETWORK.factions.Get(id)

	self.factionID = id
	self.color = faction and faction.color or NETWORK.theme.textDim
	self.caption = NETWORK.util.Upper(faction and L(faction.name) or L("playersNoFaction"))

	if (string.sub(id, 1, 6) == "class:") then
		local classTable = NETWORK.classes.Get(string.sub(id, 7))
		local citizen = NETWORK.factions.Get("citizen")

		self.color = citizen and citizen.color or self.color
		self.caption = NETWORK.util.Upper(classTable and L(classTable.name) or id)
	end

	if (id == "stranger") then
		self.color = NETWORK.recognition.strangerColor
		self.caption = NETWORK.util.Upper(L("playersStrangers"))
	end
end

function GROUP:Sync(list)
	local Sc = NETWORK.util.Scale
	local seen = {}

	for index, client in ipairs(list) do
		local row = self.rows[client]

		seen[client] = true

		if (IsValid(row) and row:IsStale()) then
			row:Remove()
			row = nil
		end

		if (!IsValid(row)) then
			row = self:Add("nwScoreboardRow")
			row:Dock(TOP)
			row:DockMargin(0, 0, 0, Sc(6))
			row:SetTall(Sc(62))
			row:Setup(client, self.color, index)

			self.rows[client] = row
		end
	end

	for client, row in pairs(self.rows) do
		if (!seen[client] or !IsValid(row)) then
			if (IsValid(row)) then
				row:Remove()
			end

			self.rows[client] = nil
		end
	end

	self.count = #list

	self:InvalidateLayout(true)
	self:SizeToChildren(false, true)
end

function GROUP:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local reveal = NETWORK.util.EaseOut(math.Clamp((RealTime() - self.born) / 0.4, 0, 1))
	local tagHeight = Sc(26)

	draw.SimpleText(self.caption, "nwInvKey", 0, math.Round(tagHeight * 0.5),
		ColorAlpha(self.color, 240 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(tostring(self.count or 0), "nwInvSub", width - Sc(6),
		math.Round(tagHeight * 0.5), ColorAlpha(theme.textDim, 240 * reveal),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 14 * reveal)
	surface.DrawRect(0, tagHeight - 1, width - Sc(6), 1)
end

vgui.Register("nwScoreboardGroup", GROUP, "DPanel")

local BOARD = {}

function BOARD:Init()
	local Sc = NETWORK.util.Scale
	local bar = self:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(math.floor(width * 0.5), 0, 0, width, height,
			Color(255, 255, 255, 60))
	end

	self.groups = {}
	self.nextSync = 0
	self.filter = ""

	local theme = NETWORK.theme

	local search = NETWORK.gui.BindEntry(self:Add("DTextEntry"))

	search:Dock(TOP)
	search:DockMargin(0, 0, Sc(10), Sc(12))
	search:SetTall(Sc(32))
	search:SetFont("nwInvBody")
	search:SetDrawLanguageID(false)
	search:SetPaintBackground(false)
	search:SetTextColor(theme.text)
	search:SetCursorColor(theme.combine)
	search:SetHighlightColor(theme.combineDeep)
	search:SetTextInset(Sc(28), 0)
	search:SetUpdateOnType(true)
	search.OnValueChange = function(panel, value)
		self.filter = NETWORK.util.Lower(string.Trim(value))
		self.nextSync = 0
	end
	search.OnMousePressed = function(panel)
		panel:RequestFocus()
	end
	search.Paint = function(panel, width, height)
		local bFocus = panel:HasFocus()
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(10, 11, 13, 230))

		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
			bFocus and ColorAlpha(theme.combine, 210) or Color(255, 255, 255, 30))

		draw.SimpleText("⌕", "nwInvBody", Sc(9), math.Round(height * 0.5) - 1,
			ColorAlpha(theme.textFaint, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (panel:GetValue() == "") then
			draw.SimpleText(L("playersSearch"), "nwInvBody", Sc(28), math.Round(height * 0.5),
				ColorAlpha(theme.textFaint, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)
	end

	self.search = search
end

function BOARD:Think()
	if (RealTime() < self.nextSync) then
		return
	end

	self.nextSync = RealTime() + 0.5

	local Sc = NETWORK.util.Scale
	local grouped = {}
	local viewer = LocalPlayer()
	local shown = {}

	for _, client in ipairs(player.GetAll()) do
		if (!client:HasCharacter() or
			hook.Run("NetworkShouldShowOnScoreboard", client) == false) then
			continue
		end

		local bKnown = client == viewer or viewer:IsRecognised(client) or viewer:IsAdmin()
		local shownName = bKnown and client:GetCharacterName() or client:GetUnknownName()

		shown[client] = shownName

		if (self.filter != "") then
			local haystack = NETWORK.util.Lower(shownName .. " " .. client:Name())

			if (!string.find(haystack, self.filter, 1, true)) then
				continue
			end
		end

		local id = client:GetCharacterFaction() or "none"
		local classTable = NETWORK.classes.Get(client:GetNWString("nwClass", ""))

		if (!bKnown) then
			id = "stranger"
		elseif (classTable and classTable.bCivilianHud) then
			id = "class:" .. classTable.id
		end

		grouped[id] = grouped[id] or {}
		grouped[id][#grouped[id] + 1] = client
	end

	local order = {}

	for _, id in ipairs(NETWORK.factions.order) do
		order[#order + 1] = id
	end

	for id in pairs(grouped) do
		if (string.sub(id, 1, 6) == "class:") then
			order[#order + 1] = id
		end
	end

	order[#order + 1] = "stranger"
	order[#order + 1] = "none"

	for position, id in ipairs(order) do
		local list = grouped[id]
		local group = self.groups[id]

		if (!list or #list == 0) then
			if (IsValid(group)) then
				group:Remove()
			end

			self.groups[id] = nil

			continue
		end

		table.sort(list, function(a, b)
			return (shown[a] or "") < (shown[b] or "")
		end)

		if (!IsValid(group)) then
			group = self:Add("nwScoreboardGroup")
			group:Dock(TOP)
			group:SetZPos(position + 1)
			group:DockMargin(0, 0, Sc(10), Sc(18))
			group:Setup(id)

			self.groups[id] = group
		end

		group:SetZPos(position)
		group:Sync(list)
	end
end

vgui.Register("nwScoreboard", BOARD, "DScrollPanel")
