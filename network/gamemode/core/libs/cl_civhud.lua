local compact = CreateClientConVar("network_compact_hud", "1", true, false)
local civ = CreateClientConVar("network_civ_hud", "1", true, false,
	"Новый HUD гражданских и вортигонтов")

local function IsCivilianHud(client)
	if (!civ:GetBool() or !IsValid(client) or !client:HasCharacter() or (client:IsCombine() and !compact:GetBool())) then
		return false
	end

	if (!compact:GetBool() and NETWORK.chud and NETWORK.chud.GetKind and NETWORK.chud.GetKind(client)) then
		return false
	end

	return true
end

hook.Add("NetworkShouldDrawHUD", "nwCivHud", function()
	if (IsCivilianHud(LocalPlayer())) then
		return false
	end
end)

local function Bar(x, y, width, label, fraction, color, value)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local height = math.max(Sc(3), 2)

	draw.SimpleText(label, "nwHudSmall", x, y, ColorAlpha(theme.textFaint, 220),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(value, "nwHudSmall", x + width, y, ColorAlpha(theme.text, 240),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 22)
	surface.DrawRect(x, y + Sc(10), width, height)

	surface.SetDrawColor(color.r, color.g, color.b, 235)
	surface.DrawRect(x, y + Sc(10), math.Round(width * math.Clamp(fraction, 0, 1)), height)

	return y + Sc(24)
end

local curfewHud = CreateClientConVar("network_curfew_hud", "1", true, false,
	"Показывать комендантский час вверху экрана")

NETWORK.curfewHud = NETWORK.curfewHud or {show = 0, kind = nil}

local CURFEW = NETWORK.curfewHud

CURFEW.warnBefore = 1
CURFEW.red = Color(214, 64, 56)
CURFEW.amber = Color(226, 166, 64)

local function FormatHours(hours)
	local minutes = math.max(math.floor(hours * 60 + 0.5), 0)

	return string.format("%d:%02d", math.floor(minutes / 60), minutes % 60)
end

local function FormatClock(hours)
	hours = hours % 24

	return string.format("%02d:%02d", math.floor(hours), math.floor((hours % 1) * 60))
end

-- Текущее состояние: "curfew" (идёт), "soon" (скоро начнётся) или nil.
function CURFEW.GetState()
	local schedule = NETWORK.schedule

	if (!schedule or !schedule.IsCurfew or !NETWORK.time) then
		return
	end

	local hours = NETWORK.time.GetHours()
	local level = schedule.GetAlertLevel and schedule.GetAlertLevel() or "green"
	local startAt = schedule.GetCurfewStart and schedule.GetCurfewStart() or 18
	local endAt = schedule.curfewEnd or 6

	if (schedule.IsCurfew()) then
		if (level == "red") then
			return "curfew", {bRed = true}
		end

		local total = (endAt - startAt) % 24
		local left = schedule.HoursUntil(endAt, hours)

		return "curfew", {left = left, total = total, endAt = endAt}
	end

	local untilStart = schedule.HoursUntil(startAt, hours)

	if (untilStart <= CURFEW.warnBefore) then
		return "soon", {left = untilStart, startAt = startAt}
	end
end

-- Плашка вверху по центру: красная во время комендантского часа, жёлтая — за час до него.
function CURFEW.Draw(fade)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local state, data = CURFEW.GetState()

	if (state) then
		CURFEW.kind, CURFEW.data = state, data
	end

	CURFEW.show = util.Approach(CURFEW.show, state and 1 or 0, 5)

	if (CURFEW.show < 0.01 or !CURFEW.kind) then
		return
	end

	state, data = CURFEW.kind, CURFEW.data or {}

	local show = util.EaseOut(CURFEW.show)
	local alpha = show * fade
	local bCurfew = state == "curfew"
	local accent = bCurfew and CURFEW.red or CURFEW.amber
	local pulse = 0.65 + math.abs(math.sin(CurTime() * (bCurfew and 2.2 or 1.4))) * 0.35
	local width = math.min(Sc(420), ScrW() - Sc(40))
	local height = Sc(62)
	local x = math.Round((ScrW() - width) * 0.5)
	local y = Sc(18) - math.Round((1 - show) * Sc(30))
	local title = util.Upper(bCurfew and L("curfewHud") or L("curfewSoon"))
	local hint = bCurfew and L("curfewHudHint") or L("curfewSoonHint")
	local timerText, timerCaption, progress

	if (bCurfew and data.bRed) then
		timerText = L("curfewUntilCancel")
		timerCaption = util.Upper(L("curfewRed"))
	elseif (bCurfew) then
		timerText = FormatHours(data.left or 0)
		timerCaption = util.Upper(L("curfewUntil", FormatClock(data.endAt or 6)))
		progress = 1 - (data.left or 0) / math.max(data.total or 12, 0.01)
	else
		timerText = FormatHours(data.left or 0)
		timerCaption = util.Upper(L("curfewIn", FormatClock(data.startAt or 18)))
		progress = 1 - (data.left or 0) / CURFEW.warnBefore
	end

	-- Плита
	surface.SetDrawColor(10, 11, 12, 215 * alpha)
	surface.DrawRect(x, y, width, height)

	if (NETWORK.tk and NETWORK.tk.Hatch) then
		NETWORK.tk.Hatch(x + 1, y + 1, width - 2, height - 2,
			Color(accent.r, accent.g, accent.b, 14 * alpha), Sc(8))
	end

	surface.SetDrawColor(accent.r, accent.g, accent.b, 120 * alpha)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	local stripe = math.max(Sc(4), 3)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * pulse * alpha)
	surface.DrawRect(x, y, stripe, height)

	-- Значок: треугольник с «!»
	local icon = Sc(26)
	local iconX = x + stripe + Sc(14)
	local iconY = y + math.Round((height - icon) * 0.5)

	draw.NoTexture()
	surface.SetDrawColor(accent.r, accent.g, accent.b, 235 * pulse * alpha)
	surface.DrawPoly({
		{x = iconX + math.Round(icon * 0.5), y = iconY},
		{x = iconX + icon, y = iconY + icon},
		{x = iconX, y = iconY + icon}
	})

	draw.SimpleText("!", "nwInvBodyBold", iconX + math.Round(icon * 0.5),
		iconY + math.Round(icon * 0.62), Color(12, 12, 12, 255 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	-- Заголовок и подсказка
	local textX = iconX + icon + Sc(14)
	local timerWidth = Sc(110)

	util.DrawTextSpaced(title, "nwHudLabel", textX, y + Sc(20),
		ColorAlpha(accent, 250 * alpha), Sc(2), TEXT_ALIGN_CENTER)

	draw.SimpleText(util.TruncateWidth(hint, "nwHudSmall", width - (textX - x) - timerWidth),
		"nwHudSmall", textX, y + Sc(40), Color(200, 200, 194, 225 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- Таймер справа
	local right = x + width - Sc(14)

	draw.SimpleText(timerText, "nwHudPlayer", right, y + Sc(22),
		Color(236, 234, 226, 250 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	draw.SimpleText(timerCaption, "nwHudSmall", right, y + Sc(43),
		Color(150, 150, 144, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- Прогресс по нижней кромке
	if (progress) then
		local barHeight = math.max(Sc(2), 2)
		local barX = x + stripe
		local barWidth = width - stripe

		surface.SetDrawColor(255, 255, 255, 18 * alpha)
		surface.DrawRect(barX, y + height - barHeight, barWidth, barHeight)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 230 * alpha)
		surface.DrawRect(barX, y + height - barHeight,
			math.Round(barWidth * math.Clamp(progress, 0, 1)), barHeight)
	end
end

hook.Add("HUDPaint", "nwCurfewHud", function()
	local client = LocalPlayer()

	if (!curfewHud:GetBool() or !IsValid(client) or !client:Alive() or
		!client:HasCharacter() or NETWORK.hud.IsHidden()) then
		return
	end

	-- У Альянса своя пометка в HUD, плашка нужна гражданским.
	if (client.IsCombine and client:IsCombine()) then
		return
	end

	if (IsValid(NETWORK.gui.menu) or IsValid(NETWORK.gui.tabMenu)) then
		return
	end

	local fade = NETWORK.hud.GetFade and NETWORK.hud.GetFade() or 1

	if (fade < 0.01) then
		return
	end

	CURFEW.Draw(fade)
end)

hook.Add("HUDPaint", "nwCivHud", function()
	local client = LocalPlayer()

	if (!IsCivilianHud(client) or !client:Alive() or NETWORK.hud.IsHidden()) then
		return
	end

	if (IsValid(NETWORK.gui.menu)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local fade = NETWORK.hud.GetFade()

	if (fade < 0.01) then
		return
	end

	local bVort = NETWORK.vort and NETWORK.vort.IsVort(client)
	local faction = NETWORK.factions.Get(client:GetCharacterFaction())
	local accent = bVort and Color(140, 245, 154) or (faction and faction.color or theme.accent)

	local x = Sc(26)
	local width = Sc(230)
	local y = ScrH() - Sc(26)

	local lines = {}

	local health = client:Health()
	local maxHealth = math.max(client:GetMaxHealth(), 1)
	local healthFraction = health / maxHealth
	local healthColor = healthFraction < 0.25 and theme.danger or
		(healthFraction < 0.5 and theme.warning or theme.positive)

	lines[#lines + 1] = {L("hudHealth"), healthFraction, healthColor, tostring(health)}

	if (bVort and NETWORK.vort.GetEnergy) then

		local energy = NETWORK.vort.IsHigh(client) and 1 or
			math.Clamp(NETWORK.vort.GetEnergy(client) / NETWORK.vort.energyMax, 0, 1)
		local radius = math.Round(ScrH() * 0.045)
		local centerX = ScrW() - Sc(26) - radius

		local centerY = y - Sc(30) - radius - (NETWORK.hud.GetBrandHeight and
			NETWORK.hud.GetBrandHeight() or Sc(40))

		util.DrawRing(centerX, centerY, radius, math.max(Sc(5), 3),
			Color(255, 255, 255, 22 * fade), 48)

		if (energy > 0.01) then

			util.DrawArc(centerX, centerY, radius, math.max(Sc(5), 3), energy,
				ColorAlpha(accent, 235 * fade), 48, -90)
		end

		draw.SimpleText(NETWORK.vort.IsHigh(client) and "∞" or
			tostring(math.floor(NETWORK.vort.GetEnergy(client))), "nwField",
			centerX, centerY - Sc(4), ColorAlpha(theme.text, 250 * fade),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.SimpleText(util.Upper(L("vortEnergy")), "nwHudSmall", centerX,
			centerY + Sc(12), ColorAlpha(accent, 200 * fade), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	elseif (client:Armor() > 0) then
		lines[#lines + 1] = {L("hudArmor"), client:Armor() / math.max(client:GetMaxArmor(), 1),
			theme.accent, tostring(client:Armor())}
	end

	if (NETWORK.stamina and NETWORK.stamina.Get) then
		local stamina = NETWORK.stamina.Get(client)

		if (stamina and (!compact:GetBool() or stamina < 99)) then
			lines[#lines + 1] = {L("hudStamina"), stamina / 100,
				stamina < 25 and theme.warning or theme.positive, tostring(math.floor(stamina))}
		end
	end

	local cursor = y

	for index = #lines, 1, -1 do
		local line = lines[index]

		cursor = cursor - Sc(24)

		Bar(x, cursor, width, line[1], line[2], line[3], line[4])
	end

	if (compact:GetBool()) then
		local weapon = client:GetActiveWeapon()
		if (IsValid(weapon) and weapon:Clip1() >= 0) then
			draw.SimpleText(tostring(weapon:Clip1()) .. " / " .. tostring(client:GetAmmoCount(weapon:GetPrimaryAmmoType())),
				"nwField", ScrW() - Sc(26), y - Sc(8), theme.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
		return
	end

	local class = client:GetNWString("nwClass", "")
	local classTable = class != "" and NETWORK.classes and NETWORK.classes.Get(class)
	local subtitle = util.Upper(NETWORK.factions.GetName(client:GetCharacterFaction()))

	if (classTable and classTable.name) then
		subtitle = subtitle .. " · " .. util.Upper(L(classTable.name))
	end

	cursor = cursor - Sc(12)

	util.DrawTextSpaced(subtitle, "nwHudSmall", x, cursor, ColorAlpha(accent, 230 * fade),
		Sc(2), TEXT_ALIGN_CENTER)

	draw.SimpleText(client:GetCharacterName(), "nwField", x, cursor - Sc(20),
		ColorAlpha(theme.text, 250 * fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local weapon = client:GetActiveWeapon()
	local name = IsValid(weapon) and (weapon.PrintName or weapon:GetClass()) or L("hudHands")

	if (IsValid(weapon) and NETWORK.item and NETWORK.item.GetNameByWeapon) then
		name = NETWORK.item.GetNameByWeapon(weapon) or name
	end

	draw.SimpleText(util.Upper(name), "nwHudSmall", ScrW() - Sc(26), y - Sc(8),
		ColorAlpha(theme.textFaint, 220 * fade), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end)
