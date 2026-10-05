local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0

	self:SetSize(math.min(Sc(520), math.Round(ScrW() * 0.86)),
		math.min(Sc(600), math.Round(ScrH() * 0.86)))
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
	self.save:SetLabel(L("editorSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		local editor = NETWORK.gui.dialogueEditor

		if (IsValid(editor) and editor.data) then
			editor.data.quests = editor.data.quests or {}
			editor.data.quests[self.id] = self.quest

			NETWORK.gui.Notify(L("questSavedHint"), NETWORK.theme.accentSoft)
		end

		self:Remove()
	end
end

function PANEL:Setup(editor, id)
	self.editor = editor
	self.id = id

	local source = (IsValid(editor) and editor.data and editor.data.quests[id]) or
		NETWORK.quest.Get(id) or {}

	self.quest = table.Copy(source)

	self.quest.name = self.quest.name or id
	self.quest.description = self.quest.description or ""
	self.quest.objectives = self.quest.objectives or {}
	self.quest.rewards = self.quest.rewards or {}
	self.quest.rewards.items = self.quest.rewards.items or {}

	self:Rebuild()
end

function PANEL:Label(text)
	local Sc = NETWORK.util.Scale
	local panel = self.list:Add("DPanel")

	panel:Dock(TOP)
	panel:DockMargin(0, Sc(10), Sc(10), Sc(2))
	panel:SetTall(Sc(20))
	panel.Paint = function(self, width, height)
		draw.SimpleText(text, "nwChatSmall", Sc(8), math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.accentSoft, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:Entry(value, callback, tall, bMultiline)
	local Sc = NETWORK.util.Scale
	local entry = self.list:Add("DTextEntry")

	entry:Dock(TOP)
	entry:DockMargin(0, 0, Sc(10), Sc(4))
	entry:SetTall(tall or Sc(32))
	entry:SetFont("nwChatSmall")
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
	entry:SetUpdateOnType(true)
	entry:SetMultiline(tobool(bMultiline))
	entry:SetTextColor(NETWORK.theme.text)
	entry:SetCursorColor(NETWORK.theme.accent)
	entry:SetValue(tostring(value or ""))
	entry.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(6), 0, 0, width, height, Color(255, 255, 255, 14))

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
			NETWORK.theme.accent)
	end
	entry.OnChange = function(panel)
		callback(panel:GetValue())
	end

	return entry
end

function PANEL:Button(label, callback, color)
	local Sc = NETWORK.util.Scale
	local button = self.list:Add("DButton")

	button:Dock(TOP)
	button:DockMargin(0, Sc(6), Sc(10), 0)
	button:SetTall(Sc(32))
	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
	end
	button.Paint = function(panel, width, height)
		local tint = color or NETWORK.theme.text

		draw.RoundedBox(Sc(6), 0, 0, width, height,
			ColorAlpha(tint, 18 + 22 * panel.hover))

		draw.SimpleText(label, "nwChatSmall", math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(tint, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.DoClick = function()
		NETWORK.sound.Click()

		callback()
	end

	return button
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	self.list:Clear()

	self:Label(L("questName"))
	self:Entry(self.quest.name, function(value)
		self.quest.name = value
	end)

	self:Label(L("labelDescription"))
	self:Entry(self.quest.description, function(value)
		self.quest.description = value
	end, Sc(70), true)

	self:Label(L("questObjectives"))

	local typeLabels = {
		item = "questTypeItem",
		kill = "questTypeKill",
		reach = "questTypeReach",
		use = "questTypeUse"
	}

	for index, objective in ipairs(self.quest.objectives) do
		local current = objective

		self:Button(L(typeLabels[current.type] or "questTypeItem"), function()
			local order = NETWORK.quest.types
			local at = 1

			for i, id in ipairs(order) do
				if (id == current.type) then
					at = i

					break
				end
			end

			current.type = order[(at % #order) + 1]

			if (current.type == "kill") then
				current.id = "npc_citizen"
			elseif (current.type == "item") then
				current.id = "scrap"
			else
				current.id = ""
				current.amount = 1
				current.radius = current.radius or 96
				current.name = current.name or ""
				current.class = current.class or ""
			end

			self:Rebuild()
		end)

		if (NETWORK.quest.IsPointType(current.type)) then
			self:Label(L("questPointName"))
			self:Entry(current.name or "", function(value)
				current.name = value
			end)

			self:Button(current.pos and L("questPointMove") or L("questPointSet"),
				function()
					local position = LocalPlayer():GetPos()

					current.pos = {position.x, position.y, position.z}
					current.map = game.GetMap()

					self:Rebuild()
				end, Color(126, 224, 250))

			if (current.pos) then
				self:Label(L("questPointAt") .. " " ..
					math.Round(current.pos[1]) .. ", " ..
					math.Round(current.pos[2]) .. ", " ..
					math.Round(current.pos[3]))
			end

			self:Label(L("questPointRadius"))
			self:Entry(current.radius or 96, function(value)
				current.radius = math.Clamp(math.Round(tonumber(value) or 96), 16, 1024)
			end)

			if (current.type == "use") then

				self:Label(L("questPointClass"))
				self:Entry(current.class or "", function(value)
					current.class = string.Trim(value)
				end)

				self:Button(L("questPointAim"), function()
					local entity = LocalPlayer():GetEyeTrace().Entity

					if (!IsValid(entity)) then
						NETWORK.gui.Notify(L("questPointNoAim"), NETWORK.theme.danger)

						return
					end

					local position = entity:GetPos()

					current.class = entity:GetClass()
					current.pos = {position.x, position.y, position.z}
					current.map = game.GetMap()

					self:Rebuild()
				end, Color(240, 200, 90))
			end
		else
			self:Button(NETWORK.gui.GetTargetName(current), function()
				if (current.type == "kill") then
					NETWORK.gui.OpenNPCList(function(value)
						current.id = value

						self:Rebuild()
					end)
				else
					NETWORK.gui.OpenItemList(function(value)
						current.id = value

						self:Rebuild()
					end)
				end
			end, Color(126, 224, 250))

			self:Label(L("questAmount"))
			self:Entry(current.amount or 1, function(value)
				current.amount = math.max(tonumber(value) or 1, 1)
			end)
		end

		self:Button(L("questRemove"), function()
			table.remove(self.quest.objectives, index)

			self:Rebuild()
		end, Color(226, 96, 84))
	end

	self:Button(L("questAddObjective"), function()
		self.quest.objectives[#self.quest.objectives + 1] = {type = "item", id = "scrap",
			amount = 1}

		self:Rebuild()
	end)

	self:Label(L("questRewards"))

	for index, reward in ipairs(self.quest.rewards.items) do
		local current = reward

		self:Button(NETWORK.gui.GetTargetName({type = "item", id = current.id}), function()
			NETWORK.gui.OpenItemList(function(value)
				current.id = value

				self:Rebuild()
			end)
		end, Color(126, 224, 250))

		self:Label(L("questAmount"))
		self:Entry(current.amount or 1, function(value)
			current.amount = math.max(tonumber(value) or 1, 1)
		end)

		self:Button(L("questRemove"), function()
			table.remove(self.quest.rewards.items, index)

			self:Rebuild()
		end, Color(226, 96, 84))
	end

	self:Button(L("questAddReward"), function()
		self.quest.rewards.items[#self.quest.rewards.items + 1] = {id = "ration", amount = 1}

		self:Rebuild()
	end)

	self:Label(L("questTraderReward"))

	self.quest.rewards.trader = self.quest.rewards.trader or {}

	self:Entry(self.quest.rewards.trader.id or "", function(value)
		self.quest.rewards.trader.id = string.Trim(value) != "" and string.Trim(value) or nil
	end)

	self:Button(L("tradeLevel") .. ": " .. (self.quest.rewards.trader.level or 2), function()
		self.quest.rewards.trader.level =
			((self.quest.rewards.trader.level or 2) % NETWORK.trade.maxLevel) + 1

		self:Rebuild()
	end, Color(240, 200, 90))

	self:Label(L("questMarker"))

	self:Button(self.quest.marker and L("questMarkerSet") or L("questMarkerNone"), function()
		local position = LocalPlayer():GetPos()

		self.quest.marker = {position.x, position.y, position.z}
		self.quest.markerMap = game.GetMap()

		self:Rebuild()
	end)

	if (self.quest.marker) then
		self:Button(L("questMarkerClear"), function()
			self.quest.marker = nil

			self:Rebuild()
		end, Color(226, 96, 84))
	end
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.list:SetPos(Sc(16), Sc(56))
	self.list:SetSize(width - Sc(32), height - Sc(116))

	self.save:SetPos(Sc(16), height - Sc(52))
	self.save:SetSize(width - Sc(32), Sc(40))
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)

	if (self.owner != nil and !IsValid(self.owner)) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.questEditors) then
		NETWORK.gui.questEditors[self] = nil
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

	util.DrawBlur(self, 5 * self.alpha, 0.3)

	draw.RoundedBox(Sc(12), 0, 0, width, height, Color(9, 12, 17, 250 * self.alpha))

	util.DrawTextSpaced(util.Upper(L("questEditor") .. "  " .. (self.id or "")), "nwTab",
		Sc(20), Sc(28), ColorAlpha(NETWORK.theme.text, 250 * self.alpha), Sc(4),
		TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 12 * self.alpha)
	surface.DrawRect(Sc(14), Sc(48), width - Sc(28), 1)
end

vgui.Register("nwQuestEditor", PANEL, "EditablePanel")

NETWORK.gui.questEditors = NETWORK.gui.questEditors or setmetatable({}, {__mode = "k"})

function NETWORK.gui.OpenQuestEditor(editor, id)
	local panel = vgui.Create("nwQuestEditor")

	panel:Setup(editor, id)

	NETWORK.gui.questEditors[panel] = true

	if (IsValid(editor)) then
		panel.owner = editor
	elseif (IsValid(NETWORK.gui.dialogueEditor)) then
		panel.owner = NETWORK.gui.dialogueEditor
	end

	return panel
end

function NETWORK.gui.CloseQuestEditors()
	for panel in pairs(NETWORK.gui.questEditors) do
		if (IsValid(panel)) then
			panel:Remove()
		end
	end

	NETWORK.gui.questEditors = setmetatable({}, {__mode = "k"})
end

local LIST = {}

function LIST:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0
	self.buttons = {}

	NETWORK.gui.editorLists = NETWORK.gui.editorLists or {}
	NETWORK.gui.editorLists[self] = true

	self:SetSize(Sc(400), Sc(60))
	self:MakePopup()

	self.scroll = self:Add("DScrollPanel")
	self.scroll:SetPos(Sc(10), Sc(44))

	local bar = self.scroll:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end
end

function LIST:AddOption(label, callback, color)
	local Sc = NETWORK.util.Scale
	local index = #self.buttons + 1
	local button = self.scroll:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button:SetSize(self:GetWide() - Sc(30), Sc(32))
	button:SetPos(0, (index - 1) * Sc(34))
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
	end
	button.Paint = function(panel, width, height)
		local tint = color or NETWORK.theme.text

		draw.RoundedBox(Sc(6), 0, 0, width, height,
			ColorAlpha(tint, (14 + 22 * panel.hover) * self.alpha))

		draw.SimpleText(label, "nwChatSmall", Sc(14), math.Round(height * 0.5),
			ColorAlpha(tint, 240 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	button.DoClick = function()
		NETWORK.sound.Click()

		callback()

		self:Remove()
	end

	self.buttons[index] = button

	self:SetSize(self:GetWide(), math.min(Sc(56) + index * Sc(34), ScrH() - Sc(80)))
	self:Center()

	self.scroll:SetSize(self:GetWide() - Sc(20), self:GetTall() - Sc(54))

	return button
end

function LIST:SetTitle(text)
	self.title = text
end

function LIST:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 14)

	if (self.owner != nil and !IsValid(self.owner)) then
		self:Remove()
	end
end

function LIST:OnRemove()
	if (NETWORK.gui.editorLists) then
		NETWORK.gui.editorLists[self] = nil
	end
end

function NETWORK.gui.CloseEditorLists()
	for panel in pairs(NETWORK.gui.editorLists or {}) do
		if (IsValid(panel)) then
			panel:Remove()
		end
	end

	NETWORK.gui.editorLists = {}
end

function LIST:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function LIST:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	draw.RoundedBox(Sc(10), 0, 0, width, height, Color(9, 13, 20, 250 * self.alpha))

	util.DrawTextSpaced(util.Upper(self.title or ""), "nwHudSmall", Sc(16), Sc(22),
		ColorAlpha(NETWORK.theme.accentSoft, 240 * self.alpha), Sc(4), TEXT_ALIGN_CENTER)
end

vgui.Register("nwEditorList", LIST, "EditablePanel")

function NETWORK.gui.NextQuestID(editor)
	local index = 1

	while (editor.data.quests[(editor.id != "" and editor.id or "quest") .. "_" .. index]) do
		index = index + 1
	end

	return (editor.id != "" and editor.id or "quest") .. "_" .. index, index
end

function NETWORK.gui.CreateQuest(editor)
	if (!IsValid(editor) or !editor.data) then
		return
	end

	editor.data.quests = editor.data.quests or {}

	local id, index = NETWORK.gui.NextQuestID(editor)

	editor.data.quests[id] = {
		name = L("questEditor") .. " " .. index,
		description = "",
		objectives = {},
		rewards = {items = {}}
	}

	NETWORK.gui.OpenQuestEditor(editor, id)

	return id
end

function NETWORK.gui.OpenQuestList()
	local editor = NETWORK.gui.dialogueEditor

	if (!IsValid(editor) or !editor.data) then
		return
	end

	editor.data.quests = editor.data.quests or {}

	local panel = vgui.Create("nwEditorList")

	panel.owner = IsValid(NETWORK.gui.dialogueEditor) and NETWORK.gui.dialogueEditor or nil

	panel:SetTitle(L("editorQuests"))

	local ids = {}

	for id in pairs(editor.data.quests) do
		ids[#ids + 1] = id
	end

	table.sort(ids)

	for _, id in ipairs(ids) do
		local quest = editor.data.quests[id]

		panel:AddOption((quest.name or id) .. "  [" .. id .. "]", function()
			local current = NETWORK.gui.dialogueEditor

			if (IsValid(current) and current.data) then
				NETWORK.gui.OpenQuestEditor(current, id)
			end
		end)
	end

	panel:AddOption(L("editorQuestNew"), function()
		NETWORK.gui.CreateQuest(NETWORK.gui.dialogueEditor)
	end, Color(240, 200, 90))

	return panel
end

function NETWORK.gui.OpenDialogueList()
	local editor = NETWORK.gui.dialogueEditor

	if (!IsValid(editor)) then
		return
	end

	local panel = vgui.Create("nwEditorList")

	panel.owner = IsValid(NETWORK.gui.dialogueEditor) and NETWORK.gui.dialogueEditor or nil

	panel:SetTitle(L("editorOpen"))

	local ids = {}

	for _, data in ipairs(NETWORK.dialogue.GetAll()) do
		ids[#ids + 1] = data.id
	end

	table.sort(ids)

	for _, id in ipairs(ids) do
		local data = NETWORK.dialogue.Get(id)

		panel:AddOption((data.name or id) .. "  [" .. id .. "]", function()
			local current = NETWORK.gui.dialogueEditor

			if (IsValid(current)) then
				current:Load(id)
			end
		end)
	end

	panel:AddOption(L("editorNewDialogue"), function()
		local current = NETWORK.gui.dialogueEditor

		if (IsValid(current)) then
			current:Load("")
		end
	end, Color(126, 224, 250))

	return panel
end

function NETWORK.gui.GetTargetName(objective)
	if (objective.type == "kill") then
		local list = list.Get("NPC")[objective.id]

		return (list and list.Name or objective.id or "?") .. "  [" ..
			tostring(objective.id) .. "]"
	end

	local base = NETWORK.item.Get(objective.id)

	return (base and base.name or objective.id or "?") .. "  [" ..
		tostring(objective.id) .. "]"
end

function NETWORK.gui.OpenItemList(callback)
	local panel = vgui.Create("nwEditorList")

	panel.owner = IsValid(NETWORK.gui.dialogueEditor) and NETWORK.gui.dialogueEditor or nil

	panel:SetTitle(L("questPickItem"))

	for _, base in ipairs(NETWORK.item.GetAll()) do
		local rarity = NETWORK.inventory.GetRarity(base.rarity)

		panel:AddOption(base.name .. "  [" .. base.id .. "]", function()
			callback(base.id)
		end, rarity.color)
	end

	return panel
end

function NETWORK.gui.OpenNPCList(callback)
	local panel = vgui.Create("nwEditorList")

	panel.owner = IsValid(NETWORK.gui.dialogueEditor) and NETWORK.gui.dialogueEditor or nil

	panel:SetTitle(L("questPickNPC"))

	local entries = {}

	for class, data in pairs(list.Get("NPC") or {}) do
		entries[#entries + 1] = {class = class, name = data.Name or class}
	end

	if (#entries == 0) then
		for _, class in ipairs({
			"npc_citizen", "npc_metropolice", "npc_combine_s", "npc_zombie",
			"npc_headcrab", "npc_antlion", "npc_manhack"
		}) do
			entries[#entries + 1] = {class = class, name = class}
		end
	end

	table.sort(entries, function(a, b)
		return a.name < b.name
	end)

	while (#entries > 40) do
		table.remove(entries)
	end

	for _, entry in ipairs(entries) do
		panel:AddOption(entry.name .. "  [" .. entry.class .. "]", function()
			callback(entry.class)
		end)
	end

	return panel
end

function NETWORK.gui.OpenNodeList(title, entries, callback)
	local panel = vgui.Create("nwEditorList")

	panel.owner = IsValid(NETWORK.gui.dialogueEditor) and NETWORK.gui.dialogueEditor or nil

	panel:SetTitle(title)

	for _, entry in ipairs(entries) do
		panel:AddOption(entry.label, function()
			callback(entry.value)
		end, Color(238, 118, 74))
	end

	return panel
end
