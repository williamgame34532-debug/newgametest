-- The CWU and the factory, client (sh_cwu.lua):
--   the CWU terminal   the screen of nw_cwu_terminal on the frame of the Alliance terminal
--                      (cl_cmbterminal.lua): Сводка, Поломки, Заражения, Назначение (the class and the
--                      kit), Завод
--   marks              for the CWU: the broken places and the outbreaks on the screen with the distance
--   the office         the window of the personnel office of the factory (an NPC): hire, quit, the rank
--   the instruction    /menufactory (and once for the admin who builds the first station)

local CW = NW.cwu
local CT = NW.cmbTerminal
local U = NW.ui
local I = NW.items

local AMBER = Color(232, 170, 64)
local GREEN = Color(130, 214, 90)
-- the amber of the CWU screen (CT.palettes.cwu)
local TEXT = CT.colors.text
local DIM = CT.colors.dim
local DARK = CT.colors.dark

local function Up(text)
	return NW.terminal.Upper(tostring(text or ""))
end

local function ZoneName(entity)
	local zone = NW.zones.At(NW.zones.Point(entity))

	return zone and zone.name or "вне зон"
end

local function Broken()
	local out = {}

	for _, entity in ipairs(ents.FindByClass("nw_breakdown")) do
		if (entity:GetBroken()) then
			out[#out + 1] = entity
		end
	end

	return out
end

local function Outbreaks()
	local out = {}

	for _, entity in ipairs(ents.FindByClass("nw_infestation")) do
		if (entity:GetActive()) then
			out[#out + 1] = entity
		end
	end

	return out
end

local function Meters(entity)
	return math.Round(LocalPlayer():GetPos():Distance(entity:GetPos()) / 52.5)
end

-- -------------------------------------------------------------- the terminal --
local SCREEN = {
	title = "СОЮЗ ГРАЖДАНСКИХ РАБОЧИХ / ТЕРМИНАЛ ГСР",
	footer = "ГСР / РАБОЧИЙ ДОСТУП",
	palette = "cwu",
	start = "index",
	pages = {}
}

SCREEN.order = {
	{"index", "Сводка"},
	{"breakdowns", "Поломки"},
	{"outbreaks", "Заражения"},
	{"assign", "Назначение"},
	{"factory", "Завод"}
}

local function List(area, w, h, entries, color, empty)
	local scroll = CT.Scroll(area, 0, 0, w, h)
	local rowH = math.Round(h * 0.09)

	if (#entries == 0) then
		CT.Label(area, empty, 0, 0, "nwCmtText", DIM)

		return
	end

	for _, entry in ipairs(entries) do
		local row = scroll:Add("DPanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, 8, 6)
		row:SetTall(rowH)
		row.Paint = function(_, rw, rh)
			if (!IsValid(entry.entity)) then
				return
			end

			surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 190)
			surface.DrawRect(0, 0, rw, rh)
			surface.SetDrawColor(color)
			surface.DrawRect(0, 0, 3, rh)
			draw.SimpleText(Up(entry.name), "nwCmtText", rh * 0.3, rh * 0.32, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(Up(ZoneName(entry.entity)) .. "  ·  " .. Meters(entry.entity) .. " М", "nwCmtSmall", rh * 0.3,
				rh * 0.7, DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local minutes = math.floor((CurTime() - (entry.since or CurTime())) / 60)

			draw.SimpleText(minutes .. " МИН", "nwCmtSmall", rw - rh * 0.3, rh / 2, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end
end

SCREEN.pages.index = {
	title = "Сводка",
	subtitle = "Состояние района / назначение",
	Build = function(area, w, h)
		local gap = math.Round(h * 0.03)
		local cw, ch = (w - gap) / 2, math.Round(h * 0.17)
		local me = LocalPlayer()

		CT.Card(area, 0, 0, cw, ch, "Поломки", function()
			return #Broken() .. " активных"
		end)
		CT.Card(area, cw + gap, 0, cw, ch, "Очаги заражения", function()
			return #Outbreaks() .. " активных"
		end)
		CT.Card(area, 0, ch + gap, cw, ch, "Ваше назначение", function()
			local class = CW.classByID[CW.Class(me)]

			return class and class.name or (CW.IsCWU(me) and "не назначено" or "не член ГСР")
		end)
		CT.Card(area, cw + gap, ch + gap, cw, ch, "Ранг на заводе", function()
			if (!me:GetNW2Bool("nwFactoryHired", false)) then
				return "не оформлен"
			end

			return CW.ranks[CW.Rank(me:GetNW2Int("nwFactoryXP", 0))].name
		end)

		local y = ch * 2 + gap * 3.5
		local bw, bh = (w - gap) / 2, math.Round(h * 0.075)

		CT.Label(area, "Доступные модули", 0, y)
		y = y + h * 0.04

		for index = 2, #SCREEN.order do
			local entry = SCREEN.order[index]
			local column = (index - 2) % 2
			local row = math.floor((index - 2) / 2)

			CT.Button(area, entry[2], column * (bw + gap), y + row * (bh + gap * 0.6), bw, bh, function()
				CT.Go(entry[1])
			end, true)
		end
	end
}

SCREEN.pages.breakdowns = {
	title = "Поломки",
	subtitle = "Ремонт: набор инструментов, E по месту поломки",
	Build = function(area, w, h)
		local entries = {}

		for _, entity in ipairs(Broken()) do
			entries[#entries + 1] = {entity = entity, name = entity:KindData().name, since = entity:GetBrokenSince()}
		end

		List(area, w, h, entries, AMBER, "Поломок нет")
	end
}

SCREEN.pages.outbreaks = {
	title = "Заражения",
	subtitle = "Дезинфекция: противогаз, дезинфектор, E по очагу",
	Build = function(area, w, h)
		local entries = {}

		for _, entity in ipairs(Outbreaks()) do
			entries[#entries + 1] = {entity = entity, name = "Очаг заражения", since = entity:GetSince()}
		end

		List(area, w, h, entries, GREEN, "Очагов нет")
	end
}

SCREEN.pages.assign = {
	title = "Назначение",
	subtitle = "Класс рабочего ГСР / снаряжение",
	Build = function(area, w, h)
		local me = LocalPlayer()
		local rowH = math.Round(h * 0.17)
		local gap = math.Round(h * 0.025)

		for index, class in ipairs(CW.classes) do
			local y = (index - 1) * (rowH + gap)
			local card = area:Add("DPanel")

			card:SetPos(0, y)
			card:SetSize(w, rowH)
			card.Paint = function(_, cw, ch)
				local current = CW.Class(me) == class.id

				surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 190)
				surface.DrawRect(0, 0, cw, ch)

				if (current) then
					CT.LitBar(0, 0, 4, ch)
				end

				U.DrawIcon(class.icon, ch * 0.18, ch * 0.18, ch * 0.36, current and CT.colors.cyan or DIM)
				draw.SimpleText(Up(class.name), "nwCmtHead", ch * 0.7, ch * 0.26, TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				local lines = NW.inventory.WrapText(class.text, "nwCmtText", cw * 0.62)

				for k, line in ipairs(lines) do
					if (k > 2) then
						break
					end

					draw.SimpleText(line, "nwCmtText", ch * 0.7, ch * 0.52 + (k - 1) * ch * 0.22, DIM, TEXT_ALIGN_LEFT,
						TEXT_ALIGN_CENTER)
				end
			end

			local choose = CT.Button(card, CW.Class(me) == class.id and "Назначен" or "Назначить", w - w * 0.2 - gap,
				rowH * 0.3, w * 0.2, rowH * 0.4, function()
				CT.Send("cwu_class", class.id)

				timer.Simple(0.4, CT.Refresh)
			end, CW.Class(me) != class.id)

			choose:SetEnabled(CW.IsCWU(me) and CW.Class(me) != class.id)
		end

		local gear = CT.Button(area, "Получить снаряжение", 0, #CW.classes * (rowH + gap) + gap, w * 0.4, h * 0.075, function()
			CT.Send("cwu_gear")
		end, true)

		gear:SetEnabled(CW.IsCWU(me))
	end
}

SCREEN.pages.factory = {
	title = "Завод",
	subtitle = "Ранги / опыт / линия",
	Build = function(area, w, h)
		local me = LocalPlayer()
		local xp = me:GetNW2Int("nwFactoryXP", 0)
		local rank = CW.Rank(xp)
		local rowH = math.Round(h * 0.07)

		for index, entry in ipairs(CW.ranks) do
			local row = area:Add("DPanel")

			row:SetPos(0, (index - 1) * (rowH + 4))
			row:SetSize(w, rowH)
			row.Paint = function(_, rw, rh)
				local reached = index <= rank

				surface.SetDrawColor(DARK.r, DARK.g, DARK.b, 170)
				surface.DrawRect(0, 0, rw, rh)

				if (index == rank) then
					CT.LitBar(0, 0, 4, rh)
				end

				draw.SimpleText(Up(entry.name), "nwCmtText", rh * 0.4, rh / 2, reached and TEXT or DIM, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
				draw.SimpleText(entry.xp .. " ОПЫТА", "nwCmtSmall", rw - rh * 0.4, rh / 2, DIM, TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			end
		end

		local y = #CW.ranks * (rowH + 4) + h * 0.03

		CT.Label(area, me:GetNW2Bool("nwFactoryHired", false) and ("Ваш опыт: " .. xp) or "Вы не оформлены: отдел кадров",
			0, y, "nwCmtText", TEXT)
		CT.Button(area, "Инструкция завода", 0, y + h * 0.06, w * 0.4, h * 0.075, function()
			CW.ShowInstruction()
		end, true)
	end
}

CT.screens.cwu = SCREEN

-- ------------------------------------------------------------------ marks --
surface.CreateFont("nwCwuMark", {font = "Montserrat SemiBold", size = math.max(11, math.Round(ScrH() * 0.014)),
	weight = 600, extended = true, antialias = true})

hook.Add("HUDPaint", "nwCwuMarks", function()
	local me = LocalPlayer()

	if (!IsValid(me) or !CW.IsCWU(me) or !me:Alive()) then
		return
	end

	local sh = ScrH()
	local size = math.Round(sh * 0.026)

	local function Mark(entity, icon, color)
		local distance = Meters(entity)

		if (distance > 120) then
			return
		end

		local screen = (entity:WorldSpaceCenter() + Vector(0, 0, 24)):ToScreen()

		if (!screen.visible) then
			return
		end

		local pulse = 0.75 + 0.25 * math.sin(RealTime() * 3)

		draw.RoundedBox(6, screen.x - size * 0.7, screen.y - size * 0.7, size * 1.4, size * 1.4, Color(12, 14, 18, 190))
		U.DrawIcon(icon, screen.x - size / 2, screen.y - size / 2, size, ColorAlpha(color, 255 * pulse))
		draw.SimpleTextOutlined(distance .. " м", "nwCwuMark", screen.x, screen.y + size * 0.9, color, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 170))
	end

	local class = CW.Class(me)

	for _, entity in ipairs(Broken()) do
		if (class != "icu") then
			Mark(entity, "tool", AMBER)
		end
	end

	for _, entity in ipairs(Outbreaks()) do
		if (class != "worker" or Meters(entity) < 30) then
			Mark(entity, "biohazard", GREEN)
		end
	end
end)

-- ----------------------------------------------------------- the instruction --
surface.CreateFont("nwFactoryHead", {font = "Montserrat SemiBold", size = math.max(14, math.Round(ScrH() * 0.026)),
	weight = 600, extended = true, antialias = true})
surface.CreateFont("nwFactorySection", {font = "Montserrat SemiBold", size = math.max(12, math.Round(ScrH() * 0.019)),
	weight = 600, extended = true, antialias = true})
surface.CreateFont("nwFactoryBody", {font = "Exo 2", size = math.max(11, math.Round(ScrH() * 0.0165)), weight = 500,
	extended = true, antialias = true})

local function Window(title, w, h)
	local frame = vgui.Create("EditablePanel")
	local sw, sh = ScrW(), ScrH()

	frame:SetSize(w, h)
	frame:SetPos((sw - w) / 2, (sh - h) / 2)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.born = RealTime()
	frame.Paint = function(self, pw, ph)
		local a = math.Clamp((RealTime() - self.born) / 0.2, 0, 1)

		U.Blur(0, 0, pw, ph, 3, 255 * a, self, 10)
		draw.RoundedBox(10, 0, 0, pw, ph, Color(15, 17, 21, 240 * a))
		draw.RoundedBox(2, 0, 0, pw, 3, ColorAlpha(AMBER, 255 * a))
		U.DrawIcon("factory", sh * 0.026, sh * 0.026, sh * 0.034, ColorAlpha(AMBER, 255 * a))
		draw.SimpleText(title, "nwFactoryHead", sh * 0.072, sh * 0.043, ColorAlpha(U.color.text, 255 * a), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local close = NW.widgets.Button(frame, "✕", function()
		frame:Remove()
	end)

	close:SetSize(sh * 0.04, sh * 0.04)
	close:SetPos(w - sh * 0.062, sh * 0.022)

	return frame
end

-- the pages of the instruction
local BODY = Color(208, 212, 218)
local FAINT = Color(150, 154, 160)
local PAGES = {}

-- the paragraph of a page, wrapped; returns the height used
local function Paragraph(text, x, y, w, color)
	local lineH = math.Round(ScrH() * 0.025)

	for index, line in ipairs(NW.inventory.WrapText(text, "nwFactoryBody", w)) do
		draw.SimpleText(line, "nwFactoryBody", x, y + (index - 1) * lineH, color or BODY, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	return #NW.inventory.WrapText(text, "nwFactoryBody", w) * lineH
end

local function ItemName(id)
	local item = id and I.Get(id)

	return item and item.name or id
end

-- steps: a number in a circle, a title, the text
function PAGES.steps(section, w)
	local sh = ScrH()
	local out = {}

	for index, step in ipairs(section.steps) do
		out[#out + 1] = function(y)
			local size = sh * 0.036

			draw.RoundedBox(size / 2, 0, y, size, size, AMBER)
			draw.SimpleText(index, "nwFactorySection", size / 2, y + size / 2, Color(20, 16, 10), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(step[1], "nwFactorySection", size + sh * 0.016, y + size / 2, U.color.text, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			return size + sh * 0.008 + Paragraph(step[2], size + sh * 0.016, y + size + sh * 0.004, w - size - sh * 0.02) +
				sh * 0.02
		end
	end

	return out
end

-- the line: the stations as cards with arrows, what goes in and out
function PAGES.line(section, w)
	local sh = ScrH()

	return {function(y)
		local count = #CW.order
		local gap = sh * 0.026
		local cw = (w - gap * (count - 1)) / count
		local ch = sh * 0.26

		for index, id in ipairs(CW.order) do
			local station = CW.stations[id]
			local x = (index - 1) * (cw + gap)
			local take = {}

			for item, amount in pairs(station.take) do
				take[#take + 1] = amount .. " × " .. ItemName(item)
			end

			if (station.buys) then
				take[#take + 1] = "любую продукцию линии"
			end

			draw.RoundedBox(8, x, y, cw, ch, Color(255, 255, 255, 9))
			draw.RoundedBox(2, x, y, cw, 3, AMBER)
			draw.SimpleText(index, "nwFactoryHead", x + sh * 0.014, y + sh * 0.03, AMBER, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local ty = y + sh * 0.055

			for _, line in ipairs(NW.inventory.WrapText(station.name, "nwFactorySection", cw - sh * 0.028)) do
				draw.SimpleText(line, "nwFactorySection", x + sh * 0.014, ty, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				ty = ty + sh * 0.024
			end

			ty = ty + sh * 0.008
			draw.SimpleText("берёт", "nwFactoryBody", x + sh * 0.014, ty, FAINT)
			ty = ty + sh * 0.022
			ty = ty + Paragraph(#take > 0 and table.concat(take, ", ") or "ничего", x + sh * 0.014, ty, cw - sh * 0.028)
			draw.SimpleText("даёт", "nwFactoryBody", x + sh * 0.014, ty + sh * 0.004, FAINT)
			ty = ty + sh * 0.026
			ty = ty + Paragraph(station.give and ItemName(station.give) or "токены", x + sh * 0.014, ty, cw - sh * 0.028,
				GREEN)
			draw.SimpleText(station.time .. " с  ·  от «" .. CW.ranks[station.rank].name .. "»", "nwFactoryBody",
				x + sh * 0.014, y + ch - sh * 0.026, FAINT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			-- the arrow to the next one
			if (index < count) then
				draw.SimpleText("›", "nwFactoryHead", x + cw + gap / 2, y + ch / 2, AMBER, TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)
			end
		end

		return ch + sh * 0.025 + Paragraph(section.text, 0, y + ch + sh * 0.02, w)
	end}
end

-- a table: the heads, the rows
local function Table(y, w, heads, rows, widths)
	local sh = ScrH()
	local rowH = sh * 0.04
	local x = 0

	draw.RoundedBox(6, 0, y, w, rowH, Color(255, 255, 255, 12))

	for index, head in ipairs(heads) do
		draw.SimpleText(head, "nwFactorySection", x + sh * 0.012, y + rowH / 2, AMBER, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		x = x + w * widths[index]
	end

	for row, cells in ipairs(rows) do
		local ry = y + row * rowH

		if (row % 2 == 0) then
			draw.RoundedBox(0, 0, ry, w, rowH, Color(255, 255, 255, 5))
		end

		x = 0

		for index, cell in ipairs(cells) do
			draw.SimpleText(cell, "nwFactoryBody", x + sh * 0.012, ry + rowH / 2, index == 1 and U.color.text or BODY,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			x = x + w * widths[index]
		end
	end

	return (#rows + 1) * rowH
end

function PAGES.ranks(section, w)
	local sh = ScrH()

	return {function(y)
		local rows = {}

		for index, rank in ipairs(CW.ranks) do
			local opens = {}

			for _, id in ipairs(CW.order) do
				if (CW.stations[id].rank == index) then
					opens[#opens + 1] = CW.stations[id].name
				end
			end

			rows[#rows + 1] = {rank.name, rank.xp .. " опыта", #opens > 0 and table.concat(opens, ", ") or
				(index == #CW.ranks and "+25% к оплате" or "меньше брака")}
		end

		local used = Table(y, w, {"Ранг", "Нужно", "Открывает"}, rows, {0.28, 0.2, 0.52})

		return used + sh * 0.02 + Paragraph(section.text, 0, y + used + sh * 0.02, w)
	end}
end

function PAGES.pay(section, w)
	local sh = ScrH()
	local skills = {strength = "Сила", engineering = "Инженерия"}

	return {function(y)
		local rows = {}

		for _, id in ipairs(CW.order) do
			local station = CW.stations[id]

			local pay, xp = station.pay .. " ток.", "+" .. station.xp

			if (station.buys) then
				pay, xp = "1–14 ток.", "+1–8"
			end

			rows[#rows + 1] = {station.name, pay, xp, skills[station.skill] or station.skill, station.time .. " с"}
		end

		local used = Table(y, w, {"Станция", "Оплата", "Опыт", "Навык", "Время"}, rows, {0.36, 0.16, 0.12, 0.22, 0.14})

		return used + sh * 0.02 + Paragraph(section.text, 0, y + used + sh * 0.02, w)
	end}
end

function CW.ShowInstruction(startID)
	if (IsValid(CW.help)) then
		CW.help:Remove()
	end

	local sh = ScrH()
	local w, h = math.min(ScrW() - 40, math.Round(sh * 1.3)), math.Round(sh * 0.82)
	local frame = Window("Завод: инструкция", w, h)
	local pad = math.Round(sh * 0.03)
	local navW = math.Round(w * 0.24)
	local top = sh * 0.085
	local page = vgui.Create("DScrollPanel", frame)

	page:SetPos(pad + navW + pad, top)
	page:SetSize(w - navW - pad * 3, h - top - pad)
	CW.help = frame

	local current

	local function Open(section)
		current = section
		page:Clear()

		local pw = page:GetWide() - 16
		local blocks = section.steps and PAGES.steps(section, pw) or PAGES[section.id](section, pw)
		local canvas = page:Add("DPanel")

		canvas:Dock(TOP)
		canvas:SetTall(h)
		canvas.Paint = function(self)
			draw.SimpleText(section.title, "nwFactoryHead", 0, 0, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local y = sh * 0.05

			for _, Block in ipairs(blocks) do
				y = y + Block(y)
			end

			if (math.abs(self:GetTall() - y) > 2) then
				self:SetTall(y)
			end
		end

		surface.PlaySound("network2/ui/hover.wav")
	end

	for index, section in ipairs(CW.instruction) do
		local button = vgui.Create("DButton", frame)

		button:SetText("")
		button:SetPos(pad, top + (index - 1) * (sh * 0.056))
		button:SetSize(navW, sh * 0.048)
		button.Paint = function(self, bw, bh)
			local active = current == section

			draw.RoundedBox(6, 0, 0, bw, bh, active and Color(232, 170, 64, 40) or (self:IsHovered() and
				Color(255, 255, 255, 14) or Color(255, 255, 255, 6)))

			if (active) then
				draw.RoundedBox(2, 0, 0, 3, bh, AMBER)
			end

			U.DrawIcon(section.icon, bh * 0.25, bh * 0.25, bh * 0.5, active and AMBER or FAINT)
			draw.SimpleText(section.title, "nwFactoryBody", bh * 0.95, bh / 2, active and U.color.text or BODY,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
		button.DoClick = function()
			Open(section)
		end

		if (section.id == startID or (!startID and index == 1)) then
			Open(section)
		end
	end
end

net.Receive("nwFactoryHelp", function()
	CW.ShowInstruction()
end)

-- --------------------------------------------------------------- the office --
net.Receive("nwFactoryOffice", function()
	local npc = net.ReadEntity()
	local hired = net.ReadBool()
	local xp = net.ReadUInt(20)
	local made = net.ReadUInt(20)

	if (NW.npcUI and NW.npcUI.Close) then
		NW.npcUI.Close()
	end

	if (IsValid(CW.office)) then
		CW.office:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.62), math.Round(sh * 0.46)
	local frame = Window("Отдел кадров завода", w, h)
	local pad = math.Round(sh * 0.03)
	local rank = CW.Rank(xp)
	local nextRank = CW.ranks[rank + 1]

	CW.office = frame

	local info = frame:Add("DPanel")

	info:SetPos(pad, sh * 0.09)
	info:SetSize(w - pad * 2, h * 0.5)
	info.Paint = function(_, iw, ih)
		draw.SimpleText(hired and "Вы работаете на заводе" or "Вы не оформлены", "nwFactorySection", 0, sh * 0.012,
			hired and GREEN or U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Ранг: " .. CW.ranks[rank].name .. "   ·   опыт " .. xp .. "   ·   операций " .. made, "nwFactoryBody", 0,
			sh * 0.05, Color(208, 212, 218), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (nextRank) then
			local fraction = math.Clamp((xp - CW.ranks[rank].xp) / (nextRank.xp - CW.ranks[rank].xp), 0, 1)

			draw.RoundedBox(3, 0, sh * 0.075, iw, 6, Color(255, 255, 255, 18))
			draw.RoundedBox(3, 0, sh * 0.075, iw * fraction, 6, AMBER)
			draw.SimpleText("До ранга «" .. nextRank.name .. "»: " .. (nextRank.xp - xp) .. " опыта", "nwFactoryBody", 0,
				sh * 0.1, Color(160, 164, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		draw.SimpleText("Станции и роли открываются с рангом. Подробно — в инструкции.", "nwFactoryBody", 0, sh * 0.14,
			Color(160, 164, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	local function Hire(bHire)
		net.Start("nwFactoryHire")
			net.WriteEntity(npc)
			net.WriteBool(bHire)
		net.SendToServer()
		frame:Remove()
	end

	local bw, bh = (w - pad * 2 - 16) / 3, sh * 0.046
	local by = h - pad - bh

	local hire = NW.widgets.Button(frame, hired and "Уволиться" or "Оформиться", function()
		Hire(!hired)
	end, !hired)

	hire:SetPos(pad, by)
	hire:SetSize(bw, bh)

	local help = NW.widgets.Button(frame, "Инструкция", function()
		CW.ShowInstruction()
	end)

	help:SetPos(pad + bw + 8, by)
	help:SetSize(bw, bh)

	local close = NW.widgets.Button(frame, "Закрыть", function()
		frame:Remove()
	end)

	close:SetPos(pad + (bw + 8) * 2, by)
	close:SetSize(bw, bh)
end)
