NETWORK.waypoint.list = NETWORK.waypoint.list or {}

NETWORK.waypoint.sound = "framework/cmb/hud/waypoint.mp3"
NETWORK.waypoint.appearTime = 0.45

local function KeyOf(entry)
	return string.format("%d_%d_%d_%s", entry.pos.x, entry.pos.y, entry.pos.z,
		entry.text)
end

net.Receive("nwWaypointSync", function()
	local payload = NETWORK.util.ReadTable() or {}
	local previous = {}
	local list = {}

	for _, entry in ipairs(NETWORK.waypoint.list or {}) do
		previous[KeyOf(entry)] = entry
	end

	local bNew = false

	for _, entry in ipairs(payload) do
		local position = entry.pos
		local color = entry.color
		local data = {
			pos = Vector(position[1], position[2], position[3]),
			text = entry.text or "",
			color = Color(color[1], color[2], color[3]),
			expires = entry.expires or 0,
			author = entry.author or "",
			kind = entry.kind or "point",
			mine = entry.mine == true
		}

		local old = previous[KeyOf(data)]

		if (old) then
			data.appear = old.appear
			data.reached = old.reached
		else
			data.appear = 0
			bNew = true
		end

		list[#list + 1] = data
	end

	NETWORK.waypoint.list = list

	if (bNew) then
		surface.PlaySound(NETWORK.waypoint.sound)
	end
end)

NETWORK.waypoint.reachRange = 140

hook.Add("Think", "nwWaypointReach", function()
	local list = NETWORK.waypoint.list

	if (!list or #list == 0) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local frame = math.min(FrameTime(), 0.1)
	local position = client:GetPos()

	for _, entry in ipairs(list) do
		entry.appear = math.min((entry.appear or 1) +
			frame / NETWORK.waypoint.appearTime, 1)

		if (!entry.reached and
			position:Distance(entry.pos) <= NETWORK.waypoint.reachRange) then
			entry.reached = true
			entry.fade = 1

			surface.PlaySound("buttons/button17.wav")
		end

		if (entry.reached) then
			entry.fade = math.max((entry.fade or 1) - frame * 2.2, 0)
		end
	end
end)

local function Pulse(speed, depth)
	return 1 + math.sin(CurTime() * (speed or 3)) * (depth or 0.1)
end

local function DrawMarker(x, y, size, color, alpha, bClear)

	surface.SetDrawColor(color.r, color.g, color.b, 30 * alpha)
	surface.DrawRect(x - size, y - size, size * 2, size * 2)

	local wave = (CurTime() % 1.5) / 1.5

	NETWORK.util.DrawRing(x, y, size + wave * size * 2.2,
		math.max(2, 1), ColorAlpha(color, 150 * (1 - wave) * alpha), 32, 1)

	surface.SetDrawColor(color.r, color.g, color.b, 250 * alpha)

	NETWORK.util.DrawThickLine(x, y - size, x + size, y, 2, color)
	NETWORK.util.DrawThickLine(x + size, y, x, y + size, 2, color)
	NETWORK.util.DrawThickLine(x, y + size, x - size, y, 2, color)
	NETWORK.util.DrawThickLine(x - size, y, x, y - size, 2, color)

	if (bClear) then
		local core = math.Round(size * 0.42 * Pulse(4, 0.14))

		surface.SetDrawColor(color.r, color.g, color.b, 250 * alpha)
		surface.DrawRect(x - core, y - core, core * 2, core * 2)
	end
end

local function DrawPlate(x, y, text, distance, color, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	surface.SetFont("nwHudSmall")

	local textWidth = surface.GetTextSize(text)
	local distWidth = surface.GetTextSize(distance)
	local width = textWidth + distWidth + Sc(34)
	local height = Sc(22)
	local plateX = x - math.Round(width * 0.5)
	local plateY = y

	surface.SetDrawColor(5, 8, 13, 225 * alpha)
	surface.DrawRect(plateX, plateY, width, height)

	surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)
	surface.DrawRect(plateX, plateY, math.max(Sc(3), 2), height)

	draw.SimpleText(text, "nwHudSmall", plateX + Sc(10),
		plateY + math.Round(height * 0.5), ColorAlpha(color, 250 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(distance, "nwHudSmall", plateX + width - Sc(9),
		plateY + math.Round(height * 0.5),
		ColorAlpha(NETWORK.theme.textDim, 240 * alpha), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)
end

local function DrawEdgeArrow(direction, color, alpha, distance)
	local Sc = NETWORK.util.Scale
	local margin = Sc(64)
	local centerX, centerY = ScrW() * 0.5, ScrH() * 0.5
	local length = math.max(direction:Length(), 0.001)
	local dirX, dirY = direction.x / length, direction.y / length
	local scaleX = dirX != 0 and
		((dirX > 0 and (ScrW() - margin - centerX) or (margin - centerX)) / dirX) or
		math.huge
	local scaleY = dirY != 0 and
		((dirY > 0 and (ScrH() - margin - centerY) or (margin - centerY)) / dirY) or
		math.huge
	local scale = math.min(scaleX, scaleY)
	local x = centerX + dirX * scale
	local y = centerY + dirY * scale
	local size = Sc(11) * Pulse(3.4, 0.12)
	local angle = math.atan2(dirY, dirX)

	draw.NoTexture()
	surface.SetDrawColor(color.r, color.g, color.b, 235 * alpha)
	surface.DrawPoly({
		{x = x + math.cos(angle) * size * 1.5,
			y = y + math.sin(angle) * size * 1.5},
		{x = x + math.cos(angle + 2.5) * size,
			y = y + math.sin(angle + 2.5) * size},
		{x = x + math.cos(angle - 2.5) * size,
			y = y + math.sin(angle - 2.5) * size}
	})

	draw.SimpleText(distance, "nwHudSmall", x, y + size * 2,
		ColorAlpha(color, 235 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

hook.Add("NetworkDrawHUD", "nwWaypoints", function()
	local list = NETWORK.waypoint.list

	if (!list or #list == 0) then
		return
	end

	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local eyePos = EyePos()
	local size = math.max(Sc(11), 7)

	NETWORK.waypoint.aimed = nil

	for _, entry in ipairs(list) do
		local left = entry.expires - CurTime()

		if (left <= 0) then
			continue
		end

		local alpha = math.Clamp(left / 5, 0.2, 1) *
			util.EaseOut(entry.appear or 1)

		if (entry.reached) then
			alpha = alpha * (entry.fade or 0)

			if (alpha <= 0.01) then
				continue
			end
		end
		local distance = math.Round(eyePos:Distance(entry.pos) * 0.0254) ..
			" " .. L("questMetres")
		local screen = entry.pos:ToScreen()

		if (!screen.visible) then

			local direction = Vector(screen.x - ScrW() * 0.5,
				screen.y - ScrH() * 0.5, 0)

			if (eyePos:Distance(entry.pos) > 0 and
				(entry.pos - eyePos):Dot(EyeAngles():Forward()) < 0) then
				direction = direction * -1
			end

			DrawEdgeArrow(direction, entry.color, alpha, distance)

			continue
		end

		local x, y = math.Round(screen.x), math.Round(screen.y)
		local bClear = client:IsLineOfSightClear(entry.pos)

		local aimed = math.sqrt((x - ScrW() * 0.5) ^ 2 +
			(y - ScrH() * 0.5) ^ 2) < Sc(70)

		if (aimed and entry.mine) then
			NETWORK.waypoint.aimed = entry
			alpha = math.min(alpha * 1.35, 1)
		end

		local kind = NETWORK.waypoint.kinds[entry.kind]

		if (kind and kind.radius > 0) then
			render.SetColorMaterial()

			local pulse = (CurTime() % 1.6) / 1.6
			local segments = 48
			local ring = {}

			for index = 0, segments do
				local angle = math.rad(index / segments * 360)

				ring[#ring + 1] = entry.pos + Vector(
					math.cos(angle) * kind.radius * (0.75 + pulse * 0.25),
					math.sin(angle) * kind.radius * (0.75 + pulse * 0.25),
					-40)
			end

			for index = 1, #ring - 1 do
				render.DrawBeam(ring[index], ring[index + 1], 4, 0, 1,
					ColorAlpha(entry.color, 200 * (1 - pulse) * alpha))
			end
		end

		local grow = 1 + (1 - util.EaseOut(entry.appear or 1)) * 1.2

		local scale = entry.kind == "alert" and 1.35 or 1

		DrawMarker(x, y, math.Round(size * grow * scale), entry.color, alpha,
			bClear)

		if (entry.kind == "alert") then
			DrawMarker(x, y, math.Round(size * grow * scale * 1.6),
				entry.color, alpha * 0.5, false)
		end

		local rise = (1 - util.EaseOut(entry.appear or 1)) * Sc(14)

		DrawPlate(x, y + size + Sc(8) + rise, util.Upper(entry.text), distance,
			entry.color, alpha)
	end
end)
