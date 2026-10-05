NETWORK.esp = NETWORK.esp or {}

NETWORK.esp.range = 4000

local enabled = CreateClientConVar("network_esp", "1", true, false,
	"Показывать данные игроков в ноклипе")

function NETWORK.esp.IsActive()
	local client = LocalPlayer()

	if (!enabled:GetBool() or !IsValid(client) or !client:IsAdmin()) then
		return false
	end

	return client:GetMoveType() == MOVETYPE_NOCLIP and !IsValid(NETWORK.gui.menu)
end

hook.Add("HUDPaint", "nwAdminESP", function()
	if (!NETWORK.esp.IsActive()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local client = LocalPlayer()
	local eyePos = client:EyePos()
	local shadow = math.max(Sc(2), 1)

	for _, target in ipairs(player.GetAll()) do
		if (target == client or !target:Alive()) then
			continue
		end

		local top = target:GetPos() + Vector(0, 0, target:OBBMaxs().z + 10)
		local distance = eyePos:Distance(top)

		if (distance > NETWORK.esp.range) then
			continue
		end

		local screen = top:ToScreen()

		if (!screen.visible) then
			continue
		end

		local factionID = target:GetCharacterFaction()
		local faction = factionID and NETWORK.factions.Get(factionID)
		local color = faction and faction.color or theme.accent
		local weapon = target:GetActiveWeapon()
		local x = math.Round(screen.x)
		local y = math.Round(screen.y)
		local fade = 1 - math.Clamp((distance - NETWORK.esp.range * 0.7) /
			(NETWORK.esp.range * 0.3), 0, 1)

		util.DrawSimpleTextShadow(target:GetCharacterName(), "nwField", x, y,
			ColorAlpha(theme.text, 250 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

		util.DrawSimpleTextShadow(util.Upper(faction and L(faction.name) or
			L("playersNoFaction")), "nwHudSmall", x, y + Sc(18),
			ColorAlpha(color, 235 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

		local stats = string.format("%d HP  //  %d AP", math.max(target:Health(), 0),
			target:Armor())

		util.DrawSimpleTextShadow(stats, "nwHudSmall", x, y + Sc(36),
			ColorAlpha(theme.textDim, 235 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)

		local weaponName = IsValid(weapon) and
			language.GetPhrase(weapon:GetPrintName()) or "-"

		util.DrawSimpleTextShadow(weaponName, "nwHudSmall", x, y + Sc(52),
			ColorAlpha(theme.accentSoft, 230 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			shadow)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwAdminESP", function(bDepth, bSkybox)
	if (bSkybox or !NETWORK.esp.IsActive()) then
		return
	end

	local client = LocalPlayer()

	render.SetColorMaterial()

	for _, target in ipairs(player.GetAll()) do
		if (target == client or !target:Alive()) then
			continue
		end

		local factionID = target:GetCharacterFaction()
		local faction = factionID and NETWORK.factions.Get(factionID)
		local color = faction and faction.color or NETWORK.theme.accent
		local start = target:EyePos()
		local trace = util.TraceLine({
			start = start,
			endpos = start + target:GetAimVector() * 600,
			filter = target
		})

		render.DrawLine(start, trace.HitPos, ColorAlpha(color, 200), true)
		render.DrawWireframeSphere(trace.HitPos, 6, 6, 6, ColorAlpha(color, 220), true)

		local mins, maxs = target:GetCollisionBounds()

		render.DrawWireframeBox(target:GetPos(), angle_zero, mins, maxs,
			ColorAlpha(color, 90), true)
	end

	for _, zone in pairs(NETWORK.zone.list) do
		local data = NETWORK.zone.GetType(zone.type)
		local mins = NETWORK.zone.GetMins(zone)
		local maxs = NETWORK.zone.GetMaxs(zone)
		local center = (mins + maxs) * 0.5

		render.DrawWireframeBox(center, angle_zero, mins - center, maxs - center,
			ColorAlpha(data.color, 200), true)
		render.DrawBox(center, angle_zero, mins - center, maxs - center,
			ColorAlpha(data.color, 20), true)
	end
end)

hook.Add("HUDPaint", "nwAdminESPItems", function()
	if (!NETWORK.esp.IsActive()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local eyePos = LocalPlayer():EyePos()
	local shadow = math.max(Sc(2), 1)

	for _, entity in ipairs(ents.FindByClass("nw_item")) do
		local position = entity:GetPos() + Vector(0, 0, 10)

		if (eyePos:Distance(position) > NETWORK.esp.range) then
			continue
		end

		local screen = position:ToScreen()

		if (!screen.visible) then
			continue
		end

		local item = entity:GetItem()

		if (!item) then
			continue
		end

		local rarity = NETWORK.inventory.GetRarity(NETWORK.item.GetRarity(item))

		util.DrawSimpleTextShadow(NETWORK.item.GetName(item), "nwHudSmall",
			math.Round(screen.x), math.Round(screen.y), ColorAlpha(rarity.color, 240),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)
	end

	for _, entity in ipairs(ents.FindByClass("nw_container")) do
		local position = entity:GetPos() + Vector(0, 0, entity:OBBMaxs().z + 8)

		if (eyePos:Distance(position) > NETWORK.esp.range) then
			continue
		end

		local screen = position:ToScreen()

		if (!screen.visible) then
			continue
		end

		util.DrawSimpleTextShadow(entity:GetDisplayName(), "nwHudSmall",
			math.Round(screen.x), math.Round(screen.y), ColorAlpha(theme.accentSoft, 240),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)
	end
end)

hook.Add("NetworkDrawHUD", "nwAdminESPZones", function()
	if (!NETWORK.esp.IsActive()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	for _, zone in pairs(NETWORK.zone.list) do
		local data = NETWORK.zone.GetType(zone.type)
		local mins = NETWORK.zone.GetMins(zone)
		local maxs = NETWORK.zone.GetMaxs(zone)
		local screen = ((mins + maxs) * 0.5):ToScreen()

		if (!screen.visible) then
			continue
		end

		util.DrawSimpleTextShadow(zone.name or "?", "nwHudSmall", math.Round(screen.x),
			math.Round(screen.y), ColorAlpha(data.color, 235), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER, math.max(Sc(2), 1))
	end
end)
