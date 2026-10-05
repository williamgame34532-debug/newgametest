local CONFIG = {}

function CONFIG:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.fields = {}

	self:SetSize(math.min(Sc(520), math.Round(ScrW() * 0.86)),
		math.min(Sc(760), math.Round(ScrH() * 0.9)))
	self:Center()
	self:MakePopup()

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		if (IsValid(self.entity)) then
			NETWORK.trade.SendConfig(self.entity, {
				name = self.fields.name:GetValue(),
				model = self.fields.model:GetValue(),
				description = self.fields.description:GetValue(),
				sequence = self.sequence or "",
				dialogue = self.dialogue or "",
				traderID = self.fields.traderID:GetValue(),
				factions = self.fields.factions:GetValue(),
				unlockItem = self.fields.unlockItem:GetValue(),
				unlockAmount = self.fields.unlockAmount:GetValue(),
				restock = self.fields.restock:GetValue(),
				restockAmount = self.fields.restockAmount:GetValue()
			})
		end

		self:Remove()
	end
end

function CONFIG:AddField(key, value, bMultiline)
	local Sc = NETWORK.util.Scale

	if (IsValid(self.fields[key])) then
		self.fields[key]:Remove()
	end

	local entry = self:Add("DTextEntry")

	entry:SetFont("nwChatSmall")
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
	entry:SetMultiline(tobool(bMultiline))
	entry:SetTextColor(NETWORK.theme.text)
	entry:SetCursorColor(NETWORK.theme.accent)
	entry:SetValue(value or "")
	entry.Paint = function(panel, width, height)
		local theme = NETWORK.theme

		surface.SetDrawColor(9, 24, 32, 225)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			panel:IsEditing() and 200 or 110)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		panel:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
	end

	self.fields[key] = entry

	return entry
end

