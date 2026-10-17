-- The G wheel. Hold G (the key can be changed in Бинды): a segmented ring opens in the middle of
-- the screen, the cursor in its centre. Point at a segment: it lights up and the centre shows
-- what it is.
--   Голос     → Шёпот / Обычный / Крик (how far you are heard in voice chat)
--   Анимации  → the poses (sh_acts.lua): RMB on a pose changes its variant, LMB (or letting G
--               go) starts placing it
--   Встать    (only while in a pose)
-- A click opens a group; a click in the centre goes back. Letting G go takes what is pointed at.
-- Placing a pose: the pose editor (below) - a see-through copy of the character, moved with the
-- mouse on the ground, turned with the knob on its ring, Поставить / Отмена at the bottom.
-- While talking: cl_voice.lua.

NW.wheel = NW.wheel or {}

local W = NW.wheel
local U = NW.ui
local A = NW.acts

local function KEY()
	return NW.keys.Get("wheel") or KEY_G
end

W.choice = W.choice or {}
local MUTED = Color(124, 128, 134)
local ACCENT = Color(232, 196, 72)

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwWheelName", {font = "Montserrat SemiBold", size = math.max(14, math.Round(h * 0.024)),
		weight = 600, extended = true, antialias = true})
	surface.CreateFont("nwWheelSmall", {font = "Exo 2", size = math.max(12, math.Round(h * 0.0155)), weight = 500,
		extended = true, antialias = true})
	surface.CreateFont("nwWheelLabel", {font = "Montserrat Medium", size = math.max(11, math.Round(h * 0.0128)),
		weight = 500, extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwWheelFonts", Fonts)

local function Ease(t)
	return 1 - (1 - t) ^ 3
end

-- ------------------------------------------------------------------ items --
local function SendAct(id)
	net.Start("nwAct")
		net.WriteString(id)
	net.SendToServer()
end

local function Levels()
	local client = LocalPlayer()
	local voice = A.voice[client:GetVoiceMode()] or A.voice[2]

	local root = {
		{name = "Голос", icon = "mic", hint = "Сейчас: " .. voice.name, open = "voice"},
		{name = "Анимации", icon = "acts", hint = "Позы. Любое движение сбрасывает", open = "acts"}
	}

	if (client:GetAct()) then
		root[#root + 1] = {name = "Встать", icon = "back", hint = "Выйти из позы", run = function()
			SendAct("")
		end}
	end

	local voices = {}

	for _, mode in ipairs(A.voice) do
		voices[#voices + 1] = {name = mode.name, icon = mode.icon, hint = "Слышно на " .. mode.range .. " юнитов",
			current = client:GetVoiceMode() == mode.id, run = function()
				net.Start("nwVoice")
					net.WriteUInt(mode.id, 2)
				net.SendToServer()
			end}
	end

	local acts = {}

	for _, act in ipairs(A.list) do
		local count = #A.Available(client, act)
		local choice = math.Clamp(W.choice[act.id] or 1, 1, math.max(count, 1))

		-- poses of one model only (Civil Protection): not shown to the others
		if (act.only and count == 0) then
			continue
		end

		acts[#acts + 1] = {name = act.name, icon = act.icon, disabled = count == 0, act = act,
			hint = count == 0 and "Эта модель не умеет" or (count > 1 and
				("Вариант " .. choice .. " из " .. count .. "  ·  ПКМ — другой") or "ЛКМ — разместить"),
			run = function()
				W.Place(act)
			end}
	end

	return {root = root, voice = voices, acts = acts}
end

-- ------------------------------------------------------------------ drawing --
-- a ring segment as small convex quads
local function Arc(cx, cy, r1, r2, a1, a2, color)
	local steps = math.max(2, math.ceil((a2 - a1) / 4))

	draw.NoTexture()
	surface.SetDrawColor(color)

	for i = 0, steps - 1 do
		local s = math.rad(a1 + (a2 - a1) * i / steps)
		local e = math.rad(a1 + (a2 - a1) * (i + 1) / steps)
		local cs, ss, ce, se = math.cos(s), math.sin(s), math.cos(e), math.sin(e)

		surface.DrawPoly({
			{x = cx + cs * r1, y = cy + ss * r1},
			{x = cx + cs * r2, y = cy + ss * r2},
			{x = cx + ce * r2, y = cy + se * r2},
			{x = cx + ce * r1, y = cy + se * r1}
		})
	end
end

local function Disc(cx, cy, r, color)
	local poly = {}

	for i = 0, 47 do
		local a = math.rad(i / 48 * 360)

		poly[#poly + 1] = {x = cx + math.cos(a) * r, y = cy + math.sin(a) * r}
	end

	draw.NoTexture()
	surface.SetDrawColor(color)
	surface.DrawPoly(poly)
end

-- ------------------------------------------------------------------- wheel --
function W.IsOpen()
	return IsValid(W.frame)
end

local function Hovered(frame, items)
	local sw, sh = ScrW(), ScrH()
	local cx, cy = sw / 2, sh / 2
	local mx, my = input.GetCursorPos()
	local dx, dy = mx - cx, my - cy
	local distance = math.sqrt(dx * dx + dy * dy)

	if (distance < frame.inner * 0.55) then
		return nil, true
	end

	local angle = (math.deg(math.atan2(dy, dx)) + 90 + 360 / #items / 2) % 360
	local index = math.floor(angle / (360 / #items)) + 1

	return index
end

function W.Open()
	-- unconscious: nothing to open (cl_body.lua)
	if (LocalPlayer():GetNW2Bool("nwKnocked", false)) then
		return
	end

	if (W.IsOpen()) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.appear = 0
	frame.level = "root"
	frame.levels = Levels()
	frame.inner = math.Round(sh * 0.085)
	frame.outer = math.Round(sh * 0.205)
	frame.hoverTime = 0

	input.SetCursorPos(sw / 2, sh / 2)

	local function Go(level)
		frame.level = level
		frame.levels = Levels()
		frame.switched = RealTime()
		frame.hover = nil
		frame.hoverTime = RealTime()
		input.SetCursorPos(sw / 2, sh / 2)
		U.Tick()
	end

	frame.Take = function(self)
		local items = self.levels[self.level]
		local item = self.hover and items[self.hover]

		if (item and !item.disabled) then
			if (item.open) then
				Go(item.open)

				return false
			end

			if (item.run) then
				item.run()
				surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
			end
		end

		return true
	end

	frame.OnMousePressed = function(self, code)
		local items = self.levels[self.level]
		local index, center = Hovered(self, items)
		local item = index and items[index]

		-- RMB on a pose: its next variant
		if (code == MOUSE_RIGHT and item and item.act and !item.disabled) then
			local count = #A.Available(LocalPlayer(), item.act)

			W.choice[item.act.id] = (W.choice[item.act.id] or 1) % math.max(count, 1) + 1
			self.levels = Levels()
			U.Tick()

			return
		end

		if (code == MOUSE_RIGHT or (center and code == MOUSE_LEFT)) then
			if (self.level != "root") then
				Go("root")
			end

			return
		end

		if (code == MOUSE_LEFT and self:Take()) then
			W.Close()
		end
	end

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.closing and 0 or 1, FrameTime() / 0.16)

		if (self.closing and self.appear <= 0) then
			self:Remove()

			return
		end

		if (self.closing) then
			return
		end

		local items = self.levels[self.level]
		local index = Hovered(self, items)

		if (index != self.hover) then
			self.hover = index
			self.hoverTime = RealTime()

			if (index) then
				surface.PlaySound("network2/ui/hover.wav")
			end
		end

		-- G let go: take what is pointed at
		if (!input.IsKeyDown(KEY())) then
			self:Take()
			W.Close()
		end
	end

	frame.Paint = function(self, w, h)
		local e = Ease(self.appear)
		local items = self.levels[self.level]
		local cx, cy = w / 2, h / 2
		local inner = self.inner * (0.85 + 0.15 * e)
		local outer = self.outer * (0.85 + 0.15 * e)
		local count = #items
		local span = 360 / count
		local gap = count > 2 and 1.6 or 3

		-- a soft shade around
		Disc(cx, cy, outer + h * 0.03, Color(0, 0, 0, 70 * e))

		for index, item in ipairs(items) do
			local a1 = -90 - span / 2 + (index - 1) * span + gap / 2
			local a2 = a1 + span - gap
			local hovered = self.hover == index and !item.disabled
			local fill = hovered and Color(46, 50, 56, 235 * e) or Color(16, 18, 21, 215 * e)

			Arc(cx, cy, inner, outer, a1, a2, fill)

			-- an edge on the outside: amber on the hovered one, a dot for the current choice
			Arc(cx, cy, outer - 3, outer, a1, a2, hovered and ColorAlpha(ACCENT, 255 * e) or
				Color(255, 255, 255, (item.current and 120 or 22) * e))

			local mid = math.rad((a1 + a2) / 2)
			local r = (inner + outer) / 2
			local ix, iy = cx + math.cos(mid) * r, cy + math.sin(mid) * r
			local is = math.Round(h * (count > 6 and 0.03 or 0.036) * (hovered and 1.12 or 1))
			local color = item.disabled and Color(90, 92, 96) or ((hovered or item.current) and U.color.text or
				U.color.dim)

			U.DrawIcon(item.icon, ix - is / 2, iy - is / 2 - h * 0.008, is, color, e)

			if (count <= 8 or hovered) then
				draw.SimpleText(item.name, "nwWheelLabel", ix, iy + is / 2, ColorAlpha(color, 255 * e),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			end

			if (item.current) then
				draw.RoundedBox(3, ix + is / 2 + 2, iy - is / 2 - h * 0.008, 6, 6, ColorAlpha(ACCENT, 255 * e))
			end
		end

		-- the centre: what is pointed at
		Disc(cx, cy, inner - h * 0.008, Color(10, 12, 14, 235 * e))

		local item = self.hover and items[self.hover]
		local title = item and item.name or (self.level == "root" and "Действия" or
			(self.level == "voice" and "Голос" or "Анимации"))
		local hint = item and item.hint or (self.level == "root" and "Клик — открыть, отпустите клавишу — выбрать" or
			"Клик в центр — назад")

		draw.SimpleText(title, "nwWheelName", cx, cy - h * 0.012, ColorAlpha(U.color.text, 255 * e), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		for i, line in ipairs(NW.inventory.WrapText(hint, "nwWheelSmall", inner * 1.6)) do
			draw.SimpleText(line, "nwWheelSmall", cx, cy + h * 0.012 + (i - 1) * h * 0.019,
				ColorAlpha(MUTED, 255 * e), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

	end

	W.frame = frame
	U.Play("appear")
end

function W.Close()
	if (IsValid(W.frame) and !W.frame.closing) then
		W.frame.closing = true
		W.frame:SetMouseInputEnabled(false)
	end
end

-- --------------------------------------------------------------- placing --
-- The pose editor: the cursor is on the screen and a see-through copy of the character stands
-- in the pose. Click (or drag) on the ground - it moves there; drag the gold knob on the ring
-- around it - it turns; the wheel turns too; the arrows move it a little. The panel at the
-- bottom: the pose and its variant (◀ ▶, RMB), turning by 15°, Поставить / Отмена. Green when
-- the place suits the pose, red with the reason when not. ESC / G cancels.
local GOOD = Color(120, 220, 140)
local BAD = Color(230, 96, 84)
local RING = 30

function W.CancelPlace()
	local P = W.placing

	if (P) then
		if (IsValid(P.ghost)) then
			P.ghost:Remove()
		end

		if (IsValid(P.panel)) then
			P.panel:Remove()
		end

		W.placing = nil
	end
end

function W.SetPlaceSequence()
	local P = W.placing

	if (P and IsValid(P.ghost)) then
		P.ghost:ResetSequence(P.ghost:LookupSequence(P.list[P.index]))
		P.ghost:SetCycle(0)
	end
end

local function Variant(step)
	local P = W.placing

	if (P and #P.list > 1) then
		P.index = (P.index - 1 + step) % #P.list + 1
		W.choice[P.act.id] = P.index
		W.SetPlaceSequence()
		U.Tick()
	end
end

local function Confirm()
	local P = W.placing

	if (!P or !P.ok) then
		surface.PlaySound("network2/ui/char/textline_1.wav")

		return
	end

	net.Start("nwAct")
		net.WriteString(P.act.id)
		net.WriteUInt(P.index, 4)
		net.WriteVector(P.pos)
		net.WriteFloat(P.yaw)
	net.SendToServer()

	surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
	W.CancelPlace()
end

-- where the cursor points in the world
local function CursorTrace(client)
	local mx, my = input.GetCursorPos()
	local origin = EyePos()
	local direction = gui.ScreenToVector(mx, my)

	return util.TraceLine({start = origin, endpos = origin + direction * 600, filter = client,
		mask = MASK_PLAYERSOLID}), origin, direction
end

local function Button(parent, x, y, w, h, label, onClick, accent)
	local button = parent:Add("DButton")

	button:SetPos(x, y)
	button:SetSize(w, h)
	button:SetText("")
	button.Paint = function(self, bw, bh)
		local enabled = !accent or (W.placing and W.placing.ok)
		local fill = accent and enabled and Color(232, 196, 72, self:IsHovered() and 70 or 40) or
			Color(255, 255, 255, self:IsHovered() and 24 or 12)

		draw.RoundedBox(6, 0, 0, bw, bh, fill)
		draw.SimpleText(isfunction(label) and label() or label, "nwWheelSmall", bw / 2, bh / 2,
			enabled and U.color.text or MUTED, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	button.OnCursorEntered = function()
		surface.PlaySound("network2/ui/hover.wav")
	end
	button.DoClick = onClick

	return button
end

local function Editor()
	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)

	-- the panel at the bottom
	local pw, ph = math.Round(sh * 0.62), math.Round(sh * 0.12)
	local bar = frame:Add("EditablePanel")

	bar:SetSize(pw, ph)
	bar:SetPos((sw - pw) / 2, sh - ph - sh * 0.05)
	bar.Paint = function(self, w, h)
		local P = W.placing

		if (!P) then
			return
		end

		U.Blur(0, 0, w, h, 3, 255, self, 8)
		U.Slice(U.Material("network2/ui/inv_tip.png"), 0, 0, w, h, 8)

		local pad = h * 0.14

		draw.SimpleText(P.act.name, "nwWheelName", pad, pad, U.color.text)
		draw.SimpleText(P.ok and "Место подходит" or (P.why or "Сюда нельзя"), "nwWheelSmall", w - pad, pad + h * 0.03,
			P.ok and GOOD or BAD, TEXT_ALIGN_RIGHT)
		draw.SimpleText("ЛКМ по полу — переставить  ·  тяните золотую точку — повернуть  ·  колесо — повернуть  ·  " ..
			"ПКМ — вариант", "nwWheelLabel", pad, h - pad, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
	end

	local bh = math.Round(ph * 0.3)
	local by = math.Round(ph * 0.4)
	local x = math.Round(ph * 0.14)

	Button(bar, x, by, bh, bh, "◀", function() Variant(-1) end)
	Button(bar, x + bh + 4, by, math.Round(bh * 3.2), bh, function()
		local P = W.placing

		return P and ("Вариант " .. P.index .. " / " .. #P.list) or ""
	end, function() Variant(1) end)
	Button(bar, x + bh * 4.2 + 8, by, bh, bh, "▶", function() Variant(1) end)
	Button(bar, x + bh * 5.6 + 8, by, math.Round(bh * 1.6), bh, "⟲ 15°", function()
		W.placing.turn = W.placing.turn - 15
	end)
	Button(bar, x + bh * 7.2 + 12, by, math.Round(bh * 1.6), bh, "⟳ 15°", function()
		W.placing.turn = W.placing.turn + 15
	end)
	Button(bar, pw - x - bh * 6.4 - 6, by, math.Round(bh * 2.6), bh, "Отмена", function()
		W.CancelPlace()
	end)
	Button(bar, pw - x - bh * 3.8, by, math.Round(bh * 3.8), bh, "Поставить", Confirm, true)

	-- the mouse in the world
	frame.OnMousePressed = function(self, code)
		local P = W.placing

		if (!P) then
			return
		end

		if (code == MOUSE_RIGHT) then
			Variant(1)

			return
		end

		if (code != MOUSE_LEFT) then
			return
		end

		-- on the knob: turning, elsewhere: moving
		local knob = (P.pos + Angle(0, P.yaw, 0):Forward() * RING + Vector(0, 0, 2)):ToScreen()
		local mx, my = input.GetCursorPos()

		P.drag = (math.abs(knob.x - mx) + math.abs(knob.y - my) < 22) and "turn" or "move"
		self:MouseCapture(true)
	end
	frame.OnMouseReleased = function(self)
		if (W.placing) then
			W.placing.drag = nil
		end

		self:MouseCapture(false)
	end
	frame.OnMouseWheeled = function(self, delta)
		if (W.placing) then
			W.placing.turn = W.placing.turn + delta * 10
		end
	end

	return frame
end

function W.Place(act)
	W.CancelPlace()

	local client = LocalPlayer()
	local list = A.Available(client, act)

	if (#list == 0) then
		return
	end

	local ghost = ClientsideModel(client:GetModel(), RENDERGROUP_TRANSLUCENT)

	if (!IsValid(ghost)) then
		return
	end

	ghost:SetNoDraw(true)
	ghost:SetSkin(client:GetSkin())
	ghost:SetModelScale(client:GetModelScale() or 1, 0)

	for index = 0, client:GetNumBodyGroups() - 1 do
		ghost:SetBodygroup(index, client:GetBodygroup(index))
	end

	-- start where the player looks
	local eye = client:EyePos()
	local trace = util.TraceLine({start = eye, endpos = eye + client:GetAimVector() * (A.reach + 80),
		filter = client, mask = MASK_PLAYERSOLID})

	W.placing = {act = act, list = list, index = math.Clamp(W.choice[act.id] or 1, 1, #list), turn = 0,
		ghost = ghost, started = RealTime(), nudge = Vector(0, 0, 0), held = {},
		anchor = {Hit = trace.Hit, HitPos = trace.HitPos, HitNormal = trace.HitNormal}}
	W.SetPlaceSequence()
	W.placing.panel = Editor()
end

local function UpdatePlace()
	local P = W.placing
	local client = LocalPlayer()

	if (!P or !IsValid(client) or !client:Alive() or !IsValid(P.ghost)) then
		W.CancelPlace()

		return
	end

	-- dragging: move to the cursor / turn towards it
	if (P.drag == "move") then
		local trace = CursorTrace(client)

		if (trace.Hit) then
			P.anchor = {Hit = true, HitPos = trace.HitPos, HitNormal = trace.HitNormal}
			P.nudge = Vector(0, 0, 0)
		end
	elseif (P.drag == "turn") then
		local _, origin, direction = CursorTrace(client)

		if (math.abs(direction.z) > 0.01) then
			local t = (P.pos.z - origin.z) / direction.z
			local point = origin + direction * t
			local want = (point - P.pos):Angle().y

			P.turn = P.turn + math.AngleDifference(want, P.yaw)
		end
	end

	-- the arrows move the spot a little (relative to the view)
	local yaw = Angle(0, client:EyeAngles().y, 0)

	for key, direction in pairs({[KEY_UP] = yaw:Forward(), [KEY_DOWN] = -yaw:Forward(),
		[KEY_LEFT] = -yaw:Right(), [KEY_RIGHT] = yaw:Right()}) do
		local down = input.IsKeyDown(key)

		if (down and !P.held[key]) then
			P.nudge = P.nudge + direction * 3

			if (P.nudge:Length() > 40) then
				P.nudge = P.nudge:GetNormalized() * 40
			end
		end

		P.held[key] = down
	end

	local anchor = P.anchor
	local aimed = {Hit = anchor.Hit, HitPos = anchor.HitPos + P.nudge, HitNormal = anchor.HitNormal}

	P.pos, P.yaw, P.ok, P.why = A.FindSpot(client, P.act, aimed, P.turn)

	if (!anchor.Hit) then
		P.ok, P.why = false, "Укажите место"
	end

	P.ghost:SetPos(P.pos)
	P.ghost:SetAngles(Angle(0, P.yaw, 0))
	P.ghost:FrameAdvance()
end

hook.Add("Think", "nwWheelPlace", function()
	if (W.placing) then
		UpdatePlace()
	end
end)

hook.Add("PostDrawTranslucentRenderables", "nwWheelPlace", function(bDepth, bSkybox)
	local P = W.placing

	if (!P or bSkybox or !IsValid(P.ghost) or !P.pos) then
		return
	end

	local color = P.ok and GOOD or BAD
	local pulse = 0.35 + math.sin(RealTime() * 4) * 0.08

	render.SetBlend(pulse)
	render.SetColorModulation(color.r / 255, color.g / 255, color.b / 255)
	render.SuppressEngineLighting(true)
		P.ghost:DrawModel()
	render.SuppressEngineLighting(false)
	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)

	-- the ring with the knob that turns it
	local center = P.pos + Vector(0, 0, 2)
	local previous

	for i = 0, 48 do
		local a = math.rad(i / 48 * 360)
		local point = center + Vector(math.cos(a), math.sin(a), 0) * RING

		if (previous) then
			render.DrawLine(previous, point, ColorAlpha(color, 200), false)
		end

		previous = point
	end

	local knob = center + Angle(0, P.yaw, 0):Forward() * RING

	render.DrawLine(center, knob, Color(232, 196, 72, 200), false)
	render.SetColorMaterial()
	render.DrawSphere(knob, P.drag == "turn" and 3.2 or 2.4, 12, 12, Color(232, 196, 72, 255))
end)

-- the arrows nudge the spot: they do not walk meanwhile
hook.Add("CreateMove", "nwWheelPlace", function(command)
	if (W.placing) then
		command:ClearMovement()
		command:RemoveKey(IN_ATTACK)
		command:RemoveKey(IN_ATTACK2)
	end
end)

-- hold G (not while typing or in a menu)
hook.Add("Think", "nwWheel", function()
	local down = input.IsKeyDown(KEY())

	-- G during a placement cancels it
	if (down and !W.held and W.placing) then
		W.CancelPlace()
		W.held = down

		return
	end

	if (down and !W.held and !W.IsOpen()) then
		local client = LocalPlayer()
		local busy = vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or (NW.chat and NW.chat.open) or
			(NW.menu and NW.menu.active) or (NW.inventory and NW.inventory.IsOpen and NW.inventory.IsOpen()) or
			(NW.pause and NW.pause.IsOpen and NW.pause.IsOpen()) or vgui.CursorVisible()

		if (!busy and IsValid(client) and client:Alive() and client:GetCharacterID() != 0 and
			!client:GetNW2Bool("nwKnocked", false)) then
			W.Open()
		end
	end

	W.held = down
end)
