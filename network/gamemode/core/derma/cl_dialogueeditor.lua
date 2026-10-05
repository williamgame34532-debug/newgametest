local PANEL = {}

local COLOR_GRID = Color(24, 40, 58)
local COLOR_NODE = Color(18, 58, 82)
local COLOR_HEADER = Color(126, 224, 250)
local COLOR_REPLY = Color(22, 46, 68)
local COLOR_LINK = Color(238, 118, 74)

function PANEL:Init()
	local ScDefault = NETWORK.util.Scale

	self.sideWidth = ScDefault(320)
	local Sc = NETWORK.util.Scale

	NETWORK.gui.dialogueEditor = self

	self.offsetX = 0
	self.offsetY = 0
	self.zoom = 1
	self.nodeWidth = Sc(290)
	self.rowHeight = Sc(30)
	self.headerHeight = Sc(32)
	self.textHeight = Sc(38)
	self.data = {name = "", start = "greeting", nodes = {}, quests = {}}
	self.id = ""
	self.selected = nil

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.properties = self:Add("DScrollPanel")

	local bar = self.properties:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(2), 0, 0, width, height, Color(255, 255, 255, 60))
	end

	self.toolbar = self:Add("DPanel")
	self.toolbar.Paint = function() end

	self:BuildToolbar()
end

function PANEL:OnRemove()
	if (NETWORK.gui.dialogueEditor == self) then
		NETWORK.gui.dialogueEditor = nil
	end

	if (NETWORK.gui.CloseEditorLists) then
		NETWORK.gui.CloseEditorLists()
	end

	if (NETWORK.gui.CloseQuestEditors) then
		NETWORK.gui.CloseQuestEditors()
	end

	local tutorial = NETWORK.gui.tutorial

	if (IsValid(tutorial) and (tutorial.id == nil or tutorial.id == "dialogue")) then
		tutorial:Remove()
	end
end

function PANEL:Close()
	self:Remove()
end

