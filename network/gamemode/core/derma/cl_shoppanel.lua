local PANEL = {}

local TABS = {
	{id = "settings", label = "Настройки", glyph = "sliders"},
	{id = "order", label = "Заказ", glyph = "coin"},
	{id = "place", label = "Установка", glyph = "grid"}
}

function PANEL:Init()
	NETWORK.gui.shopPanel = self

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	self.tab = "settings"
	self.alpha = 0
	self.tabButtons = {}

	self:SetSize(math.min(Sc(760), ScrW() - Sc(40)), math.min(Sc(540), ScrH() - Sc(40)))
	self:Center()
	self:MakePopup()
	self:SetKeyboardInputEnabled(true)

	local close = self:Add("DButton")

	close:SetText("")
	close:SetCursor("hand")
	close:SetSize(Sc(36), Sc(36))
	close:SetZPos(1000)
	close.DoClick = function()
		NETWORK.sound.Click()
		self:Close()
	end
	close.Paint = function(panel, width, height)
		local bHover = panel:IsHovered()
		local color = bHover and theme.danger or theme.text
		local pad = math.Round(width * 0.32)
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(255, 255, 255, bHover and 22 or 10))
		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
			bHover and ColorAlpha(theme.danger, 180) or Color(255, 255, 255, 40))
		NETWORK.util.DrawThickLine(pad, pad, width - pad, height - pad, math.max(Sc(2), 2), color)
		NETWORK.util.DrawThickLine(width - pad, pad, pad, height - pad, math.max(Sc(2), 2), color)
	end

	self.closeButton = close

	for index, tab in ipairs(TABS) do
		local button = self:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:SetSize(Sc(150), Sc(34))
		button:SetZPos(900)
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
		end
		button.DoClick = function()
			if (self.tab != tab.id) then
				NETWORK.sound.Click()
				self.tab = tab.id
				self:Rebuild()
			end
		end
		button.Paint = function(panel, width, height)
			local bActive = self.tab == tab.id
			local radius = math.max(Sc(6), 4)

			draw.RoundedBox(radius, 0, 0, width, height, Color(12, 13, 15, 220))

			if (bActive) then
				draw.RoundedBox(radius, 0, 0, width, height, ColorAlpha(theme.combine, 34))
			elseif (panel.hover > 0.01) then
				draw.RoundedBox(radius, 0, 0, width, height, Color(255, 255, 255, 12 * panel.hover))
			end

			NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, math.max(Sc(1), 1),
				bActive and ColorAlpha(theme.combine, 210) or Color(255, 255, 255, 30))
			NETWORK.gui.DrawGlyph(tab.glyph, Sc(12), math.Round(height * 0.5) - Sc(7), Sc(14),
				bActive and theme.combine or theme.textDim)
			draw.SimpleText(tab.label, "nwInvBody", Sc(34), math.Round(height * 0.5),
				bActive and theme.text or theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		self.tabButtons[index] = button
	end

	self.body = self:Add("DPanel")
	self.body:SetPaintBackground(false)
	self.body.Paint = function(panel, width, height)
		if (self.PaintTab) then
			self.PaintTab(self, width, height)
		end
	end

	self:InvalidateLayout(true)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale

	if (IsValid(self.closeButton)) then
		self.closeButton:SetPos(width - Sc(46), Sc(12))
	end

	for index, button in ipairs(self.tabButtons or {}) do
		if (IsValid(button)) then
			button:SetPos(Sc(20) + (index - 1) * Sc(158), Sc(64))
		end
	end

	if (IsValid(self.body)) then
		self.body:SetPos(Sc(20), Sc(116))
		self.body:SetSize(width - Sc(40), height - Sc(136))
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.shopPanel == self) then
		NETWORK.gui.shopPanel = nil
	end
end

function PANEL:Close()
	self:Remove()
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Close()
	end
end

function PANEL:Send(action, payload)
	net.Start("nwShopAction")
		net.WriteString(action)
		NETWORK.util.WriteTable(payload or {})
	net.SendToServer()
end

function PANEL:Update(data)
	self.data = data
	self:Rebuild()
end

local function Button(parent, x, y, width, height, label, glyph, bPrimary, callback)
	local button = parent:Add("nwInvButton")

	button:SetPos(x, y)
	button:SetSize(width, height)
	button:Setup(label, glyph, bPrimary)
	button.DoClick = callback

	return button
end

