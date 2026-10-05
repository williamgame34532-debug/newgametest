local P = NETWORK.pvp

local feed = {}
local feedLife = 6

net.Receive("nwPvpKill", function()
	local attacker = net.ReadEntity()
	local victim = net.ReadEntity()
	local weapon = net.ReadString()
	local metres = net.ReadFloat()

	local client = LocalPlayer()

	local entry = {
		attacker = IsValid(attacker) and attacker:GetCharacterName() or "?",
		victim = IsValid(victim) and victim:GetCharacterName() or "?",
		attackerTeam = IsValid(attacker) and attacker:Team() or 0,
		victimTeam = IsValid(victim) and victim:Team() or 0,
		weapon = weapon,
		metres = metres,
		start = RealTime(),
		bMine = attacker == client,
		bVictim = victim == client
	}

	feed[#feed + 1] = entry

	if (#feed > 6) then
		table.remove(feed, 1)
	end

	if (entry.bMine) then
		chat.nwAddText(Color(226, 76, 68), L("pvpYouKilled", entry.victim,
			string.format("%.1f", metres), weapon))

		surface.PlaySound("buttons/button17.wav")
	elseif (entry.bVictim) then
		chat.nwAddText(Color(226, 76, 68), L("pvpYouDied", entry.attacker,
			string.format("%.1f", metres), weapon))
	end
end)

local function TeamColor(team)
	local data = P.GetTeam(team)

	return data and data.color or NETWORK.theme.text
end

hook.Add("HUDPaint", "nwPvpFeed", function()
	if (#feed == 0) then
		return
	end

	local Sc = NETWORK.util.Scale
	local now = RealTime()
	local x = Sc(24)
	local y = Sc(90)

	for index = #feed, 1, -1 do
		local entry = feed[index]
		local age = now - entry.start

		if (age > feedLife) then
			table.remove(feed, index)

			continue
		end

		local appear = math.Clamp(age / 0.25, 0, 1)
		local fade = math.Clamp((feedLife - age) / 1, 0, 1)
		local alpha = 255 * fade
		local slide = (1 - NETWORK.util.EaseOut(appear)) * Sc(60)

		local rowY = y + (#feed - index) * Sc(26)
		local rowX = x - slide

		local curve = math.sin((#feed - index) / math.max(#feed, 1) * math.pi) *
			Sc(4)

		rowX = rowX + curve

		surface.SetDrawColor(8, 9, 11, 190 * fade)
		surface.DrawRect(rowX - Sc(8), rowY - Sc(3), Sc(360), Sc(24))

		surface.SetDrawColor(TeamColor(entry.attackerTeam).r,
			TeamColor(entry.attackerTeam).g, TeamColor(entry.attackerTeam).b,
			220 * fade)
		surface.DrawRect(rowX - Sc(8), rowY - Sc(3), math.max(Sc(2), 1), Sc(24))

		local textX = rowX

		draw.SimpleTextOutlined(entry.attacker, "nwField", textX, rowY + Sc(9),
			ColorAlpha(TeamColor(entry.attackerTeam), alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200 * fade))

		local width = surface.GetTextSize(entry.attacker)

		textX = textX + width + Sc(10)

		local middle = "→ " .. entry.weapon .. " →"

		draw.SimpleTextOutlined(middle, "nwHudSmall", textX, rowY + Sc(9),
			Color(190, 190, 190, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER,
			1, Color(0, 0, 0, 200 * fade))

		surface.SetFont("nwHudSmall")

		local middleWidth = surface.GetTextSize(middle)

		draw.SimpleTextOutlined(entry.victim, "nwField",
			textX + middleWidth + Sc(10), rowY + Sc(9),
			ColorAlpha(TeamColor(entry.victimTeam), alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200 * fade))
	end
end)

hook.Add("HUDPaint", "nwPvpScore", function()
	if (!P.IsActive()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !P.HasSide(client)) then
		return
	end

	local Sc = NETWORK.util.Scale
	local x = ScrW() * 0.5
	local y = Sc(16)

	draw.SimpleTextOutlined(P.GetScore(P.TEAM_RED), "nwInvTitle", x - Sc(40), y,
		P.GetTeam(P.TEAM_RED).color, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1,
		Color(0, 0, 0, 220))
	draw.SimpleTextOutlined(":", "nwInvTitle", x, y, NETWORK.theme.textDim,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 220))
	draw.SimpleTextOutlined(P.GetScore(P.TEAM_BLUE), "nwInvTitle", x + Sc(40), y,
		P.GetTeam(P.TEAM_BLUE).color, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1,
		Color(0, 0, 0, 220))

	local state = P.GetState()

	if (state == "live" or state == "break") then
		local left = P.GetRoundLeft()
		local clock = string.format("%d:%02d", math.floor(left / 60),
			math.floor(left % 60))

		draw.SimpleTextOutlined(state == "break" and L("pvpBreak") or clock,
			"nwField", x, y + Sc(30),
			(state == "live" and left < 30) and Color(240, 120, 110) or
			NETWORK.theme.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1,
			Color(0, 0, 0, 220))

		draw.SimpleTextOutlined(L("pvpRoundLine", P.GetRound()), "nwHudSmall",
			x, y + Sc(48), NETWORK.theme.textDim, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
	end

	if (P.IsDead(client)) then
		draw.SimpleTextOutlined(L("pvpSpectating"), "nwField", ScrW() * 0.5,
			ScrH() - Sc(70), Color(226, 120, 110), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
	end
end)

local chStyle = CreateClientConVar("network_ch_style", "cross", true, false)
local chSize = CreateClientConVar("network_ch_size", "10", true, false)
local chGap = CreateClientConVar("network_ch_gap", "4", true, false)
local chThick = CreateClientConVar("network_ch_thick", "2", true, false)
local chRed = CreateClientConVar("network_ch_r", "255", true, false)
local chGreen = CreateClientConVar("network_ch_g", "255", true, false)
local chBlue = CreateClientConVar("network_ch_b", "255", true, false)
local chDot = CreateClientConVar("network_ch_dot", "0", true, false)

NETWORK.pvp.styles = {"cross", "dot", "circle", "tshape", "off"}

hook.Add("HUDShouldDraw", "nwPvpCrosshair", function(element)
	if (element != "CHudCrosshair") then
		return
	end

	if (chStyle:GetString() == "off" or !P.IsActive()) then
		return
	end

	local client = LocalPlayer()

	if (IsValid(client) and client:Alive() and !P.IsDead(client)) then
		return false
	end
end)

hook.Add("HUDPaint", "nwPvpCrosshair", function()
	local style = chStyle:GetString()

	if (style == "off" or !P.IsActive()) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or P.IsDead(client)) then
		return
	end

	local x, y = ScrW() * 0.5, ScrH() * 0.5
	local size = math.Clamp(chSize:GetInt(), 1, 60)
	local gap = math.Clamp(chGap:GetInt(), 0, 40)
	local thick = math.Clamp(chThick:GetInt(), 1, 10)
	local color = Color(chRed:GetInt(), chGreen:GetInt(), chBlue:GetInt())

	surface.SetDrawColor(color)

	if (style == "cross" or style == "tshape") then
		surface.DrawRect(x - gap - size, y - thick * 0.5, size, thick)
		surface.DrawRect(x + gap, y - thick * 0.5, size, thick)
		surface.DrawRect(x - thick * 0.5, y + gap, thick, size)

		if (style == "cross") then
			surface.DrawRect(x - thick * 0.5, y - gap - size, thick, size)
		end
	elseif (style == "circle") then
		local segments = 32

		for index = 1, segments do
			local a1 = (index / segments) * math.pi * 2
			local a2 = ((index + 1) / segments) * math.pi * 2

			surface.DrawLine(x + math.cos(a1) * (gap + size),
				y + math.sin(a1) * (gap + size),
				x + math.cos(a2) * (gap + size),
				y + math.sin(a2) * (gap + size))
		end
	end

	if (style == "dot" or chDot:GetBool()) then
		surface.DrawRect(x - thick * 0.5, y - thick * 0.5, thick, thick)
	end
end)
