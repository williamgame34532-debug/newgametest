local VORT = NETWORK.vort

local PANEL = {}

local function SendAura(id)
	net.Start("nwVortAura")
		net.WriteString(id)
	net.SendToServer()
end

local function SendCast(id)
	net.Start("nwVortCast")
		net.WriteString(id)
	net.SendToServer()
end

function PANEL:BuildItems()
	local client = LocalPlayer()
	local items = {}

	if (!VORT.IsVort(client)) then
		return items
	end

	local bFree = VORT.IsFree(client)
	local current = VORT.GetAura(client)

	for _, data in ipairs(VORT.auras) do
		local bLocked = data.id != "none" and !bFree

		items[#items + 1] = {
			label = L(data.name),
			hint = bLocked and L("vortCollared") or L(data.hint),
			icon = data.icon,
			bActive = current == data.id,
			bLocked = bLocked,
			callback = !bLocked and function()
				SendAura(data.id)
			end or nil
		}
	end

	for _, id in ipairs(VORT.castOrder) do
		local cast = VORT.casts[id]
		local bOk, reason = VORT.CanCast(client, id)
		local hint = L(cast.hint)

		if (id == "pray" and VORT.IsPraying(client)) then
			bOk, hint = true, L("vortCastPrayStop")
		elseif (!bOk) then
			hint = reason == "vortCooldown" and
				L("vortCooldown", math.ceil(VORT.GetCooldown(client, id))) or
				L(reason)
		elseif (VORT.GetCost(client, id) > 0) then
			hint = hint .. "  ·  " .. L("vortCost", VORT.GetCost(client, id))
		end

		items[#items + 1] = {
			label = L(cast.name),
			hint = hint,
			icon = cast.icon,
			bActive = id == "pray" and VORT.IsPraying(client) or nil,
			bLocked = !bOk,
			callback = bOk and function()
				SendCast(id)
			end or nil
		}
	end

	for index, entry in ipairs(VORT.voiceLines or {}) do
		items[#items + 1] = {
			label = L(entry.name),
			hint = L("vortVoiceHint"),
			icon = "icon16/sound_low.png",
			callback = function()
				net.Start("nwVortVoice")
					net.WriteUInt(index, 4)
				net.SendToServer()
			end
		}
	end

	return items
end

function PANEL:Init()
	if (IsValid(NETWORK.gui.vortWheel)) then
		NETWORK.gui.vortWheel:Remove()
	end

	NETWORK.gui.vortWheel = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()

	self.items = self:BuildItems()
	self.open = 0
	self.hovered = nil
	self.scrollStart = RealTime()
	self.centerX = ScrW() * 0.5
	self.centerY = ScrH() * 0.5

	local Sc = NETWORK.util.Scale

	self.outer = Sc(200)
	self.inner = Sc(96)

	gui.EnableScreenClicker(true)

	input.SetCursorPos(self.centerX, self.centerY)
end

function PANEL:OnRemove()
	gui.EnableScreenClicker(false)

	if (NETWORK.gui.vortWheel == self) then
		NETWORK.gui.vortWheel = nil
	end
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true
end

function PANEL:Think()
	self.open = NETWORK.util.Approach(self.open, self.bClosing and 0 or 1, 8)

	if (self.bClosing and self.open < 0.02) then
		return self:Remove()
	end

	local x, y = gui.MousePos()
	local dx, dy = x - self.centerX, y - self.centerY
	local distance = math.sqrt(dx * dx + dy * dy)
	local hovered

	if (distance > NETWORK.util.Scale(34) and #self.items > 0) then
		local angle = math.deg(math.atan2(dy, dx)) + 90

		if (angle < 0) then
			angle = angle + 360
		end

		local step = 360 / #self.items

		hovered = math.floor((angle + step * 0.5) / step) % #self.items + 1
	end

	if (hovered != self.hovered) then
		self.hovered = hovered
		self.scrollStart = RealTime()

		if (hovered) then
			NETWORK.sound.Hover()
		end
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_RIGHT) then
		return self:Close()
	end

	local item = self.items[self.hovered or 0]

	if (item and item.callback) then
		item.callback()

		NETWORK.sound.Click()
	end

	self:Close()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

local GREEN = Color(126, 224, 140)
local GREEN_DIM = Color(74, 132, 84)

