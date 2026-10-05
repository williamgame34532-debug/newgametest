local modeConVar = CreateClientConVar("network_pickup_mode", "menu", true, false,
	"Как подбирать предметы: hold или menu")

function NETWORK.worldItem.IsMenuMode()
	return modeConVar:GetString() != "hold"
end

local target
local alpha = 0
local hold = 0

hook.Add("Think", "nwWorldItem", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		target = nil
		hold = 0

		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (IsValid(entity) and entity:GetClass() == "nw_item" and
		client:GetPos():Distance(trace.HitPos) <= NETWORK.worldItem.range) then
		target = entity
	else
		target = nil
	end

	if (NETWORK.worldItem.IsMenuMode()) then
		hold = 0

		local bDown = client:KeyDown(IN_USE)

		if (bDown and !NETWORK.worldItem.bDown) then
			NETWORK.worldItem.pressTime = CurTime()
		end

		if (!bDown and NETWORK.worldItem.bDown and target and
			CurTime() - (NETWORK.worldItem.pressTime or 0) < 0.4 and
			!IsValid(NETWORK.gui.pickup)) then
			NETWORK.gui.OpenPickupMenu(target)
		end

		NETWORK.worldItem.bDown = bDown

		return
	end

	if (target and client:KeyDown(IN_USE)) then
		hold = math.min(hold + FrameTime(), NETWORK.worldItem.holdTime)
	else
		hold = math.max(hold - FrameTime() * 3, 0)
	end
end)

