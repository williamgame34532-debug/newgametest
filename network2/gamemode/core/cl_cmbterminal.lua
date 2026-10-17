-- The command screen of the Alliance terminal (entities/entities/nw_cmb_terminal.lua): full screen,
-- the dark teal glass of the Combine (materials/network2/cmb/bg_cmb.png, branding/make_cmb_terminal.py).
--   left      the identification (the callsign, the unit), "СЕССИЯ АКТИВНА", the modules, the
--             system lines in the Combine font
--   middle    the title in a lit bar with hatching, the page:
--               КОМАНДНЫЙ ИНДЕКС   units of the branch online, the formations, your formation
--               ФОРМИРОВАНИЯ       the squads: make one, join, leave, disband; the leader - the
--                                  succession and sending members away (sh_squads.lua)
--               ПЕРСОНАЛ           the units in the game: name, zone, socio-status, formation
--               ВЫЗОВЫ             the calls of the civic terminals: how far, why; close them
--               ОПОВЕЩЕНИЯ         the announcements of the Overwatch to the whole city
--   right     the session activity (time and page), log out, exit
-- Other screens on the same frame (the CWU terminal, cl_cwu.lua) register their pages in
-- NW.cmbTerminal.screens[kind].

NW.cmbTerminal = NW.cmbTerminal or {}

local CT = NW.cmbTerminal
local SQ = NW.squads

local BG = Material("network2/cmb/bg_cmb.png", "smooth")
local HATCH = Material("network2/cmb/hatch.png", "noclamp")
local EMBLEM = Material("network2/factions/combineclaw_logo.png", "smooth mips")

local CYAN = Color(92, 204, 242)
local DIM = Color(64, 132, 160)
local DARK = Color(6, 20, 28)
local TEXT = Color(196, 236, 250)
local RED = Color(236, 96, 80)

