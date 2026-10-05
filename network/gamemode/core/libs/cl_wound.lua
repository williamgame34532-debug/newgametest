NETWORK.wound.state = NETWORK.wound.state or {}

net.Receive("nwWoundSync", function()
	NETWORK.wound.state = NETWORK.util.ReadTable()

	hook.Run("NetworkWoundsUpdated")
end)

function NETWORK.wound.RequestHeal(part, index)
	net.Start("nwWoundHeal")
		net.WriteString(part)
		net.WriteUInt(index, 8)
	net.SendToServer()
end

hook.Add("NetworkDrawHUD", "nwWound", function()
	local client = LocalPlayer()
	local fallen = client:GetNWFloat("nwFallen", 0)

	if (fallen <= CurTime()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local left = fallen - CurTime()
	local fraction = 1 - math.Clamp(left / NETWORK.wound.fallTime, 0, 1)
	local centerX = math.Round(ScrW() * 0.5)
	local centerY = math.Round(ScrH() * 0.5) + Sc(60)
	local shadow = math.max(Sc(2), 1)
	local pulse = 0.85 + math.sin(CurTime() * 4) * 0.15

	surface.SetDrawColor(120, 20, 20, 40 * pulse)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	local title = util.Upper(L("woundFallen"))
	local titleWidth = util.TextSpacedSize(title, "nwTitle", Sc(9))

	util.DrawTextSpacedShadow(title, "nwTitle", centerX - math.Round(titleWidth * 0.5),
		centerY - Sc(60), ColorAlpha(Color(232, 108, 100), 250), Sc(9), TEXT_ALIGN_CENTER,
		shadow)

	util.DrawArc(centerX, centerY + Sc(30), Sc(44), Sc(5), 1, Color(0, 0, 0, 170), 96)
	util.DrawArc(centerX, centerY + Sc(30), Sc(44), Sc(5), fraction,
		Color(232, 108, 100, 250), 96)

	util.DrawSimpleTextShadow(string.format("%.1f", math.max(left, 0)), "nwHeader", centerX,
		centerY + Sc(30), ColorAlpha(theme.text, 252), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
		shadow)
end)
