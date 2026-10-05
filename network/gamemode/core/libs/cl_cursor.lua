NETWORK.cursor = NETWORK.cursor or {}

local CURSOR = NETWORK.cursor

local enabledConVar = CreateClientConVar("network_cursor", "1", true, false,
	"Свой курсор вместо системного в меню")
local sizeConVar = CreateClientConVar("network_cursor_size", "24", true, false,
	"Размер своего курсора в пикселях", 16, 40)
local rippleConVar = CreateClientConVar("network_cursor_ripple", "1", true, false,
	"Круг от кончика курсора при нажатии")

NETWORK.option.Register("network_cursor", {
	name = "optCursor",
	description = "optCursorDesc",
	category = "interface",
	type = "bool",
	convar = "network_cursor",
	default = true
})

NETWORK.option.Register("network_cursor_size", {
	name = "optCursorSize",
	description = "optCursorSizeDesc",
	category = "interface",
	type = "number",
	convar = "network_cursor_size",
	min = 16,
	max = 40,
	decimals = 0
})

NETWORK.option.Register("network_cursor_ripple", {
	name = "optCursorRipple",
	description = "optCursorRippleDesc",
	category = "interface",
	type = "bool",
	convar = "network_cursor_ripple",
	default = true
})

local KIND_MAP = {
	arrow = "arrow",
	last = "arrow",
	none = "arrow",
	[""] = "arrow",
	hand = "hand",
	beam = "beam",
	sizeall = "move",
	sizewe = "move",
	sizens = "move",
	sizenwse = "move",
	sizenesw = "move",
	waitarrow = "busy",
	hourglass = "busy",
	blank = "hidden"
}

local KINDS = {"arrow", "hand", "beam", "move", "busy"}

local UNIT = 1 / 24
local ARROW_HOT_X, ARROW_HOT_Y = 2 * UNIT, 1.4 * UNIT
local BADGE_X, BADGE_Y = 16.2 * UNIT, 16.8 * UNIT
local MOVE_X, MOVE_Y = 16 * UNIT, 15.9 * UNIT
local RING_SIZE = 0.42
local MOVE_SIZE = 0.46
local BUSY_SIZE = 0.42
local RIPPLE_LIFE = 0.45
local FADE_TIME = 0.12

local materials
local materialsOk = false

local function LoadMaterials()
	local function Load(name)
		return Material("framework/cursor/" .. name .. ".png", "smooth mips")
	end

	materials = {
		arrow = Load("arrow"),
		accent = Load("arrow_accent"),
		shadow = Load("shadow"),
		ring = Load("hand_ring"),
		ripple = Load("ripple"),
		beam = Load("beam"),
		beamAccent = Load("beam_accent"),
		beamShadow = Load("beam_shadow"),
		move = Load("move"),
		busy = Load("busy_arc")
	}

	materialsOk = true

	for _, material in pairs(materials) do
		if (!material or material:IsError()) then
			materialsOk = false

			break
		end
	end
end

LoadMaterials()

local PANEL_META = FindMetaTable("Panel")

CURSOR.engineSetCursor = CURSOR.engineSetCursor or PANEL_META.SetCursor

local EngineSetCursor = CURSOR.engineSetCursor
local active = false

local function IsBrowser(panel)
	local cached = panel.nwCursorBrowser

	if (cached == nil) then
		local class = panel.GetClassName and panel:GetClassName() or ""
		local derma = panel.ClassName or ""

		cached = (string.find(class, "HTML", 1, true) != nil or
			string.find(class, "Awesomium", 1, true) != nil or derma == "DHTML")
		panel.nwCursorBrowser = cached
	end

	return cached
end

local function IsTextEntry(panel)
	local class = panel.GetClassName and panel:GetClassName() or ""

	return class == "TextEntry" or panel.ClassName == "DTextEntry"
end

local function DefaultCursor(panel)
	return panel.nwCursorKind or (IsTextEntry(panel) and "beam" or "arrow")
end

function PANEL_META:SetCursor(kind)
	self.nwCursorKind = kind

	if (active and !IsBrowser(self)) then
		EngineSetCursor(self, "blank")
	else
		EngineSetCursor(self, kind)
	end
end

CURSOR.vguiCreate = CURSOR.vguiCreate or vgui.Create

local VguiCreate = CURSOR.vguiCreate

function vgui.Create(...)
	local panel = VguiCreate(...)

	if (active and IsValid(panel) and panel.nwCursorKind == nil and !IsBrowser(panel)) then
		EngineSetCursor(panel, "blank")
	end

	return panel
end

local function ApplyOne(panel, bHide)
	if (IsBrowser(panel)) then
		return
	end

	EngineSetCursor(panel, bHide and "blank" or DefaultCursor(panel))
end