CT.screens = CT.screens or {}

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(10, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwCmtHead", "JetBrains Mono ExtraBold", 0.018, 800)
	F("nwCmtTitle", "JetBrains Mono Medium", 0.024, 500)
	F("nwCmtBig", "JetBrains Mono ExtraBold", 0.022, 800)
	F("nwCmtText", "JetBrains Mono Medium", 0.016, 500)
	F("nwCmtSmall", "JetBrains Mono ExtraBold", 0.0125, 800)

	local combine = GetConVar("nw_hud_combine_font")

	surface.CreateFont("nwCmtGarble", {font = combine and combine:GetString() or "Combine_Alphabet",
		size = math.max(12, math.Round(h * 0.022)), weight = 500, extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwCmtFonts", Fonts)

local function Up(text)
	return NW.terminal.Upper(tostring(text or ""))
end

local function Click()
	surface.PlaySound("network2/cmbterminal/combine_tech_click_0" .. math.random(1, 5) .. ".wav")
end

local function Send(action, arg)
	if (!IsValid(CT.entity)) then
		return
	end

	net.Start("nwCmbTerminal")
		net.WriteEntity(CT.entity)
		net.WriteString(action)
		net.WriteString(tostring(arg or ""))
	net.SendToServer()
end

CT.Send = Send

-- ------------------------------------------------------------- widgets --
-- a lit bar with hatching (the title, the heads of the cards, the buttons)
function CT.LitBar(x, y, w, h, alpha)
	alpha = alpha or 1

	surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 235 * alpha)
	surface.DrawRect(x, y, w, h)
	surface.SetMaterial(HATCH)
	surface.SetDrawColor(255, 255, 255, 255 * alpha)
	surface.DrawTexturedRectUV(x, y, w, h, 0, 0, w / 64, h / 64)
end

-- a card: a lit head with a label, a dark body with the value
function CT.Card(parent, x, y, w, h, label, value)
	local card = parent:Add("DPanel")

	card:SetPos(x, y)
	card:SetSize(w, h)
	card.Paint = function(_, cw, ch)
		local head = math.Round(ch * 0.3)

		CT.LitBar(0, 0, cw, head)
		draw.SimpleText(Up(label), "nwCmtSmall", ch * 0.14, head / 2, DARK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 200)
		surface.DrawRect(0, head, cw, ch - head)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 200)
		surface.DrawOutlinedRect(0, 0, cw, ch, 1)
		draw.SimpleText(Up(isfunction(value) and value() or value), "nwCmtBig", ch * 0.14, head + (ch - head) / 2, TEXT,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return card
end

-- a button of the screen: lit when it is the main one, outlined otherwise
function CT.Button(parent, text, x, y, w, h, onClick, bMain, bDanger)
	local button = parent:Add("DButton")

	button:SetPos(x, y)
	button:SetSize(w, h)
	button:SetText("")
	button.Paint = function(self, bw, bh)
		local hover = self:IsHovered() and self:IsEnabled()
		local color = bDanger and RED or CYAN

		if (!self:IsEnabled()) then
			surface.SetDrawColor(DIM.r, DIM.g, DIM.b, 60)
			surface.DrawOutlinedRect(0, 0, bw, bh, 1)
			draw.SimpleText(Up(text), "nwCmtSmall", bw / 2, bh / 2, Color(DIM.r, DIM.g, DIM.b, 120), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)

			return
		end

		if (bMain or hover) then
			if (bDanger) then
				surface.SetDrawColor(color.r, color.g, color.b, hover and 230 or 190)
				surface.DrawRect(0, 0, bw, bh)
			else
				CT.LitBar(0, 0, bw, bh, hover and 1 or 0.85)
			end

			draw.SimpleText(Up(text), "nwCmtText", bw / 2, bh / 2, DARK, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		else
			surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 170)
			surface.DrawRect(0, 0, bw, bh)
			surface.SetDrawColor(color.r, color.g, color.b, 200)
			surface.DrawOutlinedRect(0, 0, bw, bh, 1)
			draw.SimpleText(Up(text), "nwCmtText", bw / 2, bh / 2, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	button.DoClick = function()
		Click()
		onClick()
	end
	button.OnCursorEntered = function(self)
		if (self:IsEnabled()) then
			surface.PlaySound("network2/terminal/civic/station_menu_hover.wav")
		end
	end

	return button
end

-- a line of text on the screen (label: dim small caps; value: bright)
function CT.Label(parent, text, x, y, font, color)
	local label = parent:Add("DLabel")

	label:SetPos(x, y)
	label:SetFont(font or "nwCmtSmall")
	label:SetTextColor(color or DIM)
	label:SetText(Up(text))
	label:SizeToContents()

	return label
end

function CT.Entry(parent, x, y, w, h, placeholder)
	local entry = parent:Add("DTextEntry")

	entry:SetPos(x, y)
	entry:SetSize(w, h)
	entry:SetFont("nwCmtText")
	entry:SetDrawLanguageID(false)
	entry.Paint = function(self, ew, eh)
		surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 220)
		surface.DrawRect(0, 0, ew, eh)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, self:HasFocus() and 255 or 140)
		surface.DrawOutlinedRect(0, 0, ew, eh, 1)

		if (self:GetValue() == "" and !self:HasFocus()) then
			draw.SimpleText(Up(placeholder), "nwCmtText", eh * 0.3, eh / 2, DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		self:DrawTextEntryText(TEXT, CYAN, TEXT)
	end

	return entry
end

-- a scroll list in the colours of the screen
function CT.Scroll(parent, x, y, w, h)
	local scroll = parent:Add("DScrollPanel")

	scroll:SetPos(x, y)
	scroll:SetSize(w, h)

	local bar = scroll:GetVBar()

	bar:SetWide(4)
	bar:SetHideButtons(true)
	bar.Paint = function(_, bw, bh)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 30)
		surface.DrawRect(0, 0, bw, bh)
	end
	bar.btnGrip.Paint = function(_, bw, bh)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 180)
		surface.DrawRect(0, 0, bw, bh)
	end

	return scroll
end

