-- What is happening to the character, seen.
--   status icons   a column of small icons in the middle of the right (or left: Настройки →
--                  Интерфейс → nw_status_side) edge: обыск, оглушение, ранение, голод, жажда,
--                  усталость, радиация, бой, радиопередача. A new one slides in with a card (the name
--                  and what it means) for a few seconds, then stays as an icon. nw_status_icons 0 - off.
--   the unit card  looking at a unit of the Alliance close by: a card on the right - ИМЯ // ФРАКЦИЯ //
--                  УКАЗАНИЕ (what to do: подчиняться, защищать, содействовать...), typed out.
--                  nw_unit_panel 0 - off.
--   Состояние      a page of the inventory (Q → Меню состояния): the character, the health, the
--                  needs, the statuses with their explanation and the medical things of the inventory
--                  to use right there.

NW.status = NW.status or {}

local ST = NW.status
local U = NW.ui
local I = NW.items

local enabled = CreateClientConVar("nw_status_icons", "1", true, false, "Иконки статуса")
local side = CreateClientConVar("nw_status_side", "right", true, false, "Иконки статуса: right / left")
local unitPanel = CreateClientConVar("nw_unit_panel", "1", true, false, "Карточка юнита при наведении")

local MUTED = Color(124, 128, 134)
local CARD = Color(16, 20, 26, 236)
local LINE = Color(60, 70, 86)
local ORANGE = Color(236, 164, 80)
local RED = Color(232, 92, 80)
local BLUE = Color(96, 200, 255)
local GREEN = Color(130, 220, 140)
local YELLOW = Color(236, 206, 90)

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwStatusTitle", "Montserrat SemiBold", 0.019, 700)
	F("nwStatusText", "Exo 2", 0.0155, 500)
	F("nwUnitHead", "JetBrains Mono ExtraBold", 0.0135, 800)
	F("nwUnitText", "JetBrains Mono Medium", 0.018, 500)
	F("nwStatePage", "Montserrat SemiBold", 0.017, 600)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwStatusFonts", Fonts)

-- ---------------------------------------------------------------- statuses --
ST.list = {
	{id = "search", icon = "st_search", color = ORANGE, title = "Обыск", text = "Другой персонаж обыскивает вас.",
		Active = function(c) return c:GetNW2Float("nwSearchedUntil", 0) > CurTime() end},
	{id = "stun", icon = "st_stun", color = BLUE, title = "Оглушение",
		text = "Удар электрошоком. Ещё несколько — и вы потеряете сознание.",
		Active = function(c) return c:GetNW2Float("nwStunnedUntil", 0) > CurTime() end},
	{id = "wounded", icon = "st_wounded", color = RED, title = "Ранение",
		text = "Здоровье ниже половины. Перевяжитесь или найдите медика.",
		Active = function(c) return c:Health() < c:GetMaxHealth() * 0.5 end},
	{id = "hunger", icon = "hunger", color = YELLOW, title = "Голод", text = "Персонаж голоден: поешьте.",
		Active = function(c) return c.GetHunger and c:GetHunger() < 20 end},
	{id = "thirst", icon = "thirst", color = BLUE, title = "Жажда",
		text = "Персонаж хочет пить. Без воды стамина тает быстрее.",
		Active = function(c) return c.GetThirst and c:GetThirst() < 20 end},
	{id = "tired", icon = "st_tired", color = MUTED, title = "Усталость", text = "Нет сил бежать: отдышитесь.",
		Active = function(c) return c.GetStamina and c:GetStamina() < 15 end},
	{id = "radiation", icon = "st_radiation", color = GREEN, title = "Радиация",
		text = "Зона заражения. Нужен противогаз — или уходите.",
		Active = function(c) return c:GetNW2Bool("nwRadiation", false) and !c:GetNW2Bool("nwRadSafe", false) end},
	{id = "combat", icon = "st_combat", color = RED, title = "Бой",
		text = "Вокруг стреляют. Вид от первого лица, пока не утихнет.",
		Active = function() return NW.combatUntil != nil and NW.combatUntil > CurTime() end},
	{id = "radio", icon = "st_broadcast", color = BLUE, title = "Радиопередача",
		text = "Ваш голос идёт в эфир рации.",
		Active = function(c) return c:GetNW2Bool("nwRadioTalk", false) end}
}

