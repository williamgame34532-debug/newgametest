NETWORK.chud = NETWORK.chud or {}

local hud = NETWORK.chud

hud.alpha = hud.alpha or 0

hud.gradientUp = Material("vgui/gradient-u")

hud.palettes = {
	cwu = {
		main = Color(240, 196, 84),
		soft = Color(186, 148, 66),
		dim = Color(116, 92, 44),
		warn = Color(240, 96, 86),
		back = Color(20, 15, 6)
	},
	cp = {
		main = Color(122, 202, 252),
		soft = Color(74, 140, 190),
		dim = Color(38, 78, 116),
		warn = Color(240, 96, 86),
		back = Color(6, 11, 22)
	},
	cmb = {
		main = Color(236, 98, 86),
		soft = Color(178, 74, 66),
		dim = Color(112, 48, 44),
		warn = Color(255, 156, 96),
		back = Color(16, 7, 7)
	}
}

hud.statuses = {
	green = {label = "Стабильно", color = Color(96, 212, 120), speed = 1},
	yellow = {label = "Напряжённо", color = Color(232, 206, 96), speed = 1.7},
	orange = {label = "Тревога", color = Color(238, 152, 70), speed = 2.6},
	red = {label = "Критическое", color = Color(238, 88, 78), speed = 3.7},
	black = {label = "Чрезвычайное", color = Color(220, 220, 228), speed = 5}
}

hud.states = {
	{minimum = 75, label = "Стабильно", color = Color(122, 214, 130)},
	{minimum = 50, label = "Ранен", color = Color(232, 206, 96)},
	{minimum = 30, label = "Повреждения", color = Color(238, 152, 70)},
	{minimum = 0, label = "Критическое", color = Color(240, 72, 64), bCritical = true}
}

local fonts = {}

function hud.Sc(value)
	return math.max(math.Round(value * (ScrH() / 1080)), 1)
end

function hud.Font(size, weight, bAlphabet, bZekton)
	local scaled = hud.Sc(size)
	local face = bAlphabet and "Combine Alphabet" or
		(bZekton and "Zekton Rg" or "Boxed Round")
	local name = "nwCombine" .. string.gsub(face, "%s", "") .. scaled .. "w" .. weight

	if (!fonts[name]) then
		surface.CreateFont(name, {
			font = face,
			size = scaled,
			weight = weight,
			extended = true,
			antialias = true
		})

		fonts[name] = true
	end

	return name
end

function hud.Fade(color, alpha)
	return Color(color.r, color.g, color.b,
		(color.a or 255) * math.Clamp(alpha or 1, 0, 1))
end

function hud.GetKind(client)
	if (!IsValid(client) or !client:HasCharacter() or !client:IsCombine()) then
		return
	end

	local faction = client:GetCharacterFaction()

	return hud.palettes[faction] and faction or "cp"
end

local oldGetKind = hud.GetKind

function hud.GetKind(client)
	if (NETWORK.classes and NETWORK.classes.HasCivilianHud(client)) then
		return
	end

	local kind = oldGetKind(client)

	if (kind) then
		return kind
	end

	if (IsValid(client) and client.IsCWUMember and client:IsCWUMember()) then
		return "cwu"
	end
end

function hud.GetPalette(kind)
	return hud.palettes[kind] or hud.palettes.cp
end

function hud.GetStatus()

	local level = NETWORK.dispatch.GetLevel()

	return {
		label = L(level.label),
		color = level.color,
		speed = level.speed
	}
end