local function ApplyTree(panel, bHide, depth)
	if (!IsValid(panel) or depth > 64) then
		return
	end

	ApplyOne(panel, bHide)

	for _, child in ipairs(panel:GetChildren() or {}) do
		ApplyTree(child, bHide, depth + 1)
	end
end

local function ApplyAll(bHide)
	ApplyTree(vgui.GetWorldPanel(), bHide, 0)

	local hud = GetHUDPanel and GetHUDPanel()

	if (IsValid(hud)) then
		ApplyTree(hud, bHide, 0)
	end
end

local function ShouldBeActive()
	if (!materialsOk or !enabledConVar:GetBool()) then
		return false
	end

	if (gui.IsGameUIVisible() or gui.IsConsoleVisible()) then
		return false
	end

	return true
end

local function ResolveKind(hovered)
	local panel = hovered
	local depth = 0

	while (IsValid(panel) and depth < 32) do
		local kind = panel.nwCursorKind

		if (kind != nil) then
			return KIND_MAP[kind] or "arrow"
		end

		if (depth == 0 and IsTextEntry(panel)) then
			return "beam"
		end

		panel = panel:GetParent()
		depth = depth + 1
	end

	return "arrow"
end

local lastDrag
local dragMoved = false

local function CurrentKind()

	local drag = NETWORK.gui and NETWORK.gui.drag

	if (drag != nil) then

		if (drag != lastDrag) then
			lastDrag = drag
			dragMoved = false
		end

		if (!dragMoved) then
			local startX, startY = drag.startX, drag.startY

			dragMoved = !startX or !startY or (math.abs(gui.MouseX() - startX) +
				math.abs(gui.MouseY() - startY) >= NETWORK.util.Scale(8))
		end

		if (dragMoved) then
			return "move"
		end
	else
		lastDrag = nil
	end

	if (dragndrop and dragndrop.IsDragging and dragndrop.IsDragging()) then
		return "move"
	end

	local hovered = vgui.GetHoveredPanel()

	if (!IsValid(hovered)) then
		return "arrow"
	end

	if (IsBrowser(hovered)) then
		return "system"
	end

	return ResolveKind(hovered)
end

local weights = {arrow = 0, hand = 0, beam = 0, move = 0, busy = 0}
local appear = 0
local press = 0
local wasDown = false
local ringAngle = 0
local busyAngle = 0
local ripples = {}
local rippleNext = 1
local kind = "arrow"
local wasVisible = false

for i = 1, 4 do
	ripples[i] = {start = -1, x = 0, y = 0}
end

hook.Add("Think", "nwCursor", function()
	local want = ShouldBeActive()

	if (want != active) then
		active = want
		ApplyAll(want)
	end

	if (!active or !vgui.CursorVisible()) then
		return
	end

	local world = vgui.GetWorldPanel()

	if (IsValid(world)) then
		EngineSetCursor(world, "blank")
	end

	local hovered = vgui.GetHoveredPanel()

	if (IsValid(hovered) and !IsBrowser(hovered)) then
		EngineSetCursor(hovered, "blank")
	end
end)

local function EaseOut(x)
	x = 1 - x

	return 1 - x * x * x
end

local function DrawTex(material, x, y, w, h, rotation)
	surface.SetMaterial(material)

	surface.DrawTexturedRectRotated(x + w * 0.5, y + h * 0.5, w, h, rotation or 0)
end

local function DrawCentered(material, cx, cy, size, rotation)
	surface.SetMaterial(material)
	surface.DrawTexturedRectRotated(cx, cy, size, size, rotation or 0)
end

local function ResetState(newKind)
	for _, id in ipairs(KINDS) do
		weights[id] = (id == newKind) and 1 or 0
	end

	appear = 0
	press = 0
	wasDown = input.IsMouseDown(MOUSE_LEFT)

	for i = 1, #ripples do
		ripples[i].start = -1
	end
end

local function Update(dt, mouseX, mouseY, now)
	kind = CurrentKind()

	if (!wasVisible) then
		ResetState(kind)
		wasVisible = true
	end

	appear = math.Approach(appear, 1, dt / 0.08)

	local step = dt / FADE_TIME

	for _, id in ipairs(KINDS) do
		weights[id] = math.Approach(weights[id], (id == kind) and 1 or 0, step)
	end

	local down = input.IsMouseDown(MOUSE_LEFT)

	press = math.Approach(press, down and 1 or 0, dt / (down and 0.06 or 0.14))

	if (down and !wasDown and kind != "hidden" and rippleConVar:GetBool()) then
		local ripple = ripples[rippleNext]

		ripple.start = now
		ripple.x = mouseX
		ripple.y = mouseY
		rippleNext = rippleNext % #ripples + 1
	end

	wasDown = down

	ringAngle = (ringAngle + dt * 50) % 360
	busyAngle = (busyAngle - dt * 320) % 360
end

