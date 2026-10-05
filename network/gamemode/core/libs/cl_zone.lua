NETWORK.zone.current = nil
NETWORK.zone.alpha = 0
NETWORK.zone.bEditing = false
NETWORK.zone.editStart = nil

local fogAlpha = 0

net.Receive("nwZoneSync", function()
	NETWORK.zone.list = NETWORK.util.ReadTable()

	hook.Run("NetworkZonesUpdated")
end)

net.Receive("nwZoneEditor", function()
	local action = net.ReadString()
	local payload = NETWORK.util.ReadTable()

	if (action == "toggle") then
		NETWORK.zone.ToggleEditing()
	end
end)

NETWORK.zone.grace = 0.4

hook.Add("Think", "nwZone", function()
	if (!NETWORK.util.Throttle("zone.current", 0.15)) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local zone = NETWORK.zone.AtEntity(client)

	if (zone) then
		NETWORK.zone.lastSeen = CurTime()

		if (!NETWORK.zone.current or NETWORK.zone.current.id != zone.id) then
			NETWORK.zone.enterTime = CurTime()

			NETWORK.zone.typed = 0
			NETWORK.zone.typeTime = CurTime()

			if (zone.greeting and zone.greeting != "" and NETWORK.option.Get("zoneGreeting") != "off") then
				local data = NETWORK.zone.GetType(zone.type)

				if (hook.Run("NetworkZoneGreeting", zone, data) != true) then
					NETWORK.gui.Notify(zone.greeting, data.color)
				end
			end

			hook.Run("NetworkZoneChanged", NETWORK.zone.current, zone)
		end

		NETWORK.zone.current = zone

		return
	end

	if (!NETWORK.zone.current) then
		return
	end

	if (CurTime() - (NETWORK.zone.lastSeen or 0) < NETWORK.zone.grace) then
		return
	end

	hook.Run("NetworkZoneChanged", NETWORK.zone.current, nil)

	NETWORK.zone.current = nil
end)

local typeSpeed = 0.045

local function SubChars(text, count)
	if (count <= 0) then
		return ""
	end

	local length = utf8.len(text) or #text

	if (count >= length) then
		return text
	end

	local offset = utf8.offset(text, count + 1)

	return offset and string.sub(text, 1, offset - 1) or text
end

local PLATE_HOLD = 6
local PLATE_COLLAPSE = 0.6
local LINE_GROW = 1.2
local RAD_COLOR = Color(222, 208, 70)
local TOXIC_COLOR = Color(126, 214, 92)
local ZONE_TYPE_ICONS = {neutral = "location_city", toxic = "coronavirus", loot = "backpack",
	npc = "group", outlands = "forest", radiation = "warning"}

