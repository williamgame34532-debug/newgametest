local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.repair = self

	self.alpha = 0
	self.round = 1
	self.hits = 0
	self.marker = 0
	self.direction = 1
	self.bDone = false
	self.flash = 0
	self.flashColour = NETWORK.theme.accent

	self:SetSize(math.min(Sc(560), ScrW() - Sc(80)), Sc(300))
	self:Center()
	self:MakePopup()

	self:NextRound()
end

function PANEL:OnRemove()
	if (NETWORK.gui.repair == self) then
		NETWORK.gui.repair = nil
	end

	if (!self.bDone) then
		NETWORK.scanner.SendResult(false)
	end
end

function PANEL:NextRound()
	local width = math.max(NETWORK.scanner.window -
		(self.round - 1) * NETWORK.scanner.windowStep, 0.08)

	self.window = {
		size = width,
		start = math.Rand(0.12, 0.88 - width)
	}

	self.marker = 0
	self.direction = 1
	self.speed = NETWORK.scanner.speed + (self.round - 1) * 0.35
end

function PANEL:Attempt()
	if (self.bDone) then
		return
	end

	local bHit = self.marker >= self.window.start and
		self.marker <= self.window.start + self.window.size

	self.flash = CurTime() + 0.4
	self.flashColour = bHit and NETWORK.theme.positive or NETWORK.theme.danger

	surface.PlaySound(bHit and "buttons/button24.wav" or "buttons/button10.wav")

	if (!bHit) then
		return self:Finish(false)
	end

	self.hits = self.hits + 1

	if (self.hits >= NETWORK.scanner.rounds) then
		return self:Finish(true)
	end

	self.round = self.round + 1

	self:NextRound()
end

function PANEL:Finish(bSuccess)
	if (self.bDone) then
		return
	end

	self.bDone = true
	self.bSuccess = bSuccess

	NETWORK.scanner.SendResult(bSuccess)

	timer.Simple(1.2, function()
		if (IsValid(self)) then
			self:Remove()
		end
	end)
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_SPACE) then
		self:Attempt()
	elseif (key == KEY_ESCAPE and !self.bDone) then
		self:Finish(false)
	end
end

function PANEL:OnMousePressed(code)
	if (code == MOUSE_LEFT) then
		self:Attempt()
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 12)

	if (self.bDone) then
		return
	end

	self.marker = self.marker + FrameTime() * self.speed * self.direction

	if (self.marker >= 1) then
		self.marker = 1
		self.direction = -1
	elseif (self.marker <= 0) then
		self.marker = 0
		self.direction = 1
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	local radius = math.max(Sc(10), 6)

	util.DrawBlurRounded(self, 0, 0, width, height, radius, 4 * alpha)

	draw.RoundedBox(radius, 0, 0, width, height, Color(8, 9, 10, 236 * alpha))

	util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
		Color(255, 255, 255, 26 * alpha))

	draw.SimpleText(util.Upper(L("repairTitle")), "nwInvKey", math.Round(width * 0.5), Sc(40),
		ColorAlpha(theme.textFaint, 252 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local subtitle = L("repairHint")

	if (self.bDone) then
		subtitle = L(self.bSuccess and "repairSuccess" or "repairFailure")
	end

	draw.SimpleText(subtitle, "nwHudSmall", math.Round(width * 0.5), Sc(66),
		ColorAlpha(self.bDone and (self.bSuccess and theme.positive or theme.danger) or
		theme.textDim, 245 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local barX = Sc(40)
	local barY = Sc(140)
	local barWidth = width - Sc(80)
	local barHeight = Sc(46)

	local trackRadius = math.max(Sc(6), 4)

	draw.RoundedBox(trackRadius, barX, barY, barWidth, barHeight, Color(12, 13, 15, 240 * alpha))

	surface.SetDrawColor(255, 255, 255, 14 * alpha)

	for step = 1, 19 do
		surface.DrawRect(barX + math.Round(barWidth * (step / 20)), barY + Sc(8), 1,
			barHeight - Sc(16))
	end

	local windowX = barX + math.Round(barWidth * self.window.start)
	local windowWidth = math.Round(barWidth * self.window.size)

	draw.RoundedBox(math.max(Sc(4), 3), windowX, barY, windowWidth, barHeight,
		ColorAlpha(theme.combine, 50 * alpha))

	util.DrawRoundedBorder(windowX, barY, windowWidth, barHeight, math.max(Sc(4), 3),
		math.max(Sc(1), 1), ColorAlpha(theme.combine, 220 * alpha))

	local markerX = barX + math.Round(barWidth * self.marker)

	surface.SetDrawColor(theme.text.r, theme.text.g, theme.text.b, 250 * alpha)
	surface.DrawRect(markerX - math.max(Sc(2), 1), barY - Sc(8),
		math.max(Sc(4), 3), barHeight + Sc(16))

	if (self.flash > CurTime()) then
		local pulse = (self.flash - CurTime()) / 0.4
		local colour = self.flashColour

		surface.SetDrawColor(colour.r, colour.g, colour.b, 90 * pulse * alpha)
		surface.DrawRect(barX, barY, barWidth, barHeight)
	end

	util.DrawRoundedBorder(barX, barY, barWidth, barHeight, trackRadius, math.max(Sc(1), 1),
		Color(255, 255, 255, 30 * alpha))

	local pipY = barY + barHeight + Sc(34)
	local pipSize = Sc(14)
	local total = NETWORK.scanner.rounds
	local pipX = math.Round(width * 0.5 - (total * (pipSize + Sc(10)) - Sc(10)) * 0.5)

	for index = 1, total do
		local x = pipX + (index - 1) * (pipSize + Sc(10))
		local bDone = index <= self.hits

		draw.RoundedBox(math.floor(pipSize * 0.5), x, pipY, pipSize, pipSize,
			bDone and ColorAlpha(theme.combine, 245 * alpha) or Color(255, 255, 255, 30 * alpha))
	end
end

vgui.Register("nwRepairGame", PANEL, "EditablePanel")

function NETWORK.gui.OpenRepairGame()
	if (IsValid(NETWORK.gui.repair)) then
		return
	end

	return vgui.Create("nwRepairGame")
end
