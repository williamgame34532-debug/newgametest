-- TAB → Навыки (sh_skills.lua): a panel beside the sheet of players. A card for every skill: the
-- icon, the name, the level of 10 in segments, the bar of the experience to the next level, what
-- the skill gives now and how it grows.

local SK = NW.skills
local U = NW.ui
local MUTED = Color(118, 120, 122)
local ACCENT = Color(232, 196, 72)

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwSkillTitle", "Montserrat SemiBold", 0.026, 600)
	F("nwSkillName", "Montserrat SemiBold", 0.019, 600)
	F("nwSkillText", "Exo 2", 0.0155, 500)
	F("nwSkillSmall", "Montserrat Medium", 0.0128, 500)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwSkillFonts", Fonts)

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

	if (line != "") then
		lines[#lines + 1] = line
	end

	return lines
end

-- the panel inside the TAB frame, at x
function SK.OpenPanel(frame, x)
	if (IsValid(SK.panel)) then
		SK.panel:Remove()
		SK.panel = nil

		return
	end

	local sw, sh = ScrW(), ScrH()
	local w = math.Round(math.min(sw - x - sh * 0.04, sh * 1.05))
	local h = math.Round(sh * 0.84)
	local panel = frame:Add("EditablePanel")

	panel:SetPos(x, (sh - h) / 2)
	panel:SetSize(w, h)
	panel.born = RealTime()
	SK.panel = panel

	local pad = math.Round(sh * 0.026)
	local gap = math.Round(sh * 0.016)
	local columns = 2
	local cardW = math.floor((w - pad * 2 - gap) / columns)
	local top = math.Round(sh * 0.085)
	local rows = math.ceil(#NW.char.skills / columns)
	local cardH = math.floor((h - top - pad - gap * (rows - 1)) / rows)

	panel.Paint = function(self, pw, ph)
		local a = math.Clamp((RealTime() - self.born) / 0.2, 0, 1)

		U.Blur(0, 0, pw, ph, 3, 255 * a, self, 1)
		draw.RoundedBox(10, 0, 0, pw, ph, Color(16, 18, 21, 236 * a))
		draw.RoundedBox(2, 0, 0, pw, 3, ColorAlpha(ACCENT, 255 * a))
		U.DrawIcon("skills", pad, pad, sh * 0.034, ColorAlpha(ACCENT, 255 * a))
		draw.SimpleText("НАВЫКИ", "nwSkillTitle", pad + sh * 0.046, pad + sh * 0.017, ColorAlpha(U.color.text, 255 * a),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Растут от дела: чем чаще персонаж что-то делает, тем лучше это у него получается",
			"nwSkillSmall", pw - pad, pad + sh * 0.017, ColorAlpha(MUTED, 255 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	for index, skill in ipairs(NW.char.skills) do
		local info = SK.info[skill.id] or {gain = {}, Effect = function() return "" end}
		local column = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local card = panel:Add("DPanel")

		card:SetPos(pad + column * (cardW + gap), top + row * (cardH + gap))
		card:SetSize(cardW, cardH)
		card.Paint = function(_, cw, ch)
			local level = SK.Level(LocalPlayer(), skill.id)
			local xp = tonumber(SK.mine.xp[skill.id]) or 0
			local need = SK.Need(level)
			local maxed = level >= SK.max
			local ip = math.Round(ch * 0.07)
			local is = math.Round(ch * 0.16)

			draw.RoundedBox(8, 0, 0, cw, ch, Color(255, 255, 255, 8))

			-- the icon and the name
			U.DrawIcon(skill.icon, ip, ip, is, U.color.text)
			draw.SimpleText(skill.name, "nwSkillName", ip * 2 + is, ip + is * 0.3, U.color.text, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(skill.text, "nwSkillSmall", ip * 2 + is, ip + is * 0.78, MUTED, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(level .. " / " .. SK.max, "nwSkillName", cw - ip, ip + is * 0.3, maxed and ACCENT or U.color.text,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

			-- the level in segments
			local sy = ip * 2 + is
			local segW = (cw - ip * 2 - (SK.max - 1) * 4) / SK.max

			for i = 1, SK.max do
				local lit = i <= level

				draw.RoundedBox(2, ip + (i - 1) * (segW + 4), sy, segW, math.max(4, ch * 0.03),
					lit and ACCENT or Color(255, 255, 255, 18))
			end

			-- the experience to the next one
			local by = sy + ch * 0.06
			local fraction = maxed and 1 or math.Clamp(xp / need, 0, 1)

			draw.RoundedBox(2, ip, by, cw - ip * 2, 3, Color(255, 255, 255, 14))
			draw.RoundedBox(2, ip, by, (cw - ip * 2) * fraction, 3, ColorAlpha(U.color.text, 170))
			draw.SimpleText(maxed and "Наивысший уровень" or ("Опыт  " .. math.floor(xp) .. " / " .. need), "nwSkillSmall",
				ip, by + ch * 0.045, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			-- what it gives now
			local ey = by + ch * 0.1

			U.DrawIcon("trend", ip, ey - ch * 0.025, ch * 0.05, ACCENT)
			draw.SimpleText(info.Effect(level), "nwSkillText", ip + ch * 0.065, ey, U.color.text, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)

			-- how it grows
			local gy = ey + ch * 0.075

			draw.SimpleText("КАК РАЗВИТЬ", "nwSkillSmall", ip, gy, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			gy = gy + ch * 0.06

			for _, line in ipairs(info.gain) do
				for k, part in ipairs(Wrap(line, "nwSkillText", cw - ip * 3)) do
					draw.SimpleText((k == 1 and "•  " or "    ") .. part, "nwSkillText", ip, gy, Color(196, 198, 202),
						TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
					gy = gy + ch * 0.065
				end
			end
		end
	end

	return panel
end
