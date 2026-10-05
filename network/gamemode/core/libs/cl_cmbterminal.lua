NETWORK.cmbterm = NETWORK.cmbterm or {}

local PANEL = {}

function PANEL:Init()
	self.open = 0
	self.boot = 0
	self.bootTime = 4
	self.page = "boot"
	self.buttons = {}
	self.pageItems = {}
	self.alpha = 0

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.background = Material(NETWORK.cmbterm.background, "smooth")
	self.logo = Material(NETWORK.cmbterm.logo, "smooth")

	self.close = self:Add("DButton")

	self:BuildFullscreenButton()

	self.close:SetText("")
	self.close:SetCursor("hand")
	self.close.DoClick = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.back)

		net.Start("nwCmbClose")
		net.SendToServer()

		NETWORK.cmbterm.Close()
	end
	self.close.Paint = function(panel, width, height)
		local Sc = NETWORK.util.Scale
		local color = panel:IsHovered() and Color(228, 86, 80) or
			Color(90, 200, 235)
		local inset = Sc(12)
		local thickness = math.max(Sc(2), 2)

		NETWORK.util.DrawThickLine(inset, inset, width - inset, height - inset,
			thickness, color)
		NETWORK.util.DrawThickLine(width - inset, inset, inset, height - inset,
			thickness, color)
	end
end

function PANEL:Setup(entity, bootTime)
	self.entity = entity
	self.bootTime = bootTime or 4
	self.bCWU = IsValid(entity) and entity:GetClass() == "nw_cwuterminal"
end