-- --------------------------------------------------------------- pages --
local function Socio(client)
	local ratio = client:Health() / math.max(client:GetMaxHealth(), 1)

	if (!client:Alive()) then
		return "НЕТ СИГНАЛА", RED
	elseif (ratio >= 0.75) then
		return "ЗЕЛЁНЫЙ", Color(110, 232, 132)
	elseif (ratio >= 0.5) then
		return "ЖЁЛТЫЙ", Color(240, 214, 90)
	elseif (ratio >= 0.25) then
		return "ОРАНЖЕВЫЙ", Color(244, 150, 64)
	end

	return "КРАСНЫЙ", RED
end

local function Units(bSameSide)
	local me = LocalPlayer()
	local out = {}

	for _, other in ipairs(player.GetAll()) do
		if (other:GetCharacterID() != 0 and NW.zones.IsAlliance(other) and
			(!bSameSide or SQ.Side(other) == SQ.Side(me))) then
			out[#out + 1] = other
		end
	end

	return out
end

local CMB = {
	title = "АЛЬЯНС :: ГРАЖДАНСКАЯ АДМИНИСТРАЦИЯ / КОМАНДНЫЙ ДОСТУП",
	footer = "АЛЬЯНС / ЗАЩИЩЁННЫЙ ДОСТУП",
	start = "index",
	pages = {}
}

CMB.order = {
	{"index", "Командный индекс"},
	{"formations", "Формирования"},
	{"personnel", "Персонал"},
	{"calls", "Вызовы"},
	{"broadcast", "Оповещения"}
}

CMB.pages.index = {
	title = "Командный индекс",
	subtitle = "Обзор персонала / доступные модули",
	Build = function(area, w, h)
		local me = LocalPlayer()
		local gap = math.Round(h * 0.03)
		local cw, ch = (w - gap) / 2, math.Round(h * 0.17)
		local squad = SQ.Of(me)

		CT.Card(area, 0, 0, cw, ch, "Персонал ветви", function()
			return #Units(true) .. " юнитов в сети"
		end)
		CT.Card(area, cw + gap, 0, cw, ch, "Активные формирования", function()
			return SQ.Count(SQ.Side(me)) .. " / " .. SQ.max:GetInt()
		end)
		CT.Card(area, 0, ch + gap, cw, ch, "Прикреплённый персонал", function()
			local current = SQ.Of(me)

			return current and (#SQ.Members(current) .. " / " .. SQ.size:GetInt() .. " юнитов") or "нет"
		end)
		CT.Card(area, cw + gap, ch + gap, cw, ch, "Текущее назначение", function()
			local current = SQ.Of(me)

			return current and current.name or "не назначен"
		end)

		local y = ch * 2 + gap * 3.5

		CT.Label(area, "Доступные модули", 0, y)
		y = y + h * 0.04

		local bw, bh = (w - gap) / 2, math.Round(h * 0.075)

		for index = 2, #CMB.order do
			local entry = CMB.order[index]
			local column = (index - 2) % 2
			local row = math.floor((index - 2) / 2)

			CT.Button(area, entry[2], column * (bw + gap), y + row * (bh + gap * 0.6), bw, bh, function()
				CT.Go(entry[1])
			end, true)
		end
	end
}

CMB.pages.formations = {
	title = "Формирования",
	subtitle = "Отряды стороны / создание / управление",
	Build = function(area, w, h)
		local me = LocalPlayer()
		local mine = SQ.Of(me)
		local side = SQ.Side(me)
		local gap = math.Round(h * 0.025)
		local rowH = math.Round(h * 0.075)
		local y = 0

		-- make one
		if (!mine) then
			local entry = CT.Entry(area, 0, 0, w * 0.6, rowH, "Название формирования")

			CT.Button(area, "Создать формирование", w * 0.62, 0, w * 0.38, rowH, function()
				SQ.Action("create", entry:GetValue())
			end, true)
			y = rowH + gap
		else
			local leader = mine.leader == me

			CT.Button(area, "Покинуть формирование", 0, 0, w * 0.32, rowH, function()
				SQ.Action("leave")
			end, false, true)

			local succession = CT.Button(area, "Преемственность: " .. (mine.succession and "вкл" or "выкл"), w * 0.34, 0,
				w * 0.32, rowH, function()
				SQ.Action("succession")
			end, mine.succession)

			succession:SetEnabled(leader)

			local disband = CT.Button(area, "Расформировать", w * 0.68, 0, w * 0.32, rowH, function()
				SQ.Action("disband", mine.id)
			end, false, true)

			disband:SetEnabled(leader or me:IsAdmin())
			y = rowH + gap
		end

		local scroll = CT.Scroll(area, 0, y, w, h - y)

		for _, squad in SortedPairsByMemberValue(SQ.list, "created") do
			if (squad.side == side) then
				local members = SQ.Members(squad)
				local card = scroll:Add("DPanel")
				local cardH = math.Round(rowH * 1.1 + #members * h * 0.04 + gap)

				card:Dock(TOP)
				card:DockMargin(0, 0, 8, gap)
				card:SetTall(cardH)
				card.Paint = function(_, cw, ch)
					local head = rowH * 0.6

					CT.LitBar(0, 0, cw, head)
					draw.SimpleText(Up(squad.name) .. "  ·  " .. #members .. " / " .. SQ.size:GetInt(), "nwCmtHead",
						head * 0.3, head / 2, DARK, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					draw.SimpleText(squad.succession and "ПРЕЕМСТВЕННОСТЬ" or "", "nwCmtSmall", cw - head * 0.3, head / 2, DARK,
						TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
					surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 190)
					surface.DrawRect(0, head, cw, ch - head)
					surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 160)
					surface.DrawOutlinedRect(0, 0, cw, ch, 1)
				end

				for index, member in ipairs(members) do
					local line = card:Add("DPanel")
					local my = rowH * 0.6 + gap * 0.5 + (index - 1) * h * 0.04

					line:SetPos(gap, my)
					line:SetSize(w - gap * 2 - 8, h * 0.04)
					line.Paint = function(_, lw, lh)
						if (!IsValid(member)) then
							return
						end

						local status, color = Socio(member)
						local leader = member == squad.leader

						draw.SimpleText((leader and "[Л] " or "") .. Up(member:Nick()), "nwCmtText", 0, lh / 2,
							leader and SQ.colors.leader or TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
						draw.SimpleText(status, "nwCmtSmall", lw * 0.62, lh / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					end

					-- the leader sends a member away
					if (mine == squad and squad.leader == me and member != me) then
						CT.Button(line, "Исключить", w - gap * 2 - 8 - w * 0.16, 2, w * 0.16, h * 0.04 - 4, function()
							SQ.Action("kick", "#" .. member:UserID())
						end, false, true)
					end
				end

				if (!mine) then
					local join = CT.Button(card, "Вступить", w - 8 - w * 0.2 - gap, rowH * 0.6 + gap * 0.5, w * 0.2, rowH * 0.6,
						function()
						SQ.Action("join", squad.id)
					end, true)

					join:SetEnabled(#members < SQ.size:GetInt())
				end
			end
		end
	end
}

CMB.pages.personnel = {
	title = "Персонал",
	subtitle = "Юниты в сети / зона / социо-статус / формирование",
	Build = function(area, w, h)
		local scroll = CT.Scroll(area, 0, 0, w, h)
		local rowH = math.Round(h * 0.06)

		for _, unit in ipairs(Units(false)) do
			local row = scroll:Add("DPanel")

			row:Dock(TOP)
			row:DockMargin(0, 0, 8, 4)
			row:SetTall(rowH)
			row.Paint = function(_, rw, rh)
				if (!IsValid(unit)) then
					return
				end

				local status, color = Socio(unit)
				local zone = NW.zones.At(NW.zones.Point(unit))
				local squad = SQ.Of(unit)

				surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 170)
				surface.DrawRect(0, 0, rw, rh)
				surface.SetDrawColor(SQ.colors[SQ.Side(unit)])
				surface.DrawRect(0, 0, 3, rh)
				draw.SimpleText(Up(unit:Nick()), "nwCmtText", rh * 0.3, rh / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(Up(zone and zone.name or "вне зон"), "nwCmtSmall", rw * 0.46, rh / 2, DIM, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
				draw.SimpleText(status, "nwCmtSmall", rw * 0.66, rh / 2, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(Up(squad and squad.name or "—"), "nwCmtSmall", rw - rh * 0.3, rh / 2, DIM, TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			end
		end
	end
}

CMB.pages.calls = {
	title = "Вызовы",
	subtitle = "Гражданские терминалы / причина / расстояние",
	Build = function(area, w, h)
		local alerts = NW.terminal.alerts or {}
		local rowH = math.Round(h * 0.12)
		local scroll = CT.Scroll(area, 0, 0, w, h)

		if (#alerts == 0) then
			CT.Label(area, "Активных вызовов нет", 0, 0, "nwCmtText", DIM)

			return
		end

		for _, alert in ipairs(alerts) do
			local row = scroll:Add("DPanel")

			row:Dock(TOP)
			row:DockMargin(0, 0, 8, 6)
			row:SetTall(rowH)
			row.Paint = function(_, rw, rh)
				surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 190)
				surface.DrawRect(0, 0, rw, rh)
				surface.SetDrawColor(RED.r, RED.g, RED.b, 220)
				surface.DrawRect(0, 0, 3, rh)

				local distance = IsValid(LocalPlayer()) and math.Round(LocalPlayer():GetPos():Distance(alert.pos) / 52.5) or 0

				draw.SimpleText(string.format("ТЕРМИНАЛ %03d  ·  %s (#%s)  ·  %d М", alert.number or 0, Up(alert.name),
					alert.cid or "?", distance), "nwCmtText", rh * 0.2, rh * 0.3, RED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(alert.reason or "", "nwCmtText", rh * 0.2, rh * 0.68, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			CT.Button(row, "Закрыть вызов", w - 8 - w * 0.22 - 8, rowH * 0.18, w * 0.22, rowH * 0.32, function()
				Send("resolve", alert.terminal)
			end, false, true)
		end
	end
}

CMB.pages.broadcast = {
	title = "Оповещения",
	subtitle = "Голос Надзора / на весь город",
	Build = function(area, w, h)
		local rowH = math.Round(h * 0.075)
		local scroll = CT.Scroll(area, 0, 0, w, h)

		for _, entry in ipairs(NW.overwatch.list) do
			local row = scroll:Add("DPanel")

			row:Dock(TOP)
			row:DockMargin(0, 0, 8, 4)
			row:SetTall(rowH)
			row.Paint = function(_, rw, rh)
				surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 170)
				surface.DrawRect(0, 0, rw, rh)
				draw.SimpleText(entry.text, "nwCmtText", rh * 0.25, rh / 2, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end

			CT.Button(row, "Передать", w - 8 - w * 0.16 - 6, rowH * 0.15, w * 0.16, rowH * 0.7, function()
				Send("broadcast", entry.id)
			end, true)
		end
	end
}

CT.screens.cmb = CMB

-- ---------------------------------------------------------------- frame --
local function Log(text)
	CT.log = CT.log or {}
	table.insert(CT.log, 1, {time = os.date("%H:%M:%S"), text = text})

	while (#CT.log > 8) do
		table.remove(CT.log)
	end
end

local GARBLE = {"Uplink :: overwatch", "Node handshake", "Civil index sync", "Biosignal mesh", "Sector grid 17",
	"Ration cycle", "Curfew schedule", "Restriction zone", "Compliance audit", "Unit roster"}

function CT.Close(bQuiet)
	if (IsValid(CT.frame)) then
		CT.frame:Remove()
	end

	if (!bQuiet) then
		Send("close")
	end

	CT.entity = nil
end

function CT.Go(page, bQuiet)
	local screen = CT.screens[CT.kind]
	local data = screen and screen.pages[page]

	if (!data or !IsValid(CT.area)) then
		return
	end

	CT.page = page
	CT.area:Clear()
	data.Build(CT.area, CT.area:GetWide(), CT.area:GetTall())

	if (!bQuiet) then
		Log(data.title)
	end
end

function CT.Refresh()
	if (CT.page) then
		CT.Go(CT.page, true)
	end
end

function CT.Open(entity, kind)
	CT.Close(true)

	local screen = CT.screens[kind]

	if (!screen) then
		return
	end

	CT.entity = entity
	CT.kind = kind
	CT.log = {}

	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame.born = RealTime()
	CT.frame = frame

	-- the panel of the screen
	local px, py = math.Round(sw * 0.1), math.Round(sh * 0.17)
	local pw, ph = sw - px * 2, math.Round(sh * 0.66)
	local col = math.Round(pw * 0.17)
	local node = entity:EntIndex() % 97

	frame.Paint = function(self, w, h)
		local a = math.Clamp((RealTime() - self.born) / 0.35, 0, 1)

		surface.SetDrawColor(0, 0, 0, 200 * a)
		surface.DrawRect(0, 0, w, h)
		surface.SetMaterial(BG)
		surface.SetDrawColor(255, 255, 255, 255 * a)
		surface.DrawTexturedRect(px, py, pw, ph)

		-- a slow line of light going down the glass
		local sweep = (RealTime() * 0.12) % 1

		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 14 * a)
		surface.DrawRect(px, py + ph * sweep, pw, 2)

		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 70 * a)
		surface.DrawOutlinedRect(px, py, pw, ph, 1)

		-- the head and the foot
		local pad = sh * 0.03

		draw.SimpleText(screen.title, "nwCmtHead", px + pad, py + pad, ColorAlpha(CYAN, 255 * a), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(string.format("ЛОКАЛЬНЫЙ УЗЕЛ :: %02d", node), "nwCmtSmall", px + pw - pad - sh * 0.05, py + pad,
			ColorAlpha(DIM, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		surface.SetMaterial(EMBLEM)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 200 * a)
		surface.DrawTexturedRect(px + pw - pad - sh * 0.032, py + pad - sh * 0.016, sh * 0.032, sh * 0.032)
		surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 60 * a)
		surface.DrawRect(px + pad, py + pad * 1.9, pw - pad * 2, 1)
		surface.DrawRect(px + pad, py + ph - pad * 1.6, pw - pad * 2, 1)
		draw.SimpleText(screen.footer, "nwCmtSmall", px + pad, py + ph - pad * 0.9, ColorAlpha(DIM, 200 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText(os.date("%H:%M:%S") .. "  /  ЛОКАЛЬНОЕ ВРЕМЯ", "nwCmtSmall", px + pw - pad, py + ph - pad * 0.9,
			ColorAlpha(DIM, 200 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- left: who is in
		local lx, ly = px + pad, py + pad * 2.8
		local me = LocalPlayer()

		draw.SimpleText("ИДЕНТИФИКАЦИЯ", "nwCmtSmall", lx, ly, ColorAlpha(DIM, 255 * a))
		draw.SimpleText(Up(me:Nick()), "nwCmtText", lx, ly + sh * 0.022, ColorAlpha(TEXT, 255 * a))
		draw.SimpleText("СЕССИЯ АКТИВНА", "nwCmtSmall", lx, ly + sh * 0.05, ColorAlpha(CYAN, 255 * a))

		-- the system lines in the Combine font, under the modules
		local gy = py + ph * 0.66

		for index, line in ipairs(GARBLE) do
			if (index > 6) then
				break
			end

			local shift = math.floor(RealTime() * 0.7 + index) % #GARBLE + 1

			draw.SimpleText(GARBLE[shift], "nwCmtGarble", lx, gy + (index - 1) * sh * 0.026,
				ColorAlpha(CYAN, (90 + 60 * math.abs(math.sin(RealTime() + index))) * a))
		end

		-- the title of the page
		local page = screen.pages[CT.page or ""]
		local cx = px + pad + col
		local cw = pw - pad * 2 - col * 2

		if (page) then
			CT.LitBar(cx, ly - sh * 0.004, cw, sh * 0.04, a)
			draw.SimpleText(Up(page.title), "nwCmtTitle", cx + sh * 0.012, ly + sh * 0.016, ColorAlpha(DARK, 255 * a),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(Up(page.subtitle or ""), "nwCmtSmall", cx, ly + sh * 0.052, ColorAlpha(DIM, 255 * a))
			surface.SetDrawColor(CYAN.r, CYAN.g, CYAN.b, 40 * a)
			surface.DrawRect(cx, ly + sh * 0.068, cw, 1)
		end

		-- right: the session
		local rx = px + pw - pad - col + sh * 0.02

		draw.SimpleText("АКТИВНОСТЬ СЕССИИ", "nwCmtSmall", rx, ly, ColorAlpha(DIM, 255 * a))

		for index, entry in ipairs(CT.log or {}) do
			local ey = ly + sh * 0.03 + (index - 1) * sh * 0.045

			draw.SimpleText(entry.time, "nwCmtSmall", rx, ey, ColorAlpha(DIM, 220 * a))
			draw.SimpleText(Up(entry.text), "nwCmtSmall", rx, ey + sh * 0.017, ColorAlpha(CYAN, 255 * a))
		end
	end

	-- left: the modules
	local pad = sh * 0.03
	local ly = py + pad * 2.8 + sh * 0.085

	for index, entry in ipairs(screen.order) do
		CT.Button(frame, entry[2], px + pad, ly + (index - 1) * sh * 0.044, col - pad * 0.6, sh * 0.036, function()
			CT.Go(entry[1])
		end, false)
	end

	-- middle: the page
	local area = frame:Add("EditablePanel")

	area:SetPos(px + pad + col, py + pad * 2.8 + sh * 0.085)
	area:SetSize(pw - pad * 2 - col * 2, ph - pad * 2.8 - sh * 0.085 - pad * 2)
	CT.area = area

	-- right: log out, exit
	local rx = px + pw - pad - col + sh * 0.02
	local bw = col - sh * 0.02

	CT.Button(frame, "Выйти из системы", rx, py + ph - pad * 2 - sh * 0.09, bw, sh * 0.036, function()
		CT.Go(screen.start)
		CT.log = {}
		Log("вход")
	end, true)
	CT.Button(frame, "Закрыть терминал", rx, py + ph - pad * 2 - sh * 0.045, bw, sh * 0.036, function()
		CT.Close()
	end, true)

	CT.Go(screen.start)

	-- what the squads were when the page was built: a change rebuilds the page
	frame.squadKey = nil
	frame.Think = function(self)
		local key = {}

		for id, squad in pairs(SQ.list) do
			key[#key + 1] = id .. ":" .. #SQ.Members(squad) .. ":" .. tostring(squad.succession) .. ":" ..
				(IsValid(squad.leader) and squad.leader:EntIndex() or 0)
		end

		key = table.concat(key, ",") .. "|" .. LocalPlayer():GetNW2Int("nwSquad", 0) .. "|" .. #(NW.terminal.alerts or {})

		if (self.squadKey and self.squadKey != key and CT.page != "personnel") then
			-- keep what is being typed
			local focus = vgui.GetKeyboardFocus()

			if (!IsValid(focus) or focus:GetClassName() != "TextEntry") then
				CT.Refresh()
			end
		end

		self.squadKey = key

		-- walked away, died, fell
		if (!IsValid(CT.entity) or !LocalPlayer():Alive() or LocalPlayer():GetPos():DistToSqr(CT.entity:GetPos()) > 180 * 180 or
			(NW.Incapable and NW.Incapable(LocalPlayer()))) then
			CT.Close()
		end
	end

	frame.OnKeyCodePressed = function(_, code)
		if (code == KEY_ESCAPE) then
			CT.Close()
		end
	end
end

net.Receive("nwCmbTerminalOpen", function()
	local entity = net.ReadEntity()
	local kind = net.ReadString()

	if (IsValid(entity)) then
		CT.Open(entity, kind)
	end
end)

-- the unit leans to the screen (harassfront1 on the Civil Protection models)
net.Receive("nwCmbTerminalLean", function()
	local client = net.ReadEntity()

	if (!IsValid(client)) then
		return
	end

	local sequence = client:LookupSequence("harassfront1")

	if (sequence and sequence > 0) then
		client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, sequence, 0, true)
	end
end)

hook.Add("NWEscape", "nwCmbTerminal", function()
	if (IsValid(CT.frame)) then
		CT.Close()

		return true
	end
end)
