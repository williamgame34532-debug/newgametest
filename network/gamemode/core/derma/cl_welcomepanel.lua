local PANEL = {}

function PANEL:Init()
	self.alpha = 0
	self.bClosing = false
	self.born = RealTime()

	self:SetSize(ScrW(), NETWORK.util.Scale(150))
	self:SetPos(0, ScrH() - NETWORK.util.Scale(150))
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
end

function PANEL:Close()
	self.bClosing = true
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 6)

	if (self.bClosing and self.alpha <= 0.01) then
		self:Remove()

		return
	end

	if (!self.bClosing and input.IsKeyDown(KEY_O)) then
		self:Close()
	end

	if (!self.bClosing and RealTime() - (self.born or RealTime()) > 25) then
		self:Close()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha
	local client = LocalPlayer()
	local faction = NETWORK.factions.Get(client:GetCharacterFaction())
	local color = faction and faction.color or theme.accent
	local slide = (1 - alpha) * Sc(30)
	local centerX = math.Round(width * 0.5)
	local y = Sc(34) + slide

	local plateY = Sc(18) + slide
	local plateHeight = height - Sc(18)
	local accent = color

	util.DrawBlurRounded(self, 0, plateY, width, plateHeight, 0, 3 * alpha)

	surface.SetDrawColor(8, 9, 10, 232 * alpha)
	surface.DrawRect(0, plateY, width, plateHeight)

	surface.SetDrawColor(255, 255, 255, 26 * alpha)
	surface.DrawRect(0, plateY, width, math.max(Sc(1), 1))

	surface.SetDrawColor(accent.r, accent.g, accent.b, 220 * alpha)
	surface.DrawRect(centerX - Sc(70), plateY + Sc(14), Sc(140), math.max(Sc(2), 1))

	surface.SetDrawColor(accent.r, accent.g, accent.b, 230 * alpha)
	surface.DrawRect(Sc(20), plateY + Sc(16), math.max(Sc(3), 2), Sc(30))

	local name = client:GetCharacterName()

	if (name and name != "") then
		draw.SimpleText(util.Upper(name), "nwTipBody", Sc(30),
			Sc(18) + slide + Sc(18), ColorAlpha(theme.text, 235 * alpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		draw.SimpleText(util.Upper(faction and L(faction.name) or ""),
			"nwHudSmall", Sc(30), Sc(18) + slide + Sc(34),
			ColorAlpha(color, 220 * alpha), TEXT_ALIGN_LEFT,
			TEXT_ALIGN_CENTER)
	end

	local title = util.Upper(L("welcomeTitle"))
	local titleWidth = util.TextSpacedSize(title, "nwTipTitle", Sc(5))

	util.DrawTextSpaced(title, "nwTipTitle", centerX - math.Round(titleWidth * 0.5), y,
		ColorAlpha(color, 250 * alpha), Sc(5), TEXT_ALIGN_CENTER)

	local lines = util.WrapText(L("welcomeVocoder"), "nwTipBody",
		math.min(width - Sc(120), Sc(1100)), 3)
	local lineY = y + Sc(34)

	for _, line in ipairs(lines) do
		draw.SimpleText(line, "nwTipBody", centerX, lineY,
			ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)

		lineY = lineY + Sc(24)
	end

	local closeText = util.Upper(L("welcomeClose"))
	local closeWidth = util.TextSpacedSize(closeText, "nwHudSmall", Sc(4))

	util.DrawTextSpaced(closeText, "nwHudSmall", centerX - math.Round(closeWidth * 0.5),
		lineY + Sc(10), ColorAlpha(theme.textFaint, 235 * alpha), Sc(4),
		TEXT_ALIGN_CENTER)
end

vgui.Register("nwWelcomePanel", PANEL, "EditablePanel")

function NETWORK.gui.OpenWelcome()
	if (IsValid(NETWORK.gui.welcome)) then
		NETWORK.gui.welcome:Remove()
	end

	NETWORK.gui.welcome = vgui.Create("nwWelcomePanel")

	return NETWORK.gui.welcome
end

local welcomeConVar = CreateClientConVar("network_welcome", "1", true, false,
	"Показывать приветствие фракции")

hook.Remove("NetworkCharacterLoaded", "nwWelcome")