function PANEL:GetSections()
	local entity = self.entity

	if (IsValid(entity) and entity:GetClass() == "nw_cwuterminal") then
		local client = LocalPlayer()

		if (IsValid(client) and client:GetNWString("nwClass", "") == "mechanic") then
			return {{id = "breaks", name = "cmbNavBreaks", glyph = "gear"}}
		end

		local list = {
			{id = "tasks", name = "cmbNavTasks", glyph = "gear",
				caption = "cmbTileTasks"},
			{id = "squads", name = "cmbNavSquads", glyph = "group",
				caption = "cmbTileBrigades"},
			{id = "journal", name = "cmbNavJournal", glyph = "list",
				caption = "cmbTileJournal"}
		}

		for _, extension in ipairs(NETWORK.cmbterm.GetExtensions(entity)) do
			list[#list + 1] = extension
		end

		return list
	end

	local list = {}

	for _, section in ipairs(NETWORK.cmbterm.sections) do
		if (section.id == "breaks" or section.id == "tasks") then
			continue
		end

		list[#list + 1] = section
	end

	table.insert(list, #list, {id = "maint", name = "cmbNavMaint",
		glyph = "gear", caption = "cmbTileMaint"})

	for _, extension in ipairs(NETWORK.cmbterm.GetExtensions(entity)) do
		list[#list + 1] = extension
	end

	return list
end

function PANEL:GetTaskRow(index)
	local Sc = NETWORK.util.Scale
	local x = self:GetContentX() + Sc(34)
	local width = self:GetContentWidth() - Sc(68)
	local top = self:GetPageTop() + Sc(26)
	local height = Sc(46)
	local y = top + (index - 1) * (height + Sc(8))

	if (y + height > self:GetPageBottom()) then
		return x, nil, width, height
	end

	return x, y, width, height
end

function PANEL:GetTaskList()
	local data = self.data or {}

	if (self.page == "tasks") then
		return data.tasks or {}
	end

	if (self.page == "maint") then
		return data.maint or {}
	end

	return data.breaks or {}
end

function PANEL:Send(action, argument, extra)
	net.Start("nwCmbAction")
		net.WriteString(action)
		net.WriteString(argument or "")
		net.WriteString(extra or "")
	net.SendToServer()
end

NETWORK.cmbterm.palettes = {
	alliance = {
		accent = Color(72, 196, 236),
		dim = Color(52, 104, 128),
		text = Color(208, 232, 242),
		base = Color(4, 14, 20),
		glow = Color(26, 92, 122),
		bRounded = false
	},
	cwu = {
		accent = Color(240, 178, 70),
		dim = Color(150, 112, 58),
		text = Color(248, 236, 214),
		base = Color(18, 13, 7),
		glow = Color(122, 80, 24),
		bRounded = true
	}
}

function NETWORK.cmbterm.GetPalette(entity)
	if (IsValid(entity) and entity:GetClass() == "nw_cwuterminal") then
		return NETWORK.cmbterm.palettes.cwu
	end

	return NETWORK.cmbterm.palettes.alliance
end

local ACCENT = Color(72, 196, 236)
local DIM = Color(52, 104, 128)
local TEXT = Color(208, 232, 242)
local GREEN = Color(108, 220, 150)
local WARN = Color(232, 190, 96)
local BAD = Color(228, 86, 80)
local BASE = Color(4, 14, 20)
local ROUNDED = false

local function ApplyPalette(entity)
	local palette = NETWORK.cmbterm.GetPalette(entity)

	ACCENT = palette.accent
	DIM = palette.dim
	TEXT = palette.text
	BASE = palette.base
	ROUNDED = palette.bRounded == true
end

local function DrawHazard(panel, x, y, width, height, color, alpha)
	local Sc = NETWORK.util.Scale
	local step = Sc(18)
	local screenX, screenY = panel:LocalToScreen(x, y)

	render.SetScissorRect(screenX, screenY, screenX + width, screenY + height, true)

	draw.NoTexture()
	surface.SetDrawColor(color.r, color.g, color.b, 150 * alpha)

	for offset = -height, width + height, step do
		surface.DrawPoly({
			{x = x + offset, y = y + height},
			{x = x + offset + height, y = y},
			{x = x + offset + height + step * 0.5, y = y},
			{x = x + offset + step * 0.5, y = y + height}
		})
	end

	render.SetScissorRect(0, 0, 0, 0, false)
end

NETWORK.cmbterm.extensions = NETWORK.cmbterm.extensions or {}
NETWORK.cmbterm.extensionOrder = NETWORK.cmbterm.extensionOrder or {}

function NETWORK.cmbterm.RegisterExtension(id, data)
	data.id = id

	if (!NETWORK.cmbterm.extensions[id]) then
		NETWORK.cmbterm.extensionOrder[#NETWORK.cmbterm.extensionOrder + 1] = id
	end

	NETWORK.cmbterm.extensions[id] = data
end

function NETWORK.cmbterm.GetExtensions(entity)
	local list = {}
	local client = LocalPlayer()

	for _, id in ipairs(NETWORK.cmbterm.extensionOrder) do
		local data = NETWORK.cmbterm.extensions[id]

		if (data and (!data.access or data.access(client, entity))) then
			list[#list + 1] = data
		end
	end

	return list
end

NETWORK.cmbterm.sections = {

	{id = "journal", name = "cmbNavJournal", glyph = "list",
		caption = "cmbTileJournal"},
	{id = "alliance", name = "cmbNavAlliance", glyph = "shield", caption = "cmbTileAlliance"},
	{id = "citizen", name = "cmbNavCitizens", glyph = "person", caption = "cmbTileCitizens"},
	{id = "squads", name = "cmbNavSquads", glyph = "group", caption = "cmbTileSquads"},
	{id = "cameras", name = "cmbNavCameras", glyph = "eye", caption = "cmbTileCameras"},
	{id = "detained", name = "cmbNavDetained", glyph = "list", caption = "cmbTileDetained"},
	{id = "business", name = "cmbNavBusiness", glyph = "list", caption = "cmbTileBusiness"}
}

function PANEL:BuildFullscreenButton()
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.DoClick = function()
		self:SetFullscreen(!self:IsFullscreen())
	end
	button.Paint = function(panel, width, height)
		local Sc = NETWORK.util.Scale

		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)

		local hover = panel.hover
		local color = ColorAlpha(hover > 0.5 and TEXT or ACCENT, (170 + 85 * hover) * self.alpha)
		local line = math.max(Sc(2), 2)
		local arm = Sc(6)
		local inset = self:IsFullscreen() and Sc(4) or Sc(7)

		if (ROUNDED) then
			draw.RoundedBox(Sc(6), 0, 0, width, height, ColorAlpha(ACCENT, (14 + 26 * hover) *
				self.alpha))
		else
			surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, (10 + 24 * hover) * self.alpha)
			surface.DrawRect(0, 0, width, height)
		end

		surface.SetDrawColor(color.r, color.g, color.b, color.a)

		local bIn = self:IsFullscreen()

		for _, corner in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
			local sx, sy = corner[1], corner[2]

			local px = sx < 0 and inset or width - inset
			local py = sy < 0 and inset or height - inset

			if (bIn) then
				px = px - sx * arm
				py = py - sy * arm
			end

			local dirX = bIn and sx or -sx
			local dirY = bIn and sy or -sy

			surface.DrawRect(dirX > 0 and px or px - arm, py - math.floor(line * 0.5),
				arm, line)
			surface.DrawRect(px - math.floor(line * 0.5), dirY > 0 and py or py - arm,
				line, arm)
		end
	end

	self.fullscreenButton = button
end

local fullEffects = CreateClientConVar("network_full_effects", "1", true, false,
	"Полный набор анимаций на фоне терминалов")

function NETWORK.cmbterm.FullEffects()
	return fullEffects:GetBool()
end

local backdropNodes

local function GetNodes()
	if (backdropNodes) then
		return backdropNodes
	end

	local seed = 1337

	local function Random()
		seed = (seed * 1103515245 + 12345) % 2147483648

		return seed / 2147483648
	end

	backdropNodes = {}

	for index = 1, 28 do
		backdropNodes[index] = {
			x = Random(),
			y = Random(),
			speedX = (Random() - 0.5) * 0.014,
			speedY = (Random() - 0.5) * 0.014,
			phase = Random() * math.pi * 2
		}
	end

	return backdropNodes
end

local function Wrap(value)
	return value - math.floor(value)
end

local function Wedge(cx, cy, radius, fromAngle, toAngle, color)
	local first = math.rad(fromAngle)
	local second = math.rad(toAngle)

	draw.NoTexture()
	surface.SetDrawColor(color)
	surface.DrawPoly({
		{x = cx, y = cy},
		{x = cx + math.cos(first) * radius, y = cy + math.sin(first) * radius},
		{x = cx + math.cos(second) * radius, y = cy + math.sin(second) * radius}
	})
end

local function Art(name, parameters)
	return NETWORK.util.GetTexture("framework/" .. name .. ".png", parameters or "smooth mips")
end

local function DrawGear(cx, cy, radius, angle, teeth, color)
	local util = NETWORK.util
	local half = math.pi / teeth * 0.45
	local material = Art("terminal/gear" .. teeth)

	if (material) then
		local size = radius * 1.22 * 2

		surface.SetMaterial(material)
		surface.SetDrawColor(color)
		surface.DrawTexturedRectRotated(cx, cy, size, size, -angle)
		draw.NoTexture()

		teeth = 0
	else
		util.DrawArc(cx, cy, radius, math.max(math.Round(radius * 0.16), 2), 1, color, 64)
		util.DrawArc(cx, cy, math.Round(radius * 0.55), math.max(math.Round(radius * 0.05), 1),
			1, color, 48)
	end

	draw.NoTexture()
	surface.SetDrawColor(color)

	for index = 0, teeth - 1 do
		local middle = math.rad(angle) + index * (math.pi * 2 / teeth)
		local inner = radius * 0.98
		local outer = radius * 1.2
		local left, right = middle - half, middle + half

		surface.DrawPoly({
			{x = cx + math.cos(left) * inner, y = cy + math.sin(left) * inner},
			{x = cx + math.cos(left) * outer, y = cy + math.sin(left) * outer},
			{x = cx + math.cos(right) * outer, y = cy + math.sin(right) * outer},
			{x = cx + math.cos(right) * inner, y = cy + math.sin(right) * inner}
		})
	end

	draw.SimpleText("24", radius > NETWORK.util.Scale(90) and "nwTermTitle" or "nwTermNav",
		cx, cy, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function NETWORK.cmbterm.DrawBackdrop(panel, x, y, width, height, alpha, style, palette)
	local bFull = NETWORK.cmbterm.FullEffects()
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local time = RealTime()
	local accent = palette.accent
	local base = palette.base
	local glow = palette.glow

	surface.SetDrawColor(base.r, base.g, base.b, 252 * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-u"))
	surface.SetDrawColor(glow.r, glow.g, glow.b, 60 * alpha)
	surface.DrawTexturedRect(x, y, width, height)

	local screenX, screenY = panel:LocalToScreen(x, y)

	render.SetScissorRect(screenX, screenY, screenX + width, screenY + height, true)

	if (style == "cwu") then

		local fine = Sc(24)
		local coarse = fine * 5
		local shift = (time * 10) % coarse
		local grid = Art("pattern/grid_cwu", "noclamp smooth mips")

		if (grid) then

			surface.SetDrawColor(accent.r, accent.g, accent.b, 20 * alpha)
			util.DrawTiled(grid, x, y, width, height, coarse, coarse, shift, shift)
			draw.NoTexture()
		else
			for offset = -coarse, width + coarse, fine do
				local bMajor = math.Round(offset / fine) % 5 == 0

				surface.SetDrawColor(accent.r, accent.g, accent.b, (bMajor and 20 or 8) * alpha)
				surface.DrawRect(x + offset + shift, y, 1, height)
			end

			for offset = -coarse, height + coarse, fine do
				local bMajor = math.Round(offset / fine) % 5 == 0

				surface.SetDrawColor(accent.r, accent.g, accent.b, (bMajor and 20 or 8) * alpha)
				surface.DrawRect(x, y + offset + shift, width, 1)
			end
		end

		local unit = math.min(width, height)
		local gearColor = ColorAlpha(accent, 34 * alpha)

		DrawGear(x + width * 0.12, y + height * 0.84, unit * 0.24, time * 9, 14, gearColor)
		DrawGear(x + width * 0.12 + unit * 0.37, y + height * 0.84 - unit * 0.1,
			unit * 0.13, -time * 16.5 + 10, 9, gearColor)

		if (bFull) then
			DrawGear(x + width * 0.9, y + height * 0.16, unit * 0.18, -time * 7, 12,
				ColorAlpha(accent, 24 * alpha))
		end

		for index, node in ipairs(GetNodes()) do
			if (index > 16) then
				break
			end

			local rise = Wrap(node.y - time * (0.02 + index * 0.001))
			local sparkX = x + Wrap(node.x + math.sin(time * 0.6 + node.phase) * 0.01) * width
			local sparkY = y + rise * height
			local size = math.max(Sc(2), 2)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 130 * rise * alpha)
			surface.DrawRect(sparkX, sparkY, size, size)

			if (bFull and index % 4 == 0) then
				util.DrawSoftLight(math.Round(sparkX), math.Round(sparkY), Sc(24), Sc(24),
					accent, 40 * rise * alpha)
			end

		end

		local bandHeight = Sc(10)
		local bandY = y + height - bandHeight
		local stripe = Sc(20)
		local drift = (time * 30) % (stripe * 2)

		local hazard = Art("pattern/hazard", "noclamp smooth mips")

		draw.NoTexture()
		surface.SetDrawColor(accent.r, accent.g, accent.b, 45 * alpha)

		if (hazard) then

			util.DrawTiled(hazard, x, bandY, width, bandHeight, stripe * 2, bandHeight, drift, 0)
			draw.NoTexture()
		else
			for offset = -stripe * 2, width + stripe * 2, stripe * 2 do
				local stripeX = x + offset + drift

				surface.DrawPoly({
					{x = stripeX, y = bandY + bandHeight},
					{x = stripeX + bandHeight, y = bandY},
					{x = stripeX + bandHeight + stripe, y = bandY},
					{x = stripeX + stripe, y = bandY + bandHeight}
				})
			end
		end
	else

		local step = Sc(56)
		local scroll = (time * 12) % step
		local grid = Art("pattern/grid_al", "noclamp smooth mips")

		if (grid) then

			surface.SetDrawColor(accent.r, accent.g, accent.b, 22 * alpha)
			util.DrawTiled(grid, x, y, width, height, step * 4, step, 0, scroll)
			draw.NoTexture()
		else
			for offset = 0, width, step do
				local bMajor = math.Round(offset / step) % 4 == 0

				surface.SetDrawColor(accent.r, accent.g, accent.b, (bMajor and 22 or 10) * alpha)
				surface.DrawRect(x + offset, y, 1, height)
			end

			for offset = -step, height, step do
				surface.SetDrawColor(accent.r, accent.g, accent.b, 10 * alpha)
				surface.DrawRect(x, y + offset + scroll, width, 1)
			end
		end

		local centerX = x + width * 0.5
		local centerY = y + height * 0.54
		local radius = math.min(width, height) * 0.42
		local sweep = (time * 42) % 360

		local rings = Art("terminal/radar")

		if (rings) then
			local size = radius * 2 * 512 / 508

			surface.SetMaterial(rings)
			surface.SetDrawColor(accent.r, accent.g, accent.b, 24 * alpha)
			surface.DrawTexturedRect(centerX - size * 0.5, centerY - size * 0.5, size, size)
			draw.NoTexture()
		else
			for ring = 1, 4 do
				util.DrawArc(centerX, centerY, radius * ring / 4, 1, 1,
					ColorAlpha(accent, 24 * alpha), 96)
			end
		end

		draw.SimpleText("24", "nwTermTitle", centerX, centerY,
			ColorAlpha(accent, 60 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		local trailArt = Art("terminal/sweep")

		if (trailArt) then
			local size = radius * 2 * 256 / 254

			surface.SetMaterial(trailArt)
			surface.SetDrawColor(accent.r, accent.g, accent.b, 30 * alpha)
			surface.DrawTexturedRectRotated(centerX, centerY, size, size, -sweep)
			draw.NoTexture()
		else
			for trail = 0, 13 do
				Wedge(centerX, centerY, radius, sweep - (trail + 1) * 3, sweep - trail * 3,
					ColorAlpha(accent, 30 * (1 - trail / 14) * alpha))
			end
		end

		local nodes = GetNodes()
		local points = {}
		local reach = Sc(230)

		local nodeLimit = bFull and #nodes or 18

		for index, node in ipairs(nodes) do
			if (index > nodeLimit) then
				break
			end

			local pointX = x + Wrap(node.x + node.speedX * time) * width
			local pointY = y + Wrap(node.y + node.speedY * time) * height

			points[index] = {pointX, pointY}
		end

		for first = 1, #points do
			for second = first + 1, #points do
				local dx = points[first][1] - points[second][1]
				local dy = points[first][2] - points[second][2]
				local distance = math.sqrt(dx * dx + dy * dy)

				if (distance < reach) then
					surface.SetDrawColor(accent.r, accent.g, accent.b,
						40 * (1 - distance / reach) * alpha)
					surface.DrawLine(points[first][1], points[first][2], points[second][1],
						points[second][2])
				end
			end
		end

		for index, point in ipairs(points) do
			local dx, dy = point[1] - centerX, point[2] - centerY
			local lit = 0

			if (dx * dx + dy * dy <= radius * radius) then
				local nodeAngle = math.deg(math.atan2(dy, dx)) % 360

				lit = math.max(1 - ((sweep - nodeAngle) % 360) / 90, 0)
			end

			local pulse = 0.5 + 0.5 * math.sin(time * 1.5 + nodes[index].phase)
			local size = math.max(Sc(3), 2) + math.Round(lit * Sc(3))

			surface.SetDrawColor(accent.r, accent.g, accent.b, (40 + 30 * pulse + 180 * lit) * alpha)
			surface.DrawRect(point[1] - math.floor(size * 0.5), point[2] - math.floor(size * 0.5),
				size, size)
		end
	end

	local blobs = bFull and (style == "cwu" and 3 or 4) or 2

	for index = 1, blobs do
		local phase = index * 1.9
		local blobX = x + width * (0.5 + math.sin(time * 0.07 + phase) * 0.38)
		local blobY = y + height * (0.5 + math.cos(time * 0.05 + phase * 1.3) * 0.34)
		local size = math.min(width, height) * (0.7 + 0.2 * math.sin(time * 0.3 + phase))
		local pulse = style == "cwu" and (0.7 + 0.3 * math.abs(math.sin(time * 0.9 + phase))) or 1

		util.DrawSoftLight(math.Round(blobX), math.Round(blobY), size, size, accent,
			22 * pulse * alpha)
	end

	if (style == "cwu") then

		local pipes = bFull and 3 or 2

		for index = 1, pipes do
			local pipeY = y + height * ((bFull and 0.18 or 0.3) + index * 0.2)
			local dash = Sc(26)
			local flow = (time * (40 + index * 12)) % (dash * 2)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 12 * alpha)
			surface.DrawRect(x, pipeY - Sc(3), width, Sc(6))

			surface.SetDrawColor(accent.r, accent.g, accent.b, (bFull and 38 or 26) * alpha)

			local dashes = Art("pattern/dash", "noclamp")
			local shift = index % 2 == 0 and -flow or flow

			if (dashes) then

				util.DrawTiled(dashes, x, pipeY - 1, width, 2, dash * 2, 4, shift, 0)
				draw.NoTexture()
			else
				for offset = -dash * 2, width, dash * 2 do
					surface.DrawRect(x + offset + shift, pipeY - 1, dash, 2)
				end
			end
		end
	elseif (bFull) then

		for index, node in ipairs(GetNodes()) do
			if (index > 18) then
				break
			end

			local streamX = x + math.floor(node.x * width / Sc(28)) * Sc(28)
			local fall = Wrap(node.y + time * (0.05 + index * 0.004))
			local headY = y + fall * (height + Sc(200)) - Sc(100)
			local tail = Sc(120)

			util.DrawVGradient(streamX, headY - tail, 1, tail, ColorAlpha(accent, 0),
				ColorAlpha(accent, 50 * alpha))
			surface.SetDrawColor(accent.r, accent.g, accent.b, 150 * alpha)
			surface.DrawRect(streamX - 1, headY - 2, 3, 3)
		end
	end

	local wave = (time * 0.25) % 1.4

	if (bFull and wave < 1) then
		util.DrawSoftLight(math.Round(x + width * wave), y, Sc(420), Sc(80), accent, 40 * alpha)
		util.DrawSoftLight(math.Round(x + width * (1 - wave)), y + height, Sc(420), Sc(80),
			accent, 40 * alpha)
	end

	render.SetScissorRect(0, 0, 0, 0, false)
end

NETWORK.cmbterm.bootSteps = {
	alliance = {"bootAl1", "bootAl2", "bootAl3", "bootAl4", "bootAl5", "bootAl6", "bootAl7"},
	cwu = {"bootCw1", "bootCw2", "bootCw3", "bootCw4", "bootCw5", "bootCw6", "bootCw7"},
	jail = {"bootJl1", "bootJl2", "bootJl3", "bootJl4", "bootJl5"}
}

local HEX = "0123456789ABCDEF"

local function HexLine(seed)
	local out = {}

	for index = 1, 4 do
		local value = (seed * 2654435761 + index * 40503) % 65536

		out[index] = string.sub(HEX, math.floor(value / 4096) % 16 + 1,
			math.floor(value / 4096) % 16 + 1) ..
			string.sub(HEX, math.floor(value / 256) % 16 + 1, math.floor(value / 256) % 16 + 1) ..
			string.sub(HEX, math.floor(value / 16) % 16 + 1, math.floor(value / 16) % 16 + 1) ..
			string.sub(HEX, value % 16 + 1, value % 16 + 1)
	end

	return table.concat(out, " ")
end

function NETWORK.cmbterm.DrawBoot(panel, x, y, width, height, alpha, progress, total,
	kind, color, logo)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local green = Color(108, 220, 150)
	local text = Color(Lerp(0.6, color.r, 255), Lerp(0.6, color.g, 255),
		Lerp(0.6, color.b, 255))
	local dim = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7)
	local fraction = math.Clamp(progress / math.max(total, 0.1), 0, 1)
	local steps = NETWORK.cmbterm.bootSteps[kind] or NETWORK.cmbterm.bootSteps.alliance
	local rounded = kind == "cwu"

	local blockWidth = math.min(Sc(1000), width - Sc(120))
	local blockHeight = math.min(Sc(420), height - Sc(200))
	local blockX = math.Round(x + (width - blockWidth) * 0.5)
	local blockY = math.Round(y + (height - blockHeight) * 0.42)

	local logoSize = math.min(Sc(170), math.Round(blockHeight * 0.44))
	local centerX = blockX + math.Round(blockWidth * 0.18)
	local centerY = blockY + math.Round(blockHeight * 0.4)
	local ringRadius = math.Round(logoSize * 0.72)

	util.DrawSoftLight(centerX, centerY, ringRadius * 4, ringRadius * 4, color, 40 * alpha)

	util.DrawArc(centerX, centerY, ringRadius, math.max(Sc(2), 2), 0.3,
		ColorAlpha(color, 200 * alpha), 48, RealTime() * 120)
	util.DrawArc(centerX, centerY, ringRadius, math.max(Sc(2), 2), 0.3,
		ColorAlpha(color, 200 * alpha), 48, RealTime() * 120 + 180)
	util.DrawArc(centerX, centerY, ringRadius + Sc(12), 1, 1,
		ColorAlpha(color, 40 * alpha), 96)
	util.DrawArc(centerX, centerY, ringRadius + Sc(12), math.max(Sc(3), 2), fraction,
		ColorAlpha(color, 230 * alpha), 96)

	if (logo) then
		surface.SetDrawColor(color.r, color.g, color.b, 255 * alpha)
		surface.SetMaterial(logo)
		surface.DrawTexturedRectRotated(centerX, centerY, logoSize, logoSize,
			-RealTime() * 30)
	end

	draw.SimpleText(math.floor(fraction * 100) .. "%", "nwTermTitle", centerX,
		centerY + ringRadius + Sc(44), ColorAlpha(text, 250 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	util.DrawTextSpaced(util.Upper(L("cmbBooting")), "nwHudSmall",
		centerX - math.Round(util.TextSpacedSize(util.Upper(L("cmbBooting")), "nwHudSmall",
		Sc(4)) * 0.5), centerY + ringRadius + Sc(74), ColorAlpha(dim, 230 * alpha), Sc(4),
		TEXT_ALIGN_CENTER)

	local logX = blockX + math.Round(blockWidth * 0.38)
	local logWidth = blockX + blockWidth - logX
	local logY = blockY
	local lineHeight = math.min(Sc(34), math.floor((blockHeight - Sc(60)) / #steps))

	if (rounded) then
		draw.RoundedBox(Sc(14), logX, logY, logWidth, blockHeight, ColorAlpha(color, 12 * alpha))
		util.DrawRoundedBorder(logX, logY, logWidth, blockHeight, Sc(14), 1,
			ColorAlpha(color, 70 * alpha))
	else
		surface.SetDrawColor(color.r, color.g, color.b, 10 * alpha)
		surface.DrawRect(logX, logY, logWidth, blockHeight)
		surface.SetDrawColor(color.r, color.g, color.b, 60 * alpha)
		surface.DrawOutlinedRect(logX, logY, logWidth, blockHeight, 1)
	end

	draw.SimpleText(util.Upper(L("bootLogTitle")), "nwHudSmall", logX + Sc(18), logY + Sc(20),
		ColorAlpha(dim, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText("PID " .. (1000 + (IsValid(panel.entity) and panel.entity:EntIndex() or 0)),
		"nwHudSmall", logX + logWidth - Sc(18), logY + Sc(20), ColorAlpha(dim, 200 * alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(color.r, color.g, color.b, 40 * alpha)
	surface.DrawRect(logX + Sc(18), logY + Sc(38), logWidth - Sc(36), 1)

	local stepLength = total / #steps
	local current = steps[#steps]

	for index, key in ipairs(steps) do
		local startTime = (index - 1) * stepLength
		local lineY = logY + Sc(54) + (index - 1) * lineHeight + math.floor(lineHeight * 0.5)

		if (progress < startTime) then
			break
		end

		local local_ = math.Clamp((progress - startTime) / stepLength, 0, 1)
		local bDone = local_ >= 1 or (index == #steps and fraction >= 1)
		local label = L(key)
		local shown = bDone and label or
			string.sub(label, 1, math.max(math.floor(#label * math.min(local_ * 1.6, 1)), 0))
		local stamp = string.format("[%06.3f]", startTime)

		if (!bDone) then
			current = key
		end

		draw.SimpleText(stamp, "nwHudSmall", logX + Sc(18), lineY,
			ColorAlpha(dim, 200 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetFont("nwHudSmall")

		local stampWidth = surface.GetTextSize(stamp) + Sc(12)

		surface.SetFont("nwTermBody")

		local shownWidth = surface.GetTextSize(shown)

		draw.SimpleText(shown, "nwTermBody", logX + Sc(18) + stampWidth, lineY,
			ColorAlpha(bDone and text or color, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local statusX = logX + logWidth - Sc(18)

		if (bDone) then
			local tag = index == #steps and L("bootReady") or "OK"

			draw.SimpleText("[ " .. tag .. " ]", "nwHudSmall", statusX, lineY,
				ColorAlpha(green, 245 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		else

			if (math.floor(RealTime() * 3) % 2 == 0) then
				surface.SetDrawColor(color.r, color.g, color.b, 230 * alpha)
				surface.DrawRect(logX + Sc(20) + stampWidth + shownWidth, lineY - Sc(7),
					math.max(Sc(7), 4), Sc(14))
			end

			local spinner = ({"|", "/", "-", "\\"})[math.floor(RealTime() * 10) % 4 + 1]

			draw.SimpleText("[ " .. spinner .. " ]", "nwHudSmall", statusX, lineY,
				ColorAlpha(color, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	local hexX = x + width - Sc(170)
	local hexTop = y + Sc(80)
	local hexRows = math.floor((height - Sc(200)) / Sc(16))
	local tick = math.floor(RealTime() * 12)

	if (hexX > blockX + blockWidth + Sc(20)) then
		for row = 0, hexRows - 1 do
			local fade = 1 - math.abs(row / math.max(hexRows - 1, 1) - 0.5) * 2

			draw.SimpleText(HexLine(tick + row * 7), "nwHudSmall", hexX, hexTop + row * Sc(16),
				ColorAlpha(color, 40 * fade * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local barWidth = blockWidth
	local barX = blockX
	local barY = blockY + blockHeight + Sc(46)
	local barHeight = math.max(Sc(5), 4)

	draw.SimpleText(util.Upper(L(current)), "nwHudSmall", barX, barY - Sc(16),
		ColorAlpha(text, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(string.format("%.1f / %.1f", math.min(progress, total), total),
		"nwHudSmall", barX + barWidth, barY - Sc(16), ColorAlpha(dim, 220 * alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (rounded) then
		draw.RoundedBox(math.floor(barHeight * 0.5), barX, barY, barWidth, barHeight,
			ColorAlpha(color, 36 * alpha))
	else
		surface.SetDrawColor(color.r, color.g, color.b, 36 * alpha)
		surface.DrawRect(barX, barY, barWidth, barHeight)
	end

	local fill = math.Round(barWidth * util.EaseInOut(fraction))

	if (fill > 0) then
		util.DrawHGradient(barX, barY, fill, barHeight, ColorAlpha(color, 140 * alpha),
			ColorAlpha(color, 255 * alpha))
		util.DrawSoftLight(barX + fill, barY + math.floor(barHeight * 0.5), Sc(50), Sc(24),
			color, 90 * alpha)
	end

	for index = 1, 9 do
		surface.SetDrawColor(color.r, color.g, color.b, 70 * alpha)
		surface.DrawRect(barX + math.Round(barWidth * index / 10), barY + barHeight + Sc(4), 1,
			Sc(5))
	end
end

NETWORK.cmbterm.fullscreen = cookie.GetNumber("nwTermFullscreenV2", 1) == 1

function PANEL:IsFullscreen()
	return NETWORK.cmbterm.fullscreen == true
end

function PANEL:SetFullscreen(bValue)
	NETWORK.cmbterm.fullscreen = bValue == true

	cookie.Set("nwTermFullscreenV2", bValue and "1" or "0")

	surface.PlaySound(NETWORK.cmbterm.sounds.back)

	self.switchFade = 0

	self:InvalidateLayout(true)

	if (self.page != "boot") then
		self:Rebuild()
	end
end

function PANEL:GetFrameWidth()
	return self:IsFullscreen() and ScrW() or math.Round(ScrW() * 0.86)
end

function PANEL:GetFrameHeight()
	return self:IsFullscreen() and ScrH() or math.Round(ScrH() * 0.84)
end

function PANEL:GetFrameX()
	return math.Round((ScrW() - self:GetFrameWidth()) * 0.5)
end

function PANEL:GetFrameY()
	return math.Round((ScrH() - self:GetFrameHeight()) * 0.5)
end

function PANEL:GetBarHeight()
	return math.Round(NETWORK.util.Scale(54))
end

function PANEL:GetNavHeight()
	return math.Round(NETWORK.util.Scale(36))
end

function PANEL:GetCardWidth()
	local maximum = self:IsFullscreen() and 1600 or 1080

	return math.min(math.Round(NETWORK.util.Scale(maximum)),
		self:GetFrameWidth() - math.Round(NETWORK.util.Scale(140)))
end

function PANEL:GetCardX()
	return self:GetFrameX() + math.Round((self:GetFrameWidth() - self:GetCardWidth()) * 0.5)
end

function PANEL:GetCardY()
	return self:GetFrameY() + self:GetBarHeight() + self:GetNavHeight() +
		math.Round(NETWORK.util.Scale(30))
end

function PANEL:GetCardBottom()
	return self:GetFrameY() + self:GetFrameHeight() - math.Round(NETWORK.util.Scale(64))
end

function PANEL:GetContentX()
	return self:GetCardX()
end

function PANEL:GetContentWidth()
	return self:GetCardWidth()
end

function PANEL:GetPageTop()
	return self:GetCardY() + math.Round(NETWORK.util.Scale(120))
end

function PANEL:GetPageBottom()
	return self:GetCardBottom() - math.Round(NETWORK.util.Scale(24))
end

function PANEL:ClearButtons()
	for _, button in ipairs(self.buttons) do

		if (IsValid(button) and button != self.close) then
			button:Remove()
		end
	end

	self.buttons = {}

	self:ClearPage()
end

function PANEL:ClearPage()
	for _, panel in ipairs(self.pageItems or {}) do
		if (IsValid(panel)) then
			panel:Remove()
		end
	end

	self.pageItems = {}
end

function PANEL:AddNavButton(section, index)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")
	local label = NETWORK.util.Upper(L(section.name))

	button:SetText("")
	button:SetCursor("hand")
	button.born = CurTime() + index * 0.04
	button.section = section
	button.DoClick = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.select)

		if (section.id == "close") then
			net.Start("nwCmbClose")
			net.SendToServer()

			NETWORK.cmbterm.Close()

			return
		end

		self:Open(section.id)
	end
	button.OnCursorEntered = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.hover)
	end
	button.GetPreferredWidth = function(panel)
		surface.SetFont("nwTermNav")

		return surface.GetTextSize(label) + Sc(42)
	end
	button.Paint = function(panel, width, height)
		local reveal = math.Clamp((CurTime() - panel.born) / 0.3, 0, 1)

		if (reveal <= 0) then
			return
		end

		local bClose = section.id == "close"
		local bActive = self.page == section.id or
			(self.page != nil and section.id == self.parentPage)
		local hover = panel:IsHovered() and 1 or 0
		local base = bClose and BAD or ACCENT
		local middle = math.Round(height * 0.5)

		if (ROUNDED) then
			local pill = math.floor((height - Sc(8)) * 0.5)

			if (bActive or hover > 0) then
				draw.RoundedBox(pill, 0, Sc(4), width, height - Sc(8),
					ColorAlpha(base, (bActive and 60 or 20) * reveal))
			end

			if (bActive) then
				NETWORK.util.DrawRoundedBorder(0, Sc(4), width, height - Sc(8), pill, 1,
					ColorAlpha(base, 200 * reveal))
			end
		else
			if (bActive) then
				NETWORK.util.DrawVGradient(0, Sc(3), width, height - Sc(6),
					ColorAlpha(base, 0), ColorAlpha(base, 60 * reveal))

				surface.SetDrawColor(base.r, base.g, base.b, 240 * reveal)
				surface.DrawRect(0, height - Sc(3), width, math.max(Sc(2), 2))
			elseif (hover > 0) then
				surface.SetDrawColor(base.r, base.g, base.b, 16 * reveal)
				surface.DrawRect(0, Sc(3), width, height - Sc(6))

				surface.SetDrawColor(base.r, base.g, base.b, 120 * reveal)
				surface.DrawRect(Sc(8), height - Sc(3), width - Sc(16), 1)
			end
		end

		local glyphSize = Sc(11)
		local color = (bActive or hover > 0) and (bClose and BAD or TEXT) or DIM

		NETWORK.gui.DrawGlyph(section.glyph or "dot", Sc(12), middle - math.Round(glyphSize * 0.5),
			glyphSize, Color(base.r, base.g, base.b, (bActive and 250 or 140 + 90 * hover) * reveal))

		draw.SimpleText(label, "nwTermNav", Sc(12) + glyphSize + Sc(8), middle,
			Color(color.r, color.g, color.b, 245 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	self.buttons[#self.buttons + 1] = button

	return button
end

function PANEL:AddAction(label, x, y, width, height, callback, color)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button:SetPos(x, y)
	button:SetSize(width, height)
	button.DoClick = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.select)

		callback()
	end
	button.OnCursorEntered = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.hover)
	end
	button.hover = 0
	button.Paint = function(panel, buttonWidth, buttonHeight)
		local base = color or ACCENT
		local hover = NETWORK.util.EaseInOut(panel.hover)

		panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 14)

		if (ROUNDED) then
			local radius = math.min(Sc(8), math.floor(buttonHeight * 0.5))

			draw.RoundedBox(radius, 0, 0, buttonWidth, buttonHeight,
				ColorAlpha(base, 22 + 50 * hover))
			NETWORK.util.DrawRoundedBorder(0, 0, buttonWidth, buttonHeight, radius, 1,
				ColorAlpha(base, 140 + 100 * hover))
		else
			surface.SetDrawColor(base.r, base.g, base.b, 12 + 30 * hover)
			surface.DrawRect(0, 0, buttonWidth, buttonHeight)

			surface.SetDrawColor(base.r, base.g, base.b, 110 + 110 * hover)
			surface.DrawOutlinedRect(0, 0, buttonWidth, buttonHeight, 1)

			local tick = Sc(6)
			local line = math.max(Sc(2), 2)

			surface.SetDrawColor(base.r, base.g, base.b, 230)
			surface.DrawRect(0, 0, tick, line)
			surface.DrawRect(0, 0, line, tick)
			surface.DrawRect(buttonWidth - tick, buttonHeight - line, tick, line)
			surface.DrawRect(buttonWidth - line, buttonHeight - tick, line, tick)
		end

		draw.SimpleText(NETWORK.util.Upper(label), "nwHudSmall",
			math.Round(buttonWidth * 0.5), math.Round(buttonHeight * 0.5),
			ColorAlpha(hover > 0.5 and Color(255, 255, 255) or TEXT, 245),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	self.pageItems[#self.pageItems + 1] = button

	return button
end

function PANEL:AddEntry(x, y, width, height, placeholder, callback)
	local entry = self:Add("DTextEntry")

	entry:SetPos(x, y)
	entry:SetSize(width, height)
	entry:SetFont("nwTermBody")
	entry:SetPaintBackground(false)
	entry:SetDrawLanguageID(false)
	entry:SetTextColor(TEXT)
	entry:SetCursorColor(ACCENT)
	entry:SetPlaceholderText(placeholder)
	entry.OnEnter = function(panel)
		callback(panel:GetValue())
	end
	entry.Paint = function(panel, entryWidth, entryHeight)
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 12)
		surface.DrawRect(0, 0, entryWidth, entryHeight)

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b,
			panel:IsEditing() and 200 or 100)
		surface.DrawOutlinedRect(0, 0, entryWidth, entryHeight, 1)

		panel:DrawTextEntryText(TEXT, ACCENT, ACCENT)
	end

	self.pageItems[#self.pageItems + 1] = entry

	return entry
end

function PANEL:Open(page)
	self.pageSwitched = RealTime()
	self.page = page
	self.record = nil
	self.selected = nil
	self.rows = nil

	if (page != "home") then
		self:Send(page)
	end

	self:Rebuild()
	self:InvalidateLayout(true)
end

function PANEL:Rebuild()
	local Sc = NETWORK.util.Scale

	self:ClearButtons()
	self:ClearDossiers()

	local x = self:GetFrameX()
	local navY = self:GetFrameY() + self:GetBarHeight()
	local navHeight = self:GetNavHeight()
	local cursor = x + Sc(26)

	local entries = {{id = "home", name = "cmbNavHome", glyph = "grid"}}

	for _, section in ipairs(self:GetSections()) do
		entries[#entries + 1] = section
	end

	local close = self:AddNavButton({id = "close", name = "cmbNavClose", glyph = "back"},
		#entries + 1)
	local closeWidth = close:GetPreferredWidth()
	local limit = x + self:GetFrameWidth() - closeWidth - Sc(40)

	for index, section in ipairs(entries) do
		local button = self:AddNavButton(section, index)
		local buttonWidth = button:GetPreferredWidth()

		if (cursor + buttonWidth > limit) then
			button:Remove()

			break
		end

		button:SetPos(cursor, navY)
		button:SetSize(buttonWidth, navHeight)

		cursor = cursor + buttonWidth + Sc(6)
	end

	close:SetPos(x + self:GetFrameWidth() - closeWidth - Sc(26), navY)
	close:SetSize(closeWidth, navHeight)

	self:BuildPage()
end

function PANEL:AddConsoleRow(section, x, y, width, height, index)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")
	local label = NETWORK.util.Upper(L(section.name))
	local bClose = section.id == "close"

	button:SetText("")
	button:SetCursor("hand")
	button:SetPos(x, y)
	button:SetSize(width, height)
	button.born = CurTime() + index * 0.05
	button.DoClick = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.select)

		if (bClose) then
			net.Start("nwCmbClose")
			net.SendToServer()

			NETWORK.cmbterm.Close()

			return
		end

		self:Open(section.id)
	end
	button.OnCursorEntered = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.hover)
	end
	button.Paint = function(panel, rowWidth, rowHeight)
		local reveal = math.Clamp((CurTime() - panel.born) / 0.3, 0, 1)

		if (reveal <= 0) then
			return
		end

		local hover = panel:IsHovered() and 1 or 0
		local base = bClose and BAD or ACCENT

		surface.SetDrawColor(base.r, base.g, base.b, (8 + 14 * hover) * reveal)
		surface.DrawRect(0, 0, rowWidth, rowHeight)

		surface.SetDrawColor(base.r, base.g, base.b, (120 + 110 * hover) * reveal)
		surface.DrawOutlinedRect(0, 0, rowWidth, rowHeight, 1)

		local mark = Sc(12)
		local markY = math.Round(rowHeight * 0.5) - math.Round(mark * 0.5)

		surface.DrawOutlinedRect(Sc(16), markY, mark + Sc(4), mark, 1)

		if (hover > 0) then
			surface.DrawRect(Sc(16) + 2, markY + 2, mark, mark - 4)
		end

		local spacing = Sc(4)
		local labelWidth = NETWORK.util.TextSpacedSize(label, "nwTermNav", spacing)

		NETWORK.util.DrawTextSpaced(label, "nwTermNav",
			math.Round((rowWidth - labelWidth) * 0.5), math.Round(rowHeight * 0.5),
			ColorAlpha(hover > 0 and TEXT or Color(base.r, base.g, base.b), 245 * reveal),
			spacing, TEXT_ALIGN_CENTER)
	end

	self.pageItems[#self.pageItems + 1] = button

	return button
end

function PANEL:AddTile(section, x, y, width, height, index)
	local Sc = NETWORK.util.Scale
	local button = self:Add("DButton")
	local header = "<:: " .. NETWORK.util.Upper(L(section.name)) .. " ::>"
	local caption = section.caption and L(section.caption) or ""

	button:SetText("")
	button:SetCursor("hand")
	button:SetPos(x, y)
	button:SetSize(width, height)
	button.born = CurTime() + index * 0.05
	button.DoClick = function()
		surface.PlaySound(NETWORK.cmbterm.sounds.select)

		self:Open(section.id)
	end
	button.OnCursorEntered = function(panel)
		panel.hoverStart = RealTime()

		surface.PlaySound(NETWORK.cmbterm.sounds.hover)
	end
	button.hover = 0
	button.Paint = function(panel, tileWidth, tileHeight)
		local util = NETWORK.util
		local reveal = util.EaseOut(math.Clamp((CurTime() - panel.born) / 0.35, 0, 1))

		if (reveal <= 0) then
			return
		end

		panel.hover = util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)

		local hover = util.EaseInOut(panel.hover)
		local headerHeight = Sc(30)
		local glyphSize = Sc(38) + math.Round(Sc(4) * hover)
		local number = string.format("%02d", index)

		if (ROUNDED) then

			local radius = Sc(12)

			draw.RoundedBox(radius, 0, 0, tileWidth, tileHeight,
				ColorAlpha(BASE, 235 * reveal))
			draw.RoundedBox(radius, 0, 0, tileWidth, tileHeight,
				ColorAlpha(ACCENT, (12 + 22 * hover) * reveal))

			draw.RoundedBoxEx(radius, 0, 0, tileWidth, headerHeight,
				ColorAlpha(ACCENT, (40 + 30 * hover) * reveal), true, true, false, false)

			DrawHazard(panel, tileWidth - Sc(70), 0, Sc(70) - radius, headerHeight,
				Color(0, 0, 0), reveal)

			NETWORK.util.DrawRoundedBorder(0, 0, tileWidth, tileHeight, radius,
				math.max(Sc(2), 1), ColorAlpha(ACCENT, (90 + 140 * hover) * reveal))

			draw.SimpleText(NETWORK.util.Upper(L(section.name)), "nwTermTile", Sc(14),
				math.Round(headerHeight * 0.5), ColorAlpha(TEXT, 250 * reveal),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		else

			surface.SetDrawColor(BASE.r, BASE.g, BASE.b, 220 * reveal)
			surface.DrawRect(0, 0, tileWidth, tileHeight)

			util.DrawVGradient(0, 0, tileWidth, tileHeight,
				ColorAlpha(ACCENT, (6 + 10 * hover) * reveal),
				ColorAlpha(ACCENT, (18 + 26 * hover) * reveal))

			surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, (60 + 80 * hover) * reveal)
			surface.DrawOutlinedRect(0, 0, tileWidth, tileHeight, 1)

			local arm = Sc(14) + math.Round(Sc(10) * hover)
			local line = math.max(Sc(2), 2)

			surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 240 * reveal)
			surface.DrawRect(0, 0, arm, line)
			surface.DrawRect(0, 0, line, arm)
			surface.DrawRect(tileWidth - arm, 0, arm, line)
			surface.DrawRect(tileWidth - line, 0, line, arm)
			surface.DrawRect(0, tileHeight - line, arm, line)
			surface.DrawRect(0, tileHeight - arm, line, arm)
			surface.DrawRect(tileWidth - arm, tileHeight - line, arm, line)
			surface.DrawRect(tileWidth - line, tileHeight - arm, line, arm)

			surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 80 * reveal)
			surface.DrawRect(Sc(14), headerHeight, tileWidth - Sc(28), 1)

			NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(L(section.name)), "nwTermTile",
				Sc(14), math.Round(headerHeight * 0.5) + Sc(2),
				ColorAlpha(TEXT, 250 * reveal), Sc(2), TEXT_ALIGN_CENTER)
		end

		draw.SimpleText(number, "nwHudSmall", tileWidth - Sc(12),
			math.Round(headerHeight * 0.5), ColorAlpha(ROUNDED and BASE or DIM,
			240 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local bodyTop = headerHeight
		local bodyHeight = tileHeight - headerHeight - Sc(30)

		NETWORK.gui.DrawGlyph(section.glyph or "dot",
			math.Round((tileWidth - glyphSize) * 0.5),
			bodyTop + math.Round((bodyHeight - glyphSize) * 0.5), glyphSize,
			ColorAlpha(ACCENT, (200 + 55 * hover) * reveal))

		draw.SimpleText(caption, "nwTermCaption", math.Round(tileWidth * 0.5),
			tileHeight - Sc(20), ColorAlpha(TEXT, (170 + 60 * hover) * reveal),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		if (hover > 0.01) then
			util.DrawSoftLight(math.Round(tileWidth * 0.5),
				bodyTop + math.Round(bodyHeight * 0.5), glyphSize * 3.4, glyphSize * 3.4,
				ACCENT, 50 * hover * reveal)

			if (NETWORK.cmbterm.FullEffects()) then
				local sweep = ((RealTime() - (panel.hoverStart or RealTime())) * 0.9) % 1.6

				if (sweep < 1) then
					util.DrawSoftLight(math.Round(tileWidth * sweep), math.Round(tileHeight * 0.5),
						Sc(90), tileHeight * 1.4, Color(255, 255, 255), 16 * hover * reveal)
				end
			end

		end
	end

	self.pageItems[#self.pageItems + 1] = button

	return button
end

function PANEL:BuildPage()
	local Sc = NETWORK.util.Scale

	self:ClearPage()
	local x = self:GetContentX() + Sc(34)
	local y = self:GetPageTop()
	local width = self:GetContentWidth() - Sc(68)
	local bottom = self:GetPageBottom()

	if (self.page == "home") then

		local sections = self:GetSections()
		local count = #sections
		local columns = count <= 3 and math.max(count, 1) or (count <= 8 and 4 or 5)
		local rows = math.ceil(count / columns)
		local gap = Sc(14)
		local areaX = self:GetCardX()
		local areaWidth = self:GetCardWidth()
		local areaY = self:GetCardY() + Sc(64)
		local areaHeight = self:GetCardBottom() - areaY
		local tileWidth = math.floor((areaWidth - gap * (columns - 1)) / columns)
		local tileHeight = math.min(Sc(170),
			math.floor((areaHeight - gap * (rows - 1)) / math.max(rows, 1)))

		for index, section in ipairs(sections) do
			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)

			self:AddTile(section, areaX + column * (tileWidth + gap),
				areaY + row * (tileHeight + gap), tileWidth, tileHeight, index)
		end

		return
	end

	local extension = NETWORK.cmbterm.extensions[self.page]

	if (extension and extension.Build) then
		extension.Build(self, x, y, width, bottom)

		return
	end

	if (self.page == "business" and self.record and
		self.record.status == "pending") then

		local combo = self:Add("DComboBox")

		combo:SetPos(x, bottom - Sc(96))
		combo:SetSize(math.min(Sc(520), width), Sc(34))
		combo:SetFont("nwTermBody")
		combo:SetTextColor(Color(226, 236, 246))
		combo:SetValue(L("cmbBusinessDoor"))
		combo.Paint = function(this, comboWidth, comboHeight)
			surface.SetDrawColor(10, 20, 32, 240)
			surface.DrawRect(0, 0, comboWidth, comboHeight)

			surface.SetDrawColor(52, 122, 178, 160)
			surface.DrawOutlinedRect(0, 0, comboWidth, comboHeight, 1)
		end

		for _, label in ipairs((self.data or {}).doors or {}) do
			combo:AddChoice(label)
		end

		if (#((self.data or {}).doors or {}) == 0) then
			combo:AddChoice(L("cmbBusinessNoDoors"))
		end

		self.pageItems[#self.pageItems + 1] = combo

		local record = self.record

		local function Decide(bApproved)
			local selected = combo:GetSelected()

			net.Start("nwBusinessDecide")
				net.WriteString(record.id)
				net.WriteString(selected or "")
				net.WriteBool(bApproved)
			net.SendToServer()

			self.record = nil
		end

		self:AddAction(L("cmbBusinessApprove"), x, bottom - Sc(48), Sc(200),
			Sc(38), function()
				Decide(true)
			end)

		self:AddAction(L("cmbBusinessDeny"), x + Sc(212), bottom - Sc(48),
			Sc(200), Sc(38), function()
				Decide(false)
			end, Color(232, 84, 76))

		if (record.status and record.status != "pending") then
			self:AddAction(L("bizResetShort"), x + Sc(424), bottom - Sc(48),
				Sc(200), Sc(38), function()
					net.Start("nwBusinessReset")
						net.WriteString(record.id)
					net.SendToServer()

					self.record = nil
				end, WARN)

			self:AddAction(L("termBack"), x + Sc(636), bottom - Sc(48),
				Sc(160), Sc(38), function()
					self.record = nil

					self:BuildPage()
				end, DIM)
		else
			self:AddAction(L("termBack"), x + Sc(424), bottom - Sc(48), Sc(160),
				Sc(38), function()
					self.record = nil

					self:BuildPage()
				end, DIM)
		end

		return
	end

	if (self.page == "business" and self.record) then
		self:AddAction(L("termBack"), x, bottom - Sc(48), Sc(200), Sc(38),
			function()
				self.record = nil

				self:BuildPage()
			end, DIM)

		return
	end

	if (self.page == "alliance") then
		local list = self:GetList()

		if (self.record) then

			self:AddAction(L("cmbAddNote"), x, bottom - Sc(48), Sc(240), Sc(38),
				function()
					self:OpenNote(self.record)
				end)

			self:AddAction(L("termBack"), x + Sc(252), bottom - Sc(48), Sc(200),
				Sc(38), function()
					self.record = nil

					self:BuildPage()
				end, DIM)

			return
		end

		for index, entry in ipairs(list) do
			local rowY = y + Sc(58) + (index - 1) * Sc(50)

			if (rowY + Sc(44) > bottom) then
				break
			end

			self:AddAction(L("cmbNoteShort"), x + width - Sc(150), rowY + Sc(6),
				Sc(150), Sc(32), function()
					self:OpenNote(entry)
				end)
		end

		return
	end

	if (self.page == "citizen") then
		local entry = self:AddEntry(x, y, Sc(280), Sc(38), L("cmbEnterID"),
			function(value)
				self:Send("citizen", value)
			end)

		self:AddAction(L("cmbQuery"), x + Sc(292), y, Sc(160), Sc(38), function()
			self:Send("citizen", entry:GetValue())
		end)

		if (self.record) then
			self:AddAction(L("cmbLoyaltyEdit"), x, bottom - Sc(48), Sc(240), Sc(38),
				function()
					local record = self.record

					NETWORK.gui.TerminalPrompt({
						title = L("cmbLoyaltyEdit"),
						hint = L("cmbLoyaltyHint", record.name),
						mode = "number",
						value = 0,
						minimum = -25,
						maximum = 25,
						callback = function(value)
							self:Send("loyalty", record.cid, tostring(value))
						end
					})
				end)

			self:AddAction(L("cmbAddNote"), x + Sc(252), bottom - Sc(48), Sc(240),
				Sc(38), function()
					self:OpenNote(self.record)
				end)
		end

		return
	end

	if (self.page == "breaks" or self.page == "maint" or
		self.page == "tasks") then
		local list = self:GetTaskList()

		for index in ipairs(list) do
			local rowX, rowY, rowWidth, rowHeight = self:GetTaskRow(index)

			if (!rowY) then
				break
			end

			self:AddAction(L("cmbBreaksTake"),
				rowX + rowWidth - Sc(170), rowY + math.Round((rowHeight -
				Sc(30)) * 0.5), Sc(160), Sc(30), function()
					self:Send(self.page == "tasks" and "tasktake" or
						(self.page == "maint" and "mainttake" or "breaktake"),
						tostring(index))
				end)
		end

		return
	end

	if (self.page == "squads") then

		local client = LocalPlayer()

		if (client:GetNWString("nwSquadInvite", "") != "") then
			self:AddAction(L("cmbSquadAccept") .. ": " ..
				client:GetNWString("nwSquadInvite"), x, bottom - Sc(96),
				Sc(360), Sc(38), function()
					self:Send("squadaccept")
				end)
		end

		local squad = client.GetSquadData and client:GetSquadData()

		if (squad and squad.leader == client:SteamID64()) then
			local kind = NETWORK.squad.GetSquadKind(squad)

			self:AddAction(L(kind == "cwu" and "cmbSquadInviteCWU" or
				"cmbSquadInvite"), x + Sc(372),
				bottom - Sc(96), Sc(260), Sc(38), function()
					local menu = DermaMenu()

					for _, target in ipairs(player.GetAll()) do
						if (target:HasCharacter() and target != client and
							!target:GetSquad() and
							NETWORK.squad.CanSee(target, squad)) then
							menu:AddOption(target:GetCharacterName(),
								function()
									self:Send("squadinvite",
										target:SteamID64())
								end)
						end
					end

					menu:Open()
				end)
		end

		self:BuildSquadPage(x, y, width, bottom)
	end

	if (self.page == "cameras") then
		self:BuildCameraPage(x, y, width, bottom)
	end
end

function PANEL:GetSquadRows(list, y, bottom, rowHeight)
	local Sc = NETWORK.util.Scale
	local rows = {}
	local cursor = y + Sc(36)

	for _, squad in ipairs(list) do
		if (cursor + rowHeight > bottom - Sc(80)) then
			break
		end

		rows[#rows + 1] = {squad = squad, y = cursor}

		cursor = cursor + rowHeight + Sc(8)

		if (self.selected == squad.id) then
			cursor = cursor + Sc(20) * math.max(#(squad.roster or {}), 1) + Sc(8)
		end
	end

	return rows
end

function PANEL:OpenNote(record)
	if (!record or !record.id) then
		return
	end

	NETWORK.gui.TerminalPrompt({
		title = L("cmbAddNote"),
		hint = L("cmbNoteHint", record.name or "?"),
		mode = "note",
		callback = function(text)
			self:Send("note", text, tostring(record.id))
		end
	})
end

local function Rule(x, y, width, alpha, amount)
	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, (amount or 60) * alpha)
	surface.DrawRect(x, y, width, 1)
end

local function Row(x, y, width, height, alpha, bActive)
	local Sc = NETWORK.util.Scale

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, (bActive and 22 or 8) * alpha)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, (bActive and 150 or 55) * alpha)
	surface.DrawOutlinedRect(x, y, width, height, 1)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, (bActive and 235 or 110) * alpha)
	surface.DrawRect(x, y, math.max(Sc(3), 2), height)
end

local CAMERA_WIDTH, CAMERA_HEIGHT = 1024, 576
local cameraRT = GetRenderTarget("nwCmbCameraRT", CAMERA_WIDTH, CAMERA_HEIGHT)
local cameraMaterial = CreateMaterial("nwCmbCameraMat2", "UnlitGeneric", {
	["$basetexture"] = cameraRT:GetName()
})

NETWORK.cmbterm.viewMemory = NETWORK.cmbterm.viewMemory or {}

local function GetViewState(index)
	local state = NETWORK.cmbterm.viewMemory[index]

	if (!state) then
		state = {yaw = 0, pitch = 0, fov = 78, targetYaw = 0, targetPitch = 0,
			targetFov = 78}
		NETWORK.cmbterm.viewMemory[index] = state
	end

	return state
end

local function GetCameraOrigin(entry)
	local entity = Entity(entry.index or 0)

	if (IsValid(entity) and entity:GetClass() == "npc_combine_camera") then
		local lens = entity:LookupBone("Combine_Camera.Lens")
		local root = entity:LookupBone("Combine_Camera.bone1")

		if (lens and root) then
			local position = entity:GetBonePosition(lens)
			local _, angles = entity:GetBonePosition(root)

			angles.r = angles.r + 90

			return position + angles:Forward() * 2.8, angles
		end
	end

	return Vector(entry.x or 0, entry.y or 0, entry.z or 0),
		Angle(entry.pitch or 0, entry.yaw or 0, entry.roll or 0)
end

function PANEL:GetCameraEntry()
	if (!self.cameraIndex) then
		return
	end

	for _, entry in ipairs(self:GetList()) do
		if (entry.index == self.cameraIndex) then
			return entry
		end
	end
end

function DrawCameraTargets(origin, angles, fov)
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	for _, target in ipairs(player.GetAll()) do
		if (target == client or !target:Alive() or !target:HasCharacter()) then
			continue
		end

		if (NETWORK.nameplate and NETWORK.nameplate.IsHidden(target)) then
			continue
		end

		local head = target:EyePos()
		local offset = head - origin

		if (offset:Dot(angles:Forward()) <= 0 or offset:Length() > 2048) then
			continue
		end

		local trace = util.TraceLine({
			start = origin,
			endpos = head,
			filter = target,
			mask = MASK_OPAQUE
		})

		if (trace.Hit) then
			continue
		end

		local top = (head + Vector(0, 0, 6)):ToScreen()
		local bottom = target:GetPos():ToScreen()

		if (!top.visible) then
			continue
		end

		local height = math.max(bottom.y - top.y, 12)
		local width = math.Round(height * 0.45)
		local x = math.Round(top.x - width * 0.5)
		local y = math.Round(top.y)
		local colour = Color(120, 220, 235)

		local size = math.Round(math.min(width, height) * 0.28)

		surface.SetDrawColor(colour.r, colour.g, colour.b, 220)
		surface.DrawRect(x, y, size, 2)
		surface.DrawRect(x, y, 2, size)
		surface.DrawRect(x + width - size, y, size, 2)
		surface.DrawRect(x + width - 2, y, 2, size)
		surface.DrawRect(x, y + height - 2, size, 2)
		surface.DrawRect(x, y + height - size, 2, size)
		surface.DrawRect(x + width - size, y + height - 2, size, 2)
		surface.DrawRect(x + width - 2, y + height - size, 2, size)

		local bKnown = client:IsRecognised(target)
		local label = bKnown and target:GetCharacterName() or
			target:GetUnknownName()
		local callsign = bKnown and target:GetNWString("nwCallsign", "") or ""

		if (callsign != "") then
			label = callsign
		end

		draw.SimpleText(NETWORK.util.Upper(label), "nwHudSmall",
			math.Round(top.x), y - 14, colour, TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

function PANEL:RenderCameraFeed()
	if (self.page != "cameras" or NETWORK.cmbterm.control) then
		return
	end

	if ((self.lastFeed or 0) > RealTime()) then
		return
	end

	local delta = math.min(RealTime() - (self.lastFeedTime or RealTime()), 0.1)

	self.lastFeedTime = RealTime()
	self.lastFeed = RealTime() + 1 / 60

	local entry = self:GetCameraEntry()

	if (!entry) then
		self.bFeedReady = false

		return
	end

	local state = GetViewState(entry.index)
	local speed = math.Clamp(delta * 9, 0, 1)

	state.yaw = Lerp(speed, state.yaw, state.targetYaw)
	state.pitch = Lerp(speed, state.pitch, state.targetPitch)
	state.fov = Lerp(speed, state.fov, state.targetFov)

	local position, angles = GetCameraOrigin(entry)

	angles = Angle(angles.p, angles.y, angles.r)
	angles:RotateAroundAxis(angles:Up(), -state.yaw)
	angles:RotateAroundAxis(angles:Right(), state.pitch)

	render.PushRenderTarget(cameraRT)
		render.Clear(0, 0, 0, 255, true, true)

		render.RenderView({
			origin = position,
			angles = angles,
			fov = state.fov,
			aspect = CAMERA_WIDTH / CAMERA_HEIGHT,
			x = 0,
			y = 0,
			w = CAMERA_WIDTH,
			h = CAMERA_HEIGHT,
			drawviewmodel = false,
			drawviewer = true
		})

		cam.Start2D()
			DrawCameraTargets(position, angles, state.fov)
		cam.End2D()
	render.PopRenderTarget()

	cameraMaterial:SetTexture("$basetexture", cameraRT)

	self.bFeedReady = true
end

hook.Add("Tick", "nwCmbCameraFeed", function()
	local panel = NETWORK.gui.cmbTerminal

	if (IsValid(panel)) then
		panel:RenderCameraFeed()
	end
end)

hook.Remove("HUDPaint", "nwCmbCameraFeed")

function PANEL:BuildCameraPage(x, y, width, bottom)
	local Sc = NETWORK.util.Scale
	local list = self:GetList()
	local listWidth = Sc(250)

	if (#list == 0) then
		return
	end

	if (!self.cameraIndex) then
		self.cameraIndex = list[1].index
	end

	self:Send("camwatch", tostring(self.cameraIndex))

	local rowY = y

	for order, entry in ipairs(list) do
		if (rowY + Sc(48) > bottom) then
			break
		end

		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:SetPos(x, rowY)
		button:SetSize(listWidth, Sc(44))
		button.born = CurTime() + order * 0.03
		button.DoClick = function()
			surface.PlaySound(NETWORK.cmbterm.sounds.select)

			self.cameraIndex = entry.index

			self:Send("camwatch", tostring(entry.index))
		end
		button.OnCursorEntered = function()
			surface.PlaySound(NETWORK.cmbterm.sounds.hover)
		end
		button.Paint = function(panel, buttonWidth, buttonHeight)
			local reveal = math.Clamp((CurTime() - panel.born) / 0.3, 0, 1)
			local bActive = self.cameraIndex == entry.index
			local hover = panel:IsHovered() and 1 or 0

			Row(0, 0, buttonWidth, buttonHeight, reveal, bActive or hover > 0)

			draw.SimpleText("C-i" .. entry.index, "nwTermBody", Sc(16),
				math.Round(buttonHeight * 0.5) - Sc(9),
				ColorAlpha(bActive and ACCENT or TEXT, 250 * reveal),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local zone = entry.zone and (NETWORK.lang.Exists(entry.zone) and
				L(entry.zone) or entry.zone) or L("owUnknownZone")

			draw.SimpleText(zone, "nwHudSmall", Sc(16),
				math.Round(buttonHeight * 0.5) + Sc(10), ColorAlpha(DIM, 235 * reveal),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(entry.bEnabled != false and "ON" or "OFF", "nwHudSmall",
				buttonWidth - Sc(12), math.Round(buttonHeight * 0.5),
				ColorAlpha(entry.bEnabled != false and GREEN or BAD, 240 * reveal),
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		self.pageItems[#self.pageItems + 1] = button

		rowY = rowY + Sc(50)
	end

	local viewX = x + listWidth + Sc(20)
	local viewWidth = width - listWidth - Sc(20)
	local viewHeight = math.min(bottom - y, math.Round(viewWidth * CAMERA_HEIGHT / CAMERA_WIDTH))
	local view = self:Add("DButton")

	view:SetText("")
	view:SetCursor("hand")
	view:SetPos(viewX, y)
	view:SetSize(viewWidth, viewHeight)
	view.OnMousePressed = function(panel, code)
		if (code != MOUSE_LEFT) then
			return
		end

		panel.bDragging = true
		panel.dragDistance = 0
		panel.lastX, panel.lastY = gui.MousePos()

		panel:MouseCapture(true)
	end
	view.OnMouseReleased = function(panel, code)
		if (code != MOUSE_LEFT) then
			return
		end

		panel.bDragging = false
		panel:MouseCapture(false)

		if ((panel.dragDistance or 0) < Sc(6)) then
			local entry = self:GetCameraEntry()

			if (entry) then
				surface.PlaySound(NETWORK.cmbterm.sounds.select)

				self:EnterCameraControl(entry)
			end
		end
	end
	view.OnMouseWheeled = function(panel, delta)
		local entry = self:GetCameraEntry()

		if (!entry) then
			return
		end

		local state = GetViewState(entry.index)

		state.targetFov = math.Clamp(state.targetFov - delta * 6, 28, 92)

		return true
	end
	view.Think = function(panel)
		if (!panel.bDragging) then
			return
		end

		local mouseX, mouseY = gui.MousePos()
		local deltaX = mouseX - (panel.lastX or mouseX)
		local deltaY = mouseY - (panel.lastY or mouseY)

		panel.lastX, panel.lastY = mouseX, mouseY
		panel.dragDistance = (panel.dragDistance or 0) + math.abs(deltaX) + math.abs(deltaY)

		local entry = self:GetCameraEntry()

		if (!entry) then
			return
		end

		local state = GetViewState(entry.index)
		local sensitivity = 0.22 * (state.targetFov / 78)

		state.targetYaw = math.Clamp(state.targetYaw + deltaX * sensitivity, -75, 75)
		state.targetPitch = math.Clamp(state.targetPitch + deltaY * sensitivity * 0.7, -40, 40)
	end
	view.Paint = function(panel, panelWidth, panelHeight)
		local Sc = NETWORK.util.Scale

		surface.SetDrawColor(0, 0, 0, 250)
		surface.DrawRect(0, 0, panelWidth, panelHeight)

		local entry = self:GetCameraEntry()

		if (entry and self.bFeedReady) then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(cameraMaterial)
			surface.DrawTexturedRect(0, 0, panelWidth, panelHeight)
		end

		NETWORK.util.DrawScanlines(0, 0, panelWidth, panelHeight, 28, math.max(Sc(3), 3))

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 170)
		surface.DrawOutlinedRect(0, 0, panelWidth, panelHeight, 1)

		if (!entry) then
			draw.SimpleText(L("cmbCameraSelect"), "nwTermBody",
				math.Round(panelWidth * 0.5), math.Round(panelHeight * 0.5),
				ColorAlpha(DIM, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

			return
		end

		local state = GetViewState(entry.index)

		draw.SimpleText("<:: C-i" .. entry.index .. " ::>", "nwTermTile", Sc(10), Sc(12),
			ColorAlpha(ACCENT, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local zone = entry.zone and (NETWORK.lang.Exists(entry.zone) and L(entry.zone) or
			entry.zone) or L("owUnknownZone")

		draw.SimpleText(zone, "nwHudSmall", Sc(10), Sc(30), ColorAlpha(TEXT, 220),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(string.format("FOV %d  ·  Y %+d  ·  P %+d", math.Round(state.fov),
			math.Round(state.yaw), math.Round(state.pitch)), "nwHudSmall", Sc(10),
			panelHeight - Sc(14), ColorAlpha(DIM, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(L("cmbCameraHint"), "nwHudSmall", panelWidth - Sc(10),
			panelHeight - Sc(14), ColorAlpha(DIM, 210), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local centerX = math.Round(panelWidth * 0.5)
		local centerY = math.Round(panelHeight * 0.5)

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 190)
		surface.DrawRect(centerX - Sc(7), centerY, Sc(5), 1)
		surface.DrawRect(centerX + Sc(3), centerY, Sc(5), 1)
		surface.DrawRect(centerX, centerY - Sc(7), 1, Sc(5))
		surface.DrawRect(centerX, centerY + Sc(3), 1, Sc(5))
	end

	self.pageItems[#self.pageItems + 1] = view
end

function PANEL:EnterCameraControl(entry)
	if (NETWORK.cmbterm.control) then
		return
	end

	local state = GetViewState(entry.index)

	local position, angles = GetCameraOrigin(entry)

	NETWORK.cmbterm.control = {
		index = entry.index,
		entry = entry,
		panel = self,
		basePos = position,
		baseAng = Angle(angles.p, angles.y, angles.r),
		nextAim = 0,
		nextSnap = 0,
		flash = 0
	}

	state.targetFov = math.Clamp(state.targetFov, 55, 92)

	self:Send("camcontrol", tostring(entry.index))

	self:SetVisible(false)
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	gui.EnableScreenClicker(false)

	surface.PlaySound("buttons/combine_button1.wav")
end

function PANEL:ExitCameraControl()
	local control = NETWORK.cmbterm.control

	if (!control) then
		return
	end

	NETWORK.cmbterm.control = nil

	self:Send("camcontrol", "")

	if (IsValid(self)) then
		self:SetVisible(true)
		self:MakePopup()
	end

	surface.PlaySound("buttons/combine_button2.wav")
end

local function GetControl()
	local control = NETWORK.cmbterm.control

	if (!control) then
		return
	end

	if (!IsValid(control.panel) or !IsValid(NETWORK.gui.cmbTerminal)) then
		NETWORK.cmbterm.control = nil

		return
	end

	return control
end

hook.Add("InputMouseApply", "nwCmbCameraControl", function(cmd, deltaX, deltaY, angles)
	local control = GetControl()

	if (!control) then
		return
	end

	local state = GetViewState(control.index)
	local sensitivity = 0.032 * (state.fov / 78)

	state.targetYaw = math.Clamp(state.targetYaw + deltaX * sensitivity, -75, 75)
	state.targetPitch = math.Clamp(state.targetPitch + deltaY * sensitivity, -40, 40)

	return true
end)

hook.Add("CreateMove", "nwCmbCameraControl", function(cmd)
	local control = GetControl()

	if (!control) then
		return
	end

	local buttons = cmd:GetButtons()
	local bAttack = bit.band(buttons, IN_ATTACK) != 0
	local bExit = bit.band(buttons, IN_ATTACK2) != 0 or bit.band(buttons, IN_USE) != 0
	local forward = cmd:GetForwardMove()
	local side = cmd:GetSideMove()

	cmd:ClearMovement()
	cmd:SetButtons(0)

	if (bExit) then
		control.panel:ExitCameraControl()

		return
	end

	if (math.abs(forward) > 1 or math.abs(side) > 1) then
		local state = GetViewState(control.index)
		local frame = math.min(FrameTime(), 0.05)
		local rate = 65 * frame * (0.35 + 0.65 * state.fov / 78)

		if (math.abs(side) > 1) then
			state.targetYaw = math.Clamp(state.targetYaw +
				(side > 0 and rate or -rate), -75, 75)
		end

		if (math.abs(forward) > 1) then
			state.targetPitch = math.Clamp(state.targetPitch +
				(forward > 0 and -rate or rate), -40, 40)
		end
	end

	if (bAttack and control.nextSnap < RealTime()) then
		control.nextSnap = RealTime() + 1
		control.flash = RealTime() + 0.18

		net.Start("nwCmbSnap")
		net.SendToServer()
	end
end)

hook.Add("PlayerBindPress", "nwCmbCameraControl", function(client, bind, bPressed)
	local control = GetControl()

	if (!control) then
		return
	end

	bind = string.lower(bind)

	if (bind == "invprev" or bind == "invnext") then
		if (bPressed) then
			local state = GetViewState(control.index)

			state.targetFov = math.Clamp(state.targetFov +
				(bind == "invprev" and -7 or 7), 28, 92)
		end

		return true
	end

	local slot = string.match(bind, "^slot(%d)$")

	if (slot) then
		if (bPressed) then
			NETWORK.cmbterm.PlaceCameraMark(tonumber(slot))
		end

		return true
	end

	if (string.find(bind, "slot", 1, true) or bind == "lastinv" or
		string.find(bind, "attack", 1, true) or bind == "impulse 100") then
		return true
	end
end)

function NETWORK.cmbterm.PlaceCameraMark(key)
	local control = GetControl()

	if (!control) then
		return
	end

	local entry

	for _, preset in ipairs(NETWORK.cmbterm.cameraMarks) do
		if (preset.key == key) then
			entry = preset

			break
		end
	end

	if (!entry) then
		return
	end

	if ((control.nextMark or 0) > RealTime()) then
		return
	end

	control.nextMark = RealTime() + 1

	local origin = EyePos()
	local trace = util.TraceLine({
		start = origin,
		endpos = origin + EyeAngles():Forward() * NETWORK.cmbterm.markRange,
		filter = LocalPlayer()
	})

	local position = trace.HitPos

	control.panel:Send("cammark", entry.id,
		string.format("%.1f %.1f %.1f", position.x, position.y, position.z))

	control.markSent = entry
	control.markSentAt = RealTime()
end

net.Receive("nwCmbMarkDone", function()
	local control = NETWORK.cmbterm.control
	local entry = NETWORK.cmbterm.GetCameraMark(net.ReadString())

	if (control and entry) then
		control.markDone = entry
		control.markDoneAt = RealTime()
	end

	surface.PlaySound("buttons/button17.wav")
end)

local function CameraViewModifier(client, view)
	local control = GetControl()

	if (!control) then
		return
	end

	local state = GetViewState(control.index)
	local frame = math.min(RealFrameTime(), 0.05)
	local speed = math.Clamp(frame * 10, 0, 1)

	state.yaw = Lerp(speed, state.yaw, state.targetYaw)
	state.pitch = Lerp(speed, state.pitch, state.targetPitch)
	state.fov = Lerp(speed, state.fov, state.targetFov)

	local angles = Angle(control.baseAng.p, control.baseAng.y, control.baseAng.r)

	angles:RotateAroundAxis(angles:Up(), -state.yaw)
	angles:RotateAroundAxis(angles:Right(), state.pitch)

	view.origin = control.basePos
	view.angles = angles
	view.fov = state.fov
	view.drawviewer = true

	if (control.nextAim < RealTime()) then
		control.nextAim = RealTime() + 0.12

		local panel = control.panel

		if (IsValid(panel)) then
			panel:Send("camaim", string.format("%.1f %.1f", state.yaw, state.pitch))
		end
	end

	return "stop"
end

local function RegisterCameraView()
	if (!NETWORK.view or !NETWORK.view.Register) then
		return false
	end

	NETWORK.view.Register("cmbcamera", 900, CameraViewModifier)

	return true
end

if (!RegisterCameraView()) then
	hook.Add("Initialize", "nwCmbCameraView", function()
		RegisterCameraView()

		hook.Remove("Initialize", "nwCmbCameraView")
	end)
end

hook.Add("HUDPaint", "nwCmbCameraControl", function()
	local control = GetControl()

	if (!control) then
		return
	end

	local Sc = NETWORK.util.Scale
	local width, height = ScrW(), ScrH()
	local state = GetViewState(control.index)

	DrawCameraTargets(EyePos(), EyeAngles(), 75)

	NETWORK.util.DrawScanlines(0, 0, width, height, 26, math.max(Sc(3), 3))

	local inset = Sc(26)
	local tick = Sc(22)
	local thickness = math.max(Sc(2), 2)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 200)
	surface.DrawRect(inset, inset, tick, thickness)
	surface.DrawRect(inset, inset, thickness, tick)
	surface.DrawRect(width - inset - tick, inset, tick, thickness)
	surface.DrawRect(width - inset - thickness, inset, thickness, tick)
	surface.DrawRect(inset, height - inset - thickness, tick, thickness)
	surface.DrawRect(inset, height - inset - tick, thickness, tick)
	surface.DrawRect(width - inset - tick, height - inset - thickness, tick, thickness)
	surface.DrawRect(width - inset - thickness, height - inset - tick, thickness, tick)

	local pulse = math.sin(RealTime() * 5) * 0.5 + 0.5

	surface.SetDrawColor(228, 86, 80, 120 + 130 * pulse)
	surface.DrawRect(inset + Sc(16), inset + Sc(14), Sc(8), Sc(8))

	draw.SimpleText("REC", "nwTermTile", inset + Sc(32), inset + Sc(18),
		Color(228, 86, 80, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText("<:: C-i" .. control.index .. " ::>", "nwTermTile",
		math.Round(width * 0.5), inset + Sc(18), ColorAlpha(ACCENT, 245),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(string.format("FOV %d  ·  Y %+d  ·  P %+d", math.Round(state.fov),
		math.Round(state.yaw), math.Round(state.pitch)), "nwHudSmall",
		inset + Sc(16), height - inset - Sc(18), ColorAlpha(TEXT, 225),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	draw.SimpleText(L("cmbControlHint"), "nwHudSmall", width - inset - Sc(16),
		height - inset - Sc(18), ColorAlpha(TEXT, 225), TEXT_ALIGN_RIGHT,
		TEXT_ALIGN_CENTER)

	local legendX = inset + Sc(16)
	local legendY = height - inset - Sc(44)

	surface.SetFont("nwHudSmall")

	for _, entry in ipairs(NETWORK.cmbterm.cameraMarks) do
		local label = entry.key .. " " .. NETWORK.util.Upper(L(entry.name))
		local textWidth = surface.GetTextSize(label)
		local bLit = control.markDone == entry and (RealTime() - (control.markDoneAt or 0)) < 1.5

		draw.SimpleText(label, "nwHudSmall", legendX, legendY,
			ColorAlpha(entry.color, bLit and 255 or 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		surface.SetDrawColor(entry.color.r, entry.color.g, entry.color.b, bLit and 230 or 110)
		surface.DrawRect(legendX, legendY + Sc(10), textWidth, math.max(Sc(1), 1))

		legendX = legendX + textWidth + Sc(18)
	end

	draw.SimpleText(L("camMarkLegend"), "nwHudSmall", inset + Sc(16), legendY - Sc(18),
		ColorAlpha(TEXT, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (control.markDone and (RealTime() - (control.markDoneAt or 0)) < 1.5) then
		local fade = 1 - (RealTime() - control.markDoneAt) / 1.5
		local color = control.markDone.color

		draw.SimpleText(NETWORK.util.Upper(L("camMarkPlaced", L(control.markDone.name))),
			"nwTermTile", math.Round(width * 0.5), math.Round(height * 0.5) + Sc(46),
			ColorAlpha(color, 240 * fade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local centerX = math.Round(width * 0.5)
	local centerY = math.Round(height * 0.5)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 200)
	surface.DrawRect(centerX - Sc(12), centerY, Sc(8), 1)
	surface.DrawRect(centerX + Sc(4), centerY, Sc(8), 1)
	surface.DrawRect(centerX, centerY - Sc(12), 1, Sc(8))
	surface.DrawRect(centerX, centerY + Sc(4), 1, Sc(8))

	if (control.flash > RealTime()) then
		local fade = (control.flash - RealTime()) / 0.18

		surface.SetDrawColor(255, 255, 255, 230 * fade)
		surface.DrawRect(0, 0, width, height)
	end
end)

local flashes = {}

net.Receive("nwCmbFlash", function()
	local index = net.ReadUInt(16)

	flashes[index] = RealTime() + 0.16
end)

hook.Add("Think", "nwCmbCameraFlash", function()
	for index, until_ in pairs(flashes) do
		if (until_ < RealTime()) then
			flashes[index] = nil

			continue
		end

		local camera = Entity(index)

		if (!IsValid(camera)) then
			continue
		end

		local light = DynamicLight(index)

		if (light) then
			light.pos = camera:WorldSpaceCenter() + camera:GetForward() * 8
			light.r = 255
			light.g = 255
			light.b = 255
			light.brightness = 4
			light.decay = 900
			light.size = 220
			light.dietime = CurTime() + 0.1
		end
	end
end)

function PANEL:BuildSquadPage(x, y, width, bottom)
	local Sc = NETWORK.util.Scale
	local data = self:GetData()
	local list = data.list or {}
	local rowHeight = Sc(64)

	local bMember = data.squad != nil

	for _, row in ipairs(self:GetSquadRows(list, y, bottom, rowHeight)) do
		local squad = row.squad
		local buttonHeight = Sc(32)
		local buttonY = row.y + math.Round((rowHeight - buttonHeight) * 0.5)

		self:AddAction(L("cmbRoster"),
			x + width - Sc(16) - (bMember and Sc(150) or Sc(312)), buttonY,
			Sc(150), buttonHeight, function()

				self.selected = self.selected != squad.id and squad.id or nil

				self:BuildPage()
			end)

		if (!bMember) then
			self:AddAction(L("cmbJoin"), x + width - Sc(16) - Sc(150), buttonY,
				Sc(150), buttonHeight, function()
					self:Send("squadjoin", squad.id)
				end, GREEN)
		end
	end

	if (!data.squad) then
		local entry = self:AddEntry(x, bottom - Sc(48), Sc(260), Sc(38),
			L("cmbSquadName"), function() end)
		local size = self:AddEntry(x + Sc(272), bottom - Sc(48), Sc(90), Sc(38),
			L("cmbSquadSize"), function() end)

		self:AddAction(L("cmbCreate"), x + Sc(374), bottom - Sc(48), Sc(200),
			Sc(38), function()
				self:Send("squadcreate", entry:GetValue(), size:GetValue())
			end)

		return
	end

	self:AddAction(L("cmbLeave"), x, bottom - Sc(48), Sc(200), Sc(38), function()
		self:Send("squadleave")
	end, WARN)

	local bLeading = false

	for _, squad in ipairs(list) do
		if (squad.bLeading) then
			bLeading = true
		end
	end

	if (!bLeading) then
		return
	end

	self:AddAction(L("cmbDisband"), x + Sc(212), bottom - Sc(48), Sc(200), Sc(38),
		function()
			self:Send("squaddisband")
		end, BAD)

	self:AddAction(L("cmbOrders"), x + Sc(424), bottom - Sc(48), Sc(200), Sc(38),
		function()
			NETWORK.gui.TerminalPrompt({
				title = L("cmbOrders"),
				hint = L("cmbOrderPrompt"),
				mode = "note",
				callback = function(text)
					net.Start("nwCmbOrder")
						net.WriteString(text)
					net.SendToServer()
				end
			})
		end)
end

function PANEL:PerformLayout()
	local Sc = NETWORK.util.Scale

	if (!IsValid(self.close)) then
		return
	end

	self.close:SetSize(Sc(34), Sc(34))
	self.close:SetPos(self:GetFrameX() + self:GetFrameWidth() - Sc(44),
		self:GetFrameY() + Sc(10))
	self.close:SetVisible(false)

	if (IsValid(self.fullscreenButton)) then
		local size = Sc(30)

		self.fullscreenButton:SetSize(size, size)
		self.fullscreenButton:SetPos(self:GetFrameX() + self:GetFrameWidth() - Sc(24) - size,
			self:GetFrameY() + math.Round((self:GetBarHeight() - size) * 0.5))
		self.fullscreenButton:SetVisible(self.page != "boot")
	end
end

function PANEL:Think()
	if (IsValid(self.fullscreenButton) and self.fullscreenButton:IsVisible() !=
		(self.page != "boot")) then
		self:InvalidateLayout()
	end

	self.alpha = NETWORK.util.Approach(self.alpha, 1, 4)
	self.open = NETWORK.util.Approach(self.open, 1, 2.2)

	if (self.page != "boot") then
		return
	end

	self.boot = self.boot + FrameTime()

	if (self.boot >= self.bootTime and self.open > 0.98) then

		local client = LocalPlayer()
		local bMechanic = IsValid(self.entity) and
			self.entity:GetClass() == "nw_cwuterminal" and
			IsValid(client) and !client:IsAdmin() and
			client:GetNWString("nwClass", "") == "mechanic"

		self:Open(bMechanic and "breaks" or "home")
	end

end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_F11) then
		return self:SetFullscreen(!self:IsFullscreen())
	end

	if (key == KEY_BACKSPACE and !IsValid(vgui.GetKeyboardFocus()) and
		self.page != "home" and self.page != "boot") then
		surface.PlaySound(NETWORK.cmbterm.sounds.back)

		return self:Open("home")
	end

	if (key == KEY_ESCAPE) then
		net.Start("nwCmbClose")
		net.SendToServer()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local alpha = self.alpha

	ApplyPalette(self.entity)

	if (!self:IsFullscreen()) then
		NETWORK.cmbterm.DrawBackdrop(self, 0, 0, width, height, alpha * 0.55,
			self.bCWU and "cwu" or "alliance", NETWORK.cmbterm.GetPalette(self.entity))

		surface.SetDrawColor(0, 0, 0, 120 * alpha)
		surface.DrawRect(0, 0, width, height)
	else
		surface.SetDrawColor(0, 0, 0, 225 * alpha)
		surface.DrawRect(0, 0, width, height)
	end

	local eased = NETWORK.util.EaseOut(self.open)
	local frameWidth = math.Round(self:GetFrameWidth() * (0.9 + 0.1 * eased))
	local frameHeight = math.Round(self:GetFrameHeight() * math.max(eased, 0.01))
	local x = math.Round(ScrW() * 0.5 - frameWidth * 0.5)
	local y = math.Round(ScrH() * 0.5 - frameHeight * 0.5)

	if (frameHeight < 2) then
		return
	end

	local palette = NETWORK.cmbterm.GetPalette(self.entity)
	local base = palette.base
	local accent = palette.accent

	NETWORK.cmbterm.DrawBackdrop(self, x, y, frameWidth, frameHeight, alpha,
		self.bCWU and "cwu" or "alliance", palette)

	local fade = math.Round(math.min(frameWidth, frameHeight) * 0.34)

	surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-u"))
	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawTexturedRect(x, y, frameWidth, fade)

	surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-d"))
	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawTexturedRect(x, y + frameHeight - fade, frameWidth, fade)

	surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-r"))
	surface.SetDrawColor(0, 0, 0, 120 * alpha)
	surface.DrawTexturedRect(x, y, fade, frameHeight)

	surface.SetMaterial(NETWORK.util.GetMaterial("vgui/gradient-l"))
	surface.SetDrawColor(0, 0, 0, 120 * alpha)
	surface.DrawTexturedRect(x + frameWidth - fade, y, fade, frameHeight)

	local glitch = (CurTime() % 10) / 2

	if (glitch <= 1) then
		local glitchY = y + math.Round(frameHeight * glitch)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 16 * alpha)
		surface.DrawRect(x, glitchY, frameWidth, Sc(14))

		surface.SetDrawColor(accent.r, accent.g, accent.b, 34 * alpha)
		surface.DrawRect(x, glitchY, frameWidth, math.max(Sc(2), 1))
	end

	if (self.open >= 0.99) then
		NETWORK.util.DrawScanlines(x, y, frameWidth, frameHeight, 38 * alpha,
			math.max(Sc(3), 3))
	end

	local size = Sc(26)
	local thickness = math.max(Sc(2), 2)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 220 * alpha)

	surface.DrawRect(x, y, size, thickness)
	surface.DrawRect(x, y, thickness, size)
	surface.DrawRect(x + frameWidth - size, y, size, thickness)
	surface.DrawRect(x + frameWidth - thickness, y, thickness, size)
	surface.DrawRect(x, y + frameHeight - size, thickness, size)
	surface.DrawRect(x, y + frameHeight - thickness, size, thickness)
	surface.DrawRect(x + frameWidth - size, y + frameHeight - thickness, size,
		thickness)
	surface.DrawRect(x + frameWidth - thickness, y + frameHeight - size, thickness,
		size)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 120 * alpha)
	surface.DrawOutlinedRect(x, y, frameWidth, frameHeight, 1)

	if (self.open < 0.99) then
		local edge = math.max(Sc(2), 2)
		local light = Color(Lerp(0.5, accent.r, 255), Lerp(0.5, accent.g, 255),
			Lerp(0.5, accent.b, 255), 255 * alpha)

		surface.SetDrawColor(light)
		surface.DrawRect(x, y, frameWidth, edge)
		surface.DrawRect(x, y + frameHeight - edge, frameWidth, edge)

		NETWORK.util.DrawVGradient(x, y, frameWidth, Sc(40), ColorAlpha(accent, 90 * alpha),
			ColorAlpha(accent, 0))
		NETWORK.util.DrawVGradient(x, y + frameHeight - Sc(40), frameWidth, Sc(40),
			ColorAlpha(accent, 0), ColorAlpha(accent, 90 * alpha))

		return
	end

	if (self.page == "boot") then
		self:PaintBoot(x, y, frameWidth, frameHeight, ACCENT, alpha)

		return
	end

	self:PaintChrome(x, y, frameWidth, frameHeight, alpha)
	self:PaintContent(alpha)
end

function PANEL:PaintBoot(x, y, width, height, color, alpha)
	NETWORK.cmbterm.DrawBoot(self, x, y, width, height, alpha, self.boot, self.bootTime,
		self.bCWU and "cwu" or "alliance", color, self.logo)
end

function PANEL:PaintChrome(x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()
	local character = client:GetCharacter()
	local barHeight = self:GetBarHeight()
	local navHeight = self:GetNavHeight()

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 10 * alpha)
	surface.DrawRect(x, y, width, barHeight)

	local palette = NETWORK.cmbterm.GetPalette(self.entity)
	local accent = palette.accent
	local bCWU = IsValid(self.entity) and
		self.entity:GetClass() == "nw_cwuterminal"
	local logoSize = Sc(30)

	surface.SetFont("nwHudSmall")

	local codeWidth = surface.GetTextSize(bCWU and "CWU" or "C24") + Sc(14)
	local logoX = x + Sc(24) + codeWidth + Sc(14)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 235 * alpha)
	surface.SetMaterial(self.logo)
	surface.DrawTexturedRect(logoX, y + math.Round((barHeight - logoSize) * 0.5),
		logoSize, logoSize)

	local titleX = logoX + logoSize + Sc(14)

	draw.SimpleText(util.Upper(L(bCWU and "cwuTitle" or "cmbTitle")),
		"nwTermBrand", titleX,
		y + math.Round(barHeight * 0.5) - Sc(8), ColorAlpha(TEXT, 250 * alpha),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	util.DrawTextSpaced(util.Upper(L("cmbSecure")), "nwHudSmall", titleX,
		y + math.Round(barHeight * 0.5) + Sc(10), ColorAlpha(DIM, 230 * alpha), Sc(3),
		TEXT_ALIGN_CENTER)

	local code = bCWU and "CWU" or "C24"
	local codeX = x + Sc(24)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 30 * alpha)
	surface.DrawRect(codeX, y + math.Round(barHeight * 0.5) - Sc(9),
		codeWidth, Sc(18))

	surface.SetDrawColor(accent.r, accent.g, accent.b, 150 * alpha)
	surface.DrawOutlinedRect(codeX, y + math.Round(barHeight * 0.5) - Sc(9),
		codeWidth, Sc(18), 1)

	draw.SimpleText(code, "nwHudSmall", codeX + math.Round(codeWidth * 0.5),
		y + math.Round(barHeight * 0.5), ColorAlpha(accent, 245 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local operator = character and character:GetName() or "?"
	local citizenID = character and NETWORK.terminal.GetCitizenID(character) or "00000"
	local rightX = x + width - Sc(24) - Sc(44)

	util.DrawVGradient(x, y, width, barHeight, ColorAlpha(accent, 0),
		ColorAlpha(accent, 22 * alpha))

	if (bCWU) then
		DrawHazard(self, x, y + barHeight - Sc(4), width, Sc(4), accent, alpha * 0.8)
	else
		local sweep = (RealTime() * 0.35) % 1.6

		if (sweep < 1) then
			local sweepX = x + math.Round(width * sweep)

			util.DrawHGradient(sweepX - Sc(160), y + barHeight - 2, Sc(160), 2,
				ColorAlpha(accent, 0), ColorAlpha(accent, 200 * alpha))
		end
	end

	local onlineText = util.Upper(L("cmbNode"))

	surface.SetFont("nwHudSmall")

	local onlineWidth = surface.GetTextSize(onlineText)

	draw.SimpleText(onlineText, "nwHudSmall", rightX, y + math.Round(barHeight * 0.5),
		ColorAlpha(GREEN, 235 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local dot = Sc(6)

	surface.SetDrawColor(GREEN.r, GREEN.g, GREEN.b, 235 * alpha)
	surface.DrawRect(rightX - onlineWidth - Sc(14), y + math.Round(barHeight * 0.5) -
		math.Round(dot * 0.5), dot, dot)

	draw.SimpleText("// " .. util.Upper(operator) .. "  ·  " .. citizenID, "nwHudSmall",
		rightX - onlineWidth - Sc(30), y + math.Round(barHeight * 0.5),
		ColorAlpha(DIM, 235 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local navY = y + barHeight

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 60 * alpha)
	surface.DrawRect(x, navY, width, 1)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 6 * alpha)
	surface.DrawRect(x, navY, width, navHeight)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 90 * alpha)
	surface.DrawRect(x, navY + navHeight - 1, width, 1)

	if (self.page == "home" or self.page == "boot") then
		self:PaintFooterBar(x, y, width, height, alpha)

		return
	end

	local cardX = self:GetCardX()
	local cardY = self:GetCardY()
	local cardWidth = self:GetCardWidth()
	local cardBottom = self:GetCardBottom()
	local cardHeight = cardBottom - cardY

	if (ROUNDED) then
		local radius = Sc(14)

		draw.RoundedBox(radius, cardX, cardY, cardWidth, cardHeight,
			ColorAlpha(BASE, 200 * alpha))
		draw.RoundedBoxEx(radius, cardX, cardY, cardWidth, Sc(56),
			ColorAlpha(ACCENT, 26 * alpha), true, true, false, false)
		DrawHazard(self, cardX + cardWidth - Sc(160), cardY, Sc(160) - radius, Sc(8),
			ACCENT, alpha)
		NETWORK.util.DrawRoundedBorder(cardX, cardY, cardWidth, cardHeight, radius, 1,
			ColorAlpha(ACCENT, 90 * alpha))
	else
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 5 * alpha)
		surface.DrawRect(cardX, cardY, cardWidth, cardHeight)

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 45 * alpha)
		surface.DrawOutlinedRect(cardX, cardY, cardWidth, cardHeight, 1)

		local tick = Sc(16)
		local thickness = math.max(Sc(2), 2)

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 200 * alpha)
		surface.DrawRect(cardX, cardY, tick, thickness)
		surface.DrawRect(cardX, cardY, thickness, tick)
		surface.DrawRect(cardX + cardWidth - tick, cardY + cardHeight - thickness, tick, thickness)
		surface.DrawRect(cardX + cardWidth - thickness, cardY + cardHeight - tick, thickness, tick)
	end

	local titleY = cardY + Sc(32)

	util.DrawTextSpaced(util.Upper(L(self.bCWU and "cwuTitle" or "cmbTitle")), "nwTermTitle",
		cardX + Sc(30), titleY,
		ColorAlpha(TEXT, 252 * alpha), Sc(6), TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(L("cmbOperator")) .. " : " .. util.Upper(operator) ..
		"  ·  " .. citizenID, "nwHudSmall", cardX + cardWidth - Sc(30), titleY,
		ColorAlpha(DIM, 235 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 90 * alpha)
	surface.DrawRect(cardX + Sc(30), cardY + Sc(56), cardWidth - Sc(60), 1)

	self:PaintFooterBar(x, y, width, height, alpha)
end

function PANEL:PaintFooterBar(x, y, width, height, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()

	local footerY = y + height - Sc(30)
	local zone = NETWORK.zone.AtEntity(client)
	local type = zone and NETWORK.zone.GetType(zone.type)
	local sector = zone and (zone.name != "" and zone.name or (type and L(type.name))) or "-"

	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 45 * alpha)
	surface.DrawRect(x, footerY - Sc(14), width, 1)

	util.DrawTextSpaced((self.bCWU and "CWU // " or "C24 // ") ..
		util.Upper(L(self.bCWU and "cwuTitle" or "cmbTitle")), "nwHudSmall", x + Sc(26),
		footerY, ColorAlpha(DIM, 215 * alpha), Sc(2), TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(L("termTime")) .. " : " .. os.date("%d.%m.%Y") .. "  ·  " ..
		NETWORK.time.GetFormatted(), "nwHudSmall", x + math.Round(width * 0.36), footerY,
		ColorAlpha(DIM, 225 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local keys = L("termKeysHint")

	surface.SetFont("nwHudSmall")

	local keysWidth = surface.GetTextSize(keys) + Sc(24)
	local keysX = x + math.Round(width * 0.62) - math.floor(keysWidth * 0.5)

	if (ROUNDED) then
		draw.RoundedBox(Sc(10), keysX, footerY - Sc(10), keysWidth, Sc(20),
			ColorAlpha(ACCENT, 18 * alpha))
	else
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 14 * alpha)
		surface.DrawRect(keysX, footerY - Sc(10), keysWidth, Sc(20))
	end

	draw.SimpleText(keys, "nwHudSmall", keysX + math.floor(keysWidth * 0.5), footerY,
		ColorAlpha(TEXT, 210 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(L("cmbSector")) .. " : " .. util.Upper(tostring(sector)),
		"nwHudSmall", x + width - Sc(180), footerY, ColorAlpha(DIM, 225 * alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	for index = 0, 7 do
		local pulse = math.sin(RealTime() * 3 - index * 0.5) * 0.5 + 0.5

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, (24 + pulse * 150) * alpha)
		surface.DrawRect(x + width - Sc(140) + index * Sc(10), footerY - Sc(3), Sc(5), Sc(6))
	end
end

function PANEL:GetData()
	local data = self.data

	if (!data or data.page != self.page) then
		return {}
	end

	return data
end

function PANEL:GetList()
	return self:GetData().list or {}
end

function PANEL:PaintContent(alpha)

	local switch = NETWORK.util.EaseOut(math.Clamp((RealTime() - (self.pageSwitched or 0)) /
		0.3, 0, 1))

	alpha = alpha * switch

	if (switch < 1 and self.page != "home") then
		local sweepX = self:GetCardX() + math.Round(self:GetCardWidth() * switch)

		NETWORK.util.DrawSoftLight(sweepX, self:GetCardY(), NETWORK.util.Scale(300),
			NETWORK.util.Scale(40), ACCENT, 90 * (1 - switch))
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local x = self:GetContentX() + Sc(34)
	local y = self:GetPageTop() - Sc(32)
	local width = self:GetContentWidth() - Sc(68)
	local bottom = self:GetPageBottom()
	local page = self.page

	if (page == "home") then
		return self:PaintHome(alpha)
	end

	local sectionList = self:GetSections()

	for index, section in ipairs(sectionList) do
		if (section.id != page) then
			continue
		end

		local label = util.Upper(L(section.name))
		local number = string.format("%02d", index)

		local crumb = util.Upper(L("cmbBreadcrumbHome")) .. "  ›  " .. label

		draw.SimpleText(crumb, "nwHudSmall", x, y - Sc(22), ColorAlpha(DIM, 210 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(number, "nwTermBody", x, y, ColorAlpha(DIM, 220 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local labelX = x + Sc(46)
		local labelWidth = util.TextSpacedSize(label, "nwTermButton", Sc(4))

		util.DrawTextSpaced(label, "nwTermButton", labelX, y,
			ColorAlpha(ACCENT, 250 * alpha), Sc(4), TEXT_ALIGN_CENTER)

		Rule(labelX + labelWidth + Sc(18), y, width - labelWidth - Sc(64), alpha, 80)

		if (section.caption) then
			draw.SimpleText(L(section.caption), "nwHudSmall", labelX, y + Sc(20),
				ColorAlpha(TEXT, 170 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	local top = y + Sc(58)

	local extension = NETWORK.cmbterm.extensions[page]

	if (extension and extension.Paint) then
		return extension.Paint(self, x, top, width, bottom, alpha)
	end

	if (page == "breaks" or page == "maint" or page == "tasks") then
		return self:PaintTaskList(alpha)
	end

	if (page == "journal") then
		return self:PaintJournal(x, top, width, bottom, alpha)
	end

	if (page == "alliance") then
		return self:PaintAlliance(x, top, width, bottom, alpha)
	end

	if (page == "citizen") then
		return self:PaintCitizen(x, top, width, bottom, alpha)
	end

	if (page == "squads") then
		return self:PaintSquads(x, top, width, bottom, alpha)
	end

	if (page == "business") then
		return self:PaintBusiness(x, top, width, bottom, alpha)
	end

	if (page == "cameras") then
		if (#self:GetList() == 0) then
			draw.SimpleText(L("cmbNoCameras"), "nwTermBody", x, top,
				ColorAlpha(DIM, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		return
	end

	if (page == "detained") then
		local list = self:GetList()

		if (#list == 0) then
			draw.SimpleText(L("cmbNoDetainees"), "nwTermBody", x, top,
				ColorAlpha(DIM, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			self:ClearDossiers()

			return
		end

		self:PaintDossiers(x - Sc(4), y + Sc(20), width + Sc(8),
			bottom - y - Sc(20), ACCENT, alpha, list)
	end
end

function PANEL:PaintHome(alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()
	local x = self:GetCardX()
	local y = self:GetCardY()
	local width = self:GetCardWidth()
	local online, cwu = 0, 0

	for _, other in ipairs(player.GetAll()) do
		if (NETWORK.factions.IsAlliance(other)) then
			online = online + 1
		elseif (NETWORK.factions.IsCWU(other)) then
			cwu = cwu + 1
		end
	end

	util.DrawTextSpaced(util.Upper(L(self.bCWU and "cwuWelcome" or "cmbWelcome")),
		"nwHudSmall", x, y + Sc(6), ColorAlpha(DIM, 235 * alpha), Sc(3),
		TEXT_ALIGN_CENTER)

	draw.SimpleText(util.Upper(client:GetCharacterName()), "nwTermTitle", x, y + Sc(32),
		ColorAlpha(TEXT, 252 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local stats = self.bCWU and {
		{L("cwuStatWorkers"), cwu},
		{L("cmbStatUnits"), online}
	} or {
		{L("cmbStatUnits"), online},
		{L("cwuStatWorkers"), cwu}
	}

	local cursor = x + width

	for index = #stats, 1, -1 do
		local stat = stats[index]
		local text = tostring(stat[2])

		draw.SimpleText(text, "nwTermTitle", cursor, y + Sc(26),
			ColorAlpha(ACCENT, 250 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		draw.SimpleText(util.Upper(stat[1]), "nwHudSmall", cursor, y + Sc(48),
			ColorAlpha(DIM, 230 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		surface.SetFont("nwTermTitle")

		local numberWidth = surface.GetTextSize(text)

		surface.SetFont("nwHudSmall")

		cursor = cursor - math.max(numberWidth, (surface.GetTextSize(util.Upper(stat[1])))) -
			Sc(34)
	end

	if (self.bCWU) then
		DrawHazard(self, x, y + Sc(54), width, Sc(4), ACCENT, alpha)
	else
		Rule(x, y + Sc(56), width, alpha, 90)
	end
end

function PANEL:PaintTaskList(alpha)
	local Sc = NETWORK.util.Scale
	local list = self:GetTaskList()

	if (#list == 0) then
		local key = self.page == "maint" and "cmbMaintNone" or "cmbBreaksNone"

		draw.SimpleText(L(key), "nwTermBody", self:GetContentX() + Sc(34),
			self:GetPageTop() + Sc(30), ColorAlpha(DIM, 220 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	for index, entry in ipairs(list) do
		local x, y, width, height = self:GetTaskRow(index)

		if (!y) then
			break
		end

		local accent = entry.kind == "maint" and ACCENT or WARN

		surface.SetDrawColor(6, 20, 28, 190 * alpha)
		surface.DrawRect(x, y, width, height)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 60 * alpha)
		surface.DrawOutlinedRect(x, y, width, height, 1)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 235 * alpha)
		surface.DrawRect(x, y, math.max(Sc(3), 2), height)

		draw.SimpleText(NETWORK.util.Upper(entry.name or "?"), "nwTermBody",
			x + Sc(16), y + Sc(16), ColorAlpha(TEXT, 250 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(string.format("%s  //  %d %s",
			entry.zone != "" and entry.zone or L("cmbBreaksNoZone"),
			entry.distance or 0, L("questMetres")), "nwHudSmall",
			x + Sc(16), y + Sc(33), ColorAlpha(DIM, 235 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:PaintJournal(x, y, width, bottom, alpha)
	local Sc = NETWORK.util.Scale
	local list = self.data and self.data.journal or {}

	if (#list == 0) then
		draw.SimpleText(L("cmbJournalNone"), "nwTermBody", x, y + Sc(20),
			ColorAlpha(DIM, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	local rowY = y + Sc(14)

	for _, entry in ipairs(list) do
		if (rowY > bottom - Sc(30)) then
			break
		end

		local color = entry.action == "journalRepair" and GREEN or WARN

		draw.SimpleText(entry.time or "--:--", "nwHudSmall", x, rowY,
			ColorAlpha(DIM, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(NETWORK.util.Upper(L(entry.action)), "nwHudSmall",
			x + Sc(60), rowY, ColorAlpha(color, 245 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(NETWORK.util.Upper(entry.target or "?"), "nwTermBody",
			x + Sc(180), rowY, ColorAlpha(TEXT, 245 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(entry.name or "?", "nwTermBody", x + Sc(420), rowY,
			ColorAlpha(TEXT, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(entry.zone != "" and entry.zone or
			L("cmbBreaksNoZone"), "nwHudSmall", x + Sc(680), rowY,
			ColorAlpha(DIM, 235 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		rowY = rowY + Sc(26)
	end
end

function PANEL:PaintAlliance(x, y, width, bottom, alpha)
	local Sc = NETWORK.util.Scale
	local list = self:GetList()

	if (self.record) then
		return self:PaintRecord(x, y, width, bottom, alpha, true)
	end

	if (#list == 0) then
		draw.SimpleText(L("cmbNobody"), "nwTermBody", x, y,
			ColorAlpha(DIM, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	self.rows = {}

	for index, entry in ipairs(list) do
		local rowY = y + (index - 1) * Sc(50)

		if (rowY + Sc(44) > bottom) then
			break
		end

		local bHover = self:IsRowHovered(x, rowY, width, Sc(44))

		Row(x, rowY, width, Sc(44), alpha, bHover)

		draw.SimpleText(entry.name, "nwTermBody", x + Sc(20), rowY + Sc(22),
			ColorAlpha(TEXT, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(entry.squad or "-", "nwTermBody", x + Sc(400),
			rowY + Sc(22), ColorAlpha(ACCENT, 225 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		draw.SimpleText(entry.zone or L("owUnknownZone"), "nwTermBody",
			x + width - Sc(170), rowY + Sc(22), ColorAlpha(DIM, 235 * alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		self.rows[index] = {x = x, y = rowY, width = width, height = Sc(44),
			entry = entry}
	end
end

function PANEL:PaintBusiness(x, y, width, bottom, alpha)
	local Sc = NETWORK.util.Scale
	local data = self.data or {}

	if (data.bAllowed == false) then
		draw.SimpleText(L("cmbBusinessCMDOnly"), "nwTermBody", x, y,
			ColorAlpha(DIM, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	local record = self.record

	if (record) then
		local cursor = y
		local body = ColorAlpha(TEXT, 245 * alpha)

		draw.SimpleText(record.name .. "  #" .. (record.cid or "?"),
			"nwTermTitle", x, cursor, ColorAlpha(ACCENT, 250 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(34)

		draw.SimpleText(NETWORK.util.Upper(L("termBusinessWhat")) .. ": " ..
			(record.what or ""), "nwTermBody", x, cursor, body,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(30)

		draw.SimpleText(NETWORK.util.Upper(L("termBusinessWhy")) .. ":",
			"nwTermBody", x, cursor, ColorAlpha(DIM, 235 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(24)

		for _, line in ipairs(NETWORK.util.WrapText(record.why or "",
			"nwTermBody", width - Sc(40), 8)) do
			draw.SimpleText(line, "nwTermBody", x, cursor, body,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			cursor = cursor + Sc(22)
		end

		if (record.status != "pending") then
			cursor = cursor + Sc(12)

			local bOk = record.status == "approved"

			draw.SimpleText(NETWORK.util.Upper(bOk and L("termBusinessApproved")
				or L("termBusinessDenied")) .. "  //  " ..
				(record.location != "" and record.location or "-"),
				"nwTermBody", x, cursor,
				bOk and Color(96, 224, 140, 245 * alpha) or
				Color(232, 84, 76, 245 * alpha), TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		else
			draw.SimpleText(L("cmbBusinessDoorHint"), "nwTermBody", x,
				bottom - Sc(118), ColorAlpha(DIM, 220 * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		return
	end

	local list = self:GetList()

	if (#list == 0) then
		draw.SimpleText(L("cmbBusinessNone"), "nwTermBody", x, y,
			ColorAlpha(DIM, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	self.rows = {}

	for index, entry in ipairs(list) do
		local rowY = y + (index - 1) * Sc(50)

		if (rowY + Sc(44) > bottom) then
			break
		end

		local bHover = self:IsRowHovered(x, rowY, width, Sc(44))

		Row(x, rowY, width, Sc(44), alpha, bHover)

		draw.SimpleText(entry.name .. "  #" .. (entry.cid or "?"),
			"nwTermBody", x + Sc(20), rowY + Sc(22),
			ColorAlpha(TEXT, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		local status = L("termBusinessPending")
		local color = Color(240, 196, 84)

		if (entry.status == "approved") then
			status = L("termBusinessApproved")
			color = Color(96, 224, 140)
		elseif (entry.status == "denied") then
			status = L("termBusinessDenied")
			color = Color(232, 84, 76)
		end

		draw.SimpleText(NETWORK.util.Upper(status), "nwTermBody",
			x + width - Sc(30), rowY + Sc(22), ColorAlpha(color, 240 * alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		self.rows[index] = {x = x, y = rowY, width = width, height = Sc(44),
			entry = entry}
	end
end

function PANEL:PaintCitizen(x, y, width, bottom, alpha)
	local Sc = NETWORK.util.Scale

	if (!self.record) then
		draw.SimpleText(L("cmbCitizenHint"), "nwTermBody", x, y + Sc(70),
			ColorAlpha(DIM, 210 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		return
	end

	self:PaintRecord(x, y + Sc(60), width, bottom, alpha, false)
end

function PANEL:PaintRecord(x, y, width, bottom, alpha, bFull)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local record = self.record
	local cursor = y

	local fields = {
		{L("cmbFieldName"), record.name},
		{"CID", "#" .. record.cid},
		{L("termViolations"), record.violations or L("termViolationsNone")},
		{L("cmbLoyalty"), record.loyaltyBand .. "  (" .. record.loyalty .. ")"}
	}

	if (bFull) then
		fields[#fields + 1] = {L("cmbSquad"), record.squad or "-"}
		fields[#fields + 1] = {L("cmbLastZone"),
			record.zone or L("owUnknownZone")}
	end

	for _, field in ipairs(fields) do
		draw.SimpleText(util.Upper(field[1]), "nwTermBody", x, cursor,
			ColorAlpha(DIM, 215 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(tostring(field[2]), "nwTermBody", x + Sc(300), cursor,
			ColorAlpha(TEXT, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(30)
	end

	cursor = cursor + Sc(16)

	Rule(x, cursor, width, alpha)

	cursor = cursor + Sc(24)

	util.DrawTextSpaced(util.Upper(L("cmbNotes")), "nwHudSmall", x, cursor,
		ColorAlpha(ACCENT, 225 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	cursor = cursor + Sc(26)

	for _, note in ipairs(record.notes or {}) do
		if (cursor > bottom - Sc(60)) then
			break
		end

		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 160 * alpha)
		surface.DrawRect(x, cursor - Sc(9), math.max(Sc(2), 2), Sc(18))

		draw.SimpleText(os.date("%d.%m %H:%M", note.time) .. "  " .. note.author,
			"nwHudSmall", x + Sc(12), cursor - Sc(1), ColorAlpha(DIM, 220 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(18)

		draw.SimpleText(note.text, "nwTermBody", x + Sc(12), cursor,
			ColorAlpha(TEXT, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(26)
	end
end

function PANEL:PaintSquads(x, y, width, bottom, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local data = self:GetData()
	local list = data.list or {}
	local rowHeight = Sc(64)

	if (#list == 0) then
		draw.SimpleText(L("cmbNoSquads"), "nwTermBody", x, y,
			ColorAlpha(DIM, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	for _, row in ipairs(self:GetSquadRows(list, y, bottom, rowHeight)) do
		local squad = row.squad
		local rowY = row.y

		Row(x, rowY, width, rowHeight, alpha, squad.bMine)

		util.DrawTextSpaced(util.Upper(squad.name), "nwTermBody", x + Sc(20),
			rowY + Sc(22), ColorAlpha(squad.bMine and ACCENT or TEXT, 250 * alpha),
			Sc(2), TEXT_ALIGN_CENTER)

		draw.SimpleText(util.Upper(L("cmbLeader")) .. ": " ..
			(squad.leader or "-"),
			"nwHudSmall", x + Sc(20), rowY + Sc(44), ColorAlpha(DIM, 225 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText((squad.count or 0) .. " / " .. (squad.size or 0),
			"nwTermBody",
			x + Sc(420), rowY + Sc(22),
			ColorAlpha((squad.count or 0) >= (squad.size or 1) and WARN or GREEN,
				245 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(squad.zone or L("owUnknownZone"), "nwHudSmall",
			x + Sc(420), rowY + Sc(44), ColorAlpha(DIM, 225 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (self.selected == squad.id) then
			local memberY = rowY + rowHeight + Sc(6)

			for _, member in ipairs(squad.roster or {}) do
				if (memberY > bottom - Sc(120)) then
					break
				end

				draw.SimpleText((member.bLeader and "* " or "  ") .. member.name ..
					"  ::  " .. (member.zone or L("owUnknownZone")), "nwHudSmall",
					x + Sc(40), memberY, ColorAlpha(TEXT, 230 * alpha),
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				memberY = memberY + Sc(20)
			end
		end
	end

	Rule(x, bottom - Sc(66), width, alpha, 70)
end

function PANEL:IsRowHovered(x, y, width, height)
	local mouseX, mouseY = gui.MousePos()

	return mouseX >= x and mouseY >= y and mouseX <= x + width and
		mouseY <= y + height
end

function PANEL:OnMousePressed(code)
	if (code != MOUSE_LEFT or !self.rows) then
		return
	end

	for _, row in ipairs(self.rows) do
		if (self:IsRowHovered(row.x, row.y, row.width, row.height)) then
			surface.PlaySound(NETWORK.cmbterm.sounds.select)

			self.record = row.entry

			self:BuildPage()

			return
		end
	end
end

function PANEL:ClearDossiers()
	for _, panel in pairs(self.models or {}) do
		if (IsValid(panel)) then
			panel:Remove()
		end
	end

	self.models = {}
end

function PANEL:GetModelPanel(index, model)
	self.models = self.models or {}

	local panel = self.models[index]

	if (IsValid(panel) and panel.nwModel == model) then
		return panel
	end

	if (IsValid(panel)) then
		panel:Remove()
	end

	panel = self:Add("DModelPanel")
	panel.nwModel = model

	panel:SetModel(model)
	panel:SetFOV(32)
	panel:SetMouseInputEnabled(false)
	panel.LayoutEntity = function(self, entity)
		entity:SetAngles(Angle(0, 35, 0))
	end

	local entity = panel:GetEntity()

	if (IsValid(entity)) then

		local mins, maxs = entity:GetRenderBounds()
		local center = (mins + maxs) * 0.5

		center.z = maxs.z * 0.82

		panel:SetLookAt(center)
		panel:SetCamPos(center + Vector(34, 14, 3))
	end

	self.models[index] = panel

	return panel
end

function PANEL:PaintDossiers(x, y, width, height, color, alpha, list)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local cardWidth = Sc(300)
	local cardHeight = height - Sc(150)
	local gap = Sc(22)
	local perRow = math.max(math.floor((width - Sc(60) + gap) / (cardWidth + gap)), 1)
	local cardY = y + Sc(80)

	for index, record in ipairs(list) do
		if (index > perRow) then
			break
		end

		local cardX = x + Sc(30) + (index - 1) * (cardWidth + gap)

		surface.SetDrawColor(color.r, color.g, color.b, 16 * alpha)
		surface.DrawRect(cardX, cardY, cardWidth, cardHeight)

		surface.SetDrawColor(color.r, color.g, color.b, 150 * alpha)
		surface.DrawOutlinedRect(cardX, cardY, cardWidth, cardHeight,
			math.max(Sc(2), 1))

		local panel = self:GetModelPanel(index, record.model or
			"models/humans/group01/male_07.mdl")

		panel:SetPos(cardX + Sc(10), cardY + Sc(10))
		panel:SetSize(cardWidth - Sc(20), Sc(190))
		panel:SetAlpha(255 * alpha)

		local cursor = cardY + Sc(214)

		util.DrawTextSpaced(util.Upper(record.name or "?"), "nwTermButton",
			cardX + cardWidth * 0.5, cursor, ColorAlpha(color, 250 * alpha), Sc(3),
			TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(22)

		draw.SimpleText("#" .. (record.cid or "00000"), "nwTermBody",
			cardX + cardWidth * 0.5, cursor, ColorAlpha(color, 190 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(26)

		surface.SetDrawColor(color.r, color.g, color.b, 70 * alpha)
		surface.DrawRect(cardX + Sc(16), cursor, cardWidth - Sc(32), 1)

		cursor = cursor + Sc(20)

		for _, line in ipairs(util.WrapText(record.reason or "-", "nwTermBody",
			cardWidth - Sc(32), 3)) do
			draw.SimpleText(line, "nwTermBody", cardX + Sc(16), cursor,
				Color(214, 238, 248, 245 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			cursor = cursor + Sc(20)
		end

		cursor = cursor + Sc(8)

		local term = record.remaining and
			(record.remaining .. " " .. L("cmbMinutes")) or L("cmbIndefinite")

		draw.SimpleText(util.Upper(L("cmbTerm")) .. ": " .. term, "nwTermBody",
			cardX + Sc(16), cursor, ColorAlpha(color, 235 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(26)

		util.DrawTextSpaced(util.Upper(L("cmbNotes")), "nwHudSmall", cardX + Sc(16),
			cursor, ColorAlpha(color, 200 * alpha), Sc(3), TEXT_ALIGN_CENTER)

		cursor = cursor + Sc(20)

		for _, note in ipairs(record.notes or {}) do
			if (cursor > cardY + cardHeight - Sc(16)) then
				break
			end

			for _, line in ipairs(util.WrapText(note.author .. ": " .. note.text,
				"nwTermBody", cardWidth - Sc(32), 2)) do
				draw.SimpleText(line, "nwTermBody", cardX + Sc(16), cursor,
					Color(186, 210, 222, 230 * alpha), TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)

				cursor = cursor + Sc(18)
			end
		end
	end

	for index, panel in pairs(self.models or {}) do
		if (index > math.min(#list, perRow) and IsValid(panel)) then
			panel:Remove()

			self.models[index] = nil
		end
	end
end

vgui.Register("nwCmbTerminal", PANEL, "EditablePanel")

function NETWORK.cmbterm.Close()
	NETWORK.cmbterm.control = nil

	if (IsValid(NETWORK.gui.cmbTerminal)) then
		NETWORK.gui.cmbTerminal:Remove()
	end

	NETWORK.gui.cmbTerminal = nil
end

net.Receive("nwCmbOpen", function()
	local entity = net.ReadEntity()
	local bootTime = net.ReadFloat()

	NETWORK.cmbterm.Close()

	local panel = vgui.Create("nwCmbTerminal")

	if (IsValid(panel)) then
		panel.entity = entity
	end

	if (!IsValid(panel)) then
		return
	end

	panel:Setup(entity, bootTime)

	NETWORK.gui.cmbTerminal = panel
end)

net.Receive("nwCmbClose", function()
	NETWORK.cmbterm.Close()
end)

net.Receive("nwCmbData", function()
	local data = NETWORK.util.ReadTable() or {}
	local panel = NETWORK.gui.cmbTerminal

	if (!IsValid(panel)) then
		return
	end

	panel.data = data

	if (data.record) then
		panel.record = data.record
	end

	if (panel.record and data.list) then
		for _, entry in ipairs(data.list) do
			if (entry.id == panel.record.id) then
				panel.record = entry

				break
			end
		end
	end

	panel:BuildPage()
end)

local order = nil

net.Receive("nwCmbOrder", function()
	order = {
		text = net.ReadString(),
		author = net.ReadString(),
		time = RealTime()
	}
end)

hook.Add("HUDPaint", "nwCmbOrder", function()
	if (!order) then
		return
	end

	local age = RealTime() - order.time
	local hold = NETWORK.cmbterm.orderTime

	if (age > hold + 0.5) then
		order = nil

		return
	end

	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local alpha = math.Clamp(age / 0.3, 0, 1) *
		(1 - math.Clamp((age - hold) / 0.5, 0, 1))
	local centerX = math.Round(ScrW() * 0.5)
	local lines = util.WrapText(order.text, "nwTermTitle",
		math.min(ScrW() - Sc(200), Sc(1000)), 3)
	local y = math.Round(ScrH() * 0.32)

	util.DrawSimpleTextShadow(util.Upper(L("cmbOrderFrom", order.author)),
		"nwHudSmall", centerX, y - Sc(34), Color(126, 210, 245, 235 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, math.max(Sc(2), 1))

	for _, line in ipairs(lines) do
		util.DrawSimpleTextShadow(line, "nwTermTitle", centerX, y,
			Color(220, 244, 252, 252 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
			math.max(Sc(2), 1))

		y = y + Sc(38)
	end
end)
