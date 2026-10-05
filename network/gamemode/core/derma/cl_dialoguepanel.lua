local PANEL = {}

PANEL.cameraSpeed = 1.5

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.dialogue = self

	self.alpha = 0
	self.bClosing = false
	self.replies = {}
	self.lines = {}
	self.blend = 0
	self.target = 0
	self.holdUntil = 0
	self.playerHold = 0
	self.pendingNode = nil
	self.textTime = CurTime()

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
end

function PANEL:OnRemove()
	if (NETWORK.gui.dialogue == self) then
		NETWORK.gui.dialogue = nil
	end
end

function PANEL:Setup(entity)
	self.entity = entity
end

function PANEL:SetNode(payload)
	if (CurTime() < self.playerHold) then
		self.pendingNode = payload

		return
	end

	self:ApplyNode(payload)
end

function PANEL:SayReply(text)
	local Sc = NETWORK.util.Scale
	local client = LocalPlayer()

	self.bPlayerSpeaking = true
	self.name = client:GetCharacterName()
	self.text = text or ""
	self.lines = NETWORK.util.WrapText(self.text, "nwChat", Sc(760), 4)
	self.textTime = CurTime()

	for _, button in ipairs(self.replies) do
		if (IsValid(button)) then
			button:Remove()
		end
	end

	self.replies = {}

	local duration = 1 + math.Clamp(NETWORK.util.Length(self.text) / 40, 0, 2)

	self.target = 1
	self.holdUntil = CurTime() + duration
	self.playerHold = CurTime() + duration
end

