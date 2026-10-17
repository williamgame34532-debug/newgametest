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

function CW.ShowInstruction()
	if (IsValid(CW.help)) then
		CW.help:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.95), math.Round(sh * 0.8)
	local frame = Window("Завод: инструкция", w, h)
	local pad = math.Round(sh * 0.03)
	local scroll = NW.widgets.Scroll(frame)

	scroll:SetPos(pad, sh * 0.085)
	scroll:SetSize(w - pad * 2, h - sh * 0.085 - pad)
	CW.help = frame

	for _, section in ipairs(CW.instruction) do
		local lines = {}

		for _, paragraph in ipairs(section[2]) do
			local wrapped = NW.inventory.WrapText(paragraph, "nwFactoryBody", w - pad * 2 - sh * 0.06)

			for k, line in ipairs(wrapped) do
				lines[#lines + 1] = {text = line, first = k == 1}
			end
		end

		local block = scroll:Add("DPanel")
		local lineH = math.Round(sh * 0.025)

		block:Dock(TOP)
		block:DockMargin(0, 0, 8, sh * 0.018)
		block:SetTall(sh * 0.045 + #lines * lineH)
		block.Paint = function(_, bw, bh)
			draw.RoundedBox(8, 0, 0, bw, bh, Color(255, 255, 255, 7))
			draw.SimpleText(section[1], "nwFactorySection", sh * 0.018, sh * 0.024, AMBER, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			for index, line in ipairs(lines) do
				draw.SimpleText((line.first and "•  " or "    ") .. line.text, "nwFactoryBody", sh * 0.018,
					sh * 0.05 + (index - 1) * lineH, Color(208, 212, 218), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
	end
end

net.Receive("nwFactoryHelp", CW.ShowInstruction)

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
