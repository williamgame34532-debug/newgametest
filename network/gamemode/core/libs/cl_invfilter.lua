NETWORK.gui = NETWORK.gui or {}

NETWORK.gui.filter = NETWORK.gui.filter or {text = "", category = "all"}

NETWORK.gui.filterOrder = {"all", "weapon", "food", "medical", "clothing",
	"tool", "misc"}

function NETWORK.gui.GetFilterDim(item)
	local filter = NETWORK.gui.filter

	if (!item) then
		return 1
	end

	if (filter.category != "all") then
		local base = NETWORK.item.Get and NETWORK.item.Get(item.uniqueID or "")
		local category = (base and base.category) or item.category or "misc"

		if (category != filter.category) then
			return 0.22
		end
	end

	if (filter.text == "") then
		return 1
	end

	local name = NETWORK.util.Lower(NETWORK.item.GetName(item) or "")
	local description = NETWORK.util.Lower(NETWORK.item.GetDescription and
		NETWORK.item.GetDescription(item) or "")

	if (string.find(name, filter.text, 1, true) or
		string.find(description, filter.text, 1, true)) then
		return 1
	end

	return 0.22
end

function NETWORK.gui.SetFilterText(text)
	NETWORK.gui.filter.text = NETWORK.util.Lower(string.Trim(text or ""))
end

function NETWORK.gui.SetFilterCategory(id)
	NETWORK.gui.filter.category = id or "all"
end

function NETWORK.gui.ResetFilter()
	NETWORK.gui.filter.text = ""
	NETWORK.gui.filter.category = "all"
end

function NETWORK.gui.BuildFilterBar(parent, x, y, width, chips)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util

	local entryWidth = math.min(Sc(220), math.floor(width * 0.45))
	local entryHeight = Sc(28)

	local entry = NETWORK.gui.BindEntry(parent:Add("DTextEntry"))

	entry:SetSize(entryWidth, entryHeight)
	entry:SetPos(x + width - entryWidth, y)
	entry:SetFont("nwInvBody")
	entry:SetDrawLanguageID(false)
	entry:SetPaintBackground(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.combine)
	entry:SetHighlightColor(theme.combineDeep)
	entry:SetTextInset(Sc(28), 0)
	entry:SetKeyboardInputEnabled(true)
	entry:SetMouseInputEnabled(true)
	entry:SetUpdateOnType(true)

	entry.OnValueChange = function(panel, value)
		NETWORK.gui.SetFilterText(value)
	end

	entry.OnMousePressed = function(panel)
		panel:RequestFocus()
	end

	entry.Paint = function(panel, panelWidth, panelHeight)
		local bFocus = panel:HasFocus()
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight, Color(10, 11, 13, 230))

		util.DrawRoundedBorder(0, 0, panelWidth, panelHeight, radius, math.max(Sc(1), 1),
			bFocus and ColorAlpha(theme.combine, 210) or Color(255, 255, 255, 30))

		draw.SimpleText("⌕", "nwInvBody", Sc(9), math.Round(panelHeight * 0.5) - 1,
			ColorAlpha(theme.textFaint, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		if (panel:GetValue() == "") then
			draw.SimpleText(L("invSearch"), "nwInvBody", Sc(28),
				math.Round(panelHeight * 0.5), ColorAlpha(theme.textFaint, 170),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(theme.text, theme.combineDeep, theme.combine)
	end

	local present = {}

	for _, source in ipairs({NETWORK.inventory.state.items,
		NETWORK.inventory.state.storage}) do
		for _, item in pairs(source or {}) do
			local base = NETWORK.item.Get and NETWORK.item.Get(item.uniqueID or "")

			present[(base and base.category) or item.category or "misc"] = true
		end
	end

	local chipParent = chips and chips.parent or parent
	local cursor = chips and chips.x or x
	local chipY = chips and chips.y or (y + entryHeight + Sc(10))
	local chipHeight = Sc(22)

	for _, id in ipairs(NETWORK.gui.filterOrder) do
		if (id == "all" or present[id]) then
			local label = L("invCat" .. string.upper(string.sub(id, 1, 1)) ..
				string.sub(id, 2))

			surface.SetFont("nwInvKey")

			local textWidth = surface.GetTextSize(label)
			local button = chipParent:Add("DButton")

			button:SetText("")
			button:SetCursor("hand")
			button:SetSize(textWidth + Sc(20), chipHeight)
			button:SetPos(cursor, chipY)
			button.hover = 0
			button.Think = function(panel)
				panel.hover = util.Approach(panel.hover, panel:IsHovered() and 1 or 0, 12)
			end
			button.DoClick = function()
				NETWORK.gui.SetFilterCategory(id)
				NETWORK.sound.Click()
			end
			button.Paint = function(panel, panelWidth, panelHeight)
				local bOn = NETWORK.gui.filter.category == id
				local radius = math.max(Sc(5), 3)
				local hover = panel.hover

				if (bOn) then
					draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight,
						ColorAlpha(theme.combine, 40))
				elseif (hover > 0.01) then
					draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight,
						Color(255, 255, 255, 10 * hover))
				end

				util.DrawRoundedBorder(0, 0, panelWidth, panelHeight, radius,
					math.max(Sc(1), 1), bOn and ColorAlpha(theme.combine, 220) or
					Color(255, 255, 255, 34 + 40 * hover))

				draw.SimpleText(label, "nwInvKey", math.Round(panelWidth * 0.5),
					math.Round(panelHeight * 0.5), bOn and theme.text or
					ColorAlpha(theme.textDim, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end

			cursor = cursor + button:GetWide() + Sc(6)
		end
	end

	if (chips) then
		return entryHeight
	end

	return chipY - y + chipHeight
end

function NETWORK.gui.PaintWeightBar(x, y, width, height)
	local theme = NETWORK.theme
	local current = NETWORK.inventory.GetWeight()
	local maximum = math.max(NETWORK.inventory.MaxWeightFor and
		NETWORK.inventory.MaxWeightFor(LocalPlayer()) or NETWORK.inventory.maxWeight, 1)
	local fraction = math.Clamp(current / maximum, 0, 1)
	local color = theme.accent

	if (current > maximum) then
		color = theme.danger
	elseif (fraction > 0.8) then
		color = theme.warning
	end

	surface.SetDrawColor(255, 255, 255, 18)
	surface.DrawRect(x, y, width, height)

	surface.SetDrawColor(color.r, color.g, color.b, 235)
	surface.DrawRect(x, y, math.Round(width * fraction), height)
end
