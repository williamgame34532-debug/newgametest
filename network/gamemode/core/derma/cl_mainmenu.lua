local PANEL = {}

local blurConVar = CreateClientConVar("network_menu_blur", "1", true, false,
	"Размывать живой фон главного меню")

local fadeStart = 0
local fadeDuration = 0

function NETWORK.gui.ScreenFade(duration)
	fadeStart = CurTime()
	fadeDuration = duration or 0.5
end

hook.Add("HUDPaint", "nwScreenFade", function()
	if (fadeDuration <= 0) then
		return
	end

	local fraction = (CurTime() - fadeStart) / fadeDuration

	if (fraction >= 1) then
		fadeDuration = 0

		return
	end

	surface.SetDrawColor(0, 0, 0,
		255 * (1 - NETWORK.util.EaseInOut(math.Clamp(fraction, 0, 1))))
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)

function PANEL:Init()
	if (IsValid(NETWORK.gui.menu)) then
		NETWORK.gui.menu:Remove()
	end

	NETWORK.gui.menu = self

	local Sc = NETWORK.util.Scale

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.startTime = CurTime()
	self.bClosing = false
	self.alpha = 0
	self.buttons = {}

	self.state = "menu"
	self.chrome = 1
	self.dim = 0
	self.dimTarget = 0
	self.pending = nil

	self.inset = Sc(64)
	self.brand = "NETWORK"

	self:BuildButtons()

	if (!NETWORK.character.bLoaded) then
		NETWORK.character.Request()
	end

	self:MakePopup()
	self:SetKeyboardInputEnabled(true)
	self:InvalidateLayout(true)
end

function PANEL:BuildButtons()
	self.buttons = {}

	self:AddButton(L("menuCharacters"), function()
		self:OpenCharacters()
	end)

	self:AddButton(L("menuDiscord"), function()
		gui.OpenURL(NETWORK.discord)
	end)

	local exit = self:AddButton(L("menuDisconnect"), function()
		self:Close()

		timer.Simple(0.55, function()
			RunConsoleCommand("disconnect")
		end)
	end)

	exit:SetDanger(true)
end

local BUTTON_HINTS = {"menuHintCharacters", "menuHintDiscord", "menuHintDisconnect"}

function PANEL:AddButton(label, callback)
	local index = #self.buttons + 1
	local button = self:Add("nwMenuButton")

	button:SetLabel(label)
	button:SetRevealDelay(0.3 + index * 0.09)
	button.DoClick = callback
	button.hint = BUTTON_HINTS[index]
	button.Paint = function(panel, width, height)
		self:PaintButton(panel, index, width, height)
	end

	self.buttons[index] = button

	return button
end