local function DrawSoftText(text, font, x, y, color, alpha)
	draw.SimpleText(text, font, x, y + 3, Color(0, 0, 0, 60 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, 150 * alpha), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
	draw.SimpleText(text, font, x, y, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "nwZone", function()
	if (GetConVar("network_zone_label") and !GetConVar("network_zone_label"):GetBool()) then return end
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter() or !client:Alive()) then
		return
	end

	if (NETWORK.hud and NETWORK.hud.IsHidden and NETWORK.hud.IsHidden()) then
		return
	end

	local zone = NETWORK.zone.current

	NETWORK.zone.alpha = NETWORK.util.Approach(NETWORK.zone.alpha, zone and 1 or 0,
		zone and 3.5 or 6)

	if (NETWORK.zone.alpha < 0.01) then
		return
	end

	zone = zone or NETWORK.zone.last

	if (!zone) then
		return
	end

	NETWORK.zone.last = zone

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local S = NETWORK.style
	local data = NETWORK.zone.GetType(zone.type)
	local color = data.color or S.Accent()
	local alpha = util.EaseInOut(NETWORK.zone.alpha)
	local name = util.Upper(zone.name or "")
	local length = utf8.len(name) or #name
	local age = CurTime() - (NETWORK.zone.enterTime or 0)

	local typed = math.Clamp(math.floor((CurTime() -
		(NETWORK.zone.typeTime or 0)) / typeSpeed), 0, length)

	if (typed > (NETWORK.zone.typed or 0)) then

		NETWORK.sound.ZoneType(typed / math.max(length, 1))

		NETWORK.zone.typed = typed
	end

	local shown = SubChars(name, typed)
	local kind = util.Upper(L(data.name))

	local protectedText

	if (zone.type == "toxic" and NETWORK.zone.IsToxicImmune) then
		local bImmune, reason = NETWORK.zone.IsToxicImmune(client)

		if (bImmune) then
			protectedText = util.Upper(L(reason == "faction" and "zoneChipProtectedFaction" or
				"zoneChipProtectedMask"))
		end
	end

	local iconName = (isstring(zone.icon) and zone.icon != "") and zone.icon or
		ZONE_TYPE_ICONS[zone.type or ""] or "location_city"
	local iconMaterial = util.GetMaterial("framework/icons/" .. iconName .. ".png", "smooth")

	if (iconMaterial and iconMaterial:IsError()) then
		iconMaterial = nil
	end

	local collapse = util.EaseInOut(math.Clamp((age - PLATE_HOLD) / PLATE_COLLAPSE, 0, 1))
	local full = alpha * (1 - collapse)
	local slim = alpha * collapse
	local x = Sc(40) - math.Round((1 - alpha) * Sc(18))
	local centerY = math.Round(ScrH() * 0.5)

	if (full > 0.01) then
		local boxSize = math.max(Sc(36), 22)
		local radius = S.Radius("cell")
		local captionY = centerY - math.Round(boxSize * 0.5) - Sc(14)
		local rowY = centerY - math.Round(boxSize * 0.5)
		local nameX = x + boxSize + Sc(12)

		util.DrawTextSpacedShadow(kind, "nwInvKey", x, captionY,
			ColorAlpha(color, 240 * full), Sc(3), TEXT_ALIGN_CENTER, 1)

		draw.RoundedBox(radius, x, rowY, boxSize, boxSize, Color(0, 0, 0, 90 * full))
		util.DrawRoundedBorder(x, rowY, boxSize, boxSize, radius, 1,
			ColorAlpha(color, 210 * full))

		if (iconMaterial) then
			local iconSize = math.Round(boxSize * 0.56)

			surface.SetMaterial(iconMaterial)
			surface.SetDrawColor(color.r, color.g, color.b, 250 * full)
			surface.DrawTexturedRect(x + math.Round((boxSize - iconSize) * 0.5),
				rowY + math.Round((boxSize - iconSize) * 0.5), iconSize, iconSize)
		end

		DrawSoftText(shown, "nwHudName", nameX, centerY, ColorAlpha(theme.text, 252 * full), full)

		surface.SetFont("nwHudName")

		local shownWidth = surface.GetTextSize(shown)
		local nameWidth = surface.GetTextSize(name)

		if (typed < length) then
			surface.SetDrawColor(color.r, color.g, color.b, 235 * full)
			surface.DrawRect(nameX + shownWidth + Sc(4), centerY + Sc(8), Sc(10),
				math.max(Sc(2), 2))
		end

		local grow = util.EaseOut(math.Clamp((age - 0.15) / LINE_GROW, 0, 1))
		local lineWidth = math.Round((boxSize + Sc(12) + math.max(nameWidth, Sc(160)) + Sc(30)) * grow)
		local lineY = rowY + boxSize + Sc(8)

		if (lineWidth > 1) then
			util.DrawHGradient(x, lineY, lineWidth, 1, ColorAlpha(color, 235 * full),
				ColorAlpha(color, 0))
		end

		local chipX = x
		local chipY = lineY + Sc(8)
		local gap = Sc(6)

		if (NETWORK.schedule and NETWORK.schedule.IsCurfew and NETWORK.schedule.IsCurfew()) then
			chipX = chipX + S.Chip(util.Upper(L("zoneChipCurfew")), "nwInvKey", chipX, chipY,
				theme.danger, full) + gap
		end

		local radLevel = client:GetNWFloat("nwRadLevel", 0)

		if (radLevel > 0.02) then
			chipX = chipX + S.Chip(util.Upper(L("zoneChipRad", math.Round(radLevel * 100))),
				"nwInvKey", chipX, chipY, RAD_COLOR, full) + gap
		end

		local toxicLevel = client:GetNWFloat("nwToxicLevel", 0)

		if (toxicLevel > 0.02) then
			chipX = chipX + S.Chip(util.Upper(L("zoneChipToxic", math.Round(toxicLevel * 100))),
				"nwInvKey", chipX, chipY, TOXIC_COLOR, full) + gap
		end

		if (protectedText) then
			chipX = chipX + S.Chip(protectedText, "nwInvKey", chipX, chipY, theme.positive or
				TOXIC_COLOR, full) + gap
		end

		S.Chip(NETWORK.time.GetFormatted(), "nwInvKey", chipX, chipY, theme.textDim, full,
			{fill = 18, border = 70})
	end

	if (slim > 0.01) then
		local iconSize = Sc(14)
		local textX = x

		if (iconMaterial) then
			surface.SetMaterial(iconMaterial)
			surface.SetDrawColor(0, 0, 0, 150 * slim)
			surface.DrawTexturedRect(x + 1, centerY - math.Round(iconSize * 0.5) + 1, iconSize, iconSize)
			surface.SetDrawColor(color.r, color.g, color.b, 240 * slim)
			surface.DrawTexturedRect(x, centerY - math.Round(iconSize * 0.5), iconSize, iconSize)

			textX = x + iconSize + Sc(8)
		end

		DrawSoftText(name, "nwLabelBold", textX, centerY, ColorAlpha(theme.text, 235 * slim), slim)

		surface.SetFont("nwLabelBold")

		local nameWidth = surface.GetTextSize(name)

		util.DrawTextSpacedShadow("·  " .. kind, "nwInvKey", textX + nameWidth + Sc(8), centerY,
			ColorAlpha(color, 200 * slim), Sc(2), TEXT_ALIGN_CENTER, 1)

		if (protectedText) then
			local kindWidth = util.TextSpacedSize("·  " .. kind, "nwInvKey", Sc(2))

			surface.SetFont("nwInvKey")

			local _, chipTextHeight = surface.GetTextSize(protectedText)
			local chipHeight = chipTextHeight + math.max(Sc(3), 2) * 2

			S.Chip(protectedText, "nwInvKey", textX + nameWidth + Sc(16) + kindWidth,
				centerY - math.Round(chipHeight * 0.5), theme.positive or TOXIC_COLOR, slim)
		end
	end
end)

