NETWORK.intro = NETWORK.intro or {}

NETWORK.intro.duration = 4.2

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

local PANEL = {}

function PANEL:Init()
	NETWORK.gui.intro = self

	self.startTime = CurTime()

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:OnRemove()
	if (NETWORK.gui.intro == self) then
		NETWORK.gui.intro = nil
	end
end

function PANEL:Think()
	self:MoveToFront()

	if (CurTime() - self.startTime > NETWORK.intro.duration) then
		self:Remove()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local age = CurTime() - self.startTime
	local fade = 1 - util.EaseInOut(math.Clamp((age - NETWORK.intro.duration * 0.72) /
		(NETWORK.intro.duration * 0.28), 0, 1))
	local sweep = util.EaseOut(math.Clamp(age / 0.5, 0, 1))
	local centerX = math.Round(width * 0.5)
	local centerY = math.Round(height * 0.5)

	surface.SetDrawColor(4, 6, 10, 255 * fade)
	surface.DrawRect(0, 0, width, height)

	local line = math.Round(height * sweep)

	render.SetScissorRect(0, 0, width, line, true)

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
		10 * fade)

	for gridX = 0, width, Sc(60) do
		surface.DrawRect(gridX, 0, 1, height)
	end

	for gridY = 0, height, Sc(60) do
		surface.DrawRect(0, gridY, width, 1)
	end

	local title = util.Upper(NETWORK.name)
	local spacing = Sc(10)
	local shown = math.Clamp(math.floor((age - 0.4) / 0.08), 0,
		utf8.len(title) or #title)
	local titleWidth = util.TextSpacedSize(title, "nwBrand", spacing)

	if (shown > 0) then
		util.DrawTextSpaced(SubChars(title, shown), "nwBrand",
			math.Round(centerX - titleWidth * 0.5), centerY,
			ColorAlpha(theme.text, 255 * fade), spacing, TEXT_ALIGN_CENTER)
	end

	if (shown > 0 and shown < (utf8.len(title) or #title) and
		math.sin(age * 18) > 0) then
		local partWidth = util.TextSpacedSize(SubChars(title, shown),
			"nwBrand", spacing)

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			235 * fade)
		surface.DrawRect(math.Round(centerX - titleWidth * 0.5 + partWidth),
			centerY - Sc(14), Sc(10), Sc(3))
	end

	local lineWidth = math.Round(math.min(Sc(220), width * 0.3) *
		util.EaseOut(math.Clamp((age - 1.1) / 0.5, 0, 1)))

	surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
		230 * fade)
	surface.DrawRect(centerX - lineWidth, centerY + Sc(36), lineWidth * 2,
		math.max(Sc(2), 1))

	local sub = util.Upper(NETWORK.version .. "  //  " .. L("introLink"))
	local subShown = math.Clamp(math.floor((age - 1.2) / 0.02), 0,
		utf8.len(sub) or #sub)
	local subWidth = util.TextSpacedSize(sub, "nwHudSmall", Sc(8))

	if (subShown > 0) then
		util.DrawTextSpaced(SubChars(sub, subShown), "nwHudSmall",
			math.Round(centerX - subWidth * 0.5), centerY + Sc(58),
			ColorAlpha(theme.textFaint, 230 * fade), Sc(8), TEXT_ALIGN_CENTER)
	end

	render.SetScissorRect(0, 0, 0, 0, false)

	if (sweep < 0.999) then
		surface.SetDrawColor(theme.text.r, theme.text.g, theme.text.b,
			200 * fade * (1 - sweep))
		surface.DrawRect(0, line - math.max(Sc(2), 1), width,
			math.max(Sc(2), 1))

		surface.SetDrawColor(theme.accent.r, theme.accent.g, theme.accent.b,
			40 * fade * (1 - sweep))
		surface.DrawRect(0, line - Sc(30), width, Sc(30))
	end
end

vgui.Register("nwIntro", PANEL, "EditablePanel")

function NETWORK.intro.Play()
	if (IsValid(NETWORK.gui.intro)) then
		return
	end

	return vgui.Create("nwIntro")
end

hook.Add("InitPostEntity", "nwIntro", function()
	timer.Simple(0.4, function()
		NETWORK.intro.Play()
	end)
end)

concommand.Add("network_intro", function()
	NETWORK.intro.Play()
end)
