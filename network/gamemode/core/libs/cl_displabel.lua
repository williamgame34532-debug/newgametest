NETWORK.displabel = NETWORK.displabel or {}

local D = NETWORK.displabel

D.current = nil

function D.Show(title, text, duration)
	if (text == "" and title == "") then
		D.current = nil

		return
	end

	D.current = {
		title = title,
		text = text,
		start = RealTime(),
		until_ = RealTime() + duration
	}

	surface.PlaySound("npc/overwatch/radiovoice/on2.wav")
end

net.Receive("nwDispLabel", function()
	local title = net.ReadString()
	local text = net.ReadString()
	local duration = net.ReadFloat()

	if (duration <= 0) then
		D.current = nil

		return
	end

	D.Show(title, text, duration)
end)

hook.Add("NetworkChatAdded", "nwDispLabelCenter", function(id, speaker, name, text)
	if (id != "center") then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !NETWORK.factions.IsAlliance(client)) then
		return
	end

	D.Show(L("patrolTitle"), text, 12)
end)

hook.Add("HUDPaint", "nwDispLabel", function()
	local data = D.current

	if (!data) then
		return
	end

	local now = RealTime()

	if (now > data.until_) then
		D.current = nil

		return
	end

	if (NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local alpha = math.Clamp((now - data.start) / 0.5, 0, 1) *
		math.Clamp((data.until_ - now) / 1, 0, 1)
	local accent = theme.combine
	local centerX = math.Round(ScrW() * 0.5)
	local y = Sc(160)
	local pulse = 0.85 + math.sin(now * 3) * 0.15

	if (data.title != "") then
		local title = ":: " .. util.Upper(data.title) .. " ::"
		local titleWidth = util.TextSpacedSize(title, "nwHudLabelSmall", Sc(4))

		util.DrawTextSpaced(title, "nwHudLabelSmall", centerX - math.Round(titleWidth * 0.5),
			y, ColorAlpha(accent, 240 * alpha * pulse), Sc(4), TEXT_ALIGN_CENTER)
	end

	draw.SimpleText(util.Upper(data.text), "nwHudLabel", centerX, y + Sc(26),
		ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local textWidth = util.TextSpacedSize(util.Upper(data.text), "nwHudLabel", 0)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 160 * alpha)
	surface.DrawRect(centerX - math.Round(textWidth * 0.5) - Sc(20), y + Sc(42),
		textWidth + Sc(40), math.max(Sc(1), 1))
end)