function hud.GetState(client)
	local fraction = client:Health() / math.max(client:GetMaxHealth(), 1) * 100

	for _, entry in ipairs(hud.states) do
		if (fraction >= entry.minimum) then
			return entry
		end
	end

	return hud.states[#hud.states]
end

function hud.Tracked(text, font, x, y, color, spacing, alignX)
	text = tostring(text or "")

	if (text == "") then
		return 0
	end

	surface.SetFont(font)

	local chars = {}
	local total = 0
	local bSuccess = pcall(function()
		for _, code in utf8.codes(text) do
			local char = utf8.char(code)
			local charWidth = surface.GetTextSize(char)

			chars[#chars + 1] = {char = char, width = charWidth}
			total = total + charWidth + spacing
		end
	end)

	if (!bSuccess) then
		draw.SimpleText(text, font, x, y, color, alignX or TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		return (surface.GetTextSize(text))
	end

	total = math.max(total - spacing, 0)

	local drawX = x

	if (alignX == TEXT_ALIGN_CENTER) then
		drawX = x - total * 0.5
	elseif (alignX == TEXT_ALIGN_RIGHT) then
		drawX = x - total
	end

	for _, entry in ipairs(chars) do
		draw.SimpleText(entry.char, font, drawX, y, color, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		drawX = drawX + entry.width + spacing
	end

	return total
end

local fadeGradient = Material("gui/gradient")

function hud.FadeLine(x, y, width, height, color, bReverse)
	if (width == 0 or height == 0) then
		return
	end

	local bStrongLeft = (width > 0) != (bReverse == true)

	surface.SetMaterial(fadeGradient)
	surface.SetDrawColor(color.r, color.g, color.b, color.a or 255)

	if (bStrongLeft) then
		surface.DrawTexturedRectUV(x + math.min(width, 0), y, math.abs(width), height, 0, 0, 1, 1)
	else
		surface.DrawTexturedRectUV(x + math.min(width, 0), y, math.abs(width), height, 1, 0, 0, 1)
	end

	draw.NoTexture()
end

function hud.DrawStatusBar(x, y, width, palette, alpha)
	local status = hud.GetStatus()
	local height = hud.Sc(27)
	local left = math.Round(x - width)
	local font = hud.Font(18, 700)
	local unit = "СТАТУС // " .. string.upper(status.label)

	surface.SetFont(font)

	local unitWidth = math.max(surface.GetTextSize(unit), 1)
	local period = unitWidth + hud.Sc(28)
	local offset = (RealTime() * hud.Sc(46) * (status.speed or 1)) % period

	surface.SetDrawColor(palette.back.r, palette.back.g, palette.back.b, 205 * alpha)
	surface.DrawRect(left, y, width, height)

	surface.SetMaterial(hud.gradientUp)
	surface.SetDrawColor(palette.main.r, palette.main.g, palette.main.b,
		12 * alpha)
	surface.DrawTexturedRect(left, y, width, height)

	surface.SetDrawColor(status.color.r, status.color.g, status.color.b, 26 * alpha)
	surface.DrawRect(left, y, width, height)

	local line = math.max(hud.Sc(2), 1)

	hud.FadeLine(left, y, width * 0.5, line, hud.Fade(status.color, alpha * 0.7), true)
	hud.FadeLine(left + width * 0.5, y, width * 0.5, line,
		hud.Fade(status.color, alpha * 0.7))
	hud.FadeLine(left, y + height - line, width * 0.5, line,
		hud.Fade(status.color, alpha * 0.45), true)
	hud.FadeLine(left + width * 0.5, y + height - line, width * 0.5, line,
		hud.Fade(status.color, alpha * 0.45))

	render.SetScissorRect(left, y, left + width, y + height, true)

	local textColor = Color(Lerp(0.55, status.color.r, 255),
		Lerp(0.55, status.color.g, 255), Lerp(0.55, status.color.b, 255), 255 * alpha)
	local drawX = left - unitWidth + offset

	while (drawX < left + width) do
		draw.SimpleText(unit, font, math.Round(drawX), y + height * 0.5, textColor,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		drawX = drawX + period
	end

	render.SetScissorRect(0, 0, 0, 0, false)

	local arm = math.Round(height * 0.5)
	local thick = math.max(hud.Sc(2), 2)

	surface.SetDrawColor(status.color.r, status.color.g, status.color.b, 210 * alpha)
	surface.DrawRect(left - hud.Sc(6), y, thick, arm)
	surface.DrawRect(left + width + hud.Sc(6) - thick, y + height - arm, thick, arm)

	return height + hud.Sc(12)
end

function hud.DrawNeeds(x, y, width, palette, alpha)
	local client = LocalPlayer()
	local left = math.Round(x - width)
	local font = hud.Font(14, 600)

	hud.Tracked("ВРЕМЯ", font, left, y, hud.Fade(palette.soft, alpha),
		hud.Sc(2), TEXT_ALIGN_LEFT)
	draw.SimpleText(NETWORK.time.GetFormatted(), font, left + width, y,
		hud.Fade(palette.main, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	y = y + hud.Sc(18)

	local rows = {}

	if (client:GetCharacterFaction() != "cmb") then
		rows[#rows + 1] = {"ГОЛОД", client:GetHunger() / 100,
			Color(178, 140, 62)}
		rows[#rows + 1] = {"ЖАЖДА", client:GetThirst() / 100,
			Color(78, 132, 178)}
	end

	rows[#rows + 1] = {"ВЫНОСЛИВОСТЬ", client:GetStamina() / 100,
		client:IsExhausted() and Color(176, 58, 52) or Color(96, 168, 138)}
	local cursor = y

	for _, row in ipairs(rows) do
		local fraction = math.Clamp(row[2], 0, 1)

		hud.Tracked(row[1], font, left, cursor, hud.Fade(palette.soft, alpha),
			hud.Sc(2), TEXT_ALIGN_LEFT)

		draw.SimpleText(math.Round(fraction * 100), font, left + width, cursor,
			hud.Fade(row[3], alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		cursor = cursor + hud.Sc(12)

		local barHeight = math.max(hud.Sc(4), 2)

		surface.SetDrawColor(palette.dim.r, palette.dim.g, palette.dim.b,
			90 * alpha)
		surface.DrawRect(left, cursor, width, barHeight)

		surface.SetDrawColor(row[3].r, row[3].g, row[3].b, 235 * alpha)
		surface.DrawRect(left, cursor, math.Round(width * fraction), barHeight)

		cursor = cursor + hud.Sc(18)
	end

	return cursor - y + hud.Sc(18)
end

local unitSwap, bUnitWarning = 0, false

function hud.DrawUnit(x, y, palette, alpha, client)
	local labelFont = hud.Font(17, 600)
	local nameFont = hud.Font(25, 700)
	local spacing = hud.Sc(2)
	local data = hud.GetState(client)
	local text = "СОСТОЯНИЕ: " .. string.upper(data.label)

	if (data.bCritical) then
		if (RealTime() >= unitSwap) then
			unitSwap = RealTime() + 2.6
			bUnitWarning = !bUnitWarning
		end

		if (bUnitWarning) then
			text = "КРИТИЧЕСКОЕ СОСТОЯНИЕ"
		end
	else
		bUnitWarning = false
		unitSwap = 0
	end

	local icon = NETWORK.factions.GetIcon(client)
	local material = icon and NETWORK.util.GetMaterial(icon, "smooth")
	local shift = 0

	if (material and !material:IsError()) then
		local size = hud.Sc(30)

		surface.SetDrawColor(255, 255, 255, 235 * alpha)
		surface.SetMaterial(material)
		surface.DrawTexturedRect(x, y - math.Round(size * 0.5), size, size)

		shift = size + hud.Sc(10)
	end

	hud.Tracked(string.upper(client:GetCharacterName()), nameFont, x + shift, y,
		hud.Fade(palette.main, alpha), hud.Sc(3), TEXT_ALIGN_LEFT)

	local lineY = y + hud.Sc(22)

	hud.FadeLine(x, lineY, hud.Sc(280), math.max(hud.Sc(2), 1),
		hud.Fade(palette.soft, alpha * 0.9))

	local stateY = lineY + hud.Sc(24)

	if (data.bCritical and bUnitWarning) then
		local blink = 0.35 + math.abs(math.sin(RealTime() * 4.6)) * 0.65

		hud.Tracked(text, labelFont, x, stateY, hud.Fade(data.color, alpha * blink),
			spacing, TEXT_ALIGN_LEFT)
	else
		local head = "СОСТОЯНИЕ: "
		local headWidth = hud.Tracked(head, labelFont, x, stateY,
			hud.Fade(palette.soft, alpha), spacing, TEXT_ALIGN_LEFT)

		hud.Tracked(string.upper(data.label), labelFont, x + headWidth + spacing * 2,
			stateY, hud.Fade(data.color, alpha), spacing, TEXT_ALIGN_LEFT)
	end

	local zone = NETWORK.zone.AtEntity(client)
	local type = zone and NETWORK.zone.GetType(zone.type)
	local label = zone and (zone.name != "" and zone.name or
		(type and L(type.name))) or "НЕ ОПРЕДЕЛЕНА"
	local zoneColor = type and type.color or Color(128, 136, 146)

	local head = "ЗОНА: "
	local headWidth = hud.Tracked(head, labelFont, x, stateY + hud.Sc(26),
		hud.Fade(palette.soft, alpha), spacing, TEXT_ALIGN_LEFT)

	hud.Tracked(string.upper(label), labelFont, x + headWidth + spacing * 2,
		stateY + hud.Sc(26), hud.Fade(zoneColor, alpha), spacing, TEXT_ALIGN_LEFT)
end

function hud.GetBrandHeight()
	local material = NETWORK.util.GetMaterial(NETWORK.hud.bannerPath, "smooth")

	if (!material or material:IsError()) then
		return 0
	end

	local width = math.min(NETWORK.util.Scale(190), math.Round(ScrW() * 0.12))

	return math.Round(width * (material:Height() / math.max(material:Width(), 1))) +
		NETWORK.util.Scale(18)
end

local ammo = {clip = 0, reserve = 0, alpha = 0, pop = 0}

function hud.DrawAmmo(x, y, palette, alpha, client)
	local weapon = client:GetActiveWeapon()
	local bValid = IsValid(weapon) and weapon:GetPrimaryAmmoType() > -1 and
		weapon:GetMaxClip1() > 0

	ammo.alpha = math.Approach(ammo.alpha, bValid and 1 or 0, FrameTime() * 5)

	if (ammo.alpha <= 0.01) then
		return
	end

	if (bValid) then
		local clip = weapon:Clip1()

		if (clip != ammo.clip) then
			ammo.pop = 1
			ammo.clip = clip
		end

		ammo.reserve = client:GetAmmoCount(weapon:GetPrimaryAmmoType())
	end

	ammo.pop = math.Approach(ammo.pop, 0, FrameTime() * 3)

	local visual = alpha * ammo.alpha
	local bigFont = hud.Font(46, 800)
	local smallFont = hud.Font(18, 600)
	local tagFont = hud.Font(13, 600)
	local size = bValid and weapon:GetMaxClip1() or 30
	local color = ammo.clip <= math.max(1, math.floor(size * 0.25)) and
		palette.warn or palette.main

	surface.SetFont(bigFont)

	local clipWidth = surface.GetTextSize(ammo.clip)

	draw.SimpleText(ammo.clip, bigFont, x, y,
		hud.Fade(color, visual * (0.85 + ammo.pop * 0.15)), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	draw.SimpleText(ammo.reserve, smallFont, x - clipWidth - hud.Sc(10),
		y + hud.Sc(6), hud.Fade(palette.soft, visual), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	hud.Tracked("БОЕКОМПЛЕКТ", tagFont, x, y - hud.Sc(28),
		hud.Fade(palette.dim, visual), hud.Sc(3), TEXT_ALIGN_RIGHT)

	hud.FadeLine(x - hud.Sc(190), y + hud.Sc(26), hud.Sc(190),
		math.max(hud.Sc(2), 1), hud.Fade(palette.soft, visual * 0.8), true)
end

local HIDE = {
	CHudHealth = true,
	CHudBattery = true,
	CHudAmmo = true,
	CHudSecondaryAmmo = true
}

hook.Add("HUDShouldDraw", "nwCombineHud", function(name)
	if (HIDE[name] and hud.GetKind(LocalPlayer())) then
		return false
	end
end)

hook.Add("NetworkShouldDrawHUD", "nwCombineHud", function()
	if (hud.GetKind(LocalPlayer())) then
		return false
	end
end)

hook.Add("HUDPaint", "nwCombineHud", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or NETWORK.hud.IsHidden()) then
		hud.alpha = 0

		return
	end

	local kind = hud.GetKind(client)

	if (!kind) then
		hud.alpha = 0

		return
	end

	local target = (IsValid(NETWORK.gui.menu) or IsValid(NETWORK.gui.tabMenu)) and 0 or 1

	if (!client:Alive()) then
		target = target * 0.4
	end

	hud.alpha = math.Approach(hud.alpha, target, FrameTime() * 4)

	if (hud.alpha <= 0.01) then
		return
	end

	hud.UpdateSway(client)

	local palette = hud.GetPalette(kind)
	local alpha = hud.alpha
	local margin = hud.Sc(38)
	local right = ScrW() - margin
	local bottom = ScrH() - margin
	local barWidth = math.Round(math.min(ScrW() * 0.105, hud.Sc(215)))
	local top = hud.Sc(14)

	local function Block(name, ...)
		local callback = hud[name]

		if (!isfunction(callback)) then
			return 0
		end

		local bSuccess, result = pcall(callback, ...)

		if (!bSuccess) then
			if (!hud.reported or hud.reported != name) then
				hud.reported = name

				ErrorNoHalt("[network] HUD " .. name .. ": " ..
					tostring(result) .. "\n")
			end

			return 0
		end

		return tonumber(result) or 0
	end

	local bCWU = kind == "cwu"

	hud.DrawCurved(function()
		if (!bCWU) then
			Block("DrawDispatch", margin, margin + hud.Sc(16), palette, alpha)
		end

		if (!bCWU and NETWORK.schedule and NETWORK.schedule.IsCurfew()) then
			local blink = 0.7 + math.abs(math.sin(RealTime() * 2)) * 0.3

			draw.SimpleText("НАСТУПИЛ КОМЕНДАНТСКИЙ ЧАС", "nwHudSmall",
				math.Round(ScrW() * 0.5), margin + hud.Sc(4),
				Color(240, 84, 74, 235 * alpha * blink), TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER)
		end

		local cursor = top

		if (!bCWU) then
			cursor = cursor + Block("DrawStatusBar", right, cursor, barWidth,
				palette, alpha)
		else

			local font = hud.Font(14, 600)

			draw.SimpleText("ЗДОРОВЬЕ", font, right - barWidth, cursor + hud.Sc(8),
				hud.Fade(palette.soft, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText(math.max(0, client:Health()) .. "%", font, right,
				cursor + hud.Sc(8), hud.Fade(palette.main, alpha),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			cursor = cursor + hud.Sc(26)
		end

		cursor = cursor + Block("DrawNeeds", right, cursor, barWidth, palette, alpha)

		Block("DrawUnit", margin, bottom - hud.Sc(82), palette, alpha, client)
		Block("DrawAmmo", right, bottom - hud.Sc(30) - hud.GetBrandHeight(), palette, alpha, client)
		Block("DrawSquad", right, ScrH() * 0.5, palette, alpha, client)
		Block("DrawUnitTags", palette, alpha, client)

		if (!bCWU) then
			Block("DrawTargetMarkers", palette, alpha, client)
		end
	end)
end)

local feed = {}

net.Receive("nwDispatchLine", function()
	local text = net.ReadString()
	local color = net.ReadColor(false)
	local sound = net.ReadString()

	if (sound != "") then
		surface.PlaySound(sound)
	end

	feed[#feed + 1] = {text = text, color = color, time = RealTime()}

	while (#feed > NETWORK.dispatch.maxLines) do
		table.remove(feed, 1)
	end
end)

hook.Add("NetworkCharacterLoaded", "nwDispatchFeed", function()
	feed = {}
end)

function hud.DrawDispatch(x, y, palette, alpha)
	local titleFont = hud.Font(15, 700)
	local rowFont = hud.Font(14, 600)
	local status = NETWORK.dispatch.GetLevel()

	if (!NETWORK.option.Get("network_dispatchfeed")) then
		return
	end

	hud.Tracked(":: ДИСПЕТЧЕР :: " .. string.upper(L(status.label)), titleFont, x, y,
		hud.Fade(status.color, alpha), hud.Sc(3), TEXT_ALIGN_LEFT)

	hud.FadeLine(x, y + hud.Sc(12), hud.Sc(320), math.max(hud.Sc(2), 1),
		hud.Fade(status.color, alpha * 0.8))

	local cursor = y + hud.Sc(30)
	local now = RealTime()

	for index = #feed, 1, -1 do
		local line = feed[index]
		local age = now - line.time

		if (age > 20) then
			table.remove(feed, index)

			continue
		end

		local fade = 1 - math.Clamp((age - 16) / 4, 0, 1)

		hud.Tracked(string.upper(line.text), rowFont, x, cursor,
			hud.Fade(line.color, alpha * fade), hud.Sc(2), TEXT_ALIGN_LEFT)

		cursor = cursor + hud.Sc(18)
	end
end

function hud.DrawSquad(x, y, palette, alpha, client)
	local id = client:GetSquad()

	if (!id) then
		return
	end

	local members = NETWORK.squad.GetMembers(id)

	if (#members == 0) then
		members = {client}
	end

	local color = NETWORK.squad.color
	local titleFont = hud.Font(19, 700, false, true)
	local rowFont = hud.Font(15, 500, false, true)
	local smallFont = hud.Font(12, 500, false, true)
	local rowHeight = hud.Sc(30)
	local width = hud.Sc(268)
	local height = #members * rowHeight + hud.Sc(16)
	local left = x - width
	local top = y - height * 0.5

	local radius = math.max(hud.Sc(6), 4)

	NETWORK.util.DrawBlurScreen(left, top, width, height, 4 * alpha)

	draw.RoundedBox(radius, left, top, width, height, Color(4, 10, 14, 120 * alpha))

	NETWORK.util.DrawRoundedBorder(left, top, width, height, radius,
		math.max(hud.Sc(1), 1), ColorAlpha(color, 90 * alpha))

	surface.SetDrawColor(color.r, color.g, color.b, 190 * alpha)
	surface.DrawRect(x - math.max(hud.Sc(2), 2), top,
		math.max(hud.Sc(2), 2), height)

	hud.Tracked("ОТРЯД :: " .. (client:GetSquadName() or "-"), titleFont, x,
		top - hud.Sc(20), hud.Fade(color, alpha), hud.Sc(3), TEXT_ALIGN_RIGHT)

	local squad = NETWORK.squad.list and NETWORK.squad.list[id]

	hud.Tracked(#members .. "/" .. (squad and squad.size or #members),
		smallFont, left, top - hud.Sc(20), hud.Fade(color, alpha * 0.7),
		hud.Sc(2), TEXT_ALIGN_LEFT)

	hud.FadeLine(left, top - hud.Sc(8), width, math.max(hud.Sc(2), 1),
		hud.Fade(color, alpha * 0.8), true)

	local curve = hud.Sc(7)

	for index, member in ipairs(members) do
		local rowY = top + hud.Sc(14) + (index - 1) * rowHeight

		local middle = (#members + 1) * 0.5
		local bend = math.abs(index - middle) / math.max(middle - 1, 1)
		local shift = math.Round(curve * (1 - math.cos(bend * math.pi * 0.5)))
		local zone = NETWORK.zone.AtEntity(member)
		local type = zone and NETWORK.zone.GetType(zone.type)
		local label = zone and (zone.name != "" and zone.name or
			(type and L(type.name))) or "-"
		local bSelf = member == client
		local bLead = member:IsSquadLeader()
		local bAlive = member:Alive()
		local fraction = bAlive and math.Clamp(member:Health() /
			math.max(member:GetMaxHealth(), 1), 0, 1) or 0
		local barColor = fraction > 0.6 and Color(120, 220, 150) or
			(fraction > 0.3 and Color(240, 200, 90) or Color(232, 92, 92))

		local bDown = !bAlive or (member.IsDowned and member:IsDowned()) or
			(member.IsUnconscious and member:IsUnconscious())
		local pulse = (fraction < 0.35 or bDown) and
			(0.55 + math.abs(math.sin(CurTime() * 3)) * 0.45) or 1

		if (bDown) then
			draw.RoundedBox(math.max(hud.Sc(3), 2), left + hud.Sc(3),
				rowY - hud.Sc(9), width - hud.Sc(6), rowHeight,
				Color(232, 74, 66, 28 * alpha * pulse))
		end

		local memberClass = member:GetNWString("nwClass", "")
		local mark = bLead and "◆" or tostring(index)

		if (bDown) then
			mark = "✕"
		elseif (memberClass == "medic") then
			mark = "✚"
		elseif (memberClass == "mechanic") then
			mark = "⚙"
		end

		hud.Tracked(mark, smallFont,
			left + hud.Sc(8) + shift, rowY,
			hud.Fade(bDown and Color(232, 74, 66) or (bLead and color or barColor),
			alpha * pulse * (bSelf and 1 or 0.8)), hud.Sc(1), TEXT_ALIGN_LEFT)

		hud.Tracked(string.upper(member:GetCharacterName()), rowFont,
			x - hud.Sc(6) - shift * 0.5, rowY,
			hud.Fade(color, alpha * (bSelf and 1 or 0.78)),
			hud.Sc(2), TEXT_ALIGN_RIGHT)

		hud.Tracked(string.upper(label), smallFont, x - hud.Sc(6) - shift * 0.5,
			rowY + hud.Sc(11), hud.Fade(color, alpha * 0.55), hud.Sc(1),
			TEXT_ALIGN_RIGHT)

		NETWORK.util.DrawProgressBar(left + hud.Sc(22) + shift,
			rowY + hud.Sc(9), hud.Sc(74) - shift, math.max(hud.Sc(3), 2),
			fraction, barColor, alpha * 0.8 * pulse)

		local armour = math.Clamp(member:Armor() /
			math.max(member:GetMaxArmor(), 1), 0, 1)

		if (armour > 0.01) then
			NETWORK.util.DrawProgressBar(left + hud.Sc(22) + shift,
				rowY + hud.Sc(15), hud.Sc(74) - shift, math.max(hud.Sc(2), 1),
				armour, Color(150, 190, 235), alpha * 0.7)
		end

		if (NETWORK.squad.selected == member) then
			surface.SetDrawColor(240, 200, 90, 30 * alpha)
			surface.DrawRect(left, rowY - hud.Sc(9), width, rowHeight)

			hud.Tracked("►", smallFont, left - hud.Sc(10), rowY,
				hud.Fade(Color(240, 200, 90), alpha), hud.Sc(1),
				TEXT_ALIGN_RIGHT)
		end
	end

	if (!client:IsSquadLeader()) then
		return
	end

	local hints = {
		{"waypoint", "bindWaypoint"},
		{"squadselect", "bindSquadSelect"},
		{"squadorder", "bindSquadOrder"}
	}

	local hintY = top + height + hud.Sc(14)

	for _, hint in ipairs(hints) do
		local data = NETWORK.bind.Get(hint[1])
		local key = data and NETWORK.bind.GetKey(data) or KEY_NONE
		local name = key != KEY_NONE and string.upper(input.GetKeyName(key) or
			"?") or "—"

		surface.SetFont(smallFont)

		local keyWidth = math.max(surface.GetTextSize(name) + hud.Sc(12),
			hud.Sc(24))

		surface.SetDrawColor(color.r, color.g, color.b, 40 * alpha)
		surface.DrawRect(x - keyWidth, hintY - hud.Sc(8), keyWidth,
			hud.Sc(17))

		surface.SetDrawColor(color.r, color.g, color.b, 150 * alpha)
		surface.DrawOutlinedRect(x - keyWidth, hintY - hud.Sc(8), keyWidth,
			hud.Sc(17), 1)

		hud.Tracked(name, smallFont, x - keyWidth * 0.5, hintY,
			hud.Fade(color, alpha), hud.Sc(1), TEXT_ALIGN_CENTER)

		hud.Tracked(string.upper(L(hint[2])), smallFont,
			x - keyWidth - hud.Sc(8), hintY, hud.Fade(color, alpha * 0.7),
			hud.Sc(1), TEXT_ALIGN_RIGHT)

		hintY = hintY + hud.Sc(20)
	end
end

local SQUAD_RANGE = 4096

hook.Add("HUDPaint", "nwSquadMarkers", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return
	end

	if (NETWORK.hud.IsHidden()) then
		return
	end

	if (client:GetMoveType() == MOVETYPE_NOCLIP) then
		return
	end

	local id = client:GetSquad()

	if (!id) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local eyePos = client:EyePos()
	local size = math.max(Sc(26), 18)

	for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
		if (member == client or !IsValid(member) or !member:Alive()) then
			continue
		end

		if (member:GetMoveType() == MOVETYPE_NOCLIP) then
			continue
		end

		local head = member:EyePos() + Vector(0, 0, 14)
		local distance = eyePos:Distance(head)

		if (distance > SQUAD_RANGE) then
			continue
		end

		local screen = head:ToScreen()

		if (!screen.visible) then
			continue
		end

		local bClear = client:IsLineOfSightClear(member)
		local alpha = bClear and 1 or 0.62
		local color = NETWORK.squad.color or NETWORK.theme.accent
		local x, y = math.Round(screen.x), math.Round(screen.y)
		local icon = NETWORK.factions.GetIcon(member)
		local material = icon and util.GetMaterial(icon, "smooth")

		if (material and !material:IsError()) then
			local boxY = y - size - Sc(6)

			surface.SetDrawColor(5, 8, 13, 210 * alpha)
			surface.DrawRect(x - math.Round(size * 0.5) - Sc(3),
				boxY - Sc(3), size + Sc(6), size + Sc(6))

			surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)
			surface.DrawOutlinedRect(x - math.Round(size * 0.5) - Sc(3),
				boxY - Sc(3), size + Sc(6), size + Sc(6), math.max(Sc(2), 1))

			surface.SetDrawColor(255, 255, 255, 250 * alpha)
			surface.SetMaterial(material)
			surface.DrawTexturedRect(x - math.Round(size * 0.5), boxY, size,
				size)
		end

		local name = member:GetCharacterName()

		if (member:IsSquadLeader()) then
			name = "◆ " .. name
		end

		util.DrawSimpleTextShadow(util.Upper(name), "nwHudSmall", x,
			y + Sc(4), ColorAlpha(color, 250 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, math.max(Sc(2), 1))

		util.DrawSimpleTextShadow(math.Round(distance * 0.0254) .. " " ..
			L("questMetres"), "nwHudSmall", x, y + Sc(19),
			ColorAlpha(NETWORK.theme.textDim, 230 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, math.max(Sc(2), 1))
	end
end)

hook.Add("PreDrawHalos", "nwSquadHalo", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local id = client:GetSquad()

	if (!id) then
		return
	end

	local list = {}

	for _, member in ipairs(NETWORK.squad.GetMembers(id)) do
		if (member == client or !member:Alive()) then
			continue
		end

		list[#list + 1] = member

		local weapon = member:GetActiveWeapon()

		if (IsValid(weapon)) then
			list[#list + 1] = weapon
		end
	end

	if (#list == 0) then
		return
	end

	halo.Add(list, NETWORK.squad.color, 2, 2, 2, true, true)
end)

local marks = {}

net.Receive("nwOverwatchMark", function()
	local target = net.ReadEntity()
	local length = net.ReadFloat()

	if (IsValid(target)) then
		marks[target] = RealTime() + length
	end
end)

hook.Add("PreDrawHalos", "nwOverwatchMark", function()
	local now = RealTime()
	local list = {}

	for target, expires in pairs(marks) do
		if (!IsValid(target) or expires < now) then
			marks[target] = nil

			continue
		end

		list[#list + 1] = target

		local weapon = target:GetActiveWeapon()

		if (IsValid(weapon)) then
			list[#list + 1] = weapon
		end
	end

	if (#list == 0) then
		return
	end

	halo.Add(list, Color(238, 58, 52), 1, 1, 1, true, true)
end)

local tags = {}

function hud.DrawUnitTags(palette, alpha, client)
	local aim = client:GetAimVector()
	local eyes = client:EyePos()
	local now = RealTime()

	for _, target in ipairs(player.GetAll()) do
		if (target == client or !target:Alive() or !target:HasCharacter() or
			!target:IsCombine()) then
			continue
		end

		local delta = target:EyePos() - eyes
		local distance = delta:Length()
		local entry = tags[target]

		local bVisible = distance < 480 and
			delta:GetNormalized():Dot(aim) > 0.9

		if (bVisible) then
			local trace = util.TraceLine({
				start = eyes,
				endpos = target:EyePos(),
				filter = {client, target},
				mask = MASK_SHOT
			})

			bVisible = !trace.Hit
		end

		if (!entry) then
			if (!bVisible) then
				continue
			end

			entry = {reveal = 0}
			tags[target] = entry
		end

		entry.reveal = math.Approach(entry.reveal, bVisible and 1 or 0,
			FrameTime() * 4)

		if (entry.reveal <= 0.01) then
			tags[target] = nil

			continue
		end

		local screen = (target:EyePos() + Vector(0, 0, 6)):ToScreen()

		if (!screen.visible) then
			continue
		end

		local reveal = entry.reveal
		local visual = alpha * reveal
		local slide = (1 - reveal) * hud.Sc(24)
		local x = math.Round(screen.x + hud.Sc(34) + slide)
		local y = math.Round(screen.y)
		local character = target:GetCharacter()

		hud.Tracked(NETWORK.util.Upper(target:GetUnknownName()),
			hud.Font(14, 700), x, y, hud.Fade(palette.main, visual),
			hud.Sc(2), TEXT_ALIGN_LEFT)

		local barWidth = hud.Sc(190)

		surface.SetDrawColor(palette.main.r, palette.main.g, palette.main.b,
			235 * visual)
		surface.DrawRect(x, y + hud.Sc(10), math.Round(barWidth * reveal),
			math.max(hud.Sc(2), 1))

		local callsign = target:GetNWString("nwCallsign", "")
		local line = string.upper(callsign != "" and callsign or
			target:GetCharacterName())
		local cid = NETWORK.terminal.GetCitizenID(character)

		if (cid and cid != "" and cid != "00000" and callsign == "") then
			line = line .. "  №" .. cid
		end

		hud.Tracked(line, hud.Font(14, 600), x, y + hud.Sc(24),
			hud.Fade(palette.soft, visual), hud.Sc(2), TEXT_ALIGN_LEFT)
	end
end

local markerConVar = CreateClientConVar("network_cmb_markers", "1", true, false,
	"Маркеры целей в HUD Альянса (0 — выключить)")

hud.markerRange = 900
hud.markerCone = 0.85
hud.markerHostile = Color(238, 58, 52)

hud.markerCivil = Color(122, 202, 252)

hud.threatLabels = {"LOW", "MODERATE", "SEVERE"}

hud.markerFriendly = {
	npc_combine_s = true,
	npc_metropolice = true,
	npc_turret_floor = true,
	npc_turret_ceiling = true,
	npc_cscanner = true,
	npc_clawscanner = true,
	npc_manhack = true,
	npc_rollermine = true,
	npc_hunter = true,
	npc_strider = true,
	npc_combinegunship = true,
	npc_combinedropship = true,
	npc_helicopter = true,
	npc_sniper = true,
	npc_stalker = true,
	nw_npc = true
}

hud.markerClasses = {
	npc_zombie = {label = "NECROTIC", threat = 2, origin = "XEN",
		strike = "TERMINATE ON CONTACT"},
	npc_zombie_torso = {label = "NECROTIC", threat = 1, origin = "XEN",
		strike = "TERMINATE ON CONTACT"},
	npc_zombine = {label = "NECROTIC", threat = 3, origin = "XEN",
		strike = "KEEP DISTANCE // TERMINATE"},
	npc_fastzombie = {label = "NECROTIC", threat = 3, origin = "XEN",
		strike = "ENGAGE AT RANGE"},
	npc_fastzombie_torso = {label = "NECROTIC", threat = 2, origin = "XEN",
		strike = "ENGAGE AT RANGE"},
	npc_poisonzombie = {label = "NECROTIC", threat = 3, origin = "XEN",
		strike = "PRIORITY // HEADSHOT"},
	npc_headcrab = {label = "PARASITIC", threat = 1, origin = "XEN",
		strike = "STAMP OUT"},
	npc_headcrab_fast = {label = "PARASITIC", threat = 2, origin = "XEN",
		strike = "STAMP OUT"},
	npc_headcrab_black = {label = "PARASITIC", threat = 2, origin = "XEN",
		strike = "DO NOT CLOSE // SHOOT"},
	npc_barnacle = {label = "PARASITIC", threat = 1, origin = "XEN",
		strike = "AVOID CEILING // DISPOSE"},
	npc_antlion = {label = "XENOFAUNA", threat = 3, origin = "XEN",
		strike = "SUPPRESS BEFORE DISCHARGE"},
	npc_antlion_worker = {label = "XENOFAUNA", threat = 3, origin = "XEN",
		strike = "SUPPRESS BEFORE DISCHARGE"},
	npc_antlionguard = {label = "XENOFAUNA", threat = 3, origin = "XEN",
		strike = "REQUEST HEAVY SUPPORT"},
	npc_vortigaunt = {label = "XENIAN", threat = 2, origin = "XEN",
		strike = "RESTRICT AND CONTAIN"},
	npc_citizen = {label = "ANTICITIZEN", threat = 2, origin = "TERRAN",
		strike = "DETAIN OR AMPUTATE"},
	npc_alyx = {label = "ANTICITIZEN", threat = 3, origin = "TERRAN",
		strike = "DETAIN OR AMPUTATE"},
	npc_barney = {label = "ANTICITIZEN", threat = 3, origin = "TERRAN",
		strike = "DETAIN OR AMPUTATE"},
	npc_monk = {label = "ANTICITIZEN", threat = 2, origin = "TERRAN",
		strike = "DETAIN OR AMPUTATE"}
}

hud.markerUnknown = {label = "UNKNOWN", threat = 1, origin = "UNKNOWN",
	strike = "OBSERVE AND REPORT"}

hud.markerHacked = {label = "COMPROMISED UNIT", threat = 3, origin = "ANTICITIZEN",
	strike = "DESTROY ON SIGHT"}

local markers = {}
local markerNPCs = {}
local markerNPCRefresh = 0

local function IsMarkerVisible(client, target, eyes)
	local filter = {client, target}
	local trace = util.TraceLine({
		start = eyes,
		endpos = target:EyePos(),
		filter = filter,
		mask = MASK_SHOT
	})

	if (!trace.Hit) then
		return true
	end

	trace = util.TraceLine({
		start = eyes,
		endpos = target:LocalToWorld(target:OBBCenter()),
		filter = filter,
		mask = MASK_SHOT
	})

	return !trace.Hit
end

local function GetNPCInfo(target)
	if (target:GetNWBool("nwTrapHacked", false)) then
		return hud.markerHacked
	end

	local class = target:GetClass()

	return hud.markerClasses[class] or hud.markerUnknown
end

local function GetPlayerInfo(target)
	local weapon = target:GetActiveWeapon()
	local bArmed = IsValid(weapon) and weapon:GetClass() != NETWORK.weapon.hands and
		!NETWORK.weapon.alwaysRaised[weapon:GetClass()]
	local faction = NETWORK.factions.Get(target:GetCharacterFaction())
	local rows = {}

	rows[#rows + 1] = {"FACTION", string.upper(faction and L(faction.name) or "-")}

	local status = "CLEAR"

	if (target:GetNWBool("nwCuffed", false)) then
		status = "CUFFED"
	elseif (target:GetNWBool("nwTied", false)) then
		status = "TIED"
	elseif (target:GetNWBool("nwSearched", false)) then
		status = "SEARCHED"
	end

	rows[#rows + 1] = {"STATUS", status}

	if (target.GetLoyalty and NETWORK.loyalty and NETWORK.loyalty.GetBand) then
		local band = NETWORK.loyalty.GetBand(target:GetLoyalty())

		rows[#rows + 1] = {"LOYALTY", string.upper(L(band.label)), band.color}
	end

	if (bArmed) then
		rows[#rows + 1] = {"STRIKE", "DISARM // DETAIN"}
	end

	return {
		bHostile = bArmed,
		header = bArmed and "HOSTILE" or "CIVILIAN",
		name = target:GetRecognisedName(),
		rows = rows
	}
end

local function GetMarkerBounds(target)
	local mins, maxs = target:OBBMins(), target:OBBMaxs()
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge

	for _, x in ipairs({mins.x, maxs.x}) do
		for _, y in ipairs({mins.y, maxs.y}) do
			for _, z in ipairs({mins.z, maxs.z}) do
				local screen = target:LocalToWorld(Vector(x, y, z)):ToScreen()

				if (!screen.visible) then
					return
				end

				minX = math.min(minX, screen.x)
				minY = math.min(minY, screen.y)
				maxX = math.max(maxX, screen.x)
				maxY = math.max(maxY, screen.y)
			end
		end
	end

	return math.Round(minX), math.Round(minY), math.Round(maxX), math.Round(maxY)
end

local function DrawBracket(minX, minY, maxX, maxY, color, reveal)
	local arm = math.Round(hud.Sc(12) * reveal)
	local thick = 1

	if (arm < 2) then
		return
	end

	surface.SetDrawColor(color.r, color.g, color.b, color.a)

	surface.DrawRect(minX, minY, arm, thick)
	surface.DrawRect(minX, minY, thick, arm)
	surface.DrawRect(maxX - arm, minY, arm, thick)
	surface.DrawRect(maxX - thick, minY, thick, arm)
	surface.DrawRect(minX, maxY - thick, arm, thick)
	surface.DrawRect(minX, maxY - arm, thick, arm)
	surface.DrawRect(maxX - arm, maxY - thick, arm, thick)
	surface.DrawRect(maxX - thick, maxY - arm, thick, arm)
end

local function DrawMarker(target, entry, info, alpha)
	local minX, minY, maxX, maxY = GetMarkerBounds(target)

	if (!minX) then
		return
	end

	local reveal = entry.reveal
	local visual = alpha * reveal
	local color = info.bHostile and hud.markerHostile or hud.markerCivil
	local white = Color(236, 240, 244)
	local metres = math.Round(entry.distance / 40)
	local headFont = hud.FaceFont(hud.monoFace, 13, 700)
	local name = string.upper(info.name or "")
	local nameFont = hud.TextFont(name, 18, 800)
	local rowFont = hud.FaceFont(hud.monoFace, 12, 600)
	local spacing = hud.Sc(2)
	local rowStep = hud.Sc(15)
	local head = info.header .. "  " .. metres .. "M"

	DrawBracket(minX, minY, maxX, maxY, hud.Fade(color, visual * 0.9), reveal)

	surface.SetFont(headFont)

	local width = surface.GetTextSize(head) + NETWORK.util.Length(head) * spacing

	surface.SetFont(nameFont)
	width = math.max(width, surface.GetTextSize(name) + NETWORK.util.Length(name) * spacing)

	surface.SetFont(rowFont)

	for _, row in ipairs(info.rows) do
		local line = row[1] .. " :: " .. row[2]

		width = math.max(width, surface.GetTextSize(line) + NETWORK.util.Length(line) * spacing +
			(row.dots and hud.Sc(30) or 0))
	end

	local height = hud.Sc(40) + #info.rows * rowStep
	local slide = (1 - reveal) * hud.Sc(16)
	local x = maxX + hud.Sc(14) + slide

	if (x + width > ScrW() - hud.Sc(10)) then
		x = minX - hud.Sc(14) - width - slide
	end

	local y = math.Clamp(minY, hud.Sc(10), ScrH() - height - hud.Sc(10))

	x = math.Round(x)
	y = math.Round(y)

	hud.Tracked(head, headFont, x, y + hud.Sc(6), hud.Fade(color, visual), spacing,
		TEXT_ALIGN_LEFT)

	hud.Tracked(name, nameFont, x, y + hud.Sc(24), hud.Fade(white, visual), spacing,
		TEXT_ALIGN_LEFT)

	surface.SetDrawColor(color.r, color.g, color.b, 200 * visual)
	surface.DrawRect(x, y + hud.Sc(35), math.Round(width * reveal), 1)

	local cursor = y + hud.Sc(46)

	for _, row in ipairs(info.rows) do
		local labelWidth = hud.Tracked(row[1] .. " :: ", rowFont, x, cursor,
			hud.Fade(color, visual * 0.75), spacing, TEXT_ALIGN_LEFT)
		local valueWidth = hud.Tracked(row[2], rowFont, x + labelWidth + spacing, cursor,
			hud.Fade(row[3] or white, visual * 0.9), spacing, TEXT_ALIGN_LEFT)

		if (row.dots) then
			local dot = math.max(hud.Sc(5), 3)
			local dotX = x + labelWidth + spacing + valueWidth + hud.Sc(8)

			for index = 1, 3 do
				local bFilled = index <= row.dots

				surface.SetDrawColor(color.r, color.g, color.b, (bFilled and 230 or 60) * visual)
				surface.DrawRect(dotX + (index - 1) * (dot + hud.Sc(3)),
					cursor - math.floor(dot * 0.5), dot, dot)
			end
		end

		cursor = cursor + rowStep
	end
end

function hud.DrawTargetMarkers(palette, alpha, client)
	if (!markerConVar:GetBool() or !client:Alive()) then
		markers = {}

		return
	end

	local now = RealTime()
	local eyes = client:EyePos()
	local aim = client:GetAimVector()
	local candidates = {}

	for _, target in ipairs(player.GetAll()) do
		if (target == client or !target:Alive() or !target:HasCharacter() or
			NETWORK.factions.IsAlliance(target) or
			target:GetMoveType() == MOVETYPE_NOCLIP) then
			continue
		end

		candidates[#candidates + 1] = target
	end

	if (now >= markerNPCRefresh) then
		markerNPCRefresh = now + 0.5
		markerNPCs = {}

		for _, entity in ipairs(ents.FindInSphere(eyes, hud.markerRange)) do
			if (!IsValid(entity) or !entity:IsNPC() or entity:Health() <= 0) then
				continue
			end

			if (!entity:GetNWBool("nwTrapHacked", false) and
				(hud.markerFriendly[entity:GetClass()] or
				entity:GetNWString("nwDeploy", "") != "")) then
				continue
			end

			markerNPCs[#markerNPCs + 1] = entity
		end
	end

	for _, target in ipairs(markerNPCs) do
		if (IsValid(target) and target:Health() > 0) then
			candidates[#candidates + 1] = target
		end
	end

	local seen = {}

	for _, target in ipairs(candidates) do
		seen[target] = true

		local entry = markers[target]
		local delta = target:LocalToWorld(target:OBBCenter()) - eyes
		local distance = delta:Length()
		local bVisible = distance < hud.markerRange and
			delta:GetNormalized():Dot(aim) > hud.markerCone

		if (bVisible) then
			if (!entry) then
				if (!IsMarkerVisible(client, target, eyes)) then
					continue
				end

				entry = {reveal = 0, bClear = true, nextTrace = now + 0.1}
				markers[target] = entry
			elseif (now >= entry.nextTrace) then
				entry.nextTrace = now + 0.1
				entry.bClear = IsMarkerVisible(client, target, eyes)
			end

			bVisible = entry.bClear
		elseif (!entry) then
			continue
		end

		entry.distance = distance
		entry.reveal = math.Approach(entry.reveal, bVisible and 1 or 0, FrameTime() * 5)

		if (entry.reveal <= 0.01) then
			markers[target] = nil

			continue
		end

		local info

		if (target:IsPlayer()) then
			info = GetPlayerInfo(target)
		else
			local data = GetNPCInfo(target)
			local threat = math.Clamp(data.threat or 1, 1, 3)

			info = {
				bHostile = true,
				header = "HOSTILE",
				name = data.label,
				rows = {
					{"THREAT", hud.threatLabels[threat], nil, dots = threat},
					{"ORIGIN", data.origin or "UNKNOWN"},
					{"STRIKE", data.strike or "OBSERVE AND REPORT"}
				}
			}
		end

		DrawMarker(target, entry, info, alpha)
	end

	for target, _ in pairs(markers) do
		if (!seen[target]) then
			markers[target] = nil
		end
	end
end

net.Receive("nwOverwatchVO", function()
	local path = net.ReadString()

	if (path != "") then
		surface.PlaySound(path)
	end
end)

hud.monoFace = "' Mono Regular"

local glyphSizeConVar = CreateClientConVar("network_glyph_size", "22", true, false,
	"Размер глифов в шапке HUD Альянса")

hud.phrases = {
	"PREPARE UNIT HEALTH", "UPDATE DATA-BASE", "CHECKS VISOR", "CHECKS UNIT IN DATA-BASE",
	"REQUESTING NEW DIRECTIVES", "SYNC OVERWATCH LINK", "SCAN SECTOR PERIMETER",
	"VERIFY SOCIOSTATUS", "CALIBRATE BIOSIGNAL", "RECEIVING PROTECTION PROTOCOL",
	"CHECKS AMMUNITION", "LOCATING SQUAD MEMBERS", "CHECKS LOYALTY INDEX"
}

hud.ticker = hud.ticker or {}
hud.tickerNext = hud.tickerNext or 0

local TRANSLIT = {
	["а"] = "a", ["б"] = "b", ["в"] = "v", ["г"] = "g", ["д"] = "d", ["е"] = "e", ["ё"] = "e",
	["ж"] = "zh", ["з"] = "z", ["и"] = "i", ["й"] = "y", ["к"] = "k", ["л"] = "l", ["м"] = "m",
	["н"] = "n", ["о"] = "o", ["п"] = "p", ["р"] = "r", ["с"] = "s", ["т"] = "t", ["у"] = "u",
	["ф"] = "f", ["х"] = "h", ["ц"] = "c", ["ч"] = "ch", ["ш"] = "sh", ["щ"] = "sch", ["ъ"] = "",
	["ы"] = "y", ["ь"] = "", ["э"] = "e", ["ю"] = "yu", ["я"] = "ya"
}

function hud.Translit(text)
	local out = {}

	for _, code in utf8.codes(text) do
		local char = utf8.char(code)
		local lower = NETWORK.util.Lower(char)
		local mapped = TRANSLIT[lower]

		out[#out + 1] = mapped and string.upper(mapped) or char
	end

	return table.concat(out)
end

function hud.HasCyrillic(text)
	return string.find(text, "[\208\209]") != nil
end

local faceFonts = {}

function hud.FaceFont(face, size, weight)
	local scaled = hud.Sc(size)

	local name = "nwFace" .. string.gsub(face, "[^%w]", "") .. scaled .. "w" .. weight

	if (!faceFonts[name]) then
		surface.CreateFont(name, {font = face, size = scaled, weight = weight,
			extended = true, antialias = true})

		faceFonts[name] = true
	end

	return name
end

function hud.TextFont(text, size, weight)
	return hud.HasCyrillic(text) and hud.Font(size, weight, false, true) or
		hud.FaceFont(hud.monoFace, size, weight)
end

function hud.Push(text, color, sub)
	table.insert(hud.ticker, 1, {
		text = text,
		sub = sub,
		color = color,
		time = RealTime()
	})

	while (#hud.ticker > 5) do
		table.remove(hud.ticker)
	end
end

net.Receive("nwDispatchLine", function()
	local text = net.ReadString()
	local color = net.ReadColor(false)
	local sound = net.ReadString()

	if (sound != "") then
		surface.PlaySound(sound)
	end

	hud.Push(hud.Translit(string.upper(text)), color)
end)

hook.Add("NetworkCharacterLoaded", "nwDispatchFeed", function()
	hud.ticker = {}
	hud.tickerNext = RealTime() + 2
end)

function hud.DrawTicker(x, y, palette, alpha)
	if (RealTime() >= hud.tickerNext) then
		hud.tickerNext = RealTime() + math.Rand(7, 13)

		hud.Push(hud.phrases[math.random(#hud.phrases)], palette.main)
	end

	local font = hud.Font(11, 700, true)
	local cursor = y
	local now = RealTime()

	for index = #hud.ticker, 1, -1 do
		local line = hud.ticker[index]

		if (now - line.time > 22) then
			table.remove(hud.ticker, index)
		end
	end

	for _, line in ipairs(hud.ticker) do
		local age = now - line.time
		local fade = math.Clamp((22 - age) / 3, 0, 1)
		local length = NETWORK.util.Length(line.text)
		local typed = math.min(math.floor(age * 14), length)
		local shown = NETWORK.util.Sub(line.text, 1, typed)

		if (typed < length and math.floor(now * 6) % 2 == 0) then
			shown = shown .. "_"
		end

		draw.SimpleText(shown, font, x, cursor, hud.Fade(line.color, alpha * fade),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		cursor = cursor + hud.Sc(14)
	end

	return cursor - y
end

function hud.DrawGlyphHeader(x, y, palette, alpha, client)
	local size = math.Clamp(math.Round(glyphSizeConVar:GetFloat()), 12, 40)
	local font = hud.Font(size, 700, true)
	local step = hud.Sc(size + 4)
	local status = hud.GetStatus()
	local lines = {
		hud.Translit("SECTOR 24 // " .. string.upper(NETWORK.factions.Get(
			client:GetCharacterFaction()) and L(NETWORK.factions.Get(
			client:GetCharacterFaction()).name) or "UNIT")),
		hud.Translit("STATUS // " .. string.upper(status.label))
	}

	for index, line in ipairs(lines) do
		draw.SimpleText(line, font, x, y + (index - 1) * step,
			hud.Fade(index == 1 and palette.main or status.color, alpha * 0.9),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	return #lines * step
end

local function ZoneName(entity)
	local zone = NETWORK.zone and NETWORK.zone.At(entity:GetPos())

	return zone and zone.name != "" and zone.name or "—"
end

function hud.DrawTeam(x, y, palette, alpha, client)
	local id = client:GetSquad()

	if (!id) then
		return 0
	end

	local members = NETWORK.squad.GetMembers(id)
	local name = client:GetSquadName() or "—"

	local mono = hud.FaceFont("OCR A Extended", 17, 700)
	local zekton = hud.Font(17, 700, false, true)
	local rowFont = hud.FaceFont("OCR A Extended", 15, 600)
	local rowZekton = hud.Font(15, 600, false, true)
	local cursor = y

	local function Row(label, value, labelColor, valueColor, font, valueFont)
		draw.SimpleText(label, font, x, cursor, labelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		surface.SetFont(font)

		local labelWidth = surface.GetTextSize(label)

		draw.SimpleText(value, valueFont, x + labelWidth, cursor, valueColor, TEXT_ALIGN_LEFT,
			TEXT_ALIGN_TOP)
	end

	Row("TEAM :: ", string.upper(name), hud.Fade(palette.main, alpha), hud.Fade(palette.main, alpha),
		mono, hud.HasCyrillic(name) and zekton or mono)
	cursor = cursor + hud.Sc(21)

	local unit = string.upper(client:GetCharacterName())

	Row("UNIT :: ", unit, hud.Fade(palette.main, alpha), hud.Fade(palette.main, alpha), mono,
		hud.HasCyrillic(unit) and zekton or mono)
	cursor = cursor + hud.Sc(28)

	if (#members == 0) then
		members = {client}
	end

	draw.SimpleText("SQUAD MEMBERS", mono, x, cursor, hud.Fade(palette.soft, alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	cursor = cursor + hud.Sc(18)

	hud.FadeLine(x, cursor, hud.Sc(250), math.max(hud.Sc(1), 1), hud.Fade(palette.main, alpha * 0.6))
	cursor = cursor + hud.Sc(5)

	for _, member in ipairs(members) do
		if (!IsValid(member)) then
			continue
		end

		local nick = member:GetCharacterName()
		local zone = ZoneName(member)
		local bAlive = member:Alive()
		local color = bAlive and palette.main or palette.warn

		Row(nick .. " :: ", zone, hud.Fade(color, alpha), hud.Fade(palette.soft, alpha),
			hud.HasCyrillic(nick) and rowZekton or rowFont, hud.HasCyrillic(zone) and rowZekton or rowFont)
		cursor = cursor + hud.Sc(17)
	end

	return cursor - y
end

function hud.DrawInfo(x, y, palette, alpha, client)

	local mono = hud.FaceFont(hud.monoFace, 16, 700)
	local zekton = hud.Font(16, 700, false, true)
	local rows = {
		{"ЗОНА", ZoneName(client)},
		{"ЗДОРОВЬЕ", math.max(client:Health(), 0) .. "%"},
		{"ВРЕМЯ", NETWORK.time.GetFormatted()}
	}
	local cursor = y

	for _, row in ipairs(rows) do
		local value = row[2]
		local valueFont = hud.HasCyrillic(value) and zekton or mono

		draw.SimpleText(value, valueFont, x, cursor, hud.Fade(palette.main, alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		surface.SetFont(valueFont)

		local valueWidth = surface.GetTextSize(value)

		draw.SimpleText(row[1] .. " :: ", zekton, x - valueWidth, cursor, hud.Fade(palette.soft, alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

		cursor = cursor + hud.Sc(22)
	end

	return cursor - y
end

local CARDINALS = {[0] = "С", [45] = "СВ", [90] = "В", [135] = "ЮВ", [180] = "Ю", [225] = "ЮЗ",
	[270] = "З", [315] = "СЗ"}

function hud.DrawCompass(centerX, y, width, palette, alpha, bMicro)
	local yaw = LocalPlayer():EyeAngles().y
	local heading = (90 - yaw) % 360
	local span = bMicro and 90 or 120
	local perDegree = width / span
	local labelFont = hud.Font(bMicro and 13 or 16, 700, false, true)
	local numberFont = hud.FaceFont(hud.monoFace, bMicro and 10 or 12, 600)
	local left = centerX - width * 0.5

	for offset = -span * 0.5 - 15, span * 0.5 + 15 do
		local degree = math.floor(heading + offset)

		if (degree % 15 != 0) then
			continue
		end

		local x = centerX + (degree - heading) * perDegree
		local edge = 1 - math.Clamp(math.abs(x - centerX) / (width * 0.5), 0, 1)
		local fade = math.min(edge * 3, 1)
		local normalised = degree % 360

		if (x < left or x > left + width) then
			continue
		end

		local cardinal = CARDINALS[normalised]

		if (cardinal) then
			draw.SimpleText(cardinal, labelFont, x, y, hud.Fade(palette.main, alpha * fade),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		elseif (!bMicro and normalised % 45 != 0) then
			draw.SimpleText(tostring(normalised), numberFont, x, y + hud.Sc(3),
				hud.Fade(palette.soft, alpha * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		local tick = cardinal and hud.Sc(8) or hud.Sc(4)

		surface.SetDrawColor(palette.main.r, palette.main.g, palette.main.b,
			(cardinal and 200 or 110) * alpha * fade)
		surface.DrawRect(x, y + hud.Sc(bMicro and 16 or 20), 1, tick)
	end

	surface.SetDrawColor(palette.main.r, palette.main.g, palette.main.b, 230 * alpha)
	surface.DrawRect(centerX, y + hud.Sc(bMicro and 16 or 20) - hud.Sc(4), math.max(hud.Sc(2), 2),
		hud.Sc(bMicro and 12 or 16))

	draw.SimpleText(string.format("%03d", math.floor(heading)), numberFont, centerX,
		y + hud.Sc(bMicro and 30 or 36), hud.Fade(palette.main, alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_TOP)
end

hook.Add("HUDPaint", "nwCombineHud", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or NETWORK.hud.IsHidden()) then
		hud.alpha = 0

		return
	end

	local kind = hud.GetKind(client)

	if (!kind) then
		hud.alpha = 0

		return
	end

	local target = (IsValid(NETWORK.gui.menu) or IsValid(NETWORK.gui.tabMenu)) and 0 or 1

	if (!client:Alive()) then
		target = target * 0.4
	end

	hud.alpha = math.Approach(hud.alpha, target, FrameTime() * 4)

	if (hud.alpha <= 0.01) then
		return
	end

	hud.UpdateSway(client)

	local palette = hud.GetPalette(kind)
	local alpha = hud.alpha
	local margin = hud.Sc(38)
	local right = ScrW() - margin
	local bottom = ScrH() - margin
	local barWidth = math.Round(math.min(ScrW() * 0.105, hud.Sc(215)))
	local bCWU = kind == "cwu"
	local bSoldier = kind == "cmb"

	local function Block(name, ...)
		local callback = hud[name]

		if (!isfunction(callback)) then
			return 0
		end

		local bSuccess, result = pcall(callback, ...)

		if (!bSuccess) then
			if (hud.reported != name) then
				hud.reported = name

				ErrorNoHalt("[network] HUD " .. name .. ": " .. tostring(result) .. "\n")
			end

			return 0
		end

		return tonumber(result) or 0
	end

	hud.DrawCurved(function()
		local top = hud.Sc(14)
		local cursor = top

		if (!bCWU) then
			cursor = cursor + Block("DrawStatusBar", right, cursor, barWidth, palette, alpha)
		else
			cursor = cursor + hud.Sc(24)
		end

		local tickerHeight = Block("DrawTicker", right, cursor + hud.Sc(4), palette, alpha)

		Block("DrawInfo", right, cursor + hud.Sc(4) + math.max(tickerHeight, hud.Sc(60)) + hud.Sc(16),
			palette, alpha, client)

		local leftCursor = margin + Block("DrawGlyphHeader", margin, margin, palette, alpha, client)

		if (!bCWU and NETWORK.schedule and NETWORK.schedule.IsCurfew()) then
			local blink = 0.7 + math.abs(math.sin(RealTime() * 2)) * 0.3

			draw.SimpleText("НАСТУПИЛ КОМЕНДАНТСКИЙ ЧАС", hud.Font(12, 700, false, true),
				math.Round(ScrW() * 0.5), margin + hud.Sc(4),
				Color(240, 84, 74, 235 * alpha * blink), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		Block("DrawTeam", margin, leftCursor + hud.Sc(24), palette, alpha, client)

		if (bSoldier) then
			Block("DrawCompass", ScrW() * 0.5, top + hud.Sc(6), hud.Sc(560), palette, alpha, false)
		elseif (bCWU) then
			Block("DrawCompass", ScrW() * 0.5, top + hud.Sc(4), hud.Sc(320), palette, alpha, true)
		end

		Block("DrawAmmo", right, bottom - hud.Sc(30) - hud.GetBrandHeight(), palette, alpha, client)
		Block("DrawUnitTags", palette, alpha, client)

		if (!bCWU) then
			Block("DrawTargetMarkers", palette, alpha, client)
		end
	end)
end)
