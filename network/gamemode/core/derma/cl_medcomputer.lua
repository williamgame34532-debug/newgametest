local PANEL = {}

local XP = {
	titleTop = Color(0, 88, 238),
	titleBottom = Color(0, 60, 180),
	titleText = Color(255, 255, 255),
	frame = Color(0, 61, 194),
	face = Color(236, 233, 216),
	faceDark = Color(212, 208, 200),
	white = Color(255, 255, 255),
	text = Color(0, 0, 0),
	textDim = Color(90, 90, 90),
	link = Color(0, 51, 153),
	good = Color(58, 138, 58),
	bad = Color(196, 52, 52),
	tabOn = Color(255, 255, 255),
	tabOff = Color(240, 237, 226),
	shadow = Color(0, 0, 0, 120)
}

local function XPButton(parent, label, callback, bMain)
	local button = parent:Add("DButton")

	button:SetText("")
	button:SetTall(24)
	button.DoClick = callback
	button.Paint = function(panel, width, height)
		local bHover = panel:IsHovered()

		surface.SetDrawColor(XP.face)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(XP.white)
		surface.DrawRect(0, 0, width, 1)
		surface.DrawRect(0, 0, 1, height)

		surface.SetDrawColor(XP.faceDark)
		surface.DrawRect(0, height - 1, width, 1)
		surface.DrawRect(width - 1, 0, 1, height)

		surface.SetDrawColor(bHover and Color(240, 170, 60) or Color(0, 60, 116))
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		if (bMain) then
			surface.SetDrawColor(0, 60, 116, 40)
			surface.DrawOutlinedRect(2, 2, width - 4, height - 4, 1)
		end

		draw.SimpleText(label, "nwHudSmall", width * 0.5, height * 0.5, XP.text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	return button
end

local function XPEntry(parent, placeholder, bMulti)
	local entry = parent:Add("DTextEntry")

	entry:SetFont("nwHudSmall")
	entry:SetDrawLanguageID(false)
	entry:SetPaintBackground(false)
	entry:SetTextColor(XP.text)
	entry:SetCursorColor(XP.text)
	entry:SetHighlightColor(Color(49, 106, 197))
	entry:SetMultiline(bMulti or false)
	entry:SetTall(bMulti and 110 or 24)
	entry:SetUpdateOnType(true)
	entry.Paint = function(panel, width, height)
		surface.SetDrawColor(XP.white)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(127, 157, 185)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		if (panel:GetValue() == "" and !panel:HasFocus()) then
			draw.SimpleText(placeholder, "nwHudSmall", 6, bMulti and 12 or height * 0.5,
				XP.textDim, TEXT_ALIGN_LEFT, bMulti and TEXT_ALIGN_TOP or TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(XP.text, Color(49, 106, 197), XP.text)
	end

	return entry
end

local function XPLabel(parent, text, bold)
	local label = parent:Add("DLabel")

	label:SetText(text)
	label:SetFont(bold and "nwField" or "nwHudSmall")
	label:SetTextColor(XP.text)
	label:SizeToContents()

	return label
end

function PANEL:Init()
	if (IsValid(NETWORK.gui.medComputer)) then
		NETWORK.gui.medComputer:Remove()
	end

	NETWORK.gui.medComputer = self

	local Sc = NETWORK.util.Scale

	self:SetSize(math.min(Sc(760), ScrW() - 80), math.min(Sc(540), ScrH() - 80))
	self:Center()
	self:MakePopup()

	self.titleHeight = 30
	self.tabHeight = 26
	self.records = {}
	self.tab = "patients"

	local close = self:Add("DButton")

	close:SetText("")
	close:SetSize(21, 21)
	close.DoClick = function()
		self:Remove()
	end
	close.Paint = function(panel, width, height)
		surface.SetDrawColor(panel:IsHovered() and Color(230, 90, 60) or Color(214, 62, 32))
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(255, 255, 255, 180)
		surface.DrawOutlinedRect(0, 0, width, height, 1)

		draw.SimpleText("✕", "nwHudSmall", width * 0.5, height * 0.5 - 1, XP.white,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	self.close = close

	self.body = self:Add("EditablePanel")

	self:BuildTabs()
	self:SetTab("patients")
end

function PANEL:BuildTabs()
	self.tabs = {}

	local list = {
		{id = "patients", name = L("medTabPatients")},
		{id = "record", name = L("medTabRecord")},
		{id = "document", name = L("medTabDocument")},
		{id = "letter", name = L("medTabLetter")}
	}

	for index, data in ipairs(list) do
		local tab = self:Add("DButton")

		tab:SetText("")
		tab.id = data.id
		tab.DoClick = function()
			self:SetTab(data.id)
		end
		tab.Paint = function(panel, width, height)
			local bOn = self.tab == data.id

			surface.SetDrawColor(bOn and XP.tabOn or XP.tabOff)
			surface.DrawRect(0, bOn and 0 or 2, width, height)

			surface.SetDrawColor(145, 155, 156)
			surface.DrawOutlinedRect(0, bOn and 0 or 2, width, height + (bOn and 2 or 0), 1)

			if (bOn) then
				surface.SetDrawColor(XP.tabOn)
				surface.DrawRect(1, height - 1, width - 2, 2)

				surface.SetDrawColor(255, 200, 60)
				surface.DrawRect(1, 0, width - 2, 2)
			end

			draw.SimpleText(data.name, "nwHudSmall", width * 0.5, height * 0.5 + (bOn and 0 or 1),
				XP.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		self.tabs[#self.tabs + 1] = tab
	end
end

function PANEL:SetTab(id)
	self.tab = id
	self.body:Clear()

	if (id == "patients") then
		self:BuildPatients()
	elseif (id == "record") then
		self:BuildRecord()
	elseif (id == "document") then
		self:BuildDocument()
	elseif (id == "letter") then
		self:BuildLetter()
	end

	self:InvalidateLayout(true)
end

function PANEL:BuildPatients()
	local body = self.body

	local search = XPEntry(body, L("medSearchHint"))

	search:Dock(TOP)
	search:DockMargin(10, 10, 10, 6)
	search.OnEnter = function(panel)
		net.Start("nwMedComputer")
			net.WriteString(panel:GetValue())
		net.SendToServer()
	end

	local hint = XPLabel(body, L("medSearchEnter"))

	hint:SetTextColor(XP.textDim)
	hint:Dock(TOP)
	hint:DockMargin(12, 0, 10, 6)

	local list = body:Add("DScrollPanel")

	list:Dock(FILL)
	list:DockMargin(10, 0, 10, 10)
	list.Paint = function(panel, width, height)
		surface.SetDrawColor(XP.white)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(127, 157, 185)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end

	self.list = list

	self:FillRecords()
end

function PANEL:FillRecords()
	if (!IsValid(self.list)) then
		return
	end

	self.list:Clear()

	if (#self.records == 0) then
		local empty = XPLabel(self.list, L("medNoRecords"))

		empty:SetTextColor(XP.textDim)
		empty:Dock(TOP)
		empty:DockMargin(8, 8, 8, 8)

		return
	end

	for index, row in ipairs(self.records) do
		local item = self.list:Add("EditablePanel")

		item:Dock(TOP)
		item:SetTall(44)
		item.Paint = function(panel, width, height)
			surface.SetDrawColor(index % 2 == 0 and Color(245, 245, 245) or XP.white)
			surface.DrawRect(0, 0, width, height)

			draw.SimpleText(row.name or "?", "nwField", 8, 12, XP.link, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			draw.SimpleText((row.patient != row.name and row.patient or ""), "nwHudSmall",
				width - 8, 12, XP.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			draw.SimpleText(row.diagnosis or "", "nwHudSmall", 8, 31, XP.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText((row.doctor or "") .. " · " ..
				os.date("%d.%m %H:%M", tonumber(row.time) or 0), "nwHudSmall", width - 8, 31,
				XP.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			surface.SetDrawColor(220, 220, 220)
			surface.DrawRect(0, height - 1, width, 1)
		end
	end
end

function PANEL:BuildRecord()
	local body = self.body

	local caption = XPLabel(body, L("medRecordTitle"), true)

	caption:Dock(TOP)
	caption:DockMargin(10, 10, 10, 8)

	local name = XPEntry(body, L("medFieldName"))

	name:Dock(TOP)
	name:DockMargin(10, 0, 10, 6)

	local diagnosis = XPEntry(body, L("medFieldDiagnosis"), true)

	diagnosis:Dock(TOP)
	diagnosis:DockMargin(10, 0, 10, 10)

	local save = XPButton(body, L("medSave"), function()
		if (string.Trim(name:GetValue()) == "" or string.Trim(diagnosis:GetValue()) == "") then
			return NETWORK.gui.Notify(L("medFillBoth"), NETWORK.theme.warning)
		end

		net.Start("nwMedComputerAdd")
			net.WriteString(name:GetValue())
			net.WriteString(diagnosis:GetValue())
		net.SendToServer()

		name:SetValue("")
		diagnosis:SetValue("")

		self:SetTab("patients")
	end, true)

	save:Dock(TOP)
	save:DockMargin(10, 0, 10, 0)
	save:SetWide(160)
end

function PANEL:BuildDocument()
	local body = self.body

	local caption = XPLabel(body, L("medDocTitle"), true)

	caption:Dock(TOP)
	caption:DockMargin(10, 10, 10, 8)

	local holder = XPEntry(body, L("medFieldHolder"))

	holder:Dock(TOP)
	holder:DockMargin(10, 0, 10, 6)

	local text = XPEntry(body, L("medFieldConclusion"), true)

	text:Dock(TOP)
	text:DockMargin(10, 0, 10, 10)

	local issue = XPButton(body, L("medIssue"), function()
		if (string.Trim(holder:GetValue()) == "") then
			return NETWORK.gui.Notify(L("medFillHolder"), NETWORK.theme.warning)
		end

		net.Start("nwMedComputerDoc")
			net.WriteString(holder:GetValue())
			net.WriteString(text:GetValue())
		net.SendToServer()

		holder:SetValue("")
		text:SetValue("")
	end, true)

	issue:Dock(TOP)
	issue:DockMargin(10, 0, 10, 0)
end

function PANEL:BuildLetter()
	local body = self.body

	local caption = XPLabel(body, L("medLetterTitle"), true)

	caption:Dock(TOP)
	caption:DockMargin(10, 10, 10, 8)

	local to = XPEntry(body, L("medFieldTo"))

	to:Dock(TOP)
	to:DockMargin(10, 0, 10, 6)

	local subject = XPEntry(body, L("medFieldSubject"))

	subject:Dock(TOP)
	subject:DockMargin(10, 0, 10, 6)

	local letter = XPEntry(body, L("medFieldBody"), true)

	letter:Dock(TOP)
	letter:DockMargin(10, 0, 10, 10)

	local send = XPButton(body, L("medSend"), function()
		if (string.Trim(to:GetValue()) == "" or string.Trim(letter:GetValue()) == "") then
			return NETWORK.gui.Notify(L("medFillLetter"), NETWORK.theme.warning)
		end

		net.Start("nwMedComputerLetter")
			net.WriteString(to:GetValue())
			net.WriteString(subject:GetValue())
			net.WriteString(letter:GetValue())
		net.SendToServer()

		to:SetValue("")
		subject:SetValue("")
		letter:SetValue("")
	end, true)

	send:Dock(TOP)
	send:DockMargin(10, 0, 10, 0)

	local call = XPButton(body, L("medCallCP"), function()
		net.Start("nwMedComputerCall")
			net.WriteString(subject:GetValue())
		net.SendToServer()
	end)

	call:Dock(TOP)
	call:DockMargin(10, 8, 10, 0)
end

function PANEL:PerformLayout(width, height)
	if (IsValid(self.close)) then
		self.close:SetPos(width - 26, 5)
	end

	local x = 8

	for _, tab in ipairs(self.tabs or {}) do
		tab:SetSize(110, self.tabHeight)
		tab:SetPos(x, self.titleHeight + 8)

		x = x + 110 + 2
	end

	self.body:SetPos(6, self.titleHeight + 8 + self.tabHeight)
	self.body:SetSize(width - 12, height - self.titleHeight - self.tabHeight - 14)
end

function PANEL:Paint(width, height)

	draw.RoundedBox(6, 4, 6, width, height, XP.shadow)

	draw.RoundedBoxEx(8, 0, 0, width, height, XP.frame, true, true, false, false)

	NETWORK.util.DrawVGradient(2, 2, width - 4, self.titleHeight - 2, XP.titleTop, XP.titleBottom)

	draw.SimpleText(L("medWindowTitle"), "nwField", 12, self.titleHeight * 0.5 + 1,
		Color(0, 0, 0, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(L("medWindowTitle"), "nwField", 11, self.titleHeight * 0.5,
		XP.titleText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(XP.face)
	surface.DrawRect(3, self.titleHeight, width - 6, height - self.titleHeight - 3)

	local bodyY = self.titleHeight + 8 + self.tabHeight

	surface.SetDrawColor(XP.tabOn)
	surface.DrawRect(6, bodyY, width - 12, height - bodyY - 6)

	surface.SetDrawColor(145, 155, 156)
	surface.DrawOutlinedRect(6, bodyY, width - 12, height - bodyY - 6, 1)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Remove()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.medComputer == self) then
		NETWORK.gui.medComputer = nil
	end
end

vgui.Register("nwMedComputer", PANEL, "EditablePanel")

net.Receive("nwMedComputer", function()
	local panel = vgui.Create("nwMedComputer")

	net.Start("nwMedComputer")
		net.WriteString("")
	net.SendToServer()
end)

net.Receive("nwMedComputerList", function()
	local rows = NETWORK.util.ReadTable() or {}
	local panel = NETWORK.gui.medComputer

	if (IsValid(panel)) then
		panel.records = rows
		panel:FillRecords()
	end
end)

net.Receive("nwMailList", function()
	local box = net.ReadEntity()
	local letters = NETWORK.util.ReadTable() or {}

	if (IsValid(NETWORK.gui.mailbox)) then
		NETWORK.gui.mailbox:Remove()
	end

	local Sc = NETWORK.util.Scale
	local frame = vgui.Create("EditablePanel")

	NETWORK.gui.mailbox = frame

	frame:SetSize(math.min(Sc(520), ScrW() - 80), math.min(Sc(460), ScrH() - 80))
	frame:Center()
	frame:MakePopup()
	frame.Paint = function(panel, width, height)
		draw.RoundedBox(6, 4, 6, width, height, XP.shadow)
		draw.RoundedBoxEx(8, 0, 0, width, height, XP.frame, true, true, false, false)

		NETWORK.util.DrawVGradient(2, 2, width - 4, 28, XP.titleTop, XP.titleBottom)

		draw.SimpleText(L("mailWindowTitle", box:GetOwnerName()), "nwField", 11, 15,
			XP.titleText, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(XP.face)
		surface.DrawRect(3, 30, width - 6, height - 33)
	end
	frame.OnKeyCodePressed = function(panel, key)
		if (key == KEY_ESCAPE) then
			panel:Remove()
		end
	end

	local close = frame:Add("DButton")

	close:SetText("")
	close:SetSize(21, 21)
	close:SetPos(frame:GetWide() - 26, 5)
	close.DoClick = function()
		frame:Remove()
	end
	close.Paint = function(panel, width, height)
		surface.SetDrawColor(panel:IsHovered() and Color(230, 90, 60) or Color(214, 62, 32))
		surface.DrawRect(0, 0, width, height)
		draw.SimpleText("✕", "nwHudSmall", width * 0.5, height * 0.5 - 1, XP.white,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local list = frame:Add("DScrollPanel")

	list:SetPos(10, 40)
	list:SetSize(frame:GetWide() - 20, frame:GetTall() - 50)
	list.Paint = function(panel, width, height)
		surface.SetDrawColor(XP.white)
		surface.DrawRect(0, 0, width, height)
		surface.SetDrawColor(127, 157, 185)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end

	if (#letters == 0) then
		local empty = XPLabel(list, L("mailEmpty"))

		empty:SetTextColor(XP.textDim)
		empty:Dock(TOP)
		empty:DockMargin(8, 8, 8, 8)
	end

	for _, letter in ipairs(letters) do
		local item = list:Add("EditablePanel")
		local lines = NETWORK.util.WrapText(letter.body or "", "nwHudSmall",
			list:GetWide() - 30, 12)

		item:Dock(TOP)
		item:SetTall(48 + #lines * 15)
		item.Paint = function(panel, width, height)
			draw.SimpleText(letter.subject != "" and letter.subject or L("mailNoSubject"),
				"nwField", 8, 12, XP.link, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(L("mailFrom", letter.sender or "?") .. " · " ..
				os.date("%d.%m %H:%M", tonumber(letter.time) or 0), "nwHudSmall", width - 8,
				12, XP.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			for index, line in ipairs(lines) do
				draw.SimpleText(line, "nwHudSmall", 8, 30 + (index - 1) * 15, XP.text,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			surface.SetDrawColor(220, 220, 220)
			surface.DrawRect(0, height - 1, width, 1)
		end

		local remove = XPButton(item, L("mailDelete"), function()
			net.Start("nwMailDelete")
				net.WriteUInt(tonumber(letter.id) or 0, 32)
				net.WriteEntity(box)
			net.SendToServer()
		end)

		remove:SetSize(90, 20)
		remove:SetPos(list:GetWide() - 110, item:GetTall() - 26)
	end
end)