hook.Add("NetworkDrawHUD", "nwWorldItem", function()
	alpha = NETWORK.util.Approach(alpha, IsValid(target) and 1 or 0, 9)

	if (alpha < 0.02 or !IsValid(target)) then
		return
	end

	local item = target:GetItem()

	if (!item) then
		return
	end

	local Sc = NETWORK.util.Scale
	local client = LocalPlayer()
	local util = NETWORK.util
	local theme = NETWORK.theme
	local rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(item))
	local color = rarity.color
	local name = NETWORK.item.GetName(item)
	local amount = (item.amount or 1) > 1 and ("×" .. item.amount) or nil
	local base = NETWORK.item.Get(item.id)
	local factions = base and (base.pickupFactions or base.factions)
	local bAllowed = NETWORK.dialogue.FactionAllowed(client, factions)
	local fraction = hold / NETWORK.worldItem.holdTime
	local fade = util.EaseOut(alpha)
	local key = string.upper(input.LookupBinding("+use") or "E")
	local prompt = bAllowed and L(NETWORK.worldItem.IsMenuMode() and
		"itemHintMenu" or "itemHintHold") or L("itemWrongFaction")
	local detail = L(rarity.name) .. "  ·  " ..
		string.format("%.2f", NETWORK.item.GetWeight(item)) .. " " .. L("invWeightUnitLong")

	surface.SetFont("nwField")

	local nameWidth = surface.GetTextSize(name)
	local amountWidth = amount and (surface.GetTextSize(amount) + Sc(18)) or 0

	surface.SetFont("nwHudSmall")

	local detailWidth = surface.GetTextSize(detail)
	local promptWidth = surface.GetTextSize(prompt) + Sc(40)
	local icon = Sc(34)
	local pad = Sc(14)
	local textWidth = math.max(nameWidth + amountWidth, detailWidth, promptWidth)
	local width = math.min(pad + icon + Sc(12) + textWidth + pad, Sc(460))
	local height = Sc(84)
	local x = math.Round((ScrW() - width) * 0.5)
	local y = math.Round(ScrH() * 0.56) + math.Round((1 - fade) * Sc(12))

	util.DrawSoftLight(x + math.Round(width * 0.5), y + math.Round(height * 0.5),
		width * 1.4, height * 2.2, Color(0, 0, 0), 110 * fade)

	if (NETWORK.style and NETWORK.style.Leader) then
		local screen = target:WorldSpaceCenter():ToScreen()

		if (screen.visible) then
			NETWORK.style.Leader(math.Round(screen.x), math.Round(screen.y), x, y, width,
				height, color, fade * 0.9, fade)
		end
	end

	util.DrawSoftLight(x + pad + math.Round(icon * 0.5), y + Sc(26), icon * 3, icon * 3,
		color, 30 * fade)

	NETWORK.gui.DrawBlackGlass(nil, x, y, width, height, fade, Sc(12))

	local iconX = x + pad + math.floor(icon * 0.5)
	local iconY = y + Sc(26)

	util.DrawCircle(iconX, iconY, math.floor(icon * 0.5), ColorAlpha(color, 26 * fade))
	util.DrawArc(iconX, iconY, math.floor(icon * 0.5), math.max(Sc(2), 2), 1,
		ColorAlpha(color, 220 * fade), 48)
	util.DrawCircle(iconX, iconY, Sc(4), ColorAlpha(color, 250 * fade))

	local textX = x + pad + icon + Sc(12)
	local limit = x + width - pad

	draw.SimpleText(util.TruncateWidth(name, "nwField", limit - textX - amountWidth), "nwField",
		textX, y + Sc(18), ColorAlpha(theme.text, 252 * fade), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)

	if (amount) then
		surface.SetFont("nwField")

		local badgeWidth = surface.GetTextSize(amount) + Sc(12)

		draw.RoundedBox(Sc(8), limit - badgeWidth, y + Sc(9), badgeWidth, Sc(18),
			ColorAlpha(color, 34 * fade))
		draw.SimpleText(amount, "nwHudSmall", limit - math.floor(badgeWidth * 0.5),
			y + Sc(18), ColorAlpha(color, 250 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText(detail, "nwHudSmall", textX, y + Sc(37),
		ColorAlpha(theme.textDim, 235 * fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(255, 255, 255, 16 * fade)
	surface.DrawRect(x + pad, y + Sc(52), width - pad * 2, 1)

	local rowY = y + Sc(68)

	if (fraction > 0.01) then
		local barX = x + pad
		local barWidth = width - pad * 2
		local barHeight = math.max(Sc(4), 3)
		local fill = math.Round(barWidth * fraction)

		draw.RoundedBox(math.floor(barHeight * 0.5), barX, rowY - math.floor(barHeight * 0.5),
			barWidth, barHeight, Color(255, 255, 255, 16 * fade))

		if (fill >= barHeight) then
			draw.RoundedBox(math.floor(barHeight * 0.5), barX,
				rowY - math.floor(barHeight * 0.5), fill, barHeight, ColorAlpha(color, 245 * fade))

			util.DrawSoftLight(barX + fill, rowY, Sc(30), Sc(18), color, 70 * fade)
		end

		return
	end

	surface.SetFont("nwHudSmall")

	local keyWidth = math.max(Sc(22), (surface.GetTextSize(key)) + Sc(12))
	local keyColor = bAllowed and theme.hover or theme.danger

	draw.RoundedBox(Sc(5), textX - icon - Sc(12), rowY - Sc(9), keyWidth, Sc(18),
		ColorAlpha(keyColor, 36 * fade))
	util.DrawRoundedBorder(textX - icon - Sc(12), rowY - Sc(9), keyWidth, Sc(18), Sc(5), 1,
		ColorAlpha(keyColor, 200 * fade))
	draw.SimpleText(key, "nwHudSmall", textX - icon - Sc(12) + math.floor(keyWidth * 0.5), rowY,
		ColorAlpha(theme.text, 250 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(prompt, "nwHudSmall", textX - icon - Sc(12) + keyWidth + Sc(10), rowY,
		ColorAlpha(bAllowed and theme.textDim or theme.danger, 240 * fade), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end)

hook.Add("NetworkDrawHUD", "nwManhackLabel", function()
	local client = LocalPlayer()

	if (!client:HasCharacter() or !NETWORK.factions.IsAlliance(client)) then
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!IsValid(entity) or entity:GetClass() != "npc_manhack") then
		return
	end

	if (client:GetPos():Distance(entity:GetPos()) > NETWORK.manhack.range) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local screen = entity:GetPos():ToScreen()

	if (!screen.visible) then
		return
	end

	local x = math.Round(screen.x)
	local y = math.Round(screen.y) - Sc(30)
	local shadow = math.max(Sc(2), 1)

	util.DrawSimpleTextShadow(util.Upper(L("itemManhack")), "nwField", x, y,
		ColorAlpha(theme.accent, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

	util.DrawSimpleTextShadow(L("itemManhackDesc"), "nwHudSmall", x, y + Sc(18),
		ColorAlpha(theme.textDim, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

	util.DrawSimpleTextShadow(util.Upper(L("itemManhackTake")), "nwHudSmall", x,
		y + Sc(38), ColorAlpha(theme.textFaint, 220), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER, shadow)
end)