local function DrawRipples(now, size, accent, alpha)
	surface.SetMaterial(materials.ripple)

	for i = 1, #ripples do
		local ripple = ripples[i]

		if (ripple.start >= 0) then
			local t = (now - ripple.start) / RIPPLE_LIFE

			if (t >= 1 or t < 0) then
				ripple.start = -1
			else
				local radius = size * (0.25 + 1.15 * EaseOut(t))
				local fade = (1 - t) ^ 1.6

				surface.SetDrawColor(accent.r, accent.g, accent.b, 210 * fade * alpha)
				surface.DrawTexturedRectRotated(ripple.x, ripple.y, radius, radius, 0)
			end
		end
	end
end

local function DrawArrowFamily(mouseX, mouseY, D, alpha, now, accent)
	local wHand, wMove, wBusy = weights.hand, weights.move, weights.busy
	local pressEase = EaseOut(press)
	local scale = (1 - 0.1 * pressEase) * (1 - 0.1 * (wMove + wBusy))
	local size = D * scale
	local left = mouseX - ARROW_HOT_X * size
	local top = mouseY - ARROW_HOT_Y * size

	if (math.abs(scale - 1) < 0.001) then
		left = math.floor(left + 0.5)
		top = math.floor(top + 0.5)
	end

	local shadowStep = D / 30

	surface.SetDrawColor(255, 255, 255, 130 * alpha)
	DrawTex(materials.shadow, left + 2 * shadowStep, top + 3 * shadowStep, size, size)

	surface.SetDrawColor(255, 255, 255, 255 * alpha)
	DrawTex(materials.arrow, left, top, size, size)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * alpha)
	DrawTex(materials.accent, left, top, size, size)

	if (wHand > 0.001) then
		local grow = EaseOut(wHand)
		local pulse = 1 + 0.05 * math.sin(now * 4.2)
		local ringSize = D * RING_SIZE * (0.35 + 0.65 * grow) * pulse * (1 - 0.12 * pressEase)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * alpha * wHand)
		DrawCentered(materials.ring, mouseX + BADGE_X * D, mouseY + BADGE_Y * D, ringSize, ringAngle)
	end

	if (wMove > 0.001) then
		local grow = EaseOut(wMove)
		local breathe = 1 + 0.04 * math.sin(now * 3)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * alpha * wMove)
		DrawCentered(materials.move, mouseX + MOVE_X * D, mouseY + MOVE_Y * D,
			D * MOVE_SIZE * (0.4 + 0.6 * grow) * breathe)
	end

	if (wBusy > 0.001) then
		local grow = EaseOut(wBusy)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * alpha * wBusy)
		DrawCentered(materials.busy, mouseX + BADGE_X * D, mouseY + BADGE_Y * D,
			D * BUSY_SIZE * (0.4 + 0.6 * grow), busyAngle)
	end
end

local function DrawBeam(mouseX, mouseY, D, alpha, now, accent)
	local grow = EaseOut(weights.beam)
	local size = D * (0.85 + 0.15 * grow) * (1 - 0.06 * EaseOut(press))
	local left = mouseX - size * 0.5
	local top = mouseY - size * 0.5

	if (math.abs(size - D) < 0.01) then
		left = math.floor(left + 0.5)
		top = math.floor(top + 0.5)
	end

	surface.SetDrawColor(255, 255, 255, 110 * alpha)
	DrawTex(materials.beamShadow, left + D / 24, top + D / 20, size, size)

	surface.SetDrawColor(255, 255, 255, 255 * alpha)
	DrawTex(materials.beam, left, top, size, size)

	local blink = 0.7 + 0.3 * (0.5 + 0.5 * math.cos(now * 3.4))

	surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * alpha * blink)
	DrawTex(materials.beamAccent, left, top, size, size)
end

hook.Add("DrawOverlay", "nwCursor", function()
	if (!active or !vgui.CursorVisible()) then
		wasVisible = false

		return
	end

	local mouseX, mouseY = gui.MouseX(), gui.MouseY()
	local now = RealTime()
	local dt = math.min(RealFrameTime(), 0.1)

	Update(dt, mouseX, mouseY, now)

	if (kind == "system") then
		return
	end

	local size = math.Clamp(sizeConVar:GetInt(), 16, 40)
	local D = math.Round(size * 1.25 * 0.5) * 2
	local accent = NETWORK.theme and NETWORK.theme.combine or color_white

	DrawRipples(now, D, accent, appear)

	local arrowAlpha = (weights.arrow + weights.hand + weights.move + weights.busy) * appear

	if (arrowAlpha > 0.001) then
		DrawArrowFamily(mouseX, mouseY, D, math.min(arrowAlpha, 1), now, accent)
	end

	if (weights.beam > 0.001) then
		DrawBeam(mouseX, mouseY, D, weights.beam * appear, now, accent)
	end
end)

concommand.Add("network_cursor_reset", function()
	LoadMaterials()
	active = ShouldBeActive()
	ApplyAll(active)
end)
