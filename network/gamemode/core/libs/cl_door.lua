NETWORK.door.range = 260
NETWORK.door.drawRange = 420

net.Receive("nwDoorSync", function()
	NETWORK.door.list = NETWORK.util.ReadTable()
end)

local TYPE_ICONS = {
	residential = "home",
	business = "storefront",
	faction = "shield",
	public = "location_city"
}

local function DrawDoor(entity, data, eyePos)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local center = entity:LocalToWorld(entity:OBBCenter())
	local distance = eyePos:Distance(center)

	if (distance > NETWORK.door.drawRange) then
		return
	end

	local normal = entity:GetForward()
	local toEye = (eyePos - center):GetNormalized()

	if (normal:Dot(toEye) < 0) then
		normal = -normal
	end

	local facing = normal:Dot(toEye)

	if (facing < 0.25) then
		return
	end

	local angles = normal:Angle()

	angles.p = 0
	angles.r = 0

	angles:RotateAroundAxis(angles:Forward(), 90)
	angles:RotateAroundAxis(angles:Right(), -90)

	local fade = 1 - math.Clamp((distance - NETWORK.door.drawRange * 0.6) /
		(NETWORK.door.drawRange * 0.4), 0, 1)

	fade = fade * math.Clamp((facing - 0.25) / 0.25, 0, 1)

	if (fade <= 0.02) then
		return
	end

	local typeData = NETWORK.door.GetType(data.type)
	local title = (data.title and data.title != "") and data.title or L(typeData.name)
	local subtitle = NETWORK.door.Describe(data)
	local color = typeData.color
	local bLocked = NETWORK.door.IsLocked(data)
	local localID = LocalPlayer():SteamID64()

	local residents = {}

	if (NETWORK.door.GetOwners) then
		for steamID, entry in pairs(NETWORK.door.GetOwners(data) or {}) do
			if (istable(entry) and entry.name and entry.name != "") then
				residents[#residents + 1] = {name = entry.name, bSelf = steamID == localID}
			end
		end
	elseif (data.ownerName) then
		residents[1] = {name = data.ownerName, bSelf = data.owner == localID}
	end

	table.sort(residents, function(a, b)
		return a.name < b.name
	end)

	local maxWidth = 300
	local padding = 16
	local iconSize = 18
	local stateSize = 16

	local function Fit(text, font, limit)
		surface.SetFont(font)

		if (surface.GetTextSize(text) <= limit) then
			return text
		end

		local chars = {}

		for glyph in string.gmatch(text, "[%z\1-\127\194-\244][\128-\191]*") do
			chars[#chars + 1] = glyph
		end

		for count = #chars - 1, 1, -1 do
			local short = table.concat(chars, "", 1, count) .. "…"

			if (surface.GetTextSize(short) <= limit) then
				return short
			end
		end

		return "…"
	end

	local function Icon(path, x, y, size, tint, alpha)
		local material = util.GetMaterial(path, "smooth")

		if (!material or material:IsError()) then
			surface.SetDrawColor(tint.r, tint.g, tint.b, alpha)
			surface.DrawRect(x + size * 0.25, y + size * 0.25, size * 0.5, size * 0.5)

			return
		end

		surface.SetMaterial(material)
		surface.SetDrawColor(0, 0, 0, alpha * 0.5)
		surface.DrawTexturedRect(x + 1, y + 1, size, size)
		surface.SetDrawColor(tint.r, tint.g, tint.b, alpha)
		surface.DrawTexturedRect(x, y, size, size)
	end

	local titleInset = iconSize + 8
	local stateInset = stateSize + 10

	surface.SetFont("nwChat")

	local width = surface.GetTextSize(title) + padding * 2 + titleInset + stateInset

	surface.SetFont("nwInvKey")

	if (subtitle != "") then
		width = math.max(width, surface.GetTextSize(subtitle) + padding * 2)
	end

	for _, resident in ipairs(residents) do
		width = math.max(width, surface.GetTextSize(resident.name) + padding * 2 + 14)
	end

	width = math.Clamp(width, 200, maxWidth)

	local lineHeight = 15
	local height = 42 + (subtitle != "" and 20 or 0) + #residents * lineHeight +
		(#residents > 0 and 8 or 0)

	cam.Start3D2D(center + normal * 6, angles, 0.14)
		local left = -width * 0.5
		local top = -height * 0.5
		local textX = left + padding

		surface.SetDrawColor(8, 9, 10, 205 * fade)
		surface.DrawRect(left, top, width, height)

		surface.SetDrawColor(color.r, color.g, color.b, 140 * fade)
		surface.DrawOutlinedRect(left, top, width, height, 1)

		surface.SetDrawColor(color.r, color.g, color.b, 235 * fade)
		surface.DrawRect(left, top, width, 2)

		local titleY = top + (subtitle != "" and 16 or 21)

		Icon("framework/icons/" .. (TYPE_ICONS[data.type] or TYPE_ICONS.public) .. ".png",
			textX, titleY - iconSize * 0.5, iconSize, color, 240 * fade)

		draw.SimpleText(Fit(title, "nwChat", width - padding * 2 - titleInset - stateInset),
			"nwChat", textX + titleInset, titleY, ColorAlpha(theme.text, 250 * fade),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (bLocked) then
			Icon("framework/icons/lock.png", left + width - padding - stateSize,
				titleY - stateSize * 0.5, stateSize, theme.danger, 235 * fade)
		else
			Icon("framework/icons/key.png", left + width - padding - stateSize,
				titleY - stateSize * 0.5, stateSize, theme.positive, 150 * fade)
		end

		local cursor = top + 34

		if (subtitle != "") then
			draw.SimpleText(Fit(subtitle, "nwInvKey", width - padding * 2), "nwInvKey", textX, cursor,
				ColorAlpha(color, 240 * fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			cursor = cursor + 20
		end

		if (#residents > 0) then
			surface.SetDrawColor(255, 255, 255, 30 * fade)
			surface.DrawRect(textX, cursor - 6, width - padding * 2, 1)

			for index, resident in ipairs(residents) do
				local rowY = cursor + (index - 1) * lineHeight + 4
				local name = Fit(resident.name, "nwInvKey", width - padding * 2 - 14)

				surface.SetDrawColor(color.r, color.g, color.b, 220 * fade)
				surface.DrawRect(textX, rowY - 2, 4, 4)

				draw.SimpleText(name, "nwInvKey", textX + 10, rowY,
					ColorAlpha(theme.text, 235 * fade), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				if (resident.bSelf) then
					surface.SetFont("nwInvKey")

					local nameWidth = surface.GetTextSize(name)

					surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b,
						230 * fade)
					surface.DrawRect(textX + 10, rowY + 7, nameWidth, 1)
				end
			end
		end
	cam.End3D2D()
end

hook.Add("PostDrawTranslucentRenderables", "nwDoor", function(bDepth, bSkybox)
	if (bSkybox) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or NETWORK.hud.IsHidden()) then
		return
	end

	local eyePos = EyePos()

	for _, entity in ipairs(ents.FindInSphere(eyePos, NETWORK.door.drawRange)) do
		if (!NETWORK.door.IsDoor(entity)) then
			continue
		end

		local data = NETWORK.door.GetData(entity)

		if (!NETWORK.door.ShouldShow(data)) then
			continue
		end

		DrawDoor(entity, data, eyePos)
	end
end)

NETWORK.door.bInfo = false

concommand.Add("network_doorinfo", function()
	NETWORK.door.bInfo = !NETWORK.door.bInfo

	NETWORK.gui.Notify(L(NETWORK.door.bInfo and "doorInfoOn" or "doorInfoOff"),
		NETWORK.theme.accentSoft)
end)