function PANEL:Button(parent, label, callback, color)
	local Sc = NETWORK.util.Scale
	local button = parent:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
	end
	button.Paint = function(panel, width, height)
		local tint = color or COLOR_HEADER

		draw.RoundedBox(Sc(6), 0, 0, width, height,
			ColorAlpha(tint, 24 + 26 * panel.hover))

		draw.SimpleText(label, "nwChatSmall", math.Round(width * 0.5), math.Round(height * 0.5),
			ColorAlpha(tint, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.DoClick = function()
		NETWORK.sound.Click()

		callback()
	end

	return button
end

function PANEL:Entry(parent, value, callback, bMultiline)
	local Sc = NETWORK.util.Scale
	local entry = parent:Add("DTextEntry")

	entry:SetFont("nwChatSmall")
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
	entry:SetUpdateOnType(true)
	entry:SetMultiline(tobool(bMultiline))
	entry:SetTextColor(NETWORK.theme.text)
	entry:SetCursorColor(NETWORK.theme.accent)
	entry:SetValue(value or "")
	entry.Paint = function(panel, width, height)
		draw.RoundedBox(Sc(6), 0, 0, width, height, Color(255, 255, 255, 14))

		panel:DrawTextEntryText(NETWORK.theme.text, NETWORK.theme.accentDeep,
			NETWORK.theme.accent)
	end
	entry.OnChange = function(panel)
		callback(panel:GetValue())
	end
	entry.OnValueChange = function(panel, text)
		callback(text)
	end

	return entry
end

function PANEL:BuildToolbar()
	local Sc = NETWORK.util.Scale

	for _, panel in ipairs(self.toolbar:GetChildren()) do
		panel:Remove()
	end

	self.idEntry = self:Entry(self.toolbar, self.id, function(value)
		self.id = string.lower(string.Trim(value))

		if (self.id != "") then
			self.errorText = nil
		end
	end)

	self.nameEntry = self:Entry(self.toolbar, self.data.name, function(value)
		self.data.name = value

		if (string.Trim(value) != "") then
			self.errorText = nil
		end
	end)

	self.buttons = {
		self:Button(self.toolbar, L("editorAddNode"), function()
			self:AddNode()
		end),
		self:Button(self.toolbar, L("editorQuests"), function()
			NETWORK.gui.OpenQuestList()
		end, Color(240, 200, 90)),
		self:Button(self.toolbar, L("editorOpen"), function()
			NETWORK.gui.OpenDialogueList()
		end),
		self:Button(self.toolbar, L("editorSave"), function()
			self:Save()
		end),
		self:Button(self.toolbar, L("tutorOpen"), function()
			NETWORK.gui.OpenTutorial("dialogue", true)
		end, Color(120, 220, 140)),
		self:Button(self.toolbar, L("editorClose"), function()
			self:Remove()
		end, Color(226, 96, 84))
	}

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	self.sideWidth = Sc(340)

	if (IsValid(self.properties)) then
		self.properties:SetPos(width - self.sideWidth + Sc(16), Sc(76))
		self.properties:SetSize(self.sideWidth - Sc(32), height - Sc(96))
	end

	if (!IsValid(self.toolbar)) then
		return
	end

	self.toolbar:SetPos(Sc(20), Sc(24))
	self.toolbar:SetSize(width - self.sideWidth - Sc(40), Sc(36))

	if (IsValid(self.idEntry)) then
		self.idEntry:SetPos(0, 0)
		self.idEntry:SetSize(Sc(170), Sc(36))
	end

	if (IsValid(self.nameEntry)) then
		self.nameEntry:SetPos(Sc(180), 0)
		self.nameEntry:SetSize(Sc(260), Sc(36))
	end

	for index, button in ipairs(self.buttons or {}) do
		button:SetSize(Sc(118), Sc(36))
		button:SetPos(Sc(456) + (index - 1) * Sc(124), 0)
	end
end

function PANEL:Load(id)
	local Sc = NETWORK.util.Scale

	self.id = id or ""
	self.errorText = nil

	local source = NETWORK.dialogue.custom[self.id]

	if (source) then
		self.data = table.Copy(source)
	else
		local existing = NETWORK.dialogue.Get(self.id)

		if (existing) then
			self.data = table.Copy(existing)
		else
			self.data = {name = "", start = "greeting", nodes = {}, quests = {}}
		end
	end

	self.data.nodes = self.data.nodes or {}
	self.data.quests = self.data.quests or {}

	local index = 0

	for _, node in pairs(self.data.nodes) do
		node.x = node.x or (Sc(120) + (index % 3) * Sc(360))
		node.y = node.y or (Sc(140) + math.floor(index / 3) * Sc(280))
		node.replies = node.replies or {}

		index = index + 1
	end

	self:BuildToolbar()
end

function PANEL:AddNode()
	local Sc = NETWORK.util.Scale
	local index = 1

	while (self.data.nodes["node" .. index]) do
		index = index + 1
	end

	local id = "node" .. index
	local bFirst = table.Count(self.data.nodes) == 0

	if (bFirst) then
		id = "greeting"
	end

	local spawnX, spawnY = self:ToCanvas(Sc(240), Sc(220))

	self.data.nodes[id] = {
		x = spawnX,
		y = spawnY,
		text = bFirst and L("editorSampleGreeting") or "",
		replies = {
			{text = L("editorSampleReply"), exit = true}
		}
	}

	if (bFirst) then
		self.data.start = id
	end

	self:Select({type = "node", node = id})
end

function PANEL:Fail(key)
	self.errorText = L(key)
	self.errorTime = CurTime()

	NETWORK.gui.Notify(self.errorText, NETWORK.theme.danger)

	NETWORK.sound.Play("hover3", 92, 0.5)
end

function PANEL:Save()
	if (string.Trim(self.id or "") == "") then
		self:Fail("editorNoID")

		if (IsValid(self.idEntry)) then
			self.idEntry:RequestFocus()
		end

		return
	end

	if (string.Trim(self.data.name or "") == "") then
		self:Fail("editorNoName")

		if (IsValid(self.nameEntry)) then
			self.nameEntry:RequestFocus()
		end

		return
	end

	if (table.Count(self.data.nodes) == 0) then
		self:Fail("editorNoNodes")

		return
	end

	if (!self.data.nodes[self.data.start]) then
		for id in pairs(self.data.nodes) do
			self.data.start = id

			break
		end
	end

	self.errorText = nil

	NETWORK.dialogue.Save(self.id, self.data)
	NETWORK.gui.Notify(L("editorSaved", self.id), NETWORK.theme.accentSoft)
	NETWORK.gui.Notify(L("editorSavedHint"), NETWORK.theme.textDim)

	self.savedID = self.id

	NETWORK.dialogue.lastEdited = self.id

	if (file) then
		file.Write("network_lastdialogue.txt", self.id)
	end
end

function PANEL:GetNodeRect(id, node)
	local Sc = NETWORK.util.Scale
	local zoom = self.zoom
	local width = self.nodeWidth * zoom
	local height = (self.headerHeight + self.textHeight +
		#node.replies * self.rowHeight + Sc(6)) * zoom

	return node.x * zoom + self.offsetX, node.y * zoom + self.offsetY, width, height
end

function PANEL:ToCanvas(x, y)
	return (x - self.offsetX) / self.zoom, (y - self.offsetY) / self.zoom
end

function PANEL:SetZoom(zoom, anchorX, anchorY)
	local previous = self.zoom

	self.zoom = math.Clamp(zoom, 0.45, 1.8)

	if (!anchorX) then
		return
	end

	local scale = self.zoom / previous

	self.offsetX = anchorX - (anchorX - self.offsetX) * scale
	self.offsetY = anchorY - (anchorY - self.offsetY) * scale
end

function PANEL:OnMouseWheeled(delta)
	local x, y = self:CursorPos()

	if (x > self:GetWide() - self.sideWidth) then
		return
	end

	self:SetZoom(self.zoom + delta * 0.1, x, y)

	return true
end

function PANEL:GetHovered()
	local Sc = NETWORK.util.Scale
	local zoom = self.zoom
	local x, y = self:CursorPos()

	for id, node in pairs(self.data.nodes) do
		local nx, ny, width, height = self:GetNodeRect(id, node)
		local connectorX = nx + width + Sc(10) * zoom
		local replyY = ny + (self.headerHeight + self.textHeight) * zoom

		for index = 1, #node.replies do
			local centerY = replyY + self.rowHeight * zoom * 0.5

			if (math.abs(x - connectorX) <= Sc(16) * zoom and
				math.abs(y - centerY) <= Sc(16) * zoom) then
				return {type = "connector", node = id, index = index}
			end

			replyY = replyY + self.rowHeight * zoom
		end

		if (x < nx or x > nx + width or y < ny or y > ny + height) then
			continue
		end

		replyY = ny + (self.headerHeight + self.textHeight) * zoom

		for index = 1, #node.replies do
			if (y >= replyY and y <= replyY + self.rowHeight * zoom) then
				return {type = "reply", node = id, index = index}
			end

			replyY = replyY + self.rowHeight * zoom
		end

		return {type = "node", node = id}
	end
end

function PANEL:Select(target)
	self.selected = target

	self:BuildProperties()
end

function PANEL:OnMousePressed(code)
	local x, y = self:CursorPos()

	if (x > self:GetWide() - self.sideWidth) then
		return
	end

	if (code == MOUSE_RIGHT) then
		if (self.linking) then
			self.linking = nil

			return
		end

		self.panning = {x = x, y = y, offsetX = self.offsetX, offsetY = self.offsetY}

		self:MouseCapture(true)

		return
	end

	local target = self:GetHovered()

	if (self.linking) then
		if (target) then
			local node = self.data.nodes[self.linking.node]
			local reply = node and node.replies[self.linking.index]

			if (reply) then
				reply.to = target.node
				reply.exit = nil

				NETWORK.sound.Click()
			end
		end

		self.linking = nil

		self:BuildProperties()

		return
	end

	if (!target) then
		self:Select(nil)

		return
	end

	if (target.type == "connector") then
		self.linking = {node = target.node, index = target.index}

		self:Select({type = "reply", node = target.node, index = target.index})

		return
	end

	self:Select(target)

	if (target.type == "reply") then
		return
	end

	local node = self.data.nodes[target.node]

	self.dragging = {
		node = target.node,
		x = x - (node.x * self.zoom + self.offsetX),
		y = y - (node.y * self.zoom + self.offsetY)
	}

	self:MouseCapture(true)
end

function PANEL:OnMouseReleased()
	self.dragging = nil
	self.panning = nil

	self:MouseCapture(false)
end

function PANEL:Think()
	local x, y = self:CursorPos()

	if ((self.nextCursor or 0) < CurTime() and self.id != "") then
		self.nextCursor = CurTime() + 0.12

		local canvasX, canvasY = self:ToCanvas(x, y)

		NETWORK.dialogue.SendCursor(self.id, canvasX, canvasY)
	end

	if (self.panning) then
		self.offsetX = self.panning.offsetX + (x - self.panning.x)
		self.offsetY = self.panning.offsetY + (y - self.panning.y)
	elseif (self.dragging) then
		local node = self.data.nodes[self.dragging.node]

		if (node) then
			node.x = (x - self.dragging.x - self.offsetX) / self.zoom
			node.y = (y - self.dragging.y - self.offsetY) / self.zoom
		end
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		if (self.linking) then
			self.linking = nil

			return
		end

		self:Remove()
	end
end

function PANEL:AddLabel(text)
	local Sc = NETWORK.util.Scale
	local panel = self.properties:Add("DPanel")

	panel:Dock(TOP)
	panel:DockMargin(0, Sc(10), Sc(10), Sc(2))
	panel:SetTall(Sc(20))
	panel.Paint = function(self, width, height)
		draw.SimpleText(text, "nwChatSmall", Sc(8), math.Round(height * 0.5),
			ColorAlpha(NETWORK.theme.textDim, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return panel
end

function PANEL:AddEntry(value, callback, tall, bMultiline)
	local Sc = NETWORK.util.Scale
	local entry = self:Entry(self.properties, value, callback, bMultiline)

	entry:Dock(TOP)
	entry:DockMargin(0, 0, Sc(10), Sc(4))
	entry:SetTall(tall or Sc(32))

	return entry
end

function PANEL:AddButton(label, callback, color)
	local Sc = NETWORK.util.Scale
	local button = self:Button(self.properties, label, callback, color)

	button:Dock(TOP)
	button:DockMargin(0, Sc(6), Sc(10), 0)
	button:SetTall(Sc(32))

	return button
end

function PANEL:GetStartFactions(node)
	local list = {}

	for id, nodeID in pairs(self.data.starts or {}) do
		if (nodeID == node) then
			list[#list + 1] = id
		end
	end

	table.sort(list)

	return table.concat(list, ", ")
end

function PANEL:AddFactionField(label, get, set)
	self:AddLabel(label)
	self:AddEntry(table.concat(get() or {}, ", "), function(value)
		local list = {}

		for _, entry in ipairs(string.Explode(",", value)) do
			entry = string.Trim(string.lower(entry))

			if (entry != "" and NETWORK.factions.Get(entry)) then
				list[#list + 1] = entry
			end
		end

		set(#list > 0 and list or nil)
	end)

	local names = {}

	for _, id in ipairs(NETWORK.factions.order) do
		names[#names + 1] = id
	end

	self:AddLabel(L("editorFactionHint") .. " " .. table.concat(names, ", "))
end

function PANEL:BuildProperties()
	local Sc = NETWORK.util.Scale

	self.properties:Clear()

	local target = self.selected

	if (!target) then
		self:AddLabel(L("editorNothing"))

		return
	end

	local node = self.data.nodes[target.node]

	if (!node) then
		return
	end

	if (target.type == "node") then
		self:AddLabel(L("editorNodeID"))
		self:AddEntry(target.node, function(value)
			value = string.Trim(value)

			if (value == "" or value == target.node or self.data.nodes[value]) then
				return
			end

			self.data.nodes[value] = node
			self.data.nodes[target.node] = nil

			for _, other in pairs(self.data.nodes) do
				for _, reply in ipairs(other.replies) do
					if (reply.to == target.node) then
						reply.to = value
					end
				end
			end

			if (self.data.start == target.node) then
				self.data.start = value
			end

			target.node = value
		end)

		self:AddLabel(L("editorNodeText"))
		self:AddEntry(node.text, function(value)
			node.text = value
		end, Sc(110), true)

		self:AddButton(L("editorStartNode"), function()
			self.data.start = target.node
		end)

		self:AddLabel(L("editorStartForFaction"))
		self:AddEntry(self:GetStartFactions(target.node), function(value)
			self.data.starts = self.data.starts or {}

			for id, nodeID in pairs(self.data.starts) do
				if (nodeID == target.node) then
					self.data.starts[id] = nil
				end
			end

			for _, entry in ipairs(string.Explode(",", value)) do
				entry = string.Trim(string.lower(entry))

				if (entry != "" and NETWORK.factions.Get(entry)) then
					self.data.starts[entry] = target.node
				end
			end
		end)

		self:AddButton(L("editorAddReply"), function()
			node.replies[#node.replies + 1] = {text = L("editorNewReply")}

			self:BuildProperties()
		end)

		self:AddButton(L("editorDeleteNode"), function()
			self.data.nodes[target.node] = nil

			self:Select(nil)
		end, Color(226, 96, 84))

		return
	end

	local reply = node.replies[target.index]

	if (!reply) then
		return
	end

	self:AddLabel(L("editorReplyText"))
	self:AddEntry(reply.text, function(value)
		reply.text = value
	end, Sc(70), true)

	self:AddLabel(L("editorReplyTo"))
	self:AddEntry(reply.to or "", function(value)
		reply.to = string.Trim(value) != "" and string.Trim(value) or nil
	end)

	self:AddLabel(L("editorReplyQuest"))
	self:AddEntry(reply.quest or "", function(value)
		reply.quest = string.Trim(value) != "" and string.Trim(value) or nil
	end)

	self:AddLabel(L("editorReplyComplete"))
	self:AddEntry(reply.complete or "", function(value)
		reply.complete = string.Trim(value) != "" and string.Trim(value) or nil
	end)

	self:AddFactionField(L("editorReplyFactions"), function()
		return reply.factions
	end, function(list)
		reply.factions = list
	end)

	self:AddLabel(L("editorReplyUnlockItem"))
	self:AddEntry(reply.unlock and reply.unlock.id or "", function(value)
		value = string.Trim(value)

		if (value == "") then
			reply.unlock = nil

			return
		end

		reply.unlock = reply.unlock or {amount = 1, trader = ""}
		reply.unlock.id = value
	end)

	self:AddLabel(L("editorReplyUnlockAmount"))
	self:AddEntry(reply.unlock and reply.unlock.amount or 1, function(value)
		if (reply.unlock) then
			reply.unlock.amount = math.Clamp(math.Round(tonumber(value) or 1), 1, 99)
		end
	end)

	self:AddLabel(L("editorReplyUnlockTrader"))
	self:AddEntry(reply.unlock and reply.unlock.trader or "", function(value)
		if (reply.unlock) then
			reply.unlock.trader = string.Trim(value)
		end
	end)

	local function MakeNode(suffix, text, replyText)
		local base = (self.id != "" and self.id or "node") .. "_" .. suffix
		local id = base
		local index = 1

		while (self.data.nodes[id]) do
			index = index + 1
			id = base .. index
		end

		local source = self.data.nodes[target.node]

		self.data.nodes[id] = {
			x = (source and source.x or 0) + self.nodeWidth + NETWORK.util.Scale(80),
			y = (source and source.y or 0) + (target.index - 1) * NETWORK.util.Scale(60),
			text = text or "",
			replies = {{text = replyText or L("editorNewReply"), exit = true}}
		}

		reply.to = id
		reply.exit = nil

		return id
	end

	self:AddLabel(L("editorLinkTo"))

	self:AddButton(reply.to and (L("editorRelink") .. ": " .. reply.to) or
		L("editorLinkPick"), function()
		local entries = {}

		for id in pairs(self.data.nodes) do
			if (id != target.node) then
				entries[#entries + 1] = {value = id, label = id}
			end
		end

		table.sort(entries, function(a, b)
			return a.label < b.label
		end)

		NETWORK.gui.OpenNodeList(L("editorLinkPick"), entries, function(value)
			reply.to = value
			reply.exit = nil

			self:BuildProperties()
		end)
	end, COLOR_LINK)

	if (reply.to) then
		self:AddButton(L("editorUnlink"), function()
			reply.to = nil

			self:BuildProperties()
		end, Color(226, 96, 84))
	end

	self:AddLabel(L("editorQuestFlow"))

	self:AddButton(L("editorQuestGive"), function()
		local id = reply.quest

		if (!id) then
			id = NETWORK.gui.NextQuestID(self)

			self.data.quests = self.data.quests or {}
			self.data.quests[id] = {
				name = L("questEditor") .. " " .. id,
				description = "",
				objectives = {},
				rewards = {items = {}}
			}

			reply.quest = id
			reply.complete = nil
		end

		if (!reply.to) then
			MakeNode("taken", L("editorQuestTakenText"), L("editorQuestTakenReply"))
		end

		self:BuildProperties()

		NETWORK.gui.OpenQuestEditor(self, id)
	end, Color(240, 200, 90))

	self:AddButton(L("editorQuestTurnIn"), function()
		local id = reply.complete or reply.quest

		if (!id) then
			for questID in pairs(self.data.quests or {}) do
				id = questID

				break
			end
		end

		if (!id) then
			NETWORK.gui.Notify(L("editorQuestNoneYet"), NETWORK.theme.danger)

			return
		end

		reply.complete = id
		reply.quest = nil
		reply.text = reply.text != "" and reply.text or L("editorQuestTurnInReply")

		if (!reply.to) then
			MakeNode("done", L("editorQuestDoneText"), L("editorNewReply"))
		end

		self:BuildProperties()
	end, Color(120, 220, 140))

	self:AddButton(L("editorMakeNode"), function()
		MakeNode("next")

		self:Select({type = "node", node = reply.to})
	end, Color(126, 224, 250))

	self:AddButton(reply.exit and L("editorExitOn") or L("editorExitOff"), function()
		reply.exit = !reply.exit or nil

		self:BuildProperties()
	end)

	if (reply.quest or reply.complete) then
		self:AddButton(L("editorQuestEdit"), function()
			NETWORK.gui.OpenQuestEditor(self, reply.quest or reply.complete)
		end)
	else
		self:AddButton(L("editorQuestNew"), function()
			local index = 1

			while (self.data.quests["q" .. index]) do
				index = index + 1
			end

			local id = (self.id != "" and self.id or "quest") .. "_" .. index

			reply.quest = id

			self.data.quests[id] = {
				name = L("questEditor") .. " " .. index,
				description = "",
				objectives = {},
				rewards = {items = {}}
			}

			self:BuildProperties()

			NETWORK.gui.OpenQuestEditor(self, id)
		end, Color(240, 200, 90))
	end

	self:AddButton(L("editorDeleteReply"), function()
		table.remove(node.replies, target.index)

		self:Select({type = "node", node = target.node})
	end, Color(226, 96, 84))
end

function PANEL:PaintGrid(width, height)
	local Sc = NETWORK.util.Scale
	local step = Sc(34) * self.zoom

	surface.SetDrawColor(9, 12, 17, 255)
	surface.DrawRect(0, 0, width, height)

	if (step < 8) then
		return
	end

	surface.SetDrawColor(COLOR_GRID.r, COLOR_GRID.g, COLOR_GRID.b, 90)

	local dots = NETWORK.util.GetTexture("framework/pattern/dots.png", "noclamp smooth mips")

	if (dots) then
		NETWORK.util.DrawTiled(dots, 0, 0, width, height, step, step, self.offsetX % step,
			self.offsetY % step)
		draw.NoTexture()
	else
		local dot = math.max(Sc(2) * self.zoom, 1)

		for x = self.offsetX % step, width, step do
			for y = self.offsetY % step, height, step do
				surface.DrawRect(x, y, dot, dot)
			end
		end
	end

	surface.SetDrawColor(COLOR_GRID.r, COLOR_GRID.g, COLOR_GRID.b, 26)

	for x = self.offsetX % (step * 5), width, step * 5 do
		surface.DrawRect(x, 0, 1, height)
	end

	for y = self.offsetY % (step * 5), height, step * 5 do
		surface.DrawRect(0, y, width, 1)
	end
end

function PANEL:GetLinkProgress(key)
	self.linkProgress = self.linkProgress or {}

	if (!self.linkProgress[key]) then
		self.linkProgress[key] = 0
	end

	self.linkProgress[key] = math.Clamp(self.linkProgress[key] +
		FrameTime() * 3.2, 0, 1)

	return NETWORK.util.EaseOut(self.linkProgress[key])
end

function PANEL:PaintLink(fromX, fromY, toX, toY, color, key, bFocus)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local zoom = self.zoom
	local distance = math.max(math.abs(toX - fromX) * 0.55, Sc(70) * zoom)
	local thickness = math.max(Sc(bFocus and 5 or 4) * zoom, bFocus and 4 or 3)
	local tint = color or COLOR_LINK
	local progress = key and self:GetLinkProgress(key) or 1
	local segments = 30
	local points = {}

	for i = 0, segments do
		local t = (i / segments) * progress
		local inverse = 1 - t
		local x = inverse ^ 3 * fromX + 3 * inverse ^ 2 * t * (fromX + distance) +
			3 * inverse * t ^ 2 * (toX - distance) + t ^ 3 * toX
		local y = inverse ^ 3 * fromY + 3 * inverse ^ 2 * t * fromY +
			3 * inverse * t ^ 2 * toY + t ^ 3 * toY

		points[#points + 1] = {x = x, y = y}
	end

	if (#points < 2) then
		return
	end

	for i = 1, #points - 1 do
		util.DrawThickLine(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y,
			thickness + math.max(Sc(4) * zoom, 3), ColorAlpha(tint, 40))
	end

	for i = 1, #points - 1 do
		util.DrawThickLine(points[i].x, points[i].y, points[i + 1].x, points[i + 1].y,
			thickness, ColorAlpha(tint, 250))
	end

	local flow = (CurTime() * 0.55) % 1

	for offset = 0, 2 do
		local position = (flow + offset / 3) % 1
		local index = math.floor(position * (#points - 1)) + 1
		local point = points[math.Clamp(index, 1, #points)]

		util.DrawCircle(point.x, point.y, thickness * 0.85, ColorAlpha(Color(255, 240, 220),
			235), 12)
	end

	if (progress < 1) then
		return
	end

	local head = points[#points]
	local before = points[#points - 1] or points[1]
	local angle = math.atan2(head.y - before.y, head.x - before.x)
	local size = thickness * 2.6

	for step = 0, size do
		local width = (1 - step / size) * thickness * 2

		util.DrawThickLine(
			head.x - math.cos(angle) * step,
			head.y - math.sin(angle) * step,
			head.x - math.cos(angle) * (step + 1),
			head.y - math.sin(angle) * (step + 1),
			math.max(width, 1), tint)
	end
end

function PANEL:PaintNode(id, node)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local zoom = self.zoom
	local x, y, nodeWidth, nodeHeight = self:GetNodeRect(id, node)
	local headerHeight = self.headerHeight * zoom
	local textHeight = self.textHeight * zoom
	local rowHeight = self.rowHeight * zoom
	local radius = math.max(Sc(6) * zoom, 3)
	local bSelected = self.selected and self.selected.node == id
	local bStart = self.data.start == id
	local accent = bStart and Color(120, 220, 150) or COLOR_HEADER
	local font = zoom < 0.75 and "nwHudSmall" or "nwChatSmall"

	draw.RoundedBox(radius, x, y, nodeWidth, nodeHeight, Color(18, 42, 62, 250))

	draw.RoundedBoxEx(radius, x, y, nodeWidth, headerHeight,
		ColorAlpha(accent, 245), true, true, false, false)

	if (self.linking and self.linking.node != id) then
		local pulse = 140 + math.sin(RealTime() * 8) * 70

		surface.SetDrawColor(120, 230, 150, pulse)
		surface.DrawOutlinedRect(x - Sc(2), y - Sc(2), nodeWidth + Sc(4), nodeHeight + Sc(4),
			math.max(Sc(2) * zoom, 2))
	end

	if (bSelected) then
		local size = math.max(Sc(5) * zoom, 3)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 245)

		for _, corner in ipairs({
			{x - size, y - size}, {x + nodeWidth, y - size},
			{x - size, y + nodeHeight}, {x + nodeWidth, y + nodeHeight}
		}) do
			surface.DrawRect(corner[1], corner[2], size, size)
		end
	end

	draw.SimpleText(id, font, x + Sc(14) * zoom, y + headerHeight * 0.5,
		Color(10, 24, 36), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (bStart) then
		util.DrawCircle(x + nodeWidth - Sc(14) * zoom, y + headerHeight * 0.5,
			math.max(Sc(4) * zoom, 3), Color(10, 24, 36))
	end

	local text = node.text or ""

	draw.SimpleText(text != "" and ("\"" .. util.Truncate(text, 32) .. "\"") or
		L("editorEmptyLine"), font, x + Sc(16) * zoom,
		y + headerHeight + textHeight * 0.5,
		ColorAlpha(text != "" and Color(150, 220, 255) or NETWORK.theme.textFaint, 245),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local replyY = y + headerHeight + textHeight

	for index, reply in ipairs(node.replies) do
		local bReply = self.selected and self.selected.type == "reply" and
			self.selected.node == id and self.selected.index == index
		local centerY = replyY + rowHeight * 0.5

		draw.RoundedBox(math.max(Sc(5) * zoom, 3), x + Sc(7) * zoom, replyY + Sc(1) * zoom,
			nodeWidth - Sc(14) * zoom, rowHeight - Sc(3) * zoom,
			bReply and Color(38, 74, 104, 255) or Color(24, 52, 76, 245))

		draw.SimpleText("\"" .. util.Truncate(reply.text or "", 22) .. "\"", font,
			x + Sc(18) * zoom, centerY, ColorAlpha(Color(196, 232, 255), 245),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (reply.to and zoom > 0.65) then
			draw.SimpleText("→ " .. util.Truncate(reply.to, 10), "nwHudSmall",
				x + nodeWidth - Sc(26) * zoom, centerY, ColorAlpha(COLOR_LINK, 235),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		local cx = x + nodeWidth + Sc(10) * zoom
		local cursorX, cursorY = self:CursorPos()
		local bNear = math.abs(cursorX - cx) <= Sc(14) * zoom and
			math.abs(cursorY - centerY) <= Sc(14) * zoom
		local dot = math.max((bNear and Sc(7) or Sc(5)) * zoom, 4)

		util.DrawCircle(cx, centerY, dot + math.max(Sc(2) * zoom, 1),
			Color(10, 24, 36, 245))
		util.DrawCircle(cx, centerY, dot, ColorAlpha(COLOR_LINK, bNear and 255 or 225))

		if (!reply.to) then
			util.DrawCircle(cx, centerY, math.max(dot - Sc(2) * zoom, 1),
				Color(18, 42, 62, 250))
		end

		if (reply.quest or reply.complete) then
			draw.SimpleText(reply.quest and "+" or "!", "nwHudSmall",
				x + nodeWidth - Sc(12) * zoom, centerY, Color(240, 200, 90),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		replyY = replyY + rowHeight
	end

	util.DrawCircle(x, y + headerHeight * 0.5, math.max(Sc(3) * zoom, 2), COLOR_LINK)
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme

	self:PaintGrid(width, height)

	local zoom = self.zoom

	for id, node in pairs(self.data.nodes) do
		self:PaintNode(id, node)
	end

	local hovered = self:GetHovered()

	for id, node in pairs(self.data.nodes) do
		local x, y, nodeWidth = self:GetNodeRect(id, node)
		local replyY = y + (self.headerHeight + self.textHeight) * zoom

		for index, reply in ipairs(node.replies) do
			local target = reply.to and self.data.nodes[reply.to]

			if (target) then
				local tx, ty = self:GetNodeRect(reply.to, target)
				local bFocus = (hovered and hovered.node == id and
					hovered.index == index) or (self.selected and
					self.selected.node == id and self.selected.index == index)

				self:PaintLink(x + nodeWidth + Sc(10) * zoom,
					replyY + self.rowHeight * zoom * 0.5, tx,
					ty + self.headerHeight * zoom * 0.5,
					bFocus and Color(255, 214, 120) or nil, id .. index .. reply.to,
					bFocus)

				if (bFocus) then
					local tw, th = select(3, self:GetNodeRect(reply.to, target))

					surface.SetDrawColor(255, 214, 120, 235)
					surface.DrawOutlinedRect(tx - Sc(3), ty - Sc(3), tw + Sc(6),
						th + Sc(6), math.max(Sc(2), 2))

					local label = "→ " .. reply.to

					surface.SetFont("nwHudSmall")

					local labelWidth = surface.GetTextSize(label)

					surface.SetDrawColor(10, 24, 36, 240)
					surface.DrawRect(tx + tw * 0.5 - labelWidth * 0.5 - Sc(6),
						ty - Sc(22), labelWidth + Sc(12), Sc(16))

					draw.SimpleText(label, "nwHudSmall", tx + tw * 0.5, ty - Sc(14),
						Color(255, 214, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end

			replyY = replyY + self.rowHeight * zoom
		end
	end

	if (self.linking) then
		local node = self.data.nodes[self.linking.node]

		if (node) then
			local x, y, nodeWidth = self:GetNodeRect(self.linking.node, node)
			local replyY = y + (self.headerHeight + self.textHeight) * zoom +
				(self.linking.index - 1) * self.rowHeight * zoom +
				self.rowHeight * zoom * 0.5
			local cursorX, cursorY = self:CursorPos()

			self:PaintLink(x + nodeWidth + Sc(10) * zoom, replyY, cursorX, cursorY)
		end
	end

	NETWORK.gui.DrawEditorCursors(self)

	draw.RoundedBox(0, width - self.sideWidth, 0, self.sideWidth, height,
		Color(10, 18, 28, 250))

	util.DrawTextSpaced(util.Upper(L("editorProperties")), "nwTab",
		width - self.sideWidth + Sc(20), Sc(36), ColorAlpha(theme.text, 250), Sc(4),
		TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 14)
	surface.DrawRect(width - self.sideWidth, 0, 1, height)

	local bBadID = string.Trim(self.id or "") == ""
	local bBadName = string.Trim(self.data.name or "") == ""
	local flash = self.errorTime and
		math.Clamp(1 - (CurTime() - self.errorTime) / 2.5, 0, 1) or 0

	draw.SimpleText(L("editorFieldID"), "nwHudSmall", Sc(20), Sc(10),
		ColorAlpha(bBadID and theme.danger or theme.textFaint, 230), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(L("editorFieldName"), "nwHudSmall", Sc(200), Sc(10),
		ColorAlpha(bBadName and theme.danger or theme.textFaint, 230), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	if (flash > 0.01) then
		if (bBadID and IsValid(self.idEntry)) then
			local ex, ey = self.idEntry:GetPos()

			surface.SetDrawColor(theme.danger.r, theme.danger.g, theme.danger.b, 255 * flash)
			surface.DrawOutlinedRect(ex - 2, ey - 2, self.idEntry:GetWide() + 4,
				self.idEntry:GetTall() + 4, math.max(Sc(2), 1))
		end

		if (bBadName and IsValid(self.nameEntry)) then
			local ex, ey = self.nameEntry:GetPos()

			surface.SetDrawColor(theme.danger.r, theme.danger.g, theme.danger.b, 255 * flash)
			surface.DrawOutlinedRect(ex - 2, ey - 2, self.nameEntry:GetWide() + 4,
				self.nameEntry:GetTall() + 4, math.max(Sc(2), 1))
		end
	end

	if (self.errorText and flash > 0.01) then
		draw.SimpleText(self.errorText, "nwChatSmall", Sc(20), Sc(66),
			ColorAlpha(theme.danger, 250 * flash), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	if (table.Count(self.data.nodes) == 0) then
		local centerX = math.Round((width - self.sideWidth) * 0.5)
		local centerY = math.Round(height * 0.5)
		local lines = {L("editorEmpty1"), L("editorEmpty2"), L("editorEmpty3")}

		for i = 1, #lines do
			draw.SimpleText(lines[i], "nwChat", centerX, centerY + (i - 2) * Sc(28),
				ColorAlpha(theme.textFaint, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	local hint = self.linking and L("editorLinking") or L("editorHint")
	local hintColor = self.linking and COLOR_LINK or theme.textFaint

	draw.RoundedBox(Sc(6), Sc(14), height - Sc(40), Sc(880), Sc(30),
		Color(6, 12, 20, 235))

	draw.SimpleText(hint, "nwChatSmall", Sc(28), height - Sc(25),
		ColorAlpha(hintColor, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(math.Round(self.zoom * 100) .. "%", "nwChatSmall",
		width - self.sideWidth - Sc(24), height - Sc(25),
		ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (self.savedID) then
		draw.SimpleText(L("editorSavedAs", self.savedID), "nwChatSmall", Sc(910),
			height - Sc(25), ColorAlpha(Color(120, 220, 140), 240), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
end

vgui.Register("nwDialogueEditor", PANEL, "EditablePanel")

function NETWORK.gui.OpenDialogueEditor(id)
	NETWORK.gui.CloseWindows()

	if (!id or id == "") then
		id = NETWORK.dialogue.lastEdited

		if (!id and file.Exists("network_lastdialogue.txt", "DATA")) then
			id = string.Trim(file.Read("network_lastdialogue.txt", "DATA") or "")
		end

		if (id and id != "" and !NETWORK.dialogue.Get(id) and
			!NETWORK.dialogue.custom[id]) then
			id = nil
		end
	end

	local panel = vgui.Create("nwDialogueEditor")

	panel:Load(id)

	timer.Simple(0.3, function()
		if (IsValid(panel) and LocalPlayer():IsAdmin()) then
			NETWORK.gui.OpenTutorial("dialogue")
		end
	end)

	return panel
end