-- the statuses of the local player now
function ST.Active()
	local client = LocalPlayer()
	local out = {}

	if (!IsValid(client) or !client:Alive() or client:GetCharacterID() == 0) then
		return out
	end

	for _, status in ipairs(ST.list) do
		if (status.Active(client)) then
			out[#out + 1] = status
		end
	end

	return out
end

local shown = {}

local function Wrap(text, font, width)
	surface.SetFont(font)

	local lines, line = {}, ""

	for word in string.gmatch(text, "%S+") do
		local test = line == "" and word or (line .. " " .. word)

		if (surface.GetTextSize(test) > width and line != "") then
			lines[#lines + 1] = line
			line = word
		else
			line = test
		end
	end

	lines[#lines + 1] = line

	return lines
end

hook.Add("HUDPaint", "nwStatusIcons", function()
	if (!enabled:GetBool() or (NW.menu and NW.menu.active)) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local active = ST.Active()
	local now = RealTime()
	local size = math.Round(sh * 0.042)
	local gap = math.Round(sh * 0.008)
	local left = side:GetString() == "left"
	local margin = math.Round(sh * 0.02)
	local present = {}

	for _, status in ipairs(active) do
		present[status.id] = true

		if (!shown[status.id]) then
			shown[status.id] = {since = now, a = 0}
		end
	end

	for id, entry in pairs(shown) do
		if (!present[id]) then
			entry.a = math.Approach(entry.a, 0, FrameTime() * 5)

			if (entry.a <= 0) then
				shown[id] = nil
			end
		else
			entry.a = math.Approach(entry.a, 1, FrameTime() * 5)
		end
	end

	local list = {}

	for _, status in ipairs(ST.list) do
		if (shown[status.id]) then
			list[#list + 1] = status
		end
	end

	local total = #list * size + math.max(0, #list - 1) * gap
	local y = sh * 0.5 - total / 2

	for _, status in ipairs(list) do
		local entry = shown[status.id]
		local a = entry.a
		local slide = (1 - a) * size
		local x = left and (margin - slide) or (sw - margin - size + slide)

		draw.RoundedBox(8, x, y, size, size, Color(CARD.r, CARD.g, CARD.b, CARD.a * a))
		draw.RoundedBox(2, left and x or (x + size - 3), y + size * 0.2, 3, size * 0.6, ColorAlpha(status.color, 255 * a))
		U.DrawIcon(status.icon, x + size * 0.2, y + size * 0.2, size * 0.6, ColorAlpha(status.color, 255 * a))

		-- the card of a new one for 4 seconds
		local age = now - entry.since

		if (age < 4.5 and present[status.id]) then
			local open = math.Clamp(age / 0.25, 0, 1) * math.Clamp((4.5 - age) / 0.4, 0, 1)
			local cw = math.Round(sh * 0.3)
			local lines = Wrap(status.text, "nwStatusText", cw - sh * 0.04)
			local ch = math.Round(sh * 0.05 + #lines * sh * 0.021)
			local cx = left and (x + size + gap) or (x - gap - cw)
			local cy = y + size / 2 - ch / 2

			draw.RoundedBox(8, cx, cy, cw, ch, Color(CARD.r, CARD.g, CARD.b, CARD.a * open))
			surface.SetDrawColor(LINE.r, LINE.g, LINE.b, 255 * open)
			surface.DrawOutlinedRect(cx, cy, cw, ch, 1)
			draw.SimpleText(status.title, "nwStatusTitle", cx + sh * 0.02, cy + sh * 0.024,
				Color(240, 242, 246, 255 * open), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			for index, line in ipairs(lines) do
				draw.SimpleText(line, "nwStatusText", cx + sh * 0.02, cy + sh * 0.05 + (index - 1) * sh * 0.021,
					Color(200, 204, 210, 255 * open), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end

		y = y + size + gap
	end
end)

-- ---------------------------------------------------------------- the unit card --
local card = {target = nil, a = 0, since = 0}

local function Advice(viewer, unit)
	local unitSide = NW.squads.Side(unit)

	if (NW.zones.IsAlliance(viewer)) then
		local mine = NW.squads.Of(viewer)

		if (mine and NW.squads.Of(unit) == mine) then
			return "ЗАЩИЩАТЬ :: ВАШ ОТРЯД", NW.squads.colors.leader
		elseif (NW.squads.Side(viewer) == unitSide) then
			return "ПРИКРЫВАТЬ", BLUE
		end

		return "СОДЕЙСТВОВАТЬ", BLUE
	elseif (viewer:GetFaction() == "cwu") then
		return "СОДЕЙСТВОВАТЬ :: ВЫПОЛНЯТЬ УКАЗАНИЯ", ORANGE
	end

	if (unitSide == "ota") then
		return "НЕ ПРИБЛИЖАТЬСЯ :: ПОДЧИНЯТЬСЯ", RED
	end

	return "ПОДЧИНЯТЬСЯ", ORANGE
end

-- who is looked at: chosen in the HUD pass, drawn in the world (beside the unit, a line from the chest)
hook.Add("Think", "nwUnitCard", function()
	local client = LocalPlayer()

	if (!unitPanel:GetBool() or !IsValid(client) or !client:Alive() or client:GetCharacterID() == 0) then
		card.target = nil
		card.a = 0

		return
	end

	local trace = client:GetEyeTrace()
	local target = trace.Entity
	local valid = IsValid(target) and target:IsPlayer() and target:Alive() and target != client and
		NW.zones.IsAlliance(target) and target:GetPos():DistToSqr(client:GetPos()) < 320 * 320 and
		!(NW.Hidden and NW.Hidden(target))

	if (valid) then
		if (card.target != target) then
			card.since = RealTime()
		end

		card.target = target
		card.lost = nil
	elseif (card.target and !card.lost) then
		card.lost = RealTime()
	end

	if (card.lost and RealTime() - card.lost > 1) then
		card.target = nil
	end

	card.a = math.Approach(card.a, card.target and !card.lost and 1 or 0, FrameTime() * 5)
end)

-- the card itself, in its own pixels (0, 0 - the top left)
local function DrawCard(w, h, rowH, lines, color, faction, e)
	local sh = ScrH()

	draw.RoundedBox(6, 0, 0, w, h, Color(10, 14, 20, 225 * e))
	surface.SetDrawColor(color.r, color.g, color.b, 255 * e)
	surface.DrawRect(0, 0, w, 3)
	surface.SetDrawColor(LINE.r, LINE.g, LINE.b, 200 * e)
	surface.DrawOutlinedRect(0, 0, w, h, 1)

	if (faction.logo) then
		surface.SetMaterial(U.Material("network2/factions/" .. faction.logo .. ".png"))
		surface.SetDrawColor(color.r, color.g, color.b, 200 * e)
		surface.DrawTexturedRect(w - sh * 0.05, sh * 0.014, sh * 0.036, sh * 0.036)
	end

	draw.SimpleText("ЛОКАЛЬНЫЕ ДАННЫЕ ЮНИТА", "nwUnitHead", sh * 0.018, sh * 0.032, Color(150, 160, 172, 255 * e),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- typed out, line by line
	local age = RealTime() - card.since
	local budget = math.floor(age * 60)

	for index, line in ipairs(lines) do
		local ly = sh * 0.07 + (index - 1) * rowH
		local text = line[2]
		local length = utf8.len(text) or #text
		local part = budget >= length and text or string.sub(text, 1, (utf8.offset(text, math.max(budget, 0) + 1) or 1) - 1)

		budget = budget - length

		draw.SimpleText(line[1] .. " //", "nwUnitHead", sh * 0.018, ly, Color(120, 130, 142, 255 * e), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(part, "nwUnitText", sh * 0.018, ly + sh * 0.021, ColorAlpha(line[3], 255 * e), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end
end

-- the card in the world: it stands to the side of the unit (the side of nw_status_side), facing the
-- eye, over the walls; a thin line goes from the chest of the unit to it
local WIDTH = 20

hook.Add("PostDrawTranslucentRenderables", "nwUnitCard", function(_, bSkybox)
	local unit = card.target

	if (bSkybox or card.a <= 0.01 or !IsValid(unit)) then
		return
	end

	local client = LocalPlayer()
	local sh = ScrH()
	local faction = NW.char.factions[unit:GetFaction()] or {}
	local color = faction.color or BLUE
	local advice, adviceColor = Advice(client, unit)
	local lines = {
		{"ИМЯ", NW.terminal.Upper(unit:Nick()), Color(232, 240, 246)},
		{"ФРАКЦИЯ", NW.terminal.Upper(faction.name or "Альянс") .. (unit:GetNW2String("nwClassName", "") != "" and
			("  ·  " .. NW.terminal.Upper(unit:GetNW2String("nwClassName", ""))) or ""), color},
		{"УКАЗАНИЕ", advice, adviceColor}
	}
	local w = math.Round(sh * 0.36)
	local rowH = math.Round(sh * 0.05)
	local h = math.Round(sh * 0.07 + #lines * rowH)
	local scale = WIDTH / w
	local e = card.a

	-- upright, turned to the eye (only the yaw: the card does not lean)
	local yaw = EyeAngles().y
	local right, up = Angle(0, yaw, 0):Right(), Vector(0, 0, 1)
	local toSide = side:GetString() == "left" and -1 or 1
	local chest = unit:WorldSpaceCenter() + Vector(0, 0, 10)
	-- the card: beside the unit, sliding out as it appears
	local corner = chest + right * toSide * (16 + 6 * e) + up * (h * scale * 0.5 + 4)

	if (toSide < 0) then
		corner = corner - right * WIDTH
	end

	local edge = corner + right * (toSide > 0 and 0 or WIDTH) - up * (h * scale * 0.5)
	local angle = Angle(0, yaw - 90, 90)

	cam.IgnoreZ(true)
		-- the line and its dot on the chest
		render.SetColorMaterial()
		render.DrawLine(chest, edge, ColorAlpha(color, 200 * e), false)
		render.DrawSphere(chest, 0.6, 8, 8, ColorAlpha(color, 230 * e))

		cam.Start3D2D(corner, angle, scale)
			DrawCard(w, h, rowH, lines, color, faction, e)
		cam.End3D2D()
	cam.IgnoreZ(false)
end)

-- ----------------------------------------------------------- the page (Q) --
local function Bar(x, y, w, label, value, color)
	local sh = ScrH()

	draw.SimpleText(label, "nwStatePage", x, y, Color(220, 224, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(math.Round(value) .. "%", "nwStatePage", x + w, y, MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	draw.RoundedBox(3, x, y + sh * 0.016, w, math.max(5, sh * 0.007), Color(255, 255, 255, 18))
	draw.RoundedBox(3, x, y + sh * 0.016, w * math.Clamp(value / 100, 0, 1), math.max(5, sh * 0.007), color)
end

local function Medical()
	local out = {}
	local data = NW.inventory.data

	for index = 1, I.maxSize do
		local cell = data and data.grid and data.grid[index]
		local item = cell and I.Get(cell.id)

		if (NW.medical.IsMedical(item)) then
			out[#out + 1] = {index = index, item = item}
		end
	end

	return out
end

local function StatusPage(parent)
	local sw, sh = ScrW(), ScrH()
	local w, h = math.Round(sh * 1.0), math.Round(sh * 0.66)
	local page = parent:Add("EditablePanel")
	local client = LocalPlayer()

	page:SetSize(w, h)
	page.baseX, page.baseY = math.Round((sw - w) / 2), math.Round((sh - h) / 2 + sh * 0.02)
	page:SetPos(page.baseX, page.baseY)

	local pad = math.Round(sh * 0.03)
	local modelW = math.Round(w * 0.36)
	local rx = modelW + pad
	local rw = w - rx - pad

	page.Paint = function(self, pw, ph)
		U.Blur(0, 0, pw, ph, 3, 255, self, 10)
		draw.RoundedBox(10, 0, 0, pw, ph, Color(14, 17, 21, 230))
		U.DrawIcon("status", pad, pad, sh * 0.03, U.color.text)
		draw.SimpleText("СОСТОЯНИЕ", "nwInvTitle", pad + sh * 0.042, pad + sh * 0.015, U.color.text, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
		surface.SetDrawColor(255, 255, 255, 22)
		surface.DrawRect(pad, pad + sh * 0.045, pw - pad * 2, 1)

		-- the vitals
		local y = pad + sh * 0.08

		Bar(rx, y, rw, "Здоровье", client:Health() / math.max(client:GetMaxHealth(), 1) * 100, Color(222, 86, 74))
		Bar(rx, y + sh * 0.05, rw, "Сытость", client.GetHunger and client:GetHunger() or 100, Color(226, 180, 80))
		Bar(rx, y + sh * 0.1, rw, "Вода", client.GetThirst and client:GetThirst() or 100, Color(90, 170, 240))
		Bar(rx, y + sh * 0.15, rw, "Стамина", client.GetStamina and client:GetStamina() or 100, Color(140, 210, 150))

		-- the statuses
		local sy = y + sh * 0.21

		draw.SimpleText("СОСТОЯНИЯ", "nwStatusTitle", rx, sy, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		sy = sy + sh * 0.032

		local active = ST.Active()

		if (#active == 0) then
			draw.SimpleText("Всё в порядке.", "nwStatusText", rx, sy, Color(170, 200, 170), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end

		for index, status in ipairs(active) do
			if (index > 4) then
				break
			end

			U.DrawIcon(status.icon, rx, sy - sh * 0.012, sh * 0.024, status.color)
			draw.SimpleText(status.title .. " — " .. status.text, "nwStatusText", rx + sh * 0.034, sy, Color(210, 214, 220),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			sy = sy + sh * 0.03
		end

		-- the treatment
		draw.SimpleText("ЛЕЧЕНИЕ", "nwStatusTitle", rx, ph - pad - sh * 0.1, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (#Medical() == 0) then
			draw.SimpleText("В инвентаре нет бинтов, аптечек и таблеток.", "nwStatusText", rx, ph - pad - sh * 0.06, MUTED,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		-- the name under the model
		draw.SimpleText(client:Nick(), "nwStatePage", pad + modelW / 2, ph - pad - sh * 0.04, U.color.text,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local faction = NW.char.factions[client:GetFaction()]

		draw.SimpleText(faction and faction.name or "", "nwStatusText", pad + modelW / 2, ph - pad - sh * 0.015,
			faction and faction.color or MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- the character, turning slowly
	local model = page:Add("DModelPanel")

	model:SetPos(pad, pad + sh * 0.06)
	model:SetSize(modelW - pad, h - pad * 2 - sh * 0.12)
	model:SetModel(client:GetModel())
	model:SetFOV(30)
	model:SetMouseInputEnabled(false)

	local entity = model:GetEntity()

	if (IsValid(entity)) then
		entity:SetSkin(client:GetSkin())

		for _, group in ipairs(client:GetBodyGroups() or {}) do
			entity:SetBodygroup(group.id, client:GetBodygroup(group.id))
		end

		local sequence = entity:LookupSequence("idle_all_01")

		if (sequence and sequence > 0) then
			entity:ResetSequence(sequence)
		end
	end

	model:SetCamPos(Vector(110, 0, 44))
	model:SetLookAt(Vector(0, 0, 38))
	model.LayoutEntity = function(self, ent)
		ent:SetAngles(Angle(0, RealTime() * 18 % 360, 0))
		self:RunAnimation()
	end

	-- the medical things: a click uses them
	local function Treatment()
		if (IsValid(page.treat)) then
			page.treat:Remove()
		end

		local holder = page:Add("EditablePanel")

		holder:SetPos(rx, h - pad - sh * 0.085)
		holder:SetSize(rw, sh * 0.06)
		page.treat = holder

		local size = math.Round(sh * 0.058)

		for index, entry in ipairs(Medical()) do
			if (index > 8) then
				break
			end

			local button = holder:Add("DButton")

			button:SetPos((index - 1) * (size + 8), 0)
			button:SetSize(size, size)
			button:SetText("")
			button:SetTooltip(entry.item.name .. " — +" .. entry.item.heal .. " здоровья")
			button.Paint = function(self, bw, bh)
				draw.RoundedBox(6, 0, 0, bw, bh, Color(255, 255, 255, self:IsHovered() and 30 or 12))

				local icon = I.IconMaterial(entry.item)

				surface.SetMaterial(icon)
				surface.SetDrawColor(255, 255, 255, 235)
				surface.DrawTexturedRect(bw * 0.18, bh * 0.18, bw * 0.64, bh * 0.64)
			end
			button.DoClick = function()
				U.Tick()
				NW.inventory.Action("g" .. entry.index, "use")

				timer.Simple(0.6, function()
					if (IsValid(page)) then
						Treatment()
					end
				end)
			end
		end
	end

	Treatment()

	return page
end

hook.Add("Initialize", "nwStatusPage", function()
	NW.inventory.extraPages = NW.inventory.extraPages or {}
	NW.inventory.extraPages.status = StatusPage
end)

NW.inventory.extraPages = NW.inventory.extraPages or {}
NW.inventory.extraPages.status = StatusPage
