-- The civic terminal, client side (sh_terminal.lua, entities/entities/nw_terminal.lua):
--   E            looking at a button of a terminal close by presses it (instead of the usual use)
--   windows      the text of a call, a sum for the bank, a picture of an announcement
--   /announce    the editor of announcements (admins and the Alliance): a list, new, change, delete
--   the call     the Alliance sees a mark over the terminal that called (90 s) and a notification

local T = NW.terminal
local U = NW.ui
local W = NW.widgets

net.Receive("nwTerminal", function()
	local action = net.ReadString()
	local terminal = net.ReadEntity()
	local data = util.JSONToTable(net.ReadString() or "") or {}

	if (action == "alert") then
		return T.Alert(terminal, data)
	elseif (action == "alert_clear") then
		return T.ClearAlert(data.terminal, data.by)
	elseif (action == "announce_list") then
		return T.OpenEditor(data.list or {})
	end

	if (IsValid(terminal) and terminal.Receive) then
		terminal:Receive(action, data)
	end
end)

-- -------------------------------------------------------------------- E --
local function Aimed()
	local client = LocalPlayer()

	for _, terminal in ipairs(ents.FindByClass(T.class)) do
		if (T.IsNear(client, terminal) and terminal.GetHoveredButton and terminal:GetHoveredButton(client)) then
			return terminal
		end
	end
end

hook.Add("PlayerBindPress", "nwTerminal", function(client, bind, bPressed)
	if (!bPressed or !string.find(string.lower(bind), "+use", 1, true)) then
		return
	end

	local terminal = Aimed()

	if (terminal and terminal:HandleUse(client)) then
		return true
	end
end)

-- -------------------------------------------------------------- windows --
function T.OpenTextPrompt(title, value, callback, multiline)
	local sh = ScrH()
	local w, h = math.Round(sh * 0.5), math.Round(sh * (multiline and 0.36 or 0.24))
	local frame, box = W.Window(title, w, h)
	local pad = math.Round(sh * 0.022)
	local entry = W.Entry(box, value or "", "Текст…", multiline)

	entry:SetPos(pad, box.top)
	entry:SetSize(w - pad * 2, h - box.top - pad * 3 - sh * 0.038)
	entry:RequestFocus()

	local function Done()
		callback(string.Trim(entry:GetValue() or ""))
		frame:Remove()
	end

	if (!multiline) then
		entry.OnEnter = Done
	end

	local ok = W.Button(box, "Готово", Done, true)

	ok:SetSize(math.Round(w * 0.3), math.Round(sh * 0.038))
	ok:SetPos(w - pad - ok:GetWide(), h - pad - ok:GetTall())
end

function T.OpenNumberPrompt(title, callback)
	local sh = ScrH()
	local w, h = math.Round(sh * 0.4), math.Round(sh * 0.22)
	local frame, box = W.Window(title, w, h)
	local pad = math.Round(sh * 0.022)
	local entry = W.Number(box, 0, 1, 1000000)

	entry:SetText("")
	entry.placeholder = "Сколько токенов"
	entry:SetPos(pad, box.top)
	entry:SetSize(w - pad * 2, math.Round(sh * 0.04))
	entry:RequestFocus()

	local function Done()
		local amount = entry:GetNumber()

		frame:Remove()

		if (amount > 0) then
			callback(amount)
		end
	end

	entry.OnEnter = Done

	local ok = W.Button(box, "Подтвердить", Done, true)

	ok:SetSize(math.Round(w * 0.42), math.Round(sh * 0.038))
	ok:SetPos(w - pad - ok:GetWide(), h - pad - ok:GetTall())
end