function CONFIG:Setup(entity)

	for key, field in pairs(self.fields or {}) do
		if (IsValid(field)) then
			field:Remove()
		end

		self.fields[key] = nil
	end

	if (IsValid(self.sequenceChoice)) then
		self.sequenceChoice:Remove()
	end

	if (IsValid(self.dialogueChoice)) then
		self.dialogueChoice:Remove()
	end

	self.entity = entity
	self.sequence = entity:GetNPCSequence()
	self.dialogue = entity:GetDialogue()

	self:AddField("name", entity:GetNPCName())
	self:AddField("model", entity:GetNPCModel())
	self:AddField("description", entity:GetTraderDescription(), true)
	self:AddField("traderID", entity:GetTraderID())
	self:AddField("factions", entity:GetFactions())
	self:AddField("unlockItem", entity:GetUnlockItem())
	self:AddField("unlockAmount", entity:GetUnlockAmount())

	self:AddField("restock", entity:GetRestock())
	self:AddField("restockAmount", entity:GetRestockAmount())

	local sequences = {{value = "", label = "npcNoSequence"}}

	for _, name in ipairs(entity:GetSequenceList() or {}) do
		sequences[#sequences + 1] = {value = name, label = name}
	end

	self.sequenceChoice = self:Add("nwOptChoice")
	self.sequenceChoice:Setup(function()
		return self.sequence or ""
	end, function(value)
		self.sequence = value

		if (IsValid(self.entity)) then
			local index = self.entity:LookupSequence(value)

			if (index and index > 0) then
				self.entity:ResetSequence(index)
			end
		end
	end, sequences, false)

	local dialogues = {{value = "", label = "npcNoDialogue"}}

	for _, data in ipairs(NETWORK.dialogue.GetAll()) do
		dialogues[#dialogues + 1] = {value = data.id,
			label = (data.name or data.id) .. "  [" .. data.id .. "]"}
	end

	self.dialogueChoice = self:Add("nwOptChoice")
	self.dialogueChoice:Setup(function()
		return self.dialogue or ""
	end, function(value)
		self.dialogue = value
	end, dialogues, false)

	self:InvalidateLayout(true)
end

function CONFIG:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local y = Sc(74)

	for _, key in ipairs({"name", "model"}) do
		local field = self.fields[key]

		if (IsValid(field)) then
			field:SetPos(Sc(20), y)
			field:SetSize(width - Sc(40), Sc(32))
		end

		y = y + Sc(62)
	end

	if (IsValid(self.fields.description)) then
		self.fields.description:SetPos(Sc(20), y)
		self.fields.description:SetSize(width - Sc(40), Sc(64))
	end

	y = y + Sc(94)

	for _, key in ipairs({"traderID", "factions"}) do
		local field = self.fields[key]

		if (IsValid(field)) then
			field:SetPos(Sc(20), y)
			field:SetSize(width - Sc(40), Sc(32))
		end

		y = y + Sc(62)
	end

	if (IsValid(self.fields.unlockItem)) then
		self.fields.unlockItem:SetPos(Sc(20), y)
		self.fields.unlockItem:SetSize(width - Sc(40) - Sc(84), Sc(32))
	end

	if (IsValid(self.fields.unlockAmount)) then
		self.fields.unlockAmount:SetPos(width - Sc(20) - Sc(74), y)
		self.fields.unlockAmount:SetSize(Sc(74), Sc(32))
	end

	y = y + Sc(62)

	if (IsValid(self.fields.restock)) then
		self.fields.restock:SetPos(Sc(20), y)
		self.fields.restock:SetSize(width - Sc(40) - Sc(84), Sc(32))
	end

	if (IsValid(self.fields.restockAmount)) then
		self.fields.restockAmount:SetPos(width - Sc(20) - Sc(74), y)
		self.fields.restockAmount:SetSize(Sc(74), Sc(32))
	end

	y = y + Sc(62)

	if (IsValid(self.sequenceChoice)) then
		self.sequenceChoice:SetPos(Sc(20), y)
		self.sequenceChoice:SetSize(width - Sc(40), Sc(32))
	end

	y = y + Sc(62)

	if (IsValid(self.dialogueChoice)) then
		self.dialogueChoice:SetPos(Sc(20), y)
		self.dialogueChoice:SetSize(width - Sc(40), Sc(32))
	end

	self.save:SetPos(Sc(20), height - Sc(52))
	self.save:SetSize(width - Sc(40), Sc(40))
end

function CONFIG:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
end

function CONFIG:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function CONFIG:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util

	util.DrawPanel(0, 0, width, height, self.alpha, {bBrackets = true})
	util.DrawTitleBar(0, 0, width, Sc(42), L("traderConfig"), self.alpha)

	local labels = {L("npcName"), L("npcModel"), L("labelDescription"), L("traderIdent"),
		L("npcFactions"), L("traderUnlock"), L("traderRestock"), L("npcSequence"),
		L("npcDialogue")}
	local offsets = {Sc(60), Sc(122), Sc(184), Sc(280), Sc(342), Sc(404), Sc(466),
		Sc(528), Sc(590)}

	for i = 1, #labels do
		draw.SimpleText(NETWORK.util.Upper(labels[i]), "nwHudSmall", Sc(20), offsets[i],
			ColorAlpha(theme.accentSoft, 245 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwTraderConfig", CONFIG, "EditablePanel")

function NETWORK.gui.OpenTraderConfig(entity)
	if (!IsValid(entity)) then
		return
	end

	if (IsValid(NETWORK.gui.traderConfig)) then
		NETWORK.gui.traderConfig:Remove()
	end

	local panel = vgui.Create("nwTraderConfig")

	NETWORK.gui.traderConfig = panel

	panel:Setup(entity)

	return panel
end

local OFFERS = {}

function OFFERS:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.offers = {}

	self:SetSize(math.min(Sc(560), math.Round(ScrW() * 0.86)),
		math.min(Sc(620), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.list = self:Add("DScrollPanel")

	local bar = self.list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		local focus = vgui.GetKeyboardFocus()

		if (IsValid(focus) and focus.OnValueChange) then
			focus:OnValueChange(focus:GetValue())
		end

		if (IsValid(self.entity)) then
			NETWORK.trade.SendOffers(self.entity, self.offers)
		end

		self:Remove()
	end
end

function OFFERS:Setup(entity)
	self.entity = entity
	self.offers = {}

	hook.Add("NetworkTraderOffersLoaded", self, function(panel, target, offers)
		if (target != panel.entity) then
			return
		end

		panel.offers = table.Copy(offers or {})

		panel:Rebuild()
	end)

	NETWORK.trade.RequestOffers(entity)

	self:Rebuild()
end

function OFFERS:OnRemove()
	hook.Remove("NetworkTraderOffersLoaded", self)

	if (NETWORK.gui.CloseEditorLists) then
		NETWORK.gui.CloseEditorLists()
	end
end

function OFFERS:Button(label, callback, color)
	local Sc = NETWORK.util.Scale
	local button = self.list:Add("DButton")

	button:Dock(TOP)
	button:DockMargin(0, Sc(4), Sc(10), 0)
	button:SetTall(Sc(30))
	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
	end
	button.Paint = function(panel, width, height)
		local tint = color or NETWORK.theme.accent

		surface.SetDrawColor(9, 24, 32, 205 + 40 * panel.hover)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(tint.r, tint.g, tint.b, 120 + 110 * panel.hover)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		surface.SetDrawColor(tint.r, tint.g, tint.b, 200 + 55 * panel.hover)
		surface.DrawRect(0, 0, math.max(Sc(2), 2), height)

		draw.SimpleText(label, "nwChatSmall", Sc(16), math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.text, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	button.DoClick = function()
		NETWORK.sound.Click()

		callback()
	end

	return button
end

function OFFERS:Entry(value, callback)
	local Sc = NETWORK.util.Scale
	local entry = self.list:Add("DTextEntry")

	entry:Dock(TOP)
	entry:DockMargin(0, Sc(4), Sc(10), 0)
	entry:SetTall(Sc(30))
	entry:SetFont("nwChatSmall")
	entry:SetPaintBackground(false)
	entry:SetUpdateOnType(true)
	entry:SetTextColor(NETWORK.theme.text)
	entry:SetCursorColor(NETWORK.theme.accent)
	entry:SetValue(tostring(value or ""))
	entry.Paint = function(panel, width, height)
		local theme = NETWORK.theme

		surface.SetDrawColor(9, 24, 32, 225)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			panel:IsEditing() and 200 or 110)
		surface.DrawOutlinedRect(0, 0, width, height, math.max(Sc(1), 1))

		panel:DrawTextEntryText(theme.text, theme.accentDeep, theme.accent)
	end
	entry.OnChange = function(panel)
		callback(panel:GetValue())
	end

	return entry
end

function OFFERS:Separator(text)
	local Sc = NETWORK.util.Scale
	local panel = self.list:Add("DPanel")

	panel:Dock(TOP)
	panel:DockMargin(0, Sc(14), Sc(10), Sc(2))
	panel:SetTall(Sc(22))
	panel.Paint = function(self, width, height)
		NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(text), "nwHudSmall", 0,
			math.Round(height * 0.5), ColorAlpha(NETWORK.theme.accentSoft, 235), Sc(3),
			TEXT_ALIGN_CENTER)
	end
end

function OFFERS:Rebuild()
	self.list:Clear()

	for index, entry in ipairs(self.offers) do
		local current = entry

		self:Separator(NETWORK.gui.GetTargetName({type = "item", id = current.id}) ..
			"   ·   " .. L("tradeLevel") .. " " .. (current.level or 1))

		self:Button(current.side == "sell" and L("tradeSideSell") or L("tradeSideBuy"),
			function()
				current.side = current.side == "sell" and "buy" or "sell"

				self:Rebuild()
			end)

		self:Button(L("tradeLevel") .. ": " .. (current.level or 1), function()
			current.level = ((current.level or 1) % NETWORK.trade.maxLevel) + 1

			self:Rebuild()
		end, Color(126, 224, 250))

		self:Button(L("tradePickItem"), function()
			NETWORK.gui.OpenItemList(function(value)
				current.id = value

				self:Rebuild()
			end)
		end, Color(126, 224, 250))

		self:Button(current.mode == "item" and L("tradeModeItem") or L("tradeModeTokens"),
			function()
				current.mode = current.mode == "item" and "tokens" or "item"

				self:Rebuild()
			end, Color(240, 200, 90))

		if (current.mode == "item") then
			self:Button(NETWORK.gui.GetTargetName({type = "item", id = current.tradeID}),
				function()
					NETWORK.gui.OpenItemList(function(value)
						current.tradeID = value

						self:Rebuild()
					end)
				end)

			self:Entry(current.tradeAmount or 1, function(value)
				current.tradeAmount = math.max(tonumber(value) or 1, 1)
			end)
		else
			self:Entry(current.price or 10, function(value)
				current.price = math.max(tonumber(value) or 1, 0)
			end)
		end

		if (current.side == "sell") then
			local limited = (current.stock or -1) >= 0

			self:Button(L("tradeStock") .. ": " ..
				(limited and current.stock or L("tradeUnlimited")), function()
					current.stock = limited and -1 or 10
					current.stockMax = current.stock

					self:Rebuild()
				end, Color(150, 214, 170))

			if (limited) then
				self:Entry(current.stock, function(value)
					current.stock = math.max(math.Round(tonumber(value) or 0), 0)
					current.stockMax = current.stock
				end)
			end
		end

		self:Button(L("questRemove"), function()
			table.remove(self.offers, index)

			self:Rebuild()
		end, Color(226, 96, 84))
	end

	self:Button(L("tradeAddOffer"), function()
		self.offers[#self.offers + 1] = {
			id = "ration",
			side = "sell",
			mode = "tokens",
			level = 1,
			price = 20,
			amount = 1,
			tradeID = "scrap",
			tradeAmount = 1,
			stock = -1,
			stockMax = -1
		}

		self:Rebuild()
	end, Color(120, 220, 140))

	self.list:InvalidateLayout(true)
	self.list:GetCanvas():InvalidateLayout(true)

	for _, child in ipairs(self.list:GetCanvas():GetChildren()) do
		child.OnMouseWheeled = function(_, delta)
			return self.list:OnMouseWheeled(delta)
		end
	end
end

function OFFERS:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.list:SetPos(Sc(16), Sc(56))
	self.list:SetSize(width - Sc(32), height - Sc(116))

	self.save:SetPos(Sc(16), height - Sc(52))
	self.save:SetSize(width - Sc(32), Sc(40))
end

function OFFERS:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)
end

function OFFERS:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE and NETWORK.gui.CloseEditorLists) then
		NETWORK.gui.CloseEditorLists()
	end

	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function OFFERS:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	util.DrawPanel(0, 0, width, height, self.alpha, {bBrackets = true})
	util.DrawTitleBar(0, 0, width, Sc(42), L("traderOffers"), self.alpha)
end

vgui.Register("nwTraderOffers", OFFERS, "EditablePanel")

function NETWORK.gui.OpenTraderOffers(entity)
	if (!IsValid(entity)) then
		return
	end

	NETWORK.trade.Request("close")

	net.Start("nwTradeAction")
		net.WriteString("noop")
		net.WriteUInt(0, 8)
	net.SendToServer()

	local panel = vgui.Create("nwTraderOffers")

	panel:Setup(entity)

	return panel
end
