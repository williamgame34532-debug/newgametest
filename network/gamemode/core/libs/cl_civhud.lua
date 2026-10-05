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

	if (NETWORK.schedule and NETWORK.schedule.IsCurfew and
		NETWORK.schedule.IsCurfew() and
		curfewHud:GetBool()) then

		local pulse = 0.72 + math.abs(math.sin(CurTime() * 1.4)) * 0.28
		local label = util.Upper(L("curfewHud"))
		local hint = L("curfewHudHint")
		local warn = Color(226, 96, 88)
		local centerX = math.Round(ScrW() * 0.5)
		local labelY = Sc(26)
		local labelWidth = util.TextSpacedSize(label, "nwTag", Sc(3))
		local labelX = math.Round(centerX - labelWidth * 0.5)

		util.DrawTextSpaced(label, "nwTag", labelX + 1, labelY + 1,
			Color(0, 0, 0, 160 * pulse * fade), Sc(3), TEXT_ALIGN_TOP)
		util.DrawTextSpaced(label, "nwTag", labelX, labelY,
			ColorAlpha(warn, 250 * pulse * fade), Sc(3), TEXT_ALIGN_TOP)

		surface.SetFont("nwTag")

		local _, labelHeight = surface.GetTextSize("A")
		local lineY = labelY + labelHeight + Sc(4)
		local lineWidth = math.max(labelWidth, Sc(120))

		surface.SetDrawColor(warn.r, warn.g, warn.b, 170 * pulse * fade)
		surface.DrawRect(math.Round(centerX - lineWidth * 0.5), lineY, lineWidth,
			math.max(Sc(1), 1))

		draw.SimpleTextOutlined(hint, "nwHudSmall", centerX, lineY + Sc(12),
			ColorAlpha(theme.textDim, 235 * fade), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 150 * fade))
	end

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
