local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.progress = self

	self.slide = 0
	self.bClosing = false
	self.title = ""
	self.duration = 1
	self.startTime = CurTime()
	self.born = RealTime()

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	self:SetDrawOnTop(true)
end

function PANEL:OnRemove()
	if (NETWORK.gui.progress == self) then
		NETWORK.gui.progress = nil
	end
end

function PANEL:Setup(title, duration)
	self.title = title or ""
	self.duration = math.max(duration or 1, 0.1)
	self.startTime = CurTime()
end

function PANEL:GetFraction()
	return math.Clamp((CurTime() - self.startTime) / self.duration, 0, 1)
end

function PANEL:Close()
	if (!self.bClosing) then
		self.bClosing = true
		self.closeTime = RealTime()
	end
end

local function Elastic(t)
	if (t <= 0) then
		return 0
	end

	if (t >= 1) then
		return 1
	end

	return 1 + math.pow(2, -9 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) * 0.5
end

function PANEL:Think()
	local util = NETWORK.util

	if (self.bClosing) then
		self.slide = util.EaseInOut(1 - math.Clamp((RealTime() - self.closeTime) / 0.3, 0, 1))
	else
		self.slide = Elastic(math.Clamp((RealTime() - self.born) / 0.7, 0, 1))
	end

	if (self:GetFraction() >= 1 and !self.bClosing) then
		self:Close()
	end

	if (self.bClosing and self.slide < 0.01) then
		self:Remove()
	end
end

local positionVar = CreateClientConVar("network_progress_pos", "top", true, false,
	"Положение полосы действий: top или bottom")

local styleVar = CreateClientConVar("network_progress_style", "bar", true, false,
	"Вид полосы действий: glass или bar")

function PANEL:GetBarRect(width, height)
	local Sc = NETWORK.util.Scale

	local bGlass = styleVar:GetString() == "glass"
	local barWidth = bGlass and math.Clamp(math.Round(width * 0.26), Sc(300), Sc(400)) or
		math.Clamp(math.Round(width * 0.34), Sc(340), Sc(460))

	local barHeight = bGlass and Sc(30) or Sc(24)
	local x = math.Round((width - barWidth) * 0.5)

	if (positionVar:GetString() == "bottom") then
		local restY = math.Round((height or ScrH()) * 0.64)

		return x, restY + math.Round((1 - self.slide) * Sc(16)), barWidth, barHeight
	end

	local restY = Sc(26)
	local y = math.Round(-barHeight - Sc(8) + (restY + barHeight + Sc(8)) * self.slide)

	return x, y, barWidth, barHeight
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local fraction = self:GetFraction()
	local eased = util.EaseInOut(fraction)
	local x, y, barWidth, barHeight = self:GetBarRect(width, height)
	local accent = theme.combine
	local line = math.max(Sc(1), 1)
	local alpha = math.Clamp(self.slide * 1.5, 0, 1)

	if (y + barHeight < 0 or alpha <= 0.01) then
		return
	end

	local left = math.max(self.duration - (CurTime() - self.startTime), 0)
	local fill = math.Round(barWidth * eased)

	if (styleVar:GetString() == "glass") then

		util.DrawBlurRounded(self, x, y, barWidth, barHeight, 2, 5 * alpha)

		surface.SetDrawColor(10, 11, 13, 225 * alpha)
		surface.DrawRect(x, y, barWidth, barHeight)

		surface.SetDrawColor(255, 255, 255, 26 * alpha)
		surface.DrawOutlinedRect(x, y, barWidth, barHeight, line)

		surface.SetDrawColor(accent.r, accent.g, accent.b, 235 * alpha)
		surface.DrawRect(x, y, math.max(Sc(3), 2), barHeight)

		local title = util.TruncateWidth(util.Upper(self.title or ""), "nwHudSmall",
			barWidth - Sc(110))

		draw.SimpleText(title, "nwHudSmall", x + Sc(14), y + math.Round(barHeight * 0.5) - Sc(2),
			ColorAlpha(theme.text, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(math.Round(fraction * 100) .. "%  ·  " .. string.format("%.1f", left) ..
			L("progressSeconds"), "nwInvKey", x + barWidth - Sc(12),
			y + math.Round(barHeight * 0.5) - Sc(2), ColorAlpha(accent, 240 * alpha),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		local fillHeight = math.max(Sc(3), 3)

		surface.SetDrawColor(255, 255, 255, 18 * alpha)
		surface.DrawRect(x, y + barHeight - fillHeight, barWidth, fillHeight)
		surface.SetDrawColor(accent.r, accent.g, accent.b, 245 * alpha)
		surface.DrawRect(x, y + barHeight - fillHeight, fill, fillHeight)

		return
	end

	local lineHeight = math.max(Sc(3), 3)
	local lineY = y + barHeight - lineHeight

	surface.SetDrawColor(0, 0, 0, 150 * alpha)
	surface.DrawRect(x - line, lineY - line, barWidth + line * 2, lineHeight + line * 2)

	surface.SetDrawColor(255, 255, 255, 36 * alpha)
	surface.DrawRect(x, lineY, barWidth, lineHeight)

	surface.SetDrawColor(accent.r, accent.g, accent.b, 240 * alpha)
	surface.DrawRect(x, lineY, fill, lineHeight)

	if (fill > 0) then
		surface.SetDrawColor(255, 255, 255, 220 * alpha)
		surface.DrawRect(x + fill - math.max(Sc(2), 2), lineY - line, math.max(Sc(2), 2),
			lineHeight + line * 2)
	end

	local title = util.TruncateWidth(util.Upper(self.title or ""), "nwHudSmall",
		barWidth - Sc(140))
	local textY = lineY - Sc(9)

	util.DrawSimpleTextShadow(title, "nwHudSmall", x, textY,
		Color(255, 255, 255, 250 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1)

	util.DrawSimpleTextShadow(string.format("%.1f", left) .. L("progressSeconds"), "nwInvKey",
		x + barWidth, textY, ColorAlpha(accent, 240 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, 1)

	util.DrawSimpleTextShadow(math.Round(fraction * 100) .. "%", "nwInvKey",
		x + math.Round(barWidth * 0.5), textY, Color(255, 255, 255, 200 * alpha),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
end

vgui.Register("nwProgress", PANEL, "EditablePanel")

function NETWORK.gui.StartProgress(title, duration)
	NETWORK.gui.StopProgress()

	local panel = vgui.Create("nwProgress")

	panel:Setup(title, duration)

	return panel
end

function NETWORK.gui.StopProgress()
	if (IsValid(NETWORK.gui.progress)) then
		NETWORK.gui.progress:Remove()
	end

	NETWORK.gui.progress = nil
end

net.Receive("nwProgress", function()
	local title = net.ReadString()
	local duration = net.ReadFloat()

	if (duration <= 0) then
		NETWORK.gui.StopProgress()

		return
	end

	NETWORK.gui.StartProgress(L(title), duration)
end)

concommand.Add("network_progress_test", function(_, _, arguments)
	NETWORK.gui.StartProgress(L("progressTest"), tonumber(arguments[1]) or 5)
end, nil, "Показать полосу действия")
