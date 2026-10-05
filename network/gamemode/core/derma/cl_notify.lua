NETWORK.gui.notices = NETWORK.gui.notices or {}

NETWORK.gui.noticeLife = 5
NETWORK.gui.noticeMax = 6

NETWORK.gui.noticeSide = CreateClientConVar("network_notify_side", "right",
	true, false, "Сторона уведомлений: left или right")

function NETWORK.gui.IsSevere(color)
	if (!color) then
		return false
	end

	return color.r > 190 and color.b < 140
end

function NETWORK.gui.Notify(text, color)
	if (!isstring(text) or text == "") then
		return
	end

	local Sc = NETWORK.util.Scale

	NETWORK.sound.Hint()

	color = color or NETWORK.theme.text

	table.insert(NETWORK.gui.notices, 1, {
		lines = NETWORK.util.WrapText(text, "nwNoticeBig", Sc(520), 3),
		color = color,
		severe = NETWORK.gui.IsSevere(color),
		time = CurTime(),
		slide = 1,
		alpha = 0,
		y = -1
	})

	while (#NETWORK.gui.notices > NETWORK.gui.noticeMax) do
		table.remove(NETWORK.gui.notices)
	end
end

hook.Add("HUDPaint", "nwNotices", function()
	local list = NETWORK.gui.notices

	if (#list == 0 or IsValid(NETWORK.gui.menu) or IsValid(NETWORK.gui.intro)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local frame = math.min(FrameTime(), 0.1)

	local bRight = NETWORK.gui.noticeSide:GetString() != "left"
	local x = bRight and (ScrW() - Sc(56)) or Sc(56)
	local y = Sc(56)
	local shadow = math.max(Sc(2), 1)

	surface.SetFont("nwNoticeBig")

	local _, lineHeight = surface.GetTextSize("A")

	for index = #list, 1, -1 do
		local notice = list[index]

		if (CurTime() - notice.time > NETWORK.gui.noticeLife + 2.4) then
			table.remove(list, index)
		end
	end

	local cursor = y

	for index = 1, #list do
		local notice = list[index]
		local age = CurTime() - notice.time
		local bGone = age > NETWORK.gui.noticeLife
		local height = lineHeight * #notice.lines + Sc(20)

		if (notice.y < 0) then
			notice.y = cursor
		end

		notice.y = Lerp(math.Clamp(frame * 10, 0, 1), notice.y, cursor)

		notice.alpha = Lerp(math.Clamp(frame * (bGone and 3.2 or 9), 0, 1), notice.alpha,
			bGone and 0 or 1)
		notice.slide = Lerp(math.Clamp(frame * (bGone and 3.2 or 8), 0, 1), notice.slide,
			bGone and 1 or 0)

		local alpha = util.EaseOut(notice.alpha)

		local offset = math.Round(util.EaseInOut(notice.slide) * Sc(90)) *
			(bRight and 1 or -1)

		cursor = cursor + height * math.max(notice.alpha, 0.05)

		if (alpha < 0.01) then
			continue
		end

		local textY = notice.y
		local textX = x + offset

		surface.SetFont("nwNoticeBig")

		local widest = 0

		for line = 1, #notice.lines do
			widest = math.max(widest, surface.GetTextSize(notice.lines[line]))
		end

		local iconBox = Sc(26)
		local plateWidth = widest + Sc(46) + iconBox + Sc(10)
		local plateX = bRight and (x + offset - plateWidth) or (textX - Sc(14))
		local plateY = notice.y - lineHeight * 0.5 - Sc(9)
		local plateHeight = lineHeight * #notice.lines + Sc(18)
		local radius = math.max(Sc(8), 5)
		local weight = notice.severe and 1 or 0

		draw.RoundedBox(radius, plateX, plateY, plateWidth, plateHeight,
			Color(10, 11, 13, (170 + 60 * weight) * alpha))

		local bar = math.max(Sc(3), 2)
		local pulse = notice.severe and
			(0.7 + math.abs(math.sin(CurTime() * 3.4)) * 0.3) or 1

		draw.RoundedBoxEx(radius, plateX, plateY, bar + 1, plateHeight,
			ColorAlpha(notice.color, 250 * alpha * pulse), true, false, true, false)

		local glyph = "i"

		if (notice.color == NETWORK.theme.positive or notice.tone == "good") then
			glyph = "✓"
		elseif (notice.color == NETWORK.theme.danger or notice.tone == "bad") then
			glyph = "✕"
		elseif (notice.color == NETWORK.theme.warning or notice.tone == "warn" or notice.severe) then
			glyph = "!"
		end

		local iconX = plateX + Sc(12)
		local iconY = plateY + math.Round((plateHeight - iconBox) * 0.5)

		draw.RoundedBox(math.max(Sc(5), 3), iconX, iconY, iconBox, iconBox,
			ColorAlpha(notice.color, 40 * alpha))

		draw.SimpleText(glyph, "nwField", iconX + math.Round(iconBox * 0.5),
			iconY + math.Round(iconBox * 0.5), ColorAlpha(notice.color, 250 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local life = math.Clamp(1 - age / NETWORK.gui.noticeLife, 0, 1)

		if (life > 0) then
			surface.SetDrawColor(notice.color.r, notice.color.g, notice.color.b,
				110 * alpha)
			surface.DrawRect(plateX + radius, plateY + plateHeight - 2,
				math.Round((plateWidth - radius * 2) * life), 2)
		end

		textX = plateX + Sc(12) + iconBox + Sc(12)

		for line = 1, #notice.lines do
			util.DrawSimpleTextShadow(notice.lines[line], "nwNoticeBig",
				textX, textY, ColorAlpha(notice.severe and notice.color or
				NETWORK.theme.text, 250 * alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER, shadow)

			textY = textY + lineHeight
		end
	end
end)

concommand.Add("network_notify_test", function(_, _, arguments)
	NETWORK.gui.Notify(table.concat(arguments, " "), NETWORK.theme.accentSoft)
end)