function PANEL:Rebuild()
	if (!IsValid(self.body)) then
		return
	end

	self.body:Clear()
	self.PaintTab = nil

	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local data = self.data or {}
	local body = self.body
	local width, height = body:GetSize()
	local S = NETWORK.store

	if (self.tab == "settings") then
		local name = body:Add("DTextEntry")

		name:SetPos(0, Sc(26))
		name:SetSize(Sc(320), Sc(36))
		name:SetFont("nwField")
		name:SetValue(data.name or "")
		name:SetPaintBackground(false)
		name:SetTextColor(theme.text)
		name.Paint = function(this, w, h)
			draw.RoundedBox(math.max(Sc(6), 4), 0, 0, w, h, Color(12, 13, 15, 230))
			NETWORK.util.DrawRoundedBorder(0, 0, w, h, math.max(Sc(6), 4), math.max(Sc(1), 1),
				this:HasFocus() and ColorAlpha(theme.combine, 210) or Color(255, 255, 255, 30))
			this:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)
		end

		self.bOpen = data.bOpen

		Button(body, 0, Sc(84), Sc(200), Sc(36), self.bOpen and "Лавка открыта" or "Лавка закрыта",
			self.bOpen and "plus" or "minus", self.bOpen, function()
				self.bOpen = !self.bOpen
				self:Send("settings", {name = name:GetValue(), bOpen = self.bOpen})
			end)

		Button(body, 0, height - Sc(40), Sc(200), Sc(36), "Сохранить", "up", true, function()
			self:Send("settings", {name = name:GetValue(), bOpen = self.bOpen})
		end)

		self.PaintTab = function(_, w, h)
			draw.SimpleText(NETWORK.util.Upper("Название лавки"), "nwInvKey", 0, Sc(10),
				ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText("Бизнес: " .. (data.what or "—"), "nwInvBody", 0, Sc(150),
				theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText("Название и состояние видны на табличках оборудования.", "nwHudSmall",
				0, Sc(174), theme.textFaint, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	elseif (self.tab == "order") then
		local scroll = body:Add("DScrollPanel")

		scroll:SetPos(0, 0)
		scroll:SetSize(width, height - Sc(36))

		local bar = scroll:GetVBar()

		bar:SetWide(Sc(4))
		bar.Paint = function() end
		bar.btnUp.Paint = function() end
		bar.btnDown.Paint = function() end
		bar.btnGrip.Paint = function(_, w, h)
			draw.RoundedBox(Sc(2), 0, 0, w, h, Color(255, 255, 255, 60))
		end

		local function Row(entry, kind)
			local row = scroll:Add("DPanel")

			row:Dock(TOP)
			row:DockMargin(0, 0, Sc(10), Sc(6))
			row:SetTall(Sc(46))
			row.Paint = function(_, w, h)
				draw.RoundedBox(math.max(Sc(6), 4), 0, 0, w, h, Color(12, 13, 15, 220))
				NETWORK.util.DrawRoundedBorder(0, 0, w, h, math.max(Sc(6), 4), math.max(Sc(1), 1),
					Color(255, 255, 255, 26))
				draw.SimpleText(entry.name, "nwInvName", Sc(14), h * 0.5 - Sc(8), theme.text,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				draw.SimpleText(kind == "fixture" and "оборудование" or ("товар × " .. entry.amount),
					"nwInvKey", Sc(14), h * 0.5 + Sc(9), theme.textFaint, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
			end

			local buy = Button(row, 0, Sc(6), Sc(150), Sc(34), "Купить · " .. entry.cost, "coin", true,
				function()
					self:Send(kind == "fixture" and "buyFixture" or "buyGoods", {id = entry.id})
				end)

			row.PerformLayout = function(this, w)
				buy:SetPos(w - Sc(160), Sc(6))
			end
		end

		for _, entry in ipairs(S.fixtures) do
			Row(entry, "fixture")
		end

		for _, entry in ipairs(S.goods) do
			Row(entry, "goods")
		end

		self.PaintTab = function(_, w, h)
			draw.SimpleText("Доставка " .. S.deliverTime .. " с  ·  у вас " ..
				NETWORK.currency.Format(data.tokens or 0), "nwHudSmall", w, h - Sc(12),
				theme.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	else
		local cursor = Sc(10)
		local bAny = false

		for _, entry in ipairs(S.fixtures) do
			local count = (data.fixtures or {})[entry.id] or 0

			if (count > 0) then
				bAny = true

				Button(body, 0, cursor, Sc(320), Sc(36), entry.name .. " (" .. count .. " шт.)", "grid",
					true, function()
						self:Send("place", {id = entry.id})
						self:Close()
					end)

				cursor = cursor + Sc(44)
			end
		end

		self.PaintTab = function(_, w, h)
			if (!bAny) then
				draw.SimpleText("Купленного оборудования нет — закажите во вкладке «Заказ».",
					"nwHudSmall", 0, Sc(20), theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			else
				draw.SimpleText("Выберите — появится зелёная модель: ЛКМ поставить, колесо повернуть.",
					"nwHudSmall", 0, h - Sc(12), theme.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			end
		end
	end
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, 1, 8)
	self:SetAlpha(math.Round(self.alpha * 255))
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local radius = math.max(Sc(10), 6)

	NETWORK.gui.DrawHoloScreen(self, 0, 0, width, height, 1, Color(196, 160, 246))

	draw.SimpleText(NETWORK.util.Upper(L("bizScreenTitle")), "nwInvKey", Sc(20), Sc(20),
		ColorAlpha(theme.textFaint, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText("БИЗНЕС-ТЕРМИНАЛ", "nwInvTitle", Sc(20), Sc(42), theme.text,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText((self.data and self.data.name) or "", "nwInvSub", width - Sc(60), Sc(42),
		theme.combine, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	surface.SetDrawColor(theme.combine.r, theme.combine.g, theme.combine.b, 220)
	surface.DrawRect(Sc(20), Sc(56), Sc(28), math.max(Sc(2), 2))

	surface.SetDrawColor(255, 255, 255, 14)
	surface.DrawRect(Sc(20), Sc(106), width - Sc(40), 1)

	draw.SimpleText("ESC — закрыть", "nwHudSmall", width - Sc(20), height - Sc(12),
		theme.textFaint, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

vgui.Register("nwShopPanel", PANEL, "EditablePanel")
