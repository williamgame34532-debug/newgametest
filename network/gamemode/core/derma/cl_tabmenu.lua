local PANEL = {}

NETWORK.gui.tabs = NETWORK.gui.tabs or {}
NETWORK.gui.tabOrder = NETWORK.gui.tabOrder or {}

function NETWORK.gui.RegisterTab(id, data)
	data.id = id
	data.order = data.order or (#NETWORK.gui.tabOrder + 1) * 10

	if (!NETWORK.gui.tabs[id]) then
		NETWORK.gui.tabOrder[#NETWORK.gui.tabOrder + 1] = id
	end

	NETWORK.gui.tabs[id] = data
end

function NETWORK.gui.GetTabs()
	local list = {}

	for _, id in ipairs(NETWORK.gui.tabOrder) do
		local tab = NETWORK.gui.tabs[id]

		if (tab and (!tab.access or tab.access())) then
			list[#list + 1] = tab
		end
	end

	table.sort(list, function(a, b)
		return a.order < b.order
	end)

	return list
end

NETWORK.gui.tabBrand = NETWORK.gui.tabBrand or "NETWORK"

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.tabMenu = self

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.startTime = CurTime()
	self.alpha = 0
	self.bClosing = false
	self.buttons = {}
	self.secondary = {}
	self.barHeight = Sc(56)
	self.margin = Sc(28)
	self.contentX = self.margin
	self.contentY = self.barHeight + Sc(22)
	self.contentWidth = ScrW() - self.margin * 2
	self.contentHeight = ScrH() - self.contentY - self.margin

	self:BuildNav()
	self:InvalidateLayout(true)

	local tabs = NETWORK.gui.GetTabs()

	if (tabs[1]) then
		self:SetTab(tabs[1].id)
	end

	self:MakePopup()

	self:SetKeyboardInputEnabled(true)

	NETWORK.sound.Hover()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()

		return true
	end
end

hook.Add("Think", "nwTabMenuTabClose", function()
	local menu = NETWORK.gui.tabMenu

	if (!IsValid(menu) or menu.bClosing) then
		return
	end

	if (IsValid(NETWORK.gui.chat) and NETWORK.gui.chat.bActive) then
		return
	end

	local bDown = input.IsKeyDown(KEY_TAB)

	if (!menu.bTabArmed) then
		if (!bDown) then
			menu.bTabArmed = true
		end

		return
	end

	if (bDown and !menu.bTabHeld) then
		menu.bTabHeld = true

		local focus = vgui.GetKeyboardFocus()

		if (IsValid(focus) and focus.GetValue and focus.SetValue and focus:IsEditing()) then
			return
		end

		menu:Close()
	elseif (!bDown) then
		menu.bTabHeld = false
	end
end)

local TAB_ICONS = {
	inventory = "framework/icons/backpack.png",
	character = "framework/icons/person.png",
	skills = "framework/icons/star.png",
	players = "framework/icons/group.png",
	group = "framework/icons/flag.png",
	settings = "framework/icons/settings_input_component.png",
	config = "framework/icons/developer_board.png"
}

function PANEL:BuildNav()
	local tabs = NETWORK.gui.GetTabs()

	for i = 1, #tabs do
		local data = tabs[i]
		local button = self:Add("nwTabButton")

		button:SetLabel(L(data.name))
		button:SetIcon(TAB_ICONS[data.id])
		button:SetRevealDelay(0.22 + i * 0.03)
		button.tabID = data.id
		button.DoClick = function()
			self:SetTab(data.id)
		end

		self.buttons[i] = button
	end

	local help = self:Add("nwTabButton")

	help:SetLabel(L("tabHelp"))
	help:SetIcon("framework/icons/help.png")
	help:SetSecondary(true)
	help:SetRevealDelay(0.22 + (#tabs + 1) * 0.03)
	help.DoClick = function()
		self:Close()

		timer.Simple(0.2, function()
			NETWORK.gui.OpenHelp()
		end)
	end

	self.secondary[#self.secondary + 1] = help

	self.characterButton = self:Add("nwTabButton")
	self.characterButton:SetLabel(L("tabCharacterMenu"))
	self.characterButton:SetIcon("framework/icons/assignment.png")
	self.characterButton:SetSecondary(true)
	self.characterButton:SetRevealDelay(0.22 + (#tabs + 2) * 0.03)
	self.characterButton.DoClick = function()
		self:Close()

		timer.Simple(0.2, function()
			NETWORK.gui.OpenMainMenu()
		end)
	end

	self.secondary[#self.secondary + 1] = self.characterButton

	self.closeButton = self:Add("nwTabButton")
	self.closeButton:SetLabel(L("tabClose"))
	self.closeButton:SetIcon("framework/chat/ui_close.png")
	self.closeButton:SetSecondary(true)
	self.closeButton:SetRevealDelay(0.3)
	self.closeButton.DoClick = function()
		self:Close()
	end
end

function PANEL:GetStatusText()
	local text = player.GetCount() .. " / " .. game.MaxPlayers()

	if (NETWORK.time and NETWORK.time.GetFormatted) then
		text = text .. "     " .. NETWORK.time.GetFormatted()
	end

	return text
end

function PANEL:PerformLayout(width, height)
	if (not self.buttons) then
		return
	end

	local Sc = NETWORK.util.Scale

	self.margin = math.min(Sc(34), math.Round(width * 0.03))

	local margin = self.margin
	local barHeight = Sc(56)
	local buttonHeight = Sc(30)
	local gap = Sc(4)
	local buttonY = math.Round((barHeight - buttonHeight) * 0.5)

	self.barHeight = barHeight

	surface.SetFont("nwSideBrand")

	local brandWidth = surface.GetTextSize(NETWORK.util.Upper(NETWORK.gui.tabBrand) ..
		" // " .. NETWORK.util.Upper(L("tabBrandSchema")))

	self.brandX = margin
	self.brandWidth = brandWidth

	local x = margin + brandWidth + Sc(36)

	for _, button in ipairs(self.buttons) do
		if (IsValid(button)) then
			button:SetSize(button:GetPreferredWidth(), buttonHeight)
			button:SetPos(x, buttonY)

			x = x + button:GetWide() + gap
		end
	end

	self.separatorX = x + Sc(10)

	x = x + Sc(24)

	for _, button in ipairs(self.secondary) do
		if (IsValid(button)) then
			button:SetSize(button:GetPreferredWidth(), buttonHeight)
			button:SetPos(x, buttonY)

			x = x + button:GetWide() + gap
		end
	end

	if (IsValid(self.closeButton)) then
		self.closeButton:SetSize(self.closeButton:GetPreferredWidth(), buttonHeight)
		self.closeButton:SetPos(width - margin - self.closeButton:GetWide(), buttonY)

		self.statusRight = width - margin - self.closeButton:GetWide() - Sc(24)
	else
		self.statusRight = width - margin
	end

	self.contentX = margin
	self.contentY = barHeight + Sc(22)
	self.contentWidth = width - margin * 2
	self.contentHeight = height - self.contentY - margin

	if (IsValid(self.page)) then
		self.page:SetSize(self.contentWidth, self.contentHeight)
		self.page:SetPos(self.contentX, self.contentY)
	end
end

function PANEL:SetTab(id, bInstant)
	if (self.activeTab == id or self.bClosing) then
		return
	end

	NETWORK.gui.ClearGrids()

	local data = NETWORK.gui.tabs[id]

	if (!data) then
		return
	end

	if (IsValid(self.page)) then
		self.page:Remove()
	end

	self.activeTab = id

	for i = 1, #self.buttons do
		local button = self.buttons[i]

		if (IsValid(button)) then
			button:SetActive(button.tabID == id)
		end
	end

	local Sc = NETWORK.util.Scale
	local page = self:Add("DPanel")

	page:SetSize(self.contentWidth or Sc(600), self.contentHeight or Sc(400))
	page:SetPos(self.contentX or 0, self.contentY or 0)
	page:SetAlpha(0)
	page.Paint = function() end
	page.slide = bInstant and 0 or 1
	page.startTime = CurTime()

	if (bInstant) then
		page:SetAlpha(255)
	end

	self.page = page

	if (data.Build) then
		data.Build(page, self)
	end
end

function PANEL:RefreshTab(bInstant)
	local id = self.activeTab

	self.activeTab = nil

	self:SetTab(id, bInstant)
end

function PANEL:Think()
	local util = NETWORK.util

	self.alpha = util.Approach(self.alpha, self.bClosing and 0 or 1, 9)

	self:SetAlpha(math.Round(self.alpha * 255))

	if (self.bClosing and self.alpha < 0.02) then
		self:Kill()

		return
	end

	local Sc = util.Scale
	local page = self.page

	if (IsValid(page)) then
		page.slide = util.Approach(page.slide, 0, 16)
		page:SetPos(self.contentX + math.Round(page.slide * Sc(34)), self.contentY)
		page:SetAlpha(math.Round(util.EaseOut(math.Clamp(1 - page.slide, 0, 1)) * 255))
	end
end

function PANEL:GetReveal(delay, duration)
	if (self.bClosing) then
		return self.alpha
	end

	return NETWORK.util.EaseOut(NETWORK.util.Stagger(self.startTime,
		delay + 0.18, duration or 0.5))
end

function PANEL:PaintTopBar(width, height)
	local Sc = NETWORK.util.Scale
	local util = NETWORK.util
	local theme = NETWORK.theme
	local reveal = self:GetReveal(0, 0.45)

	if (reveal < 0.01) then
		return
	end

	local margin = self.margin or Sc(28)
	local barHeight = self.barHeight or Sc(56)
	local middle = math.Round(barHeight * 0.5)
	local brand = util.Upper(NETWORK.gui.tabBrand)
	local schema = " // " .. util.Upper(L("tabBrandSchema"))

	surface.SetFont("nwSideBrand")

	local brandWidth = surface.GetTextSize(brand)

	draw.SimpleText(brand, "nwSideBrand", margin, middle,
		ColorAlpha(theme.text, 250 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(schema, "nwSideBrand", margin + brandWidth, middle,
		ColorAlpha(theme.textDim, 235 * reveal), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	if (self.separatorX) then
		surface.SetDrawColor(255, 255, 255, 22 * reveal)
		surface.DrawRect(self.separatorX, middle - Sc(8), math.max(Sc(1), 1), Sc(16))
	end

	if (self.statusRight) then
		draw.SimpleText(self:GetStatusText(), "nwHud", self.statusRight, middle,
			ColorAlpha(theme.textDim, 235 * reveal), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(255, 255, 255, 24 * reveal)
	surface.DrawRect(margin, barHeight, width - margin * 2, math.max(Sc(1), 1))
end

function PANEL:PaintOverlay(width, height)
	hook.Run("NetworkDrawTabOverlay", self.contentX, self.contentY,
		self.contentWidth, self.contentHeight)
end

function PANEL:Paint(width, height)
	local palette = NETWORK.theme.inv
	local util = NETWORK.util
	local alpha = self.alpha
	local Sc = util.Scale
	local open = self.bClosing and alpha or
		util.EaseOut(util.Stagger(self.startTime, 0, 0.32))

	util.DrawBlur(self, 4 * alpha, 0.25)

	local half = math.Round(height * 0.5 * util.EaseOut(open))

	local middle = math.Round(height * 0.5)

	surface.SetDrawColor(palette.background.r, palette.background.g,
		palette.background.b, 232 * alpha)
	surface.DrawRect(0, middle - half, width, half)
	surface.DrawRect(0, middle, width, half)

	if (open < 0.995) then
		local edge = math.max(Sc(2), 1)

		surface.SetDrawColor(palette.accent.r, palette.accent.g,
			palette.accent.b, 220 * alpha * (1 - open))
		surface.DrawRect(0, math.Round(height * 0.5) - half, width, edge)
		surface.DrawRect(0, math.Round(height * 0.5) + half - edge, width, edge)
	end

	if (half > 4) then
		util.DrawVignette(0, middle - half, width, half * 2,
			math.Round(math.min(width, half * 2) * 0.5), 150 * alpha)
	end

	self:PaintTopBar(width, height)
	self:PaintOverlay(width, height)
end

function PANEL:Close()
	if (self.bClosing) then
		return
	end

	self.bClosing = true

	NETWORK.gui.drag = nil

	NETWORK.gui.ClearGrids()
	NETWORK.gui.ClearTooltip()
	NETWORK.gui.CloseDragPreview()

	if (IsValid(NETWORK.gui.itemMenu)) then
		NETWORK.gui.itemMenu:Remove()
	end

	if (IsValid(self.page)) then
		self.page:Remove()

		self.page = nil
	end

	self:SetMouseInputEnabled(false)

	for i = 1, #self.buttons do
		if (IsValid(self.buttons[i])) then
			self.buttons[i]:SetMouseInputEnabled(false)
		end
	end

	NETWORK.gui.selected = nil

	for _, button in ipairs(self.secondary or {}) do
		if (IsValid(button)) then
			button:SetMouseInputEnabled(false)
		end
	end

	if (IsValid(self.closeButton)) then
		self.closeButton:SetMouseInputEnabled(false)
	end

	NETWORK.sound.Click()
	gui.EnableScreenClicker(false)
end

function PANEL:Kill()
	NETWORK.gui.tabMenu = nil

	self:Remove()
end

function NETWORK.gui.BindEntry(entry)
	if (!IsValid(entry)) then
		return entry
	end

	entry.OnGetFocus = function()
		local menu = NETWORK.gui.tabMenu

		if (IsValid(menu)) then
			menu:SetKeyboardInputEnabled(true)
		end
	end

	entry.OnLoseFocus = function()
		local menu = NETWORK.gui.tabMenu

		if (IsValid(menu)) then

			menu:SetKeyboardInputEnabled(true)
		end
	end

	return entry
end

vgui.Register("nwTabMenu", PANEL, "EditablePanel")

hook.Add("PlayerBindPress", "nwTabMenuChat", function(client, bind, bPressed)
	if (IsValid(NETWORK.gui.tabMenu) and string.find(bind, "messagemode")) then
		return true
	end
end)

function NETWORK.gui.CanOpenMenus()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	if (!client:Alive() or IsValid(client:GetNWEntity("nwRagdollEntity", NULL))) then
		return false
	end

	return true
end

function NETWORK.gui.OpenTabMenu()
	if (!NETWORK.gui.CanOpenMenus()) then
		return
	end

	if (IsValid(NETWORK.gui.tabMenu)) then
		return NETWORK.gui.tabMenu
	end

	if (IsValid(NETWORK.gui.menu)) then
		return
	end

	NETWORK.gui.CloseWindows("tabMenu")

	return vgui.Create("nwTabMenu")
end

function NETWORK.gui.CloseTabMenu()
	if (IsValid(NETWORK.gui.tabMenu)) then
		NETWORK.gui.tabMenu:Close()
	end
end

function NETWORK.gui.ToggleTabMenu()
	local menu = NETWORK.gui.tabMenu

	if (IsValid(menu)) then
		if (!menu.bClosing) then
			menu:Close()
		end

		return
	end

	NETWORK.gui.OpenTabMenu()
end

if (IsValid(NETWORK.gui.tabMenu)) then
	NETWORK.gui.tabMenu:Remove()

	NETWORK.gui.tabMenu = nil
end
