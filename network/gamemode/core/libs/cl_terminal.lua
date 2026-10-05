NETWORK.terminal = NETWORK.terminal or {}

NETWORK.terminal.screen = {
	forward = 5.5,
	right = 0,
	up = 21,
	pitch = 0,
	yaw = -2.6,
	roll = 0,
	width = 560,
	height = 320,
	scale = 0.05
}

NETWORK.terminal.amount = NETWORK.terminal.amount or 100

local function CreateScreenFonts()
	surface.CreateFont("nwTermScreenBrand", {
		font = NETWORK.fonts.display,
		size = 44,
		weight = 700,
		extended = true,
		antialias = true
	})

	surface.CreateFont("nwTermScreenBody", {
		font = NETWORK.fonts.body,
		size = 24,
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("nwTermScreenSmall", {
		font = NETWORK.fonts.mono,
		size = 15,
		weight = 500,
		extended = true,
		antialias = true
	})

	surface.CreateFont("nwTermScreenClock", {
		font = NETWORK.fonts.display,
		size = 88,
		weight = 700,
		extended = true,
		antialias = true
	})
end

CreateScreenFonts()

concommand.Add("network_reloadtermfonts", CreateScreenFonts)

function NETWORK.terminal.IsOpen()
	return IsValid(NETWORK.gui.terminal)
end

net.Receive("nwTerminalOpen", function()
	local entity = net.ReadEntity()
	local data = NETWORK.util.ReadTable() or {}

	NETWORK.gui.OpenTerminal(entity, data)
end)

net.Receive("nwTerminalClose", function()
	NETWORK.gui.CloseTerminal()
end)

net.Receive("nwTerminalData", function()
	local data = NETWORK.util.ReadTable() or {}

	if (IsValid(NETWORK.gui.terminal)) then
		NETWORK.gui.terminal:SetData(data)
	end
end)

function NETWORK.terminal.Send(action, payload)
	net.Start("nwTerminalAction")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

function NETWORK.terminal.GetTime()
	return NETWORK.time.GetFormatted()
end

function NETWORK.terminal.GetScreen(entity)
	local screen = NETWORK.terminal.screen
	local angles = entity:GetAngles()
	local position = entity:GetPos() +
		angles:Forward() * screen.forward +
		angles:Right() * screen.right +
		angles:Up() * screen.up

	local drawAngles = Angle(angles.p, angles.y, angles.r)

	drawAngles:RotateAroundAxis(drawAngles:Up(), 90 + screen.yaw)
	drawAngles:RotateAroundAxis(drawAngles:Forward(), 90 + screen.roll)
	drawAngles:RotateAroundAxis(drawAngles:Right(), screen.pitch)

	return position, drawAngles
end

local function IsAlarm(entity)
	return entity.GetAlarm and entity:GetAlarm() or false
end

local function Palette(entity, style)
	if (IsAlarm(entity)) then
		return NETWORK.terminal.alarmColor, Color(38, 6, 8)
	end

	return style and style.color or Color(126, 226, 240),
		style and style.background or Color(6, 30, 38)
end

function NETWORK.terminal.DrawScreen(entity, style)
	local client = LocalPlayer()

	if (!IsValid(client) or client:GetPos():Distance(entity:GetPos()) > 400) then
		return
	end

	local screen = NETWORK.terminal.screen
	local position, angles = NETWORK.terminal.GetScreen(entity)
	local color, background = Palette(entity, style)
	local width, height = screen.width, screen.height

	cam.Start3D2D(position - angles:Forward() * (width * 0.5 * screen.scale) +
		angles:Up() * (height * 0.5 * screen.scale), angles, screen.scale)

		surface.SetDrawColor(6, 7, 8, 245)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(background.r, background.g, background.b, 120)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(color.r, color.g, color.b, 120)
		surface.DrawOutlinedRect(0, 0, width, height, 2)

		draw.SimpleText(style and style.brand or "CIVIC STATION", "nwTermScreenBrand",
			30, 30, ColorAlpha(color, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(NETWORK.util.Upper(L("termTime")) .. "  " ..
			NETWORK.terminal.GetTime(), "nwTermScreenSmall", width - 30, 30,
			ColorAlpha(color, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(color.r, color.g, color.b, 90)
		surface.DrawRect(24, 60, width - 48, 2)

		if (IsAlarm(entity)) then
			draw.SimpleText(NETWORK.util.Upper(L("termAlarm")),
				"nwTermScreenBrand", width * 0.5, height * 0.5 - 14, color,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			draw.SimpleText(entity:GetAlarmReason(), "nwTermScreenBody",
				width * 0.5, height * 0.5 + 26, Color(240, 200, 200),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			cam.End3D2D()

			return
		end

		if (style and style.Body) then
			style.Body(entity, width, height, color)

			cam.End3D2D()

			return
		end

		local bBusy = entity.GetUser and IsValid(entity:GetUser())
		local alpha = 130 + math.abs(math.cos(RealTime() * 2)) * 125

		draw.SimpleText(NETWORK.util.Upper(L(bBusy and "termBusy" or
			"termIdle")), "nwTermScreenBody", width * 0.5, height * 0.55,
			ColorAlpha(bBusy and Color(240, 196, 84) or color, alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end

NETWORK.terminal.marker = nil

net.Receive("nwTerminalMarker", function()
	if (!net.ReadBool()) then
		NETWORK.terminal.marker = nil

		return
	end

	NETWORK.terminal.marker = {
		position = net.ReadVector(),
		label = net.ReadString(),
		color = net.ReadColor(false)
	}
end)

hook.Add("NetworkDrawHUD", "nwTerminalMarker", function()
	local marker = NETWORK.terminal.marker

	if (!marker) then
		return
	end

	local client = LocalPlayer()
	local distance = client:GetPos():Distance(marker.position)

	if (distance < 140) then
		NETWORK.terminal.marker = nil

		return
	end

	local screen = (marker.position + Vector(0, 0, 40)):ToScreen()

	if (!screen.visible) then
		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local x, y = math.Round(screen.x), math.Round(screen.y)
	local size = math.max(Sc(9), 6)
	local pulse = 0.7 + math.abs(math.sin(RealTime() * 2)) * 0.3

	surface.SetDrawColor(marker.color.r, marker.color.g, marker.color.b, 235 * pulse)
	surface.DrawOutlinedRect(x - size, y - size, size * 2, size * 2, math.max(Sc(2), 1))

	util.DrawSimpleTextShadow(marker.label != "" and marker.label or
		util.Upper(L("termMarker")), "nwField", x, y - size - Sc(12),
		ColorAlpha(marker.color, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
		math.max(Sc(2), 1))

	util.DrawSimpleTextShadow(math.Round(distance * 0.0254) .. " " .. L("questMetres"),
		"nwHudSmall", x, y + size + Sc(12), ColorAlpha(NETWORK.theme.textDim, 235),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, math.max(Sc(2), 1))
end)
