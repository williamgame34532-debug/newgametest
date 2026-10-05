NETWORK.board = NETWORK.board or {}

local B = NETWORK.board

B.titleMax = 48
B.textMax = 700
B.range = 160

if (SERVER) then
	util.AddNetworkString("nwBoardOpen")
	util.AddNetworkString("nwBoardPin")
	util.AddNetworkString("nwBoardRemove")
	util.AddNetworkString("nwNoticeForm")
	util.AddNetworkString("nwNoticeFill")
	util.AddNetworkString("nwNoticeView")

	local function FindItem(client, item)
		local state = NETWORK.inventory.GetState(client)

		for index, other in pairs(state.items) do
			if (other == item) then
				return index
			end
		end
	end

	function B.OpenForm(client, item)
		client.nwNoticeItem = item

		net.Start("nwNoticeForm")
		net.Send(client)
	end

	net.Receive("nwNoticeFill", function(_, client)
		local title = NETWORK.util.Sanitise(net.ReadString() or "", B.titleMax)
		local text = NETWORK.util.Sanitise(net.ReadString() or "", B.textMax, true)
		local item = client.nwNoticeItem

		client.nwNoticeItem = nil

		if (!istable(item) or item.id != "notice_form" or !FindItem(client, item)) then
			return
		end

		if (title == "" or text == "") then
			return NETWORK.notice.Send(client, "noticeEmpty", "warn")
		end

		local data = {
			title = title,
			text = text,
			author = client:GetCharacterName(),
			date = os.date("%d.%m.%Y %H:%M")
		}

		if ((item.amount or 1) > 1) then
			item.amount = item.amount - 1

			if (!NETWORK.inventory.Give(client, "notice", 1, data)) then
				item.amount = item.amount + 1

				return NETWORK.notice.Send(client, "deployNoRoom", "bad")
			end
		else
			item.id = "notice"
			item.amount = 1
			item.data = data
		end

		NETWORK.inventory.Sync(client)
		NETWORK.notice.Send(client, "noticeFilled", "good")
	end)

	function B.ViewItem(client, item)
		net.Start("nwNoticeView")
			NETWORK.util.WriteTable(item.data or {})
		net.Send(client)
	end

	function B.CanRemove(client)
		return client:IsAdmin() or NETWORK.factions.IsAlliance(client)
	end

	function B.Open(client, entity)
		if (!IsValid(entity) or entity:GetClass() != "nw_board") then
			return
		end

		local own = {}
		local state = NETWORK.inventory.GetState(client)

		for index, item in pairs(state.items) do
			if (istable(item) and item.id == "notice") then
				own[#own + 1] = {index = index, title = (item.data or {}).title or "?"}
			end
		end

		net.Start("nwBoardOpen")
			net.WriteEntity(entity)
			NETWORK.util.WriteTable({
				notices = entity.notices or {},
				own = own,
				bCanRemove = B.CanRemove(client)
			})
		net.Send(client)
	end

	local function Check(client, entity)
		return IsValid(entity) and entity:GetClass() == "nw_board" and
			client:HasCharacter() and client:GetPos():Distance(entity:GetPos()) <= B.range
	end

	net.Receive("nwBoardPin", function(_, client)
		local entity = net.ReadEntity()
		local index = net.ReadUInt(8)

		if (!Check(client, entity)) then
			return
		end

		local state = NETWORK.inventory.GetState(client)
		local item = state.items[index]

		if (!istable(item) or item.id != "notice") then
			return
		end

		entity.notices = entity.notices or {}

		if (#entity.notices >= (entity.maxNotices or 12)) then
			table.remove(entity.notices, 1)
		end

		local data = item.data or {}

		entity.notices[#entity.notices + 1] = {
			title = data.title or "?",
			text = data.text or "",
			author = data.author or client:GetCharacterName(),
			date = data.date or os.date("%d.%m.%Y %H:%M"),
			cid = client:GetCharacterID()
		}

		if ((item.amount or 1) > 1) then
			item.amount = item.amount - 1
		else
			state.items[index] = nil
		end

		entity:SetCount(#entity.notices)
		entity:EmitSound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 3) .. ".wav", 55, 110)

		NETWORK.inventory.Sync(client)
		NETWORK.notice.Send(client, "noticePinned", "good")

		if (NETWORK.entities and NETWORK.entities.Save) then
			timer.Create("nwBoardSave", 5, 1, NETWORK.entities.Save)
		end

		B.Open(client, entity)
	end)

	net.Receive("nwBoardRemove", function(_, client)
		local entity = net.ReadEntity()
		local index = net.ReadUInt(8)

		if (!Check(client, entity) or !B.CanRemove(client)) then
			return
		end

		if (istable(entity.notices) and entity.notices[index]) then
			table.remove(entity.notices, index)
			entity:SetCount(#entity.notices)

			NETWORK.notice.Send(client, "noticeRemoved", "info")

			if (NETWORK.entities and NETWORK.entities.Save) then
				timer.Create("nwBoardSave", 5, 1, NETWORK.entities.Save)
			end
		end

		B.Open(client, entity)
	end)

	return
end

local function Frame(width, height, title)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local panel = vgui.Create("EditablePanel")

	panel:SetSize(width, height)
	panel:Center()
	panel:MakePopup()
	panel.OnKeyCodePressed = function(this, key)
		if (key == KEY_ESCAPE) then
			this:Remove()
		end
	end
	panel.Paint = function(this, w, h)
		NETWORK.gui.DrawBlackGlass(this, 0, 0, w, h, 1, Sc(14))

		draw.SimpleText(NETWORK.util.Upper(title), "nwInvKey", Sc(22), Sc(22),
			ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 160)
		surface.DrawRect(Sc(22), Sc(38), Sc(48), math.max(Sc(2), 1))
	end

	local close = panel:Add("nwInvButton")

	close:Setup(L("boardClose"), nil, false)
	close:SetSize(Sc(110), Sc(30))
	close:SetPos(width - Sc(132), Sc(8))
	close.DoClick = function()
		panel:Remove()
	end

	return panel
end

local function Entry(parent, x, y, width, height, bMultiline, placeholder, maxLength)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local entry = parent:Add("DTextEntry")

	entry:SetPos(x, y)
	entry:SetSize(width, height)
	entry:SetFont("nwInvBody")
	entry:SetMultiline(bMultiline)
	entry:SetDrawLanguageID(false)
	entry:SetPaintBackground(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.combine)
	entry:SetHighlightColor(theme.combineDeep)
	entry:SetUpdateOnType(true)
	entry.Paint = function(this, w, h)
		draw.RoundedBox(math.max(Sc(6), 4), 0, 0, w, h, Color(8, 9, 10, 200))
		NETWORK.util.DrawRoundedBorder(0, 0, w, h, math.max(Sc(6), 4), math.max(Sc(1), 1),
			ColorAlpha(this:HasFocus() and theme.combine or Color(255, 255, 255), this:HasFocus() and 170 or 30))

		if (this:GetValue() == "" and placeholder) then
			draw.SimpleText(placeholder, "nwInvBody", Sc(10), bMultiline and Sc(14) or math.Round(h * 0.5),
				ColorAlpha(theme.textFaint, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		this:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)
	end
	entry.OnValueChange = function(this, value)
		if (maxLength and #value > maxLength) then
			this:SetValue(string.sub(value, 1, maxLength))
		end
	end

	return entry
end

net.Receive("nwNoticeForm", function()
	local Sc = NETWORK.util.Scale

	if (IsValid(NETWORK.gui.noticeForm)) then
		NETWORK.gui.noticeForm:Remove()
	end

	local panel = Frame(Sc(520), Sc(420), L("noticeFormTitle"))

	NETWORK.gui.noticeForm = panel

	local title = Entry(panel, Sc(22), Sc(56), Sc(476), Sc(34), false, L("noticeTitlePlaceholder"), B.titleMax)
	local text = Entry(panel, Sc(22), Sc(100), Sc(476), Sc(250), true, L("noticeTextPlaceholder"), B.textMax)

	local submit = panel:Add("nwInvButton")

	submit:Setup(L("noticeFill"), "plus", true)
	submit:SetSize(Sc(180), Sc(34))
	submit:SetPos(Sc(22), Sc(366))
	submit.DoClick = function()
		net.Start("nwNoticeFill")
			net.WriteString(title:GetValue())
			net.WriteString(text:GetValue())
		net.SendToServer()

		panel:Remove()
	end

	title:RequestFocus()
end)

local function PaintNotice(parent, x, y, width, height, data)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util

	draw.RoundedBox(math.max(Sc(8), 4), x, y, width, height, Color(22, 22, 20, 235))
	util.DrawRoundedBorder(x, y, width, height, math.max(Sc(8), 4), math.max(Sc(1), 1),
		Color(255, 255, 255, 24))

	draw.SimpleText(data.title or "", "nwInvName", x + Sc(18), y + Sc(20),
		ColorAlpha(theme.text, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText((data.author or "?") .. "  ·  " .. (data.date or ""), "nwInvSub",
		x + Sc(18), y + Sc(42), ColorAlpha(theme.textDim, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 18)
	surface.DrawRect(x + Sc(18), y + Sc(56), width - Sc(36), 1)

	local lines = util.WrapText(data.text or "", "nwInvBody", width - Sc(36), 40)
	local lineY = y + Sc(72)

	for i = 1, #lines do
		if (lineY > y + height - Sc(14)) then
			break
		end

		draw.SimpleText(lines[i], "nwInvBody", x + Sc(18), lineY,
			ColorAlpha(theme.text, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		lineY = lineY + Sc(19)
	end
end

net.Receive("nwNoticeView", function()
	local Sc = NETWORK.util.Scale
	local data = NETWORK.util.ReadTable() or {}

	if (IsValid(NETWORK.gui.noticeView)) then
		NETWORK.gui.noticeView:Remove()
	end

	local panel = Frame(Sc(520), Sc(440), L("noticeViewTitle"))

	NETWORK.gui.noticeView = panel

	local paper = panel:Add("DPanel")

	paper:SetPos(Sc(22), Sc(56))
	paper:SetSize(Sc(476), Sc(362))
	paper.Paint = function(this, w, h)
		PaintNotice(this, 0, 0, w, h, data)
	end
end)

net.Receive("nwBoardOpen", function()
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local entity = net.ReadEntity()
	local payload = NETWORK.util.ReadTable() or {}
	local notices = payload.notices or {}
	local own = payload.own or {}

	if (IsValid(NETWORK.gui.board)) then
		NETWORK.gui.board:Remove()
	end

	local width, height = Sc(900), Sc(560)
	local panel = Frame(width, height, L("boardTitle"))

	NETWORK.gui.board = panel
	panel.selected = #notices > 0 and #notices or nil

	local list = panel:Add("DScrollPanel")

	list:SetPos(Sc(22), Sc(56))
	list:SetSize(Sc(300), height - Sc(120))

	local bar = list:GetVBar()

	bar:SetWide(Sc(4))
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(this, w, h)
		draw.RoundedBox(Sc(2), 0, 0, w, h, Color(255, 255, 255, 60))
	end

	for index = #notices, 1, -1 do
		local data = notices[index]
		local row = list:Add("DButton")

		row:SetText("")
		row:Dock(TOP)
		row:DockMargin(0, 0, Sc(8), Sc(6))
		row:SetTall(Sc(48))
		row.Paint = function(this, w, h)
			local bActive = panel.selected == index

			draw.RoundedBox(math.max(Sc(6), 4), 0, 0, w, h,
				bActive and ColorAlpha(theme.combine, 34) or Color(255, 255, 255, this:IsHovered() and 14 or 6))

			if (bActive) then
				NETWORK.util.DrawRoundedBorder(0, 0, w, h, math.max(Sc(6), 4), math.max(Sc(1), 1),
					ColorAlpha(theme.combine, 200))
			end

			draw.SimpleText(data.title or "?", "nwInvBody", Sc(12), Sc(15),
				ColorAlpha(theme.text, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText((data.author or "?") .. "  ·  " .. (data.date or ""), "nwHudSmall",
				Sc(12), Sc(34), ColorAlpha(theme.textFaint, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		row.DoClick = function()
			panel.selected = index

			NETWORK.sound.Click()
		end
	end

	local paper = panel:Add("DPanel")

	paper:SetPos(Sc(340), Sc(56))
	paper:SetSize(width - Sc(362), height - Sc(120))
	paper.Paint = function(this, w, h)
		local data = panel.selected and notices[panel.selected]

		if (!data) then
			draw.SimpleText(L(#notices > 0 and "boardPick" or "boardEmpty"), "nwInvBody",
				math.Round(w * 0.5), math.Round(h * 0.5), ColorAlpha(theme.textFaint, 200),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			return
		end

		PaintNotice(this, 0, 0, w, h, data)
	end

	local pin = panel:Add("nwInvButton")

	pin:Setup(L("boardPin"), "plus", true)
	pin:SetSize(Sc(200), Sc(34))
	pin:SetPos(Sc(22), height - Sc(52))
	pin.DoClick = function()
		if (#own == 0) then
			return chat.AddText(NETWORK.theme.warning or Color(238, 152, 70), L("boardNoNotice"))
		end

		local menu = DermaMenu()

		for _, entry in ipairs(own) do
			menu:AddOption(entry.title, function()
				net.Start("nwBoardPin")
					net.WriteEntity(entity)
					net.WriteUInt(entry.index, 8)
				net.SendToServer()
			end)
		end

		menu:Open()
	end

	if (payload.bCanRemove) then
		local remove = panel:Add("nwInvButton")

		remove:Setup(L("boardRemove"), "minus", false)
		remove:SetSize(Sc(200), Sc(34))
		remove:SetPos(Sc(240), height - Sc(52))
		remove.DoClick = function()
			if (!panel.selected) then
				return
			end

			net.Start("nwBoardRemove")
				net.WriteEntity(entity)
				net.WriteUInt(panel.selected, 8)
			net.SendToServer()
		end
	end

end)