local function Arc(x, y, inner, outer, start, length, color, segments)
	local points = {}

	segments = math.max(segments or math.ceil(length / 3), 2)

	for index = 0, segments do
		local angle = math.rad(start + (length / segments) * index - 90)

		points[#points + 1] = {
			x = x + math.cos(angle) * outer,
			y = y + math.sin(angle) * outer
		}
	end

	for index = segments, 0, -1 do
		local angle = math.rad(start + (length / segments) * index - 90)

		points[#points + 1] = {
			x = x + math.cos(angle) * inner,
			y = y + math.sin(angle) * inner
		}
	end

	draw.NoTexture()
	surface.SetDrawColor(color)
	surface.DrawPoly(points)
end

function PANEL:PaintScroll(item, angle, alpha)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util

	local since = RealTime() - (self.scrollStart or 0)
	local unfold = math.Clamp(since / 0.25, 0, 1)
	local eased = util.EaseOutBack and util.EaseOutBack(unfold) or
		util.EaseOut(unfold)

	local width = Sc(250)
	local full = Sc(132)
	local height = full * eased

	local distance = self.outer + width * 0.42 + Sc(24)
	local anchorX = math.Clamp(self.centerX + math.cos(angle) * distance,
		width * 0.5 + Sc(12), ScrW() - width * 0.5 - Sc(12))
	local anchorY = math.Clamp(self.centerY + math.sin(angle) * distance,
		full * 0.5 + Sc(24), ScrH() - full * 0.5 - Sc(24))

	local left = anchorX - width * 0.5
	local top = anchorY - height * 0.5

	if (eased > 0.2) then
		surface.SetDrawColor(150, 112, 60, 120 * alpha * eased)
		surface.DrawLine(self.centerX + math.cos(angle) * (self.outer + Sc(4)),
			self.centerY + math.sin(angle) * (self.outer + Sc(4)),
			anchorX - math.cos(angle) * (width * 0.42),
			anchorY - math.sin(angle) * (full * 0.42))
	end

	surface.SetDrawColor(30, 27, 22, 244 * alpha)
	surface.DrawRect(left, top, width, height)

	surface.SetDrawColor(16, 14, 11, 220 * alpha)
	surface.DrawRect(left, top, width, math.max(Sc(2), 2))
	surface.DrawRect(left, top + height - math.max(Sc(2), 2), width,
		math.max(Sc(2), 2))

	local rollHeight = math.max(Sc(9), 6)

	local function Roll(rollY)
		surface.SetDrawColor(74, 58, 38, 250 * alpha)
		surface.DrawRect(left - Sc(6), rollY - rollHeight * 0.5,
			width + Sc(12), rollHeight)

		surface.SetDrawColor(126, 100, 64, 250 * alpha)
		surface.DrawRect(left - Sc(6), rollY - rollHeight * 0.5 + 1,
			width + Sc(12), math.max(rollHeight * 0.35, 1))

		surface.SetDrawColor(48, 38, 25, 250 * alpha)
		surface.DrawRect(left - Sc(6), rollY - rollHeight * 0.5,
			math.max(Sc(4), 3), rollHeight)
		surface.DrawRect(left + width + Sc(6) - math.max(Sc(4), 3),
			rollY - rollHeight * 0.5, math.max(Sc(4), 3), rollHeight)
	end

	Roll(top)
	Roll(top + height)

	local textAlpha = math.Clamp((unfold - 0.45) / 0.55, 0, 1) * alpha

	if (textAlpha <= 0.01) then
		return
	end

	local label = util.Upper(item.label or "")

	surface.SetFont("nwField")

	local limit = width - Sc(26)
	local font = surface.GetTextSize(label) > limit and "nwHudSmall" or "nwField"

	draw.SimpleText(label, font, anchorX, top + Sc(20),
		Color(232, 214, 176, 252 * textAlpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	surface.SetDrawColor(150, 112, 60, 200 * textAlpha)
	surface.DrawRect(anchorX - width * 0.22, top + Sc(31), width * 0.44,
		math.max(Sc(1), 1))

	if (!item.hint or item.hint == "") then
		return
	end

	surface.SetFont("nwHudSmall")

	local words = string.Explode(" ", item.hint)
	local line, lines = "", {}

	for _, word in ipairs(words) do
		local try = line == "" and word or (line .. " " .. word)

		if (surface.GetTextSize(try) > limit and line != "") then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end

	if (line != "") then
		lines[#lines + 1] = line
	end

	for index = 1, math.min(#lines, 4) do
		draw.SimpleText(lines[index], "nwHudSmall", anchorX,
			top + Sc(46) + (index - 1) * Sc(13),
			Color(196, 180, 150, 240 * textAlpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local client = LocalPlayer()
	local alpha = util.EaseOut(self.open)

	if (alpha < 0.01) then
		return
	end

	util.DrawBlur(self, 4 * alpha, 0.25)

	surface.SetDrawColor(3, 4, 6, 140 * alpha)
	surface.DrawRect(0, 0, width, height)

	util.DrawVignette(0, 0, width, height, math.Round(math.min(width, height) * 0.5),
		140 * alpha)

	local x, y = self.centerX, self.centerY
	local outer = self.outer * Lerp(alpha, 0.78, 1)
	local inner = self.inner * Lerp(alpha, 0.9, 1)
	local count = #self.items

	if (count == 0) then
		return
	end

	local step = 360 / count

	for index, item in ipairs(self.items) do
		local bHovered = self.hovered == index
		local start = -step * 0.5 + step * (index - 1)
		local lit = bHovered and 1 or (item.bActive and 0.5 or 0)

		Arc(x, y, inner, outer, start, step - 2.4, Color(
			Lerp(lit, 9, 30),
			Lerp(lit, 17, 66),
			Lerp(lit, 13, 36),
			(item.bLocked and 150 or 232) * alpha
		))

		if (bHovered or item.bActive) then

			local pulse = 0.72 + math.sin(RealTime() * 4) * 0.28

			Arc(x, y, outer - math.max(Sc(3), 2), outer, start, step - 2.4,
				ColorAlpha(bHovered and GREEN or GREEN_DIM,
				(bHovered and 240 or 150) * alpha * pulse))
		end

		local angle = math.rad(start + step * 0.5 - 90)
		local iconX = x + math.cos(angle) * (inner + (outer - inner) * 0.52)
		local iconY = y + math.sin(angle) * (inner + (outer - inner) * 0.52)

		local icon = item.icon and NETWORK.nameplate and
			NETWORK.nameplate.GetIcon(item.icon)

		if (icon) then
			local size = Sc(16)

			surface.SetDrawColor(255, 255, 255,
				(item.bLocked and 120 or 240) * alpha)
			surface.SetMaterial(icon)
			surface.DrawTexturedRect(iconX - size * 0.5, iconY - size * 0.6,
				size, size)
		end

		draw.SimpleText(item.label, "nwHudSmall", iconX, iconY + Sc(14),
			ColorAlpha(item.bLocked and NETWORK.theme.textFaint or
			(bHovered and GREEN or NETWORK.theme.text), 245 * alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local energy = VORT.IsHigh(client) and 1 or
		math.Clamp(VORT.GetEnergy(client) / VORT.energyMax, 0, 1)

	util.DrawCircle(x, y, inner - Sc(12), Color(8, 9, 11, 235 * alpha))
	util.DrawArc(x, y, inner - Sc(12), math.max(Sc(1), 1), 1, Color(255, 255, 255, 30 * alpha), 96)

	Arc(x, y, inner - Sc(10), inner - Sc(5), 0, 360, Color(10, 16, 12,
		200 * alpha), 48)

	if (energy > 0.01) then
		Arc(x, y, inner - Sc(10), inner - Sc(5), 0, 360 * energy,
			ColorAlpha(GREEN, 235 * alpha), 48)
	end

	draw.SimpleText(VORT.IsHigh(client) and "∞" or
		tostring(math.floor(VORT.GetEnergy(client))), "nwInvTitle", x, y,
		ColorAlpha(GREEN, 250 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	draw.SimpleText(L("vortEnergy"), "nwHudSmall", x, y + Sc(20),
		ColorAlpha(GREEN_DIM, 220 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)

	local item = self.items[self.hovered or 0]

	if (item) then
		local start = -step * 0.5 + step * (self.hovered - 1)

		self:PaintScroll(item, math.rad(start + step * 0.5 - 90), alpha)
	end

	draw.SimpleText(util.Upper(L("vortMenu")), "nwInvKey", x, y + outer + Sc(44),
		Color(130, 168, 136, 200 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("nwVortWheel", PANEL, "EditablePanel")

function NETWORK.gui.OpenVortWheel()
	local client = LocalPlayer()

	if (!VORT.IsVort(client)) then
		return NETWORK.gui.Notify(L("vortNotVort"), NETWORK.theme.warning)
	end

	if (!client:Alive() or IsValid(NETWORK.gui.vortWheel)) then
		return
	end

	return vgui.Create("nwVortWheel")
end

concommand.Add("nw_vortwheel", function()
	NETWORK.gui.OpenVortWheel()
end)