function PANEL:ApplyNode(payload)
	local Sc = NETWORK.util.Scale

	self.bPlayerSpeaking = false
	self.pendingNode = nil
	self.name = payload.name or "?"
	self.text = payload.text or ""
	self.lines = NETWORK.util.WrapText(self.text, "nwChat", Sc(760), 6)
	self.textTime = CurTime()

	for _, button in ipairs(self.replies) do
		if (IsValid(button)) then
			button:Remove()
		end
	end

	self.replies = {}

	local list = {}

	for _, reply in ipairs(payload.replies or {}) do
		list[#list + 1] = reply
	end

	if (IsValid(self.entity) and self.entity:GetClass() == "nw_trader") then
		list[#list + 1] = {text = L("tradeOpen"), bTrade = true}
	end

	for index = #list, 1, -1 do
		local reply = list[index]

		if (reply.exit and !reply.bTrade) then
			table.remove(list, index)
		end
	end

	list[#list + 1] = {text = L("dialogueLeave"), bLeave = true}

	for index, reply in ipairs(list) do
		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button.hover = 0
		button.startTime = CurTime()
		button.index = reply.index or index
		button.label = reply.text
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end

		button.Paint = function(panel, width, height)
			local theme = NETWORK.theme
			local util = NETWORK.util
			local reveal = util.EaseOut(util.Stagger(panel.startTime, 0.05 + index * 0.06, 0.4))
			local hover = util.EaseInOut(panel.hover)
			local fade = reveal * self.alpha

			local tint = panel.bLeave and theme.danger or theme.combine
			local rowHeight = height - Sc(8)
			local radius = math.max(Sc(6), 4)
			local x = math.Round(hover * Sc(6) + (1 - reveal) * Sc(20))
			local rowWidth = width - Sc(10)

			draw.RoundedBox(radius, x, 0, rowWidth, rowHeight, Color(10, 11, 13, 225 * fade))

			if (hover > 0.01) then
				draw.RoundedBox(radius, x, 0, rowWidth, rowHeight, ColorAlpha(tint, 30 * hover * fade))
			end

			util.DrawRoundedBorder(x, 0, rowWidth, rowHeight, radius, math.max(Sc(1), 1),
				hover > 0.01 and ColorAlpha(tint, (26 + 180 * hover) * fade) or
				Color(255, 255, 255, 26 * fade))

			local badge = rowHeight - Sc(14)
			local badgeX = x + Sc(8) + math.floor(badge * 0.5)
			local middle = math.floor(rowHeight * 0.5)

			draw.RoundedBox(math.max(Sc(4), 3), x + Sc(8), middle - math.floor(badge * 0.5),
				badge, badge, ColorAlpha(tint, (36 + 120 * hover) * fade))

			draw.SimpleText(panel.bLeave and "×" or index, "nwInvKey", badgeX, middle,
				ColorAlpha(theme.text, 250 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			draw.SimpleText(panel.label, "nwChat", x + Sc(18) + badge, middle,
				ColorAlpha(panel.bLeave and theme.danger or theme.text, (210 + 45 * hover) * fade),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			if (hover > 0.01) then
				NETWORK.gui.DrawGlyph("chevron", x + rowWidth - Sc(28), middle - Sc(7), Sc(14),
					ColorAlpha(tint, 240 * hover * fade))
			end
		end
		button.bTrade = reply.bTrade
		button.bExit = reply.bExit
		button.bDanger = reply.bExit
		button.bLeave = reply.bLeave

		button.DoClick = function(panel)
			NETWORK.sound.Soft()

			if (panel.bLeave) then
				NETWORK.dialogue.Reply(255)

				self:Close()

				return
			end

			if (panel.bExit) then
				NETWORK.dialogue.Reply(0)

				self:Close()

				return
			end

			if (panel.bTrade) then
				NETWORK.trade.Request("open")
				NETWORK.dialogue.Reply(0)

				self:Close()

				return
			end

			self:SayReply(panel.label)

			NETWORK.dialogue.Reply(panel.index)
		end

		self.replies[index] = button
	end

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	if (!self.replies) then
		return
	end

	local Sc = NETWORK.util.Scale
	local rowHeight = Sc(50)
	local listWidth = Sc(760)
	local x = math.Round((width - listWidth) * 0.5)
	local y = height - Sc(96) - #self.replies * rowHeight

	self.replyX = x
	self.replyY = y
	self.replyWidth = listWidth

	for i = 1, #self.replies do
		self.replies[i]:SetSize(listWidth, rowHeight)
		self.replies[i]:SetPos(x, y + (i - 1) * rowHeight)
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)

	for _, button in ipairs(self.replies) do
		if (IsValid(button)) then
			button:SetMouseInputEnabled(false)
		end
	end

	gui.EnableScreenClicker(false)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 7)

	if (self.pendingNode and CurTime() >= self.playerHold) then
		self:ApplyNode(self.pendingNode)
	end

	if (self.target > 0 and CurTime() > self.holdUntil) then
		self.target = 0
	end

	self.blend = NETWORK.util.Approach(self.blend, self.target, self.cameraSpeed)

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		NETWORK.dialogue.Reply(0)

		self:Close()

		return
	end

	local slot

	if (key >= KEY_1 and key <= KEY_9) then
		slot = key - KEY_1 + 1
	elseif (key == KEY_0) then
		slot = 10
	elseif (key >= KEY_PAD_1 and key <= KEY_PAD_9) then
		slot = key - KEY_PAD_1 + 1
	elseif (key == KEY_PAD_0) then
		slot = 10
	end

	if (!slot) then
		return
	end

	local button = self.replies and self.replies[slot]

	if (IsValid(button) and button.DoClick) then
		button:DoClick()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = util.EaseOut(self.alpha)

	surface.SetDrawColor(0, 0, 0, 90 * alpha)
	surface.DrawRect(0, 0, width, height)

	local barHeight = Sc(70)
	local fadeHeight = Sc(90)

	surface.SetDrawColor(0, 0, 0, 240 * alpha)
	surface.DrawRect(0, 0, width, barHeight)
	surface.DrawRect(0, height - barHeight, width, barHeight)

	util.DrawVGradient(0, barHeight, width, fadeHeight, Color(0, 0, 0, 240 * alpha),
		Color(0, 0, 0, 0))
	util.DrawVGradient(0, height - barHeight - fadeHeight, width, fadeHeight,
		Color(0, 0, 0, 0), Color(0, 0, 0, 240 * alpha))

	local centerX = math.Round(width * 0.5)
	local tint = self.bPlayerSpeaking and theme.combineSoft or theme.combine
	local lines = self.lines or {}
	local lineHeight = Sc(26)
	local cardWidth = Sc(820)
	local cardHeight = #lines * lineHeight + Sc(44)
	local cardX = centerX - math.floor(cardWidth * 0.5)
	local cardBottom = (self.replyY or height - Sc(200)) - Sc(22)
	local cardY = cardBottom - cardHeight
	local switch = util.EaseOut(math.Clamp((CurTime() - self.textTime) / 0.3, 0, 1))

	cardY = cardY + math.Round((1 - switch) * Sc(10))

	util.DrawSoftLight(centerX, cardY + math.floor(cardHeight * 0.5), cardWidth * 1.3,
		cardHeight * 2.4, Color(0, 0, 0), 120 * alpha)

	local cardRadius = math.max(Sc(10), 6)

	util.DrawBlurRounded(self, cardX, cardY, cardWidth, cardHeight, cardRadius, 4 * alpha * switch)

	draw.RoundedBox(cardRadius, cardX, cardY, cardWidth, cardHeight,
		Color(8, 9, 10, 226 * alpha * switch))

	util.DrawRoundedBorder(cardX, cardY, cardWidth, cardHeight, cardRadius, math.max(Sc(1), 1),
		Color(255, 255, 255, 26 * alpha * switch))

	draw.RoundedBox(math.max(Sc(2), 2), cardX + Sc(10), cardY + Sc(18), math.max(Sc(3), 2),
		cardHeight - Sc(36), ColorAlpha(tint, 230 * alpha * switch))

	local name = self.name or ""

	surface.SetFont("nwInvName")

	local pillWidth = surface.GetTextSize(name) + Sc(28)
	local pillHeight = Sc(26)
	local pillX = cardX + Sc(24)
	local pillY = cardY - math.floor(pillHeight * 0.5)
	local pillRadius = math.max(Sc(6), 4)

	draw.RoundedBox(pillRadius, pillX, pillY, pillWidth, pillHeight, Color(10, 11, 13, 240 * alpha))
	draw.RoundedBox(pillRadius, pillX, pillY, pillWidth, pillHeight, ColorAlpha(tint, 34 * alpha))
	util.DrawRoundedBorder(pillX, pillY, pillWidth, pillHeight, pillRadius, math.max(Sc(1), 1),
		ColorAlpha(tint, 190 * alpha))
	draw.SimpleText(name, "nwInvName", pillX + Sc(14), pillY + math.floor(pillHeight * 0.5),
		ColorAlpha(theme.text, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local reveal = math.Clamp((CurTime() - self.textTime) * 34, 0, 1000)
	local shown = 0
	local lineY = cardY + Sc(30)
	local lastX, lastY
	local bTyping = false

	for i = 1, #lines do
		local line = lines[i]
		local length = NETWORK.util.Length(line)
		local visible = math.Clamp(reveal - shown, 0, length)

		shown = shown + length

		if (visible <= 0) then
			break
		end

		local part = NETWORK.util.Sub(line, 1, math.floor(visible))

		draw.SimpleText(part, "nwChat", cardX + Sc(28), lineY,
			ColorAlpha(self.bPlayerSpeaking and theme.combineSoft or theme.text, 250 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetFont("nwChat")

		lastX = cardX + Sc(28) + surface.GetTextSize(part)
		lastY = lineY
		bTyping = visible < length

		lineY = lineY + lineHeight
	end

	if (lastX and (bTyping or math.floor(RealTime() * 2) % 2 == 0)) then
		surface.SetDrawColor(tint.r, tint.g, tint.b, 220 * alpha)
		surface.DrawRect(lastX + Sc(3), lastY - Sc(8), math.max(Sc(2), 2), Sc(16))
	end
end

vgui.Register("nwDialoguePanel", PANEL, "EditablePanel")

function NETWORK.gui.OpenDialogue(entity)
	NETWORK.gui.CloseWindows()

	local panel = vgui.Create("nwDialoguePanel")

	panel:Setup(entity)

	return panel
end

local function GetHead(entity, fallback)
	local bone = entity:LookupBone("ValveBiped.Bip01_Head1")

	if (bone) then
		local position = entity:GetBonePosition(bone)

		if (position and position != vector_origin) then
			return position
		end
	end

	return entity:GetPos() + Vector(0, 0, fallback or 62)
end

NETWORK.view.Register("dialogue", 10, function(client, view)
	local panel = NETWORK.gui.dialogue

	if (!IsValid(panel) or !IsValid(panel.entity)) then
		return
	end

	local entity = panel.entity
	local npcHead = entity:GetPos() + Vector(0, 0, 62)
	local playerHead = client:GetPos() + Vector(0, 0, 62)
	local blend = NETWORK.util.EaseInOut(NETWORK.util.EaseInOut(panel.blend))
	local npcForward = entity:GetForward()
	local toPlayer = playerHead - npcHead

	toPlayer.z = 0
	toPlayer:Normalize()

	if (npcForward:Dot(toPlayer) < 0.2) then
		npcForward = toPlayer
	end

	npcForward.z = 0
	npcForward:Normalize()

	local npcRight = npcForward:Angle():Right()
	local npcShot = npcHead + npcForward * 58 + npcRight * 26 + Vector(0, 0, 4)
	local playerForward = -toPlayer
	local playerRight = playerForward:Angle():Right()
	local playerShot = playerHead + playerForward * 54 + playerRight * 26 + Vector(0, 0, 4)
	local position = LerpVector(blend, npcShot, playerShot)
	local look = LerpVector(blend, npcHead, playerHead)
	local time = CurTime()
	local shake = Vector(
		math.sin(time * 1.13) * 0.9 + math.sin(time * 2.71) * 0.35,
		math.cos(time * 0.94) * 0.9 + math.cos(time * 3.13) * 0.3,
		math.sin(time * 1.47) * 0.6
	)

	position = position + shake

	local viewAngles = (look - position):Angle()

	viewAngles.p = viewAngles.p + math.sin(time * 1.31) * 0.28
	viewAngles.y = viewAngles.y + math.cos(time * 1.07) * 0.32
	viewAngles.r = math.sin(time * 0.71) * 0.55

	view.origin = position
	view.angles = viewAngles
	view.fov = 50 + math.sin(time * 0.6) * 0.6
	view.drawviewer = true

	return "stop"
end)

local dialogueAngles

hook.Add("CreateMove", "nwDialogueLook", function(cmd)
	local panel = NETWORK.gui.dialogue

	if (!IsValid(panel) or !IsValid(panel.entity)) then
		dialogueAngles = nil

		return
	end

	if (!dialogueAngles) then
		local client = LocalPlayer()
		local toNPC = (panel.entity:GetPos() + Vector(0, 0, 60)) - client:EyePos()

		dialogueAngles = toNPC:Angle()
		dialogueAngles.r = 0
	end

	cmd:SetViewAngles(dialogueAngles)
	cmd:SetMouseX(0)
	cmd:SetMouseY(0)
end)

hook.Add("InputMouseApply", "nwDialogueLook", function(cmd)
	if (dialogueAngles and IsValid(NETWORK.gui.dialogue)) then
		cmd:SetViewAngles(dialogueAngles)

		return true
	end
end)

hook.Add("HUDShouldDraw", "nwDialogue", function(element)
	if (IsValid(NETWORK.gui.dialogue) and element != "CHudChat") then
		return false
	end
end)

local CONFIG = {}

function CONFIG:Init()
	local Sc = NETWORK.util.Scale

	self.alpha = 0

	self:SetSize(math.min(Sc(520), math.Round(ScrW() * 0.86)),
		math.min(Sc(510), math.Round(ScrH() * 0.86)))
	self:Center()
	self:MakePopup()

	self.fields = {}

	self.save = self:Add("nwActionButton")
	self.save:SetLabel(L("zoneSave"))
	self.save:SetPrimary(true)
	self.save.DoClick = function()
		if (IsValid(self.entity)) then
			NETWORK.gui.SendNPCConfig(self.entity, {
				name = self.fields.name:GetValue(),
				model = self.fields.model:GetValue(),
				sequence = self.sequence or "",
				dialogue = self.dialogue or "",
				factions = self.fields.factions:GetValue()
			})
		end

		self:Remove()
	end
end

function CONFIG:AddField(key, value)
	local Sc = NETWORK.util.Scale
	local entry = self:Add("DTextEntry")

	entry:SetFont("nwChatSmall")
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
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
	local Sc = NETWORK.util.Scale

	self.entity = entity
	self.dialogue = entity:GetDialogue()

	self:AddField("name", entity:GetNPCName())
	self:AddField("model", entity:GetNPCModel())
	self:AddField("factions", entity:GetFactions())

	self.sequence = entity:GetNPCSequence()

	local sequences = {{value = "", label = "npcNoSequence"}}

	for _, data in ipairs(entity:GetSequenceList() or {}) do
		sequences[#sequences + 1] = {value = data, label = data}
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

	local options = {{value = "", label = "npcNoDialogue"}}

	for _, data in ipairs(NETWORK.dialogue.GetAll()) do
		options[#options + 1] = {value = data.id, label = (data.name or data.id) ..
			"  [" .. data.id .. "]"}
	end

	self.choice = self:Add("nwOptChoice")
	self.choice:Setup(function()
		return self.dialogue or ""
	end, function(value)
		self.dialogue = value
	end, options, false)

	self:InvalidateLayout(true)
end

function CONFIG:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local y = Sc(74)

	for _, key in ipairs({"name", "model", "factions"}) do
		local field = self.fields[key]

		if (IsValid(field)) then
			field:SetPos(Sc(20), y)
			field:SetSize(width - Sc(40), Sc(32))
		end

		y = y + Sc(64)
	end

	if (IsValid(self.sequenceChoice)) then
		self.sequenceChoice:SetPos(Sc(20), y)
		self.sequenceChoice:SetSize(width - Sc(40), Sc(32))
	end

	y = y + Sc(64)

	if (IsValid(self.choice)) then
		self.choice:SetPos(Sc(20), y)
		self.choice:SetSize(width - Sc(40), Sc(32))
	end

	if (IsValid(self.save)) then
		self.save:SetPos(Sc(20), height - Sc(52))
		self.save:SetSize(width - Sc(40), Sc(40))
	end
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
	util.DrawTitleBar(0, 0, width, Sc(42), L("npcConfig"), self.alpha)

	local labels = {L("npcName"), L("npcModel"), L("npcFactions"), L("npcSequence"),
		L("npcDialogue")}
	local y = Sc(60)

	for i = 1, #labels do
		draw.SimpleText(labels[i], "nwChatSmall", Sc(20), y,
			ColorAlpha(theme.textDim, 230 * self.alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + Sc(64)
	end
end

vgui.Register("nwNPCConfig", CONFIG, "EditablePanel")

function NETWORK.gui.OpenNPCConfig(entity)
	if (!IsValid(entity)) then
		return
	end

	local panel = vgui.Create("nwNPCConfig")

	panel:Setup(entity)

	return panel
end