hook.Add("RenderScreenspaceEffects", "nwZoneFog", function()
	local zone = NETWORK.zone.current
	local bToxic = zone != nil and zone.type == "toxic" and zone.fog != false

	local exposure = LocalPlayer():GetNWFloat("nwToxicLevel", 0)

	fogAlpha = NETWORK.util.Approach(fogAlpha,
		bToxic and math.max(exposure, 0.25) or 0, 3)

	if (fogAlpha < 0.02) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0.02 * fogAlpha,
		["$pp_colour_addg"] = 0.06 * fogAlpha,
		["$pp_colour_addb"] = 0.01 * fogAlpha,
		["$pp_colour_brightness"] = -0.02 * fogAlpha,
		["$pp_colour_contrast"] = 1 - 0.08 * fogAlpha,
		["$pp_colour_colour"] = 1 - 0.45 * fogAlpha,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0.12 * fogAlpha,
		["$pp_colour_mulb"] = 0
	})
end)

local radAlpha = 0
local nextGeiger = 0
local GEIGER = {"player/geiger1.wav", "player/geiger2.wav", "player/geiger3.wav"}

hook.Add("Think", "nwZoneGeiger", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local zone = NETWORK.zone.current
	local level = client:GetNWFloat("nwRadLevel", 0)
	local bInside = zone != nil and zone.type == "radiation"

	if (!bInside and level < 0.02) then
		return
	end

	local intensity = math.Clamp(math.max(level, bInside and 0.2 or 0), 0, 1)

	if (RealTime() >= nextGeiger) then
		nextGeiger = RealTime() + math.Rand(0.04, 0.5) * (1.15 - intensity)

		surface.PlaySound(GEIGER[math.random(#GEIGER)])
	end
end)

hook.Add("RenderScreenspaceEffects", "nwZoneRadiation", function()
	local client = LocalPlayer()
	local level = IsValid(client) and client:GetNWFloat("nwRadLevel", 0) or 0

	radAlpha = NETWORK.util.Approach(radAlpha, level, 2)

	if (radAlpha < 0.02) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0.03 * radAlpha,
		["$pp_colour_addg"] = 0.03 * radAlpha,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.01 * radAlpha,
		["$pp_colour_contrast"] = 1 + 0.06 * radAlpha,
		["$pp_colour_colour"] = 1 - 0.35 * radAlpha,
		["$pp_colour_mulr"] = 0.05 * radAlpha,
		["$pp_colour_mulg"] = 0.05 * radAlpha,
		["$pp_colour_mulb"] = 0
	})
end)

hook.Add("HUDPaintBackground", "nwZoneFog", function()
	if (fogAlpha < 0.02) then
		return
	end

	local material = NETWORK.util.GetMaterial(NETWORK.post.vignettePath, "smooth")

	if (material:IsError()) then
		return
	end

	surface.SetDrawColor(96, 190, 88, 90 * fogAlpha)
	surface.SetMaterial(material)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)

function NETWORK.zone.ToggleEditing(bState)
	if (bState == nil) then
		bState = !NETWORK.zone.bEditing
	end

	NETWORK.zone.bEditing = bState
	NETWORK.zone.editStart = nil

	if (!bState and IsValid(NETWORK.gui.zoneEditor)) then
		NETWORK.gui.zoneEditor:Remove()
	end

	NETWORK.chat.Notify(L(bState and "zoneEditOn" or "zoneEditOff"))
end

function NETWORK.zone.GetAimPos()
	return LocalPlayer():GetEyeTraceNoCursor().HitPos
end

hook.Add("ShouldDrawCrosshair", "nwZone", function()
	if (NETWORK.zone.bEditing) then
		return true
	end
end)

hook.Add("PlayerBindPress", "nwZone", function(client, bind, bPressed)
	if (!NETWORK.zone.bEditing or !bPressed) then
		return
	end

	bind = string.lower(bind)

	if (string.find(bind, "attack2")) then
		if (NETWORK.zone.editStart) then
			NETWORK.zone.editStart = nil
		else
			NETWORK.zone.ToggleEditing(false)
		end

		return true
	end

	if (string.find(bind, "attack")) then
		if (!NETWORK.zone.editStart) then
			NETWORK.zone.editStart = NETWORK.zone.GetAimPos()

			NETWORK.sound.Click()
		elseif (!IsValid(NETWORK.gui.zoneEditor)) then
			local start = NETWORK.zone.editStart
			local finish = NETWORK.zone.GetAimPos()
			local mins = Vector(math.min(start.x, finish.x), math.min(start.y, finish.y),
				math.min(start.z, finish.z))
			local maxs = Vector(math.max(start.x, finish.x), math.max(start.y, finish.y),
				math.max(start.z, finish.z))

			if (maxs.x - mins.x < 8 or maxs.y - mins.y < 8) then
				NETWORK.chat.Notify(L("zoneTooSmall"), NETWORK.theme.danger)

				return true
			end

			if (maxs.z - mins.z < 8) then
				maxs.z = mins.z + 96
			end

			local rebound = NETWORK.zone.rebound

			NETWORK.zone.rebound = nil

			if (rebound) then
				local zone = table.Copy(rebound.data)

				zone.id = rebound.id

				NETWORK.gui.OpenZoneEditor(zone, mins, maxs)
			else
				NETWORK.gui.OpenZoneEditor(nil, mins, maxs)
			end
		end

		return true
	end

	if (string.find(bind, "reload")) then
		local zone = NETWORK.zone.At(client:GetPos()) or
			NETWORK.zone.At(NETWORK.zone.GetAimPos())

		if (zone and !IsValid(NETWORK.gui.zoneEditor)) then
			NETWORK.gui.ZoneEdit("delete", {id = zone.id})

			NETWORK.sound.Play("hover3", 92, 0.5)
		end

		return true
	end

	if (string.find(bind, "use")) then

		local zone = NETWORK.zone.At(client:GetPos()) or
			NETWORK.zone.At(NETWORK.zone.GetAimPos())

		if (zone and !IsValid(NETWORK.gui.zoneEditor)) then
			NETWORK.gui.OpenZoneEditor(zone)
		end

		return true
	end

	if (string.find(bind, "invnext") or string.find(bind, "invprev")) then
		return true
	end
end)

hook.Add("HUDPaint", "nwZoneEdit", function()
	if (!NETWORK.zone.bEditing) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local lines = {
		L("zoneHintCorner"),
		L("zoneHintProperties"),
		L("zoneHintEdit"),
		L("zoneHintDelete"),
		L("zoneHintExit")
	}
	local y = ScrH() * 0.5 - Sc(60)

	for i = 1, #lines do
		util.DrawSimpleTextShadow(lines[i], "nwChatSmall", ScrW() - Sc(48), y,
			ColorAlpha(i == 1 and theme.accentSoft or theme.textDim, 235), TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER, math.max(Sc(2), 1))

		y = y + Sc(22)
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwZoneEditor", function(bDepth, bSkybox)
	if (bSkybox or !NETWORK.zone.bEditing) then
		return
	end

	render.SetColorMaterial()

	for _, zone in pairs(NETWORK.zone.list) do
		local data = NETWORK.zone.GetType(zone.type)
		local mins = NETWORK.zone.GetMins(zone)
		local maxs = NETWORK.zone.GetMaxs(zone)
		local center = (mins + maxs) * 0.5

		render.DrawWireframeBox(center, angle_zero, mins - center, maxs - center,
			ColorAlpha(data.color, 220), true)
		render.DrawBox(center, angle_zero, mins - center, maxs - center,
			ColorAlpha(data.color, 26), true)
	end

	local start = NETWORK.zone.editStart

	if (!start) then
		return
	end

	local finish = NETWORK.zone.GetAimPos()
	local mins = Vector(math.min(start.x, finish.x), math.min(start.y, finish.y),
		math.min(start.z, finish.z))
	local maxs = Vector(math.max(start.x, finish.x), math.max(start.y, finish.y),
		math.max(start.z, finish.z))
	local center = (mins + maxs) * 0.5

	render.DrawWireframeBox(center, angle_zero, mins - center, maxs - center,
		Color(120, 230, 150), true)
	render.DrawBox(center, angle_zero, mins - center, maxs - center,
		Color(120, 230, 150, 30), true)
	render.DrawWireframeSphere(start, 8, 8, 8, Color(120, 230, 150), true)
end)

local hazeMaterial = Material("particle/particle_smokegrenade")

hook.Add("PostDrawTranslucentRenderables", "nwZoneHaze", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local eyes = EyePos()

	render.SetMaterial(hazeMaterial)

	for _, zone in pairs(NETWORK.zone.list) do
		if (zone.type != "toxic" or zone.fog == false) then
			continue
		end

		local mins = NETWORK.zone.GetMins(zone)
		local maxs = NETWORK.zone.GetMaxs(zone)
		local center = (mins + maxs) * 0.5

		if (eyes:DistToSqr(center) > 4096 * 4096) then
			continue
		end

		local size = maxs - mins
		local layers = math.Clamp(math.floor(size.z / 90), 2, 8)

		for layer = 0, layers - 1 do
			local height = mins.z + (size.z / layers) * (layer + 0.5)
			local drift = math.sin(CurTime() * 0.25 + layer) * 24

			render.DrawQuadEasy(Vector(center.x + drift, center.y, height),
				Vector(0, 0, 1), size.x, size.y,
				Color(126, 214, 92, 14), 0)
		end
	end
end)