-- a picture of an announcement: shown as is (a link to an image)
function T.OpenPhoto(url, title)
	local sh, sw = ScrH(), ScrW()
	local w, h = math.Round(sw * 0.6), math.Round(sh * 0.7)
	local frame, box = W.Window(title or "Фотоматериал", w, h)
	local html = box:Add("DHTML")
	local pad = math.Round(sh * 0.015)

	html:SetPos(pad, box.top)
	html:SetSize(w - pad * 2, h - box.top - pad)
	html:SetHTML([[<html><body style="margin:0;background:#0b1418;display:flex;align-items:center;
		justify-content:center;height:100vh;overflow:hidden"><img src="]] .. string.gsub(url, "[\"<>]", "") ..
		[[" style="max-width:100%;max-height:100%;object-fit:contain"></body></html>]])
end

-- ------------------------------------------------------- announcements --
local function Send(action, data)
	net.Start("nwTerminal")
		net.WriteString(action)
		net.WriteEntity(NULL)
		net.WriteString(util.TableToJSON(data or {}))
	net.SendToServer()
end

local editor

local function OpenForm(entry, list)
	if (IsValid(editor)) then
		editor:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.66), math.Round(sh * 0.66)
	local frame, box = W.Window(entry.id and "Объявление" or "Новое объявление", w, h, function()
		T.OpenEditor(list)
	end)

	editor = frame

	local pad = math.Round(sh * 0.022)
	local fieldH = math.Round(sh * 0.038)
	local inner = w - pad * 2
	local y = box.top

	W.Label(box, "Заголовок", pad, y)
	W.Label(box, "Приоритет", pad + inner * 0.68, y)
	y = y + math.Round(sh * 0.02)

	local title = W.Entry(box, entry.title or "", "Коротко, о чём")

	title:SetPos(pad, y)
	title:SetSize(inner * 0.65, fieldH)

	local choices = {}

	for _, id in ipairs(T.priorityOrder) do
		choices[#choices + 1] = {id, T.priorities[id].name}
	end

	local priority = W.Combo(box, choices, entry.priority or "normal")

	priority:SetPos(pad + inner * 0.68, y)
	priority:SetSize(inner * 0.32, fieldH)
	y = y + fieldH + math.Round(sh * 0.016)

	W.Label(box, "Текст", pad, y)
	y = y + math.Round(sh * 0.02)

	local body = W.Entry(box, entry.body or "", "Что нужно знать гражданам", true)

	body:SetPos(pad, y)
	body:SetSize(inner, math.Round(sh * 0.24))
	y = y + body:GetTall() + math.Round(sh * 0.016)

	W.Label(box, "Ссылка на изображение (необязательно)", pad, y)
	y = y + math.Round(sh * 0.02)

	local photo = W.Entry(box, entry.photo or "", "https://…")

	photo:SetPos(pad, y)
	photo:SetSize(inner, fieldH)

	local by = h - fieldH - pad
	local save = W.Button(box, entry.id and "Сохранить" or "Опубликовать", function()
		Send("announce_save", {id = entry.id, title = title:GetValue(), body = body:GetValue(),
			priority = priority:GetSelectedValue(), photo = string.Trim(photo:GetValue())})
		frame:Remove()
	end, true)

	save:SetPos(w - pad - inner * 0.34, by)
	save:SetSize(inner * 0.34, fieldH)

	local back = W.Button(box, "К списку", function()
		frame:Remove()
		T.OpenEditor(list)
	end)

	back:SetPos(pad, by)
	back:SetSize(inner * 0.26, fieldH)
end

function T.OpenEditor(list)
	if (IsValid(editor)) then
		editor:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.66), math.Round(sh * 0.66)
	local frame, box = W.Window("Объявления терминалов", w, h)

	editor = frame

	local pad = math.Round(sh * 0.022)
	local rowH = math.Round(sh * 0.056)
	local scroll = W.Scroll(box)

	scroll:SetPos(pad, box.top)
	scroll:SetSize(w - pad * 2, h - box.top - pad * 2 - sh * 0.038)

	if (#list == 0) then
		W.Label(scroll, "Объявлений пока нет", 0, 0)
	end

	for _, entry in ipairs(list) do
		local row = scroll:Add("EditablePanel")
		local priority = T.priorities[entry.priority] or T.priorities.normal

		row:Dock(TOP)
		row:DockMargin(0, 0, 8, 6)
		row:SetTall(rowH)
		row.Paint = function(_, rw, rh)
			draw.RoundedBox(4, 0, 0, rw, rh, Color(24, 27, 31))
			surface.SetDrawColor(priority.color)
			surface.DrawRect(0, 4, 3, rh - 8)
			draw.SimpleText(entry.title, "nwWidgetBold", 12, rh * 0.33, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(entry.gameTime .. " · " .. (entry.author or "") .. " · " .. priority.name, "nwWidget", 12,
				rh * 0.7, W.MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local delete = W.Button(row, "Удалить", function()
			Send("announce_delete", {id = entry.id})
		end)

		delete:Dock(RIGHT)
		delete:DockMargin(4, 9, 8, 9)
		delete:SetWide(math.Round(sh * 0.1))

		local edit = W.Button(row, "Изменить", function()
			OpenForm(table.Copy(entry), list)
		end, true)

		edit:Dock(RIGHT)
		edit:DockMargin(4, 9, 0, 9)
		edit:SetWide(math.Round(sh * 0.1))
	end

	local new = W.Button(box, "Новое объявление", function()
		OpenForm({}, list)
	end, true, "plus")

	new:SetSize(math.Round(w * 0.36), math.Round(sh * 0.038))
	new:SetPos(w - pad - new:GetWide(), h - pad - new:GetTall())
end

-- ---------------------------------------------------------- the alerts --
T.alerts = T.alerts or {}

function T.Alert(terminal, data)
	local pos = istable(data.pos) and Vector(data.pos[1], data.pos[2], data.pos[3]) or
		(IsValid(terminal) and terminal:GetPos())

	if (!pos) then
		return
	end

	-- a new call from the same terminal replaces the old mark
	T.ClearAlert(data.terminal)

	table.insert(T.alerts, {pos = pos, terminal = data.terminal, number = data.number or 0, reason = data.reason or "",
		name = data.name or "?", cid = data.cid or "?", until_ = RealTime() + (data.until_ or 90)})

	NW.notify.Add("ВЫЗОВ Г.О · терминал " .. string.format("%03d", data.number or 0) .. " · " .. (data.name or "?") ..
		" (#" .. (data.cid or "?") .. "): " .. (data.reason or ""))
	surface.PlaySound("network2/terminal/alarm.wav")
end

-- the call is closed (someone of the Alliance pressed E on the terminal)
function T.ClearAlert(terminal, by)
	local removed = false

	for index = #T.alerts, 1, -1 do
		if (terminal and T.alerts[index].terminal == terminal) then
			removed = true
			table.remove(T.alerts, index)
		end
	end

	if (removed and by) then
		NW.notify.Add("Вызов закрыт: " .. by)
	end
end

-- reaching the mark: within this many units it goes away (for the one who came)
local REACHED = 110

surface.CreateFont("nwTermAlert", {font = "Oswald Medium", size = math.max(14, math.Round(ScrH() * 0.019)), weight = 500,
	extended = true, antialias = true})
surface.CreateFont("nwTermAlertSmall", {font = "Exo 2", size = math.max(11, math.Round(ScrH() * 0.014)), weight = 500,
	extended = true, antialias = true})

hook.Add("HUDPaint", "nwTerminalAlerts", function()
	local now = RealTime()
	local eye = EyePos()

	for index = #T.alerts, 1, -1 do
		local alert = T.alerts[index]

		if (now > alert.until_) then
			table.remove(T.alerts, index)
		elseif (IsValid(LocalPlayer()) and LocalPlayer():GetPos():DistToSqr(alert.pos) < REACHED * REACHED) then
			-- the patrol is there: the mark has done its job
			table.remove(T.alerts, index)
			surface.PlaySound("network2/terminal/select2.wav")
		else
			local screen = (alert.pos + Vector(0, 0, 40)):ToScreen()
			local x = math.Clamp(screen.x, 40, ScrW() - 40)
			local y = math.Clamp(screen.y, 60, ScrH() - 60)
			local blink = 0.6 + 0.4 * math.abs(math.sin(now * 3))
			local red = Color(231, 78, 76, 255 * blink)
			local distance = math.Round(eye:Distance(alert.pos) / 52.5)

			surface.SetDrawColor(red)
			surface.DrawOutlinedRect(x - 9, y - 9, 18, 18, 2)
			surface.DrawRect(x - 2, y - 2, 4, 4)
			draw.SimpleTextOutlined("ВЫЗОВ Г.О · " .. distance .. " м", "nwTermAlert", x, y - 14, red, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 200))
			local reason = alert.reason

			if ((utf8.len(reason) or 0) > 80) then
				reason = string.sub(reason, 1, (utf8.offset(reason, 81) or (#reason + 1)) - 1) .. "…"
			end

			draw.SimpleTextOutlined(reason, "nwTermAlertSmall", x, y + 14,
				Color(236, 238, 242, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
		end
	end
end)