function PANEL:PaintButton(panel, index, width, height)
	local S = NETWORK.style
	local P = S.Pda()
	local util = NETWORK.util
	local Sc = util.Scale
	local reveal = util.EaseOut(util.Stagger(panel.startTime, panel.revealDelay or 0, 0.6))
	local alpha = reveal * (1 - util.EaseInOut(panel.exit or 0)) * self.alpha

	if (alpha < 0.01) then
		return
	end

	local hover = util.EaseInOut(panel.hover or 0)
	local accent = panel.bDanger and P.bad or P.accent
	local shift = math.Round((1 - reveal) * Sc(24))

	surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 200 * alpha)
	surface.DrawRect(shift, 0, width - shift, height)

	if (hover > 0.01) then
		surface.SetDrawColor(accent.r, accent.g, accent.b, 34 * hover * alpha)
		surface.DrawRect(shift, 0, width - shift, height)
	end

	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, (150 + 60 * hover) * alpha)
	surface.DrawOutlinedRect(shift, 0, width - shift, height, 1)

	surface.SetDrawColor(accent.r, accent.g, accent.b, (110 + 145 * hover) * alpha)
	surface.DrawRect(shift, 0, math.max(Sc(3), 2) + math.Round(Sc(3) * hover), height)

	local number = string.format("%02d", index)
	local textX = shift + Sc(20)

	draw.SimpleText(number, S.Font("mono", 13, 600), textX, math.Round(height * 0.5),
		ColorAlpha(accent, 230 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	textX = textX + Sc(36)

	local labelY = math.Round(height * 0.5) - (panel.hint and Sc(8) or 0)

	draw.SimpleText(panel.label, S.Font("button", 20, 700), textX + math.Round(Sc(6) * hover), labelY,
		ColorAlpha(P.text, (220 + 35 * hover) * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (panel.hint) then
		draw.SimpleText(util.Upper(L(panel.hint)), S.Font("label", 11, 700),
			textX + math.Round(Sc(6) * hover), labelY + Sc(19),
			ColorAlpha(P.muted, 220 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	draw.SimpleText("›", S.Font("body", 26, 600), width - Sc(18) + math.Round(Sc(4) * hover),
		math.Round(height * 0.5) - Sc(1), ColorAlpha(accent, (140 + 115 * hover) * alpha),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if (hover > 0.5) then
		S.Ticks(shift, 0, width - shift, height, Sc(7), ColorAlpha(accent, 255 * alpha))
	end
end

function PANEL:SetButtonsShown(bShown)
	for index, button in ipairs(self.buttons) do
		if (IsValid(button)) then
			button:SetExiting(!bShown)
			button:SetMouseInputEnabled(bShown)

			if (bShown) then
				button.startTime = CurTime()
				button:SetRevealDelay(0.05 + index * 0.09)
			end
		end
	end
end

function PANEL:PerformLayout(width, height)
	if (!self.buttons) then
		return
	end

	local Sc = NETWORK.util.Scale

	self.inset = math.min(Sc(64), math.Round(width * 0.06))

	local buttonWidth = math.Clamp(math.Round(width * 0.26), Sc(300), Sc(420))
	local buttonHeight = Sc(62)
	local gap = Sc(8)
	local count = #self.buttons
	local total = count * buttonHeight + (count - 1) * gap
	local platePad = Sc(16)
	local band = Sc(34)
	local x = width - self.inset - buttonWidth - platePad
	local y = math.Round((height - total) * 0.5) + math.Round(band * 0.5)

	self.plate = {
		x = x - platePad,
		y = y - band - platePad,
		w = buttonWidth + platePad * 2,
		h = total + band + platePad * 2,
		band = band
	}

	for i = 1, count do
		local button = self.buttons[i]

		if (IsValid(button)) then
			button:SetSize(buttonWidth, buttonHeight)
			button:SetPos(x, y)

			y = y + buttonHeight + gap
		end
	end

	if (IsValid(self.view)) then
		self.view:SetSize(width, height)
		self.view:SetPos(0, 0)
	end
end

function PANEL:Transition(callback)
	self.dimTarget = 1
	self.pending = callback
end

function PANEL:OpenCharacters()
	if (self.state != "menu") then
		return
	end

	self.state = "loading"

	self:SetButtonsShown(false)

	self:Transition(function()

		if (NETWORK.character.Count() == 0 and NETWORK.character.HasFreeSlot()) then
			self:OpenCreation()

			return
		end

		self:BuildView()
	end)
end

function PANEL:BuildView()
	if (IsValid(self.view)) then
		return
	end

	self.state = "characters"
	self.chrome = 0

	local view = self:Add("nwCharacterView")

	view:SetSize(self:GetWide(), self:GetTall())
	view:SetPos(0, 0)

	view.OnClosed = function()
		self.state = "menu"
		self.view = nil

		self:Transition(function()
			self:SetButtonsShown(true)
		end)
	end

	view.OnCreate = function(panel)
		panel:Close()

		self:Transition(function()
			self:OpenCreation()
		end)
	end

	self.view = view
end

function PANEL:OpenCreation()
	if (IsValid(self.creation)) then
		return
	end

	if (!NETWORK.character.HasFreeSlot()) then
		self.state = "menu"

		self:SetButtonsShown(true)

		return
	end

	self.state = "creation"
	self.chrome = 0

	if (!NETWORK.gui.bNewCharacterUI) then
		return self:BuildCreation(nil)
	end

	local pick = vgui.Create("nwFactionPick")

	pick.OnCancelled = function()
		self.state = "menu"

		self:Transition(function()
			self:SetButtonsShown(true)
		end)
	end

	pick.OnPicked = function(panel, factionID)
		self:BuildCreation(factionID)
	end
end

function PANEL:BuildCreation(factionID)
	if (IsValid(self.creation)) then
		return
	end

	local creation = vgui.Create("nwCharacterCreate", self)

	if (factionID and creation.SetFaction) then
		creation:SetFaction(factionID)
	end

	creation.OnClosed = function()
		self.creation = nil
		self.state = "menu"

		self:Transition(function()
			if (NETWORK.character.Count() > 0) then
				self:BuildView()

				return
			end

			self:SetButtonsShown(true)
		end)
	end

	self.creation = creation
end

function PANEL:Think()
	local util = NETWORK.util

	self.alpha = util.Approach(self.alpha, self.bClosing and 0 or 1,
		self.bClosing and 5 or 3.4)
	self.chrome = util.Approach(self.chrome, self.state == "menu" and 1 or 0, 5)
	self.dim = util.Approach(self.dim, self.dimTarget, self.dimTarget > 0 and 6 or 3.2)

	if (self.pending and self.dim > 0.94) then
		local callback = self.pending

		self.pending = nil
		self.dimTarget = 0

		callback()
	end

	if (self.bClosing and self.alpha < 0.02) then
		self:Kill()
	end
end

function PANEL:GetReveal(delay, duration)
	if (self.bClosing) then
		return self.alpha
	end

	return NETWORK.util.EaseOut(NETWORK.util.Stagger(self.startTime, delay, duration or 1))
end

function PANEL:PaintBackdrop(width, height)
	local S = NETWORK.style
	local P = S.Pda()
	local util = NETWORK.util
	local Sc = util.Scale
	local a = self.alpha

	if (NETWORK.camera.bConfigured and blurConVar:GetBool()) then
		util.DrawBlur(self, 1.3 * a)
	end

	util.DrawVGradient(0, 0, width, height, Color(8, 18, 30, 225 * a), Color(4, 9, 16, 250 * a), 32)

	-- Faint PDA grid and a horizon band of the city map.
	S.Grid(0, 0, width, height, Sc(64), a)

	local horizon = math.Round(height * 0.78)

	for i = 0, 22 do
		local bx = math.Round(width * 0.04 + i * width * 0.043)
		local bh = math.Round(height * (0.06 + ((i * 7) % 11) * 0.016))

		surface.SetDrawColor(P.bg2.r, P.bg2.g, P.bg2.b, 70 * a)
		surface.DrawRect(bx, horizon - bh, math.Round(width * 0.032), bh)
		surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 70 * a)
		surface.DrawRect(bx, horizon - bh, math.Round(width * 0.032), 1)
	end

	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 140 * a)
	surface.DrawRect(0, horizon, width, 1)

	-- Top status strip.
	local strip = Sc(40)
	local inset = self.inset or Sc(48)

	surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 225 * a)
	surface.DrawRect(0, 0, width, strip)
	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 200 * a)
	surface.DrawRect(0, strip, width, 1)

	local cap = S.Font("label", 12, 700)
	local mark = Sc(14)
	local markY = math.Round((strip - mark) * 0.5)

	surface.SetDrawColor(P.accent.r, P.accent.g, P.accent.b, 230 * a)
	surface.DrawOutlinedRect(inset, markY, mark, mark, 1)
	surface.DrawRect(inset + Sc(4), markY + Sc(4), mark - Sc(8), mark - Sc(8))

	draw.SimpleText("C24  ·  " .. util.Upper(L("menuNetwork")), cap, inset + mark + Sc(10),
		math.Round(strip * 0.5), ColorAlpha(P.muted, 240 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local pulse = 0.55 + 0.45 * math.abs(math.sin(RealTime() * 2))
	local linkText = util.Upper(L("menuLinkUp"))
	surface.SetFont(cap)

	local linkWidth = surface.GetTextSize(linkText)
	local dot = Sc(6)
	local linkX = width - inset - linkWidth

	surface.SetDrawColor(P.good.r, P.good.g, P.good.b, 240 * pulse * a)
	surface.DrawRect(linkX - dot - Sc(8), math.Round((strip - dot) * 0.5), dot, dot)

	draw.SimpleText(linkText, cap, width - inset, math.Round(strip * 0.5),
		ColorAlpha(P.good, 240 * a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	-- Button plate.
	local plate = self.plate

	if (plate) then
		local reveal = self:GetReveal(0.2, 0.7) * self.chrome

		S.Plate(plate.x, plate.y, plate.w, plate.h, reveal * a, {
			band = plate.band,
			title = L("menuMainTitle"),
			right = "v" .. tostring(NETWORK.version or ""),
			rightColor = P.faint
		})
	end
end

function PANEL:PaintBrand(width, height)
	local S = NETWORK.style
	local P = S.Pda()
	local util = NETWORK.util
	local Sc = util.Scale
	local a = self.alpha * self.chrome * self:GetReveal(0.1, 0.9)

	if (a < 0.01) then
		return
	end

	local x = self.inset
	local y = math.Round(height * 0.30)

	draw.SimpleText(util.Upper(L("menuSector")), S.Font("label", 14, 700), x, y,
		ColorAlpha(P.accent, 245 * a))

	surface.SetDrawColor(P.accent.r, P.accent.g, P.accent.b, 230 * a)
	surface.DrawRect(x, y + Sc(24), Sc(42), math.max(Sc(2), 2))

	draw.SimpleText(self.brand, S.Font("display", 92, 700), x - Sc(4), y + Sc(28),
		ColorAlpha(P.text, 252 * a))

	draw.SimpleText(L("menuTagline"), S.Font("body", 22, 500), x, y + Sc(134),
		ColorAlpha(Color(184, 202, 218), 235 * a))

	-- Faction strip: small chips in the PDA style.
	local chipFont = S.Font("label", 11, 700)
	local chipX = x
	local chipY = y + Sc(176)
	local factions = {
		{L("menuFactionCitizens"), P.accent},
		{L("menuFactionCwu"), P.warn},
		{L("menuFactionAlliance"), P.bad},
		{L("menuFactionResistance"), P.good}
	}

	surface.SetFont(chipFont)

	for _, entry in ipairs(factions) do
		local text = util.Upper(entry[1])
		local textWidth, textHeight = surface.GetTextSize(text)
		local chipWidth = textWidth + Sc(18)
		local chipHeight = textHeight + Sc(8)

		surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 210 * a)
		surface.DrawRect(chipX, chipY, chipWidth, chipHeight)
		surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 200 * a)
		surface.DrawOutlinedRect(chipX, chipY, chipWidth, chipHeight, 1)
		surface.SetDrawColor(entry[2].r, entry[2].g, entry[2].b, 240 * a)
		surface.DrawRect(chipX, chipY, math.max(Sc(2), 2), chipHeight)

		draw.SimpleText(text, chipFont, chipX + Sc(10), chipY + math.Round(chipHeight * 0.5),
			ColorAlpha(P.text, 230 * a), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		chipX = chipX + chipWidth + Sc(8)
	end
end

function PANEL:PaintClock(width, height)
	local S = NETWORK.style
	local P = S.Pda()
	local util = NETWORK.util
	local Sc = util.Scale
	local reveal = self:GetReveal(0.2, 0.9) * self.chrome * self.alpha

	if (reveal < 0.01) then
		return
	end

	local x = width - self.inset
	local y = Sc(64)

	draw.SimpleText(NETWORK.time.GetFormatted(), S.Font("mono", 40, 600), x, y,
		ColorAlpha(P.text, 240 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	draw.SimpleText(os.date("%d.%m.%Y") .. "  ·  " .. util.Upper(L("menuCityTime")),
		S.Font("label", 12, 700), x, y + Sc(48), ColorAlpha(P.muted, 230 * reveal),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

function PANEL:PaintFooter(width, height)
	local S = NETWORK.style
	local P = S.Pda()
	local util = NETWORK.util
	local Sc = util.Scale
	local reveal = self:GetReveal(0.3, 0.9) * self.chrome * self.alpha

	if (reveal < 0.01) then
		return
	end

	local strip = Sc(34)
	local top = height - strip
	local font = S.Font("label", 12, 700)
	local mid = top + math.Round(strip * 0.5)

	surface.SetDrawColor(P.deep.r, P.deep.g, P.deep.b, 225 * reveal)
	surface.DrawRect(0, top, width, strip)
	surface.SetDrawColor(P.line.r, P.line.g, P.line.b, 200 * reveal)
	surface.DrawRect(0, top, width, 1)

	draw.SimpleText(util.Upper(tostring(NETWORK.schemaName or "") .. "  ·  " .. tostring(NETWORK.version or "")),
		font, self.inset, mid, ColorAlpha(P.muted, 220 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local status = util.Upper(game.GetMap()) .. "   ·   " .. util.Upper(L("menuOnline")) .. "  " ..
		player.GetCount() .. " / " .. game.MaxPlayers()

	draw.SimpleText(status, font, width - self.inset, mid, ColorAlpha(P.muted, 220 * reveal),
		TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	local client = LocalPlayer()

	if (!NETWORK.camera.bConfigured and IsValid(client) and client:IsAdmin()) then
		draw.SimpleText(L("menuCameraHint"), font, self.inset, top - Sc(16),
			ColorAlpha(P.warn, 220 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:Paint(width, height)
	self:PaintBackdrop(width, height)
	self:PaintBrand(width, height)
	self:PaintClock(width, height)
	self:PaintFooter(width, height)
end

function PANEL:PaintOver(width, height)

	local cover = NETWORK.util.EaseInOut(math.max(1 - self.alpha, self.dim))

	if (cover < 0.003) then
		return
	end

	surface.SetDrawColor(0, 0, 0, 255 * cover)
	surface.DrawRect(0, 0, width, height)
end

function PANEL:OnKeyCodePressed(key)
	if (key != KEY_ESCAPE) then
		return
	end

	if (self.state == "creation") then
		if (IsValid(self.creation)) then
			self.creation:Close()
		end

		return
	end

	if (self.state == "characters") then
		if (IsValid(self.view)) then
			self.view:Close()
		end

		return
	end

	self:Close()
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	self:SetButtonsShown(false)

	gui.EnableScreenClicker(false)
	NETWORK.camera.ResetOffset()
end

function PANEL:Kill()
	NETWORK.gui.menu = nil

	NETWORK.gui.ScreenFade(0.55)

	self:Remove()
end

vgui.Register("nwMainMenu", PANEL, "EditablePanel")

function NETWORK.gui.CloseAll()
	if (IsValid(NETWORK.gui.menu)) then
		NETWORK.gui.menu:Remove()
	end

	NETWORK.gui.menu = nil
end

function NETWORK.gui.OpenMainMenu()
	if (LocalPlayer():HasCharacter() and !NETWORK.gui.CanOpenMenus()) then
		return
	end

	NETWORK.gui.CloseWindows()
	NETWORK.gui.CloseAll()

	return vgui.Create("nwMainMenu")
end

NETWORK.gui.CloseAll()

hook.Add("NetworkCharacterListUpdated", "nwMenuRefresh", function()
	local menu = NETWORK.gui.menu

	if (IsValid(menu) and IsValid(menu.view)) then
		menu.view:OnListUpdated()
	end
end)

hook.Add("NetworkCharacterResult", "nwMenuResult", function(action, bSuccess, text)
	local menu = NETWORK.gui.menu

	if (!IsValid(menu)) then
		return
	end

	if (action == "select" and bSuccess) then
		if (IsValid(menu.view)) then
			menu.view:Close()
		end

		menu:Close()

		return
	end

	if (action == "create" and bSuccess and IsValid(menu.creation)) then
		menu.creation:Close()
	end

	if (!bSuccess and IsValid(menu.view)) then
		menu.view:StopLoading()
	end
end)

hook.Add("NetworkCharacterLoaded", "nwMainMenuClose", function()

	NETWORK.sound.MenuStart()

	timer.Simple(0.15, function()
		local menu = NETWORK.gui.menu

		if (IsValid(menu) and menu.Close) then
			menu:Close()
		end
	end)
end)
