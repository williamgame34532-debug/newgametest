local repair = nil

net.Receive("nwArmorRepair", function()
	local duration = net.ReadFloat()
	local name = net.ReadString()

	if (duration <= 0) then
		repair = nil

		return
	end

	repair = {start = RealTime(), duration = duration, name = name}
end)

local function ConditionColor(fraction)
	local good = NETWORK.theme.good or Color(108, 220, 150)
	local bad = NETWORK.theme.danger or Color(228, 86, 80)

	return Color(Lerp(fraction, bad.r, good.r), Lerp(fraction, bad.g, good.g),
		Lerp(fraction, bad.b, good.b))
end

hook.Add("NetworkDrawHUD", "nwArmorWear", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local x = ScrW() - Sc(30)
	local y = Sc(236)
	local shadow = math.max(Sc(1), 1)

	for _, entry in ipairs({{"helmet", "armorHudHelmet"}, {"armour", "armorHudVest"}}) do
		local item = NETWORK.inventory.GetEquipped and NETWORK.inventory.GetEquipped(entry[1])
		local base = item and NETWORK.item.Get(item.id)

		if (!base or !base.maxUses or base.maxUses <= 1) then
			continue
		end

		local fraction = math.Clamp((item.uses or base.maxUses) / base.maxUses, 0, 1)
		local color = ConditionColor(fraction)
		local text = util.Upper(L(entry[2])) .. " :: " .. math.Round(fraction * 100) .. "%"

		util.DrawSimpleTextShadow(text, "nwHudLabel", x, y, ColorAlpha(color, 240),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, shadow)

		local barWidth = Sc(150)
		local barHeight = math.max(Sc(3), 2)

		surface.SetDrawColor(255, 255, 255, 26)
		surface.DrawRect(x - barWidth, y + Sc(11), barWidth, barHeight)
		surface.SetDrawColor(color.r, color.g, color.b, 230)
		surface.DrawRect(x - barWidth + math.Round(barWidth * (1 - fraction)), y + Sc(11),
			math.Round(barWidth * fraction), barHeight)

		y = y + Sc(26)
	end

	local active = client:GetActiveWeapon()
	local weaponClass = IsValid(active) and active:GetClass()

	if (weaponClass and NETWORK.weaponwear) then
		for slot in pairs(NETWORK.weaponwear.slots) do
			local item = NETWORK.inventory.GetEquipped and NETWORK.inventory.GetEquipped(slot)
			local base = item and NETWORK.item.Get(item.id)

			if (!base or !base.bWearWeapon or base.weaponClass != weaponClass) then
				continue
			end

			local maxUses = base.maxUses or NETWORK.weaponwear.maxUses
			local fraction = math.Clamp((item.uses or maxUses) / maxUses, 0, 1)
			local color = ConditionColor(fraction)
			local text = util.Upper(L("armorHudWeapon")) .. " :: " .. math.Round(fraction * 100) .. "%"

			util.DrawSimpleTextShadow(text, "nwHudLabel", x, y, ColorAlpha(color, 240),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, shadow)

			local barWidth = Sc(150)
			local barHeight = math.max(Sc(3), 2)

			surface.SetDrawColor(255, 255, 255, 26)
			surface.DrawRect(x - barWidth, y + Sc(11), barWidth, barHeight)
			surface.SetDrawColor(color.r, color.g, color.b, 230)
			surface.DrawRect(x - barWidth + math.Round(barWidth * (1 - fraction)), y + Sc(11),
				math.Round(barWidth * fraction), barHeight)

			y = y + Sc(26)

			break
		end
	end

	if (!repair) then
		return
	end

	local fraction = math.Clamp((RealTime() - repair.start) / repair.duration, 0, 1)

	if (fraction >= 1) then
		repair = nil

		return
	end

	local width = Sc(320)
	local left = math.Round(ScrW() * 0.5 - width * 0.5)
	local top = ScrH() - Sc(180)

	util.DrawSimpleTextShadow(util.Upper(L("armorRepairing", repair.name)), "nwHudLabel",
		left + math.Round(width * 0.5), top - Sc(12), ColorAlpha(theme.text, 240),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

	surface.SetDrawColor(0, 0, 0, 140)
	surface.DrawRect(left - 1, top - 1, width + 2, Sc(6) + 2)
	surface.SetDrawColor(255, 255, 255, 30)
	surface.DrawRect(left, top, width, Sc(6))
	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 235)
	surface.DrawRect(left, top, math.Round(width * fraction), Sc(6))
end)
