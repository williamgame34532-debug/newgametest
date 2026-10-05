local function CountMembers(group)
	local total = 0
	local online = 0
	local players = player.GetAll()

	for key in pairs(group.members or {}) do
		total = total + 1

		for _, target in ipairs(players) do
			if (target:HasCharacter() and
				tostring(target:GetCharacterID()) == key) then
				online = online + 1

				break
			end
		end
	end

	return total, online
end

local function IsOnline(key)
	for _, target in ipairs(player.GetAll()) do
		if (target:HasCharacter() and
			tostring(target:GetCharacterID()) == key) then
			return true
		end
	end

	return false
end

local function SortMembers(group)
	local list = {}

	for key, member in pairs(group.members or {}) do
		list[#list + 1] = {
			key = key,
			member = member,
			bLeader = key == group.leader,
			bOnline = IsOnline(key)
		}
	end

	table.sort(list, function(a, b)
		if (a.bLeader != b.bLeader) then
			return a.bLeader
		end

		if (a.bOnline != b.bOnline) then
			return a.bOnline
		end

		return string.lower(a.member.name or "") < string.lower(b.member.name or "")
	end)

	return list
end

local function DrawTag(text, x, y, width, accent)
	local Sc = NETWORK.util.Scale
	local height = Sc(24)

	NETWORK.util.DrawHGradient(x, y, width, height, ColorAlpha(accent, 90),
		ColorAlpha(accent, 0))

	surface.SetDrawColor(accent.r, accent.g, accent.b, 250)
	surface.DrawRect(x, y, math.max(Sc(3), 2), height)

	draw.SimpleText(NETWORK.util.Upper(text), "nwInvHeader", x + Sc(12),
		y + math.Round(height * 0.5), NETWORK.theme.text, TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end

local function BuildField(page, caption, accent)
	local Sc = NETWORK.util.Scale
	local panel = page:Add("DPanel")

	panel.caption = caption
	panel.Paint = function(this, width, height)
		NETWORK.gui.DrawBlackGlass(this, 0, 0, width, height, 1, Sc(14))

		if (this.caption) then
			DrawTag(L(this.caption), Sc(14), Sc(12), math.min(Sc(260), width - Sc(28)),
				accent or NETWORK.theme.hover)
		end
	end

	return panel
end

local function StyleScroll(scroll)
	local Sc = NETWORK.util.Scale
	local bar = scroll:GetVBar()

	bar:SetWide(Sc(4))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, width, height)
		draw.RoundedBox(math.max(Sc(2), 2), 0, 0, width, height,
			Color(255, 255, 255, 70))
	end

	return scroll
end

local function BuildIconPicker(parent, x, y, width, chosen, callback)
	local Sc = NETWORK.util.Scale
	local size = Sc(38)
	local gap = Sc(6)
	local perRow = math.max(math.floor((width + gap) / (size + gap)), 1)

	for index, icon in ipairs(NETWORK.group.icons) do
		local column = (index - 1) % perRow
		local row = math.floor((index - 1) / perRow)
		local button = parent:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:SetSize(size, size)
		button:SetPos(x + column * (size + gap), y + row * (size + gap))
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover,
				panel:IsHovered() and 1 or 0, 10)
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			callback(icon)
		end
		button.Paint = function(panel, panelWidth, panelHeight)
			local theme = NETWORK.theme
			local bActive = chosen() == icon
			local hover = NETWORK.util.EaseInOut(panel.hover)
			local radius = math.max(Sc(6), 4)

			draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight,
				Color(0, 0, 0, 150))

			if (bActive or hover > 0.01) then
				draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight,
					ColorAlpha(theme.hover, bActive and 46 or 20 * hover))
			end

			NETWORK.util.DrawRoundedBorder(0, 0, panelWidth, panelHeight, radius, 1,
				ColorAlpha(bActive and theme.hover or Color(255, 255, 255),
				bActive and 230 or (24 + 40 * hover)))

			surface.SetMaterial(NETWORK.util.GetMaterial(icon))
			surface.SetDrawColor(255, 255, 255,
				bActive and 255 or (190 + 65 * hover))
			surface.DrawTexturedRect(math.Round((panelWidth - 16) * 0.5),
				math.Round((panelHeight - 16) * 0.5) - (bActive and 1 or 0),
				16, 16)
		end
	end

	return math.ceil(#NETWORK.group.icons / perRow) * (size + gap)
end

local function BuildButton(parent, data)
	local Sc = NETWORK.util.Scale
	local button = parent:Add("DButton")

	button:SetText("")
	button:SetCursor("hand")
	button.hover = 0
	button.Think = function(panel)
		panel.hover = NETWORK.util.Approach(panel.hover,
			panel:IsHovered() and 1 or 0, 12)
	end
	button.OnCursorEntered = function()
		NETWORK.sound.Hover()
	end
	button.DoClick = function()
		NETWORK.sound.Click()

		data.action()
	end

	button.Paint = function(panel, width, height)
		local theme = NETWORK.theme
		local util = NETWORK.util
		local hover = util.EaseInOut(panel.hover)
		local accent = data.accent or theme.hover
		local base = data.bDanger and theme.danger or accent
		local radius = math.max(Sc(8), 5)
		local strength = data.bPrimary and (0.6 + 0.4 * hover) or hover

		draw.RoundedBox(radius, 0, 0, width, height, Color(0, 0, 0, 160))

		if (hover > 0.01) then
			draw.RoundedBox(radius, 0, 0, width, height, ColorAlpha(base, 30 * hover))
		end

		util.DrawRoundedBorder(0, 0, width, height, radius, 1,
			ColorAlpha(base, 60 + 170 * strength))

		local glyph = Sc(16)
		local textX = Sc(16) + glyph + Sc(10)

		NETWORK.gui.DrawGlyph(data.glyph or "dot", Sc(16),
			math.Round((height - glyph) * 0.5), glyph,
			ColorAlpha(base, 190 + 65 * hover))

		draw.SimpleText(NETWORK.util.Upper(L(data.label)), "nwHudSmall", textX,
			math.Round(height * 0.5),
			ColorAlpha(data.bDanger and theme.danger or theme.text, 225 + 30 * hover),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	return button
end

local function BuildEntry(parent, placeholder)
	local theme = NETWORK.theme
	local Sc = NETWORK.util.Scale
	local entry = NETWORK.gui.BindEntry(parent:Add("DTextEntry"))

	entry:SetFont("nwChatSmall")
	entry:SetDrawLanguageID(false)
	entry:SetAllowNonAsciiCharacters(true)
	entry:SetPaintBackground(false)
	entry:SetTextColor(theme.text)
	entry:SetCursorColor(theme.hover)
	entry:SetTextInset(Sc(12), 0)
	entry.Paint = function(panel, width, height)
		local bFocus = panel:HasFocus()
		local radius = math.max(Sc(6), 4)

		draw.RoundedBox(radius, 0, 0, width, height, Color(0, 0, 0, bFocus and 190 or 150))

		NETWORK.util.DrawRoundedBorder(0, 0, width, height, radius, 1,
			bFocus and ColorAlpha(theme.hover, 220) or Color(255, 255, 255, 28))

		if (panel:GetValue() == "" and !bFocus) then
			draw.SimpleText(L(placeholder), "nwChatSmall", Sc(12),
				math.Round(height * 0.5), theme.textFaint, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end

		panel:DrawTextEntryText(theme.text, theme.accentDeep, theme.hover)
	end

	return entry
end

local function BuildCreation(page, menu, width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local formWidth = math.min(Sc(420), width)
	local formX = math.Round((width - formWidth) * 0.5)
	local form = page:Add("DPanel")

	form:SetPos(formX, Sc(40))
	form:SetSize(formWidth, height - Sc(80))
	form.Paint = function(panel, panelWidth, panelHeight)
		NETWORK.gui.DrawBlackGlass(panel, 0, 0, panelWidth, panelHeight, 1, Sc(16))

		DrawTag(L("groupCreateTitle"), Sc(24), Sc(16), panelWidth - Sc(48), theme.hover)

		local lineY = Sc(56)

		for _, line in ipairs(NETWORK.util.WrapText(L("groupCreateHint"),
			"nwChatSmall", panelWidth - Sc(48), 3)) do
			draw.SimpleText(line, "nwChatSmall", Sc(24), lineY, theme.textDim,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			lineY = lineY + Sc(18)
		end

		NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(L("groupStyleColor")),
			"nwHudSmall", Sc(24), Sc(172), ColorAlpha(theme.textFaint, 220),
			Sc(4), TEXT_ALIGN_CENTER)
	end

	local entry = BuildEntry(form, "groupNamePlaceholder")

	entry:SetPos(Sc(24), Sc(124))
	entry:SetSize(formWidth - Sc(48), Sc(36))

	local icon = NETWORK.group.pendingIcon or NETWORK.group.icons[1]

	local iconHeight = BuildIconPicker(form, Sc(24), Sc(190),
		formWidth - Sc(48), function()
			return icon
		end, function(chosen)
			icon = chosen
			NETWORK.group.pendingIcon = chosen

			menu:RefreshTab()
		end)

	local create = BuildButton(form, {
		label = "groupCreateButton",
		glyph = "plus",
		bPrimary = true,
		action = function()
			NETWORK.group.Send("create", {
				name = entry:GetValue(),
				icon = icon
			})
		end
	})

	create:SetPos(Sc(24), Sc(190) + iconHeight + Sc(16))
	create:SetSize(formWidth - Sc(48), Sc(42))
end

local function BuildStyleOverlay(page, menu, style, accent, width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme

	local function Send(field, value)
		local payload = {
			color = style.color,
			layout = style.layout,
			messages = style.messages,
			bGradient = style.bGradient
		}

		payload[field] = value

		NETWORK.group.Send("style", payload)
	end

	local shade = page:Add("DButton")

	shade:SetText("")
	shade:SetPos(0, 0)
	shade:SetSize(width, height)
	shade.DoClick = function()
		NETWORK.group.styleMode = false

		menu:RefreshTab()
	end
	shade.Paint = function(panel, panelWidth, panelHeight)
		surface.SetDrawColor(0, 0, 0, 190)
		surface.DrawRect(0, 0, panelWidth, panelHeight)
	end

	local cardWidth = math.min(Sc(460), width - Sc(40))
	local cardHeight = math.min(Sc(420), height - Sc(40))
	local card = page:Add("DPanel")

	card:SetSize(cardWidth, cardHeight)
	card:SetPos(math.Round((width - cardWidth) * 0.5),
		math.Round((height - cardHeight) * 0.5))
	card.Paint = function(panel, panelWidth, panelHeight)
		NETWORK.gui.DrawBlackGlass(panel, 0, 0, panelWidth, panelHeight, 1, Sc(16))

		DrawTag(L("groupStyle"), Sc(24), Sc(14), panelWidth - Sc(48), accent)

		NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(L("groupStyleColor")),
			"nwHudSmall", Sc(24), Sc(64), ColorAlpha(theme.textDim, 235),
			Sc(3), TEXT_ALIGN_CENTER)

		NETWORK.util.DrawTextSpaced(NETWORK.util.Upper(L("groupStyleOther")),
			"nwHudSmall", Sc(24), Sc(144), ColorAlpha(theme.textDim, 235),
			Sc(3), TEXT_ALIGN_CENTER)
	end

	for index, entry in ipairs(NETWORK.group.palette) do
		local size = Sc(34)
		local swatch = card:Add("DButton")

		swatch:SetText("")
		swatch:SetCursor("hand")
		swatch:SetSize(size, size)
		swatch:SetPos(Sc(24) + (index - 1) * (size + Sc(10)), Sc(86))
		swatch.DoClick = function()
			NETWORK.sound.Click()
			Send("color", entry.id)
		end
		swatch.Paint = function(panel, panelWidth, panelHeight)
			local bActive = style.color == entry.id
			local radius = math.max(Sc(6), 4)

			draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight,
				ColorAlpha(entry.color, panel:IsHovered() or bActive and 255 or 210))

			if (bActive) then

				NETWORK.util.DrawCircle(math.Round(panelWidth * 0.5),
					math.Round(panelHeight * 0.5), math.max(Sc(4), 3),
					Color(255, 255, 255, 245))
			end
		end
	end

	local toggles = {
		{
			label = "groupStyleGradient",
			value = function()
				return style.bGradient and L("groupStyleOn") or L("groupStyleOff")
			end,
			action = function()
				Send("bGradient", !style.bGradient)
			end
		},
		{
			label = "groupStyleLayout",
			value = function()
				return L("groupStyleLayout" ..
					(style.layout == "chat" and "Chat" or "List"))
			end,
			action = function()
				Send("layout", style.layout == "chat" and "list" or "chat")
			end
		},
		{
			label = "groupStyleMessages",
			value = function()
				return L("groupStyleMsg" ..
					string.upper(string.sub(style.messages, 1, 1)) ..
					string.sub(style.messages, 2))
			end,
			action = function()
				local list = NETWORK.group.messageStyles
				local following = list[1]

				for position, id in ipairs(list) do
					if (id == style.messages) then
						following = list[position % #list + 1]

						break
					end
				end

				Send("messages", following)
			end
		}
	}

	for index, data in ipairs(toggles) do
		local button = card:Add("DButton")

		button:SetText("")
		button:SetCursor("hand")
		button:SetPos(Sc(24), Sc(166) + (index - 1) * Sc(48))
		button:SetSize(cardWidth - Sc(48), Sc(40))
		button.hover = 0
		button.Think = function(panel)
			panel.hover = NETWORK.util.Approach(panel.hover,
				panel:IsHovered() and 1 or 0, 12)
		end
		button.DoClick = function()
			NETWORK.sound.Click()

			data.action()
		end
		button.Paint = function(panel, panelWidth, panelHeight)
			local hover = NETWORK.util.EaseInOut(panel.hover)

			local radius = math.max(Sc(8), 5)

			draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight, Color(0, 0, 0, 150))

			if (hover > 0.01) then
				draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight,
					ColorAlpha(accent, 24 * hover))
			end

			NETWORK.util.DrawRoundedBorder(0, 0, panelWidth, panelHeight, radius, 1,
				ColorAlpha(hover > 0.01 and accent or Color(255, 255, 255),
				24 + 150 * hover))

			draw.SimpleText(L(data.label), "nwChatSmall", Sc(14),
				math.Round(panelHeight * 0.5), NETWORK.theme.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			draw.SimpleText(NETWORK.util.Upper(data.value()), "nwHudSmall",
				panelWidth - Sc(14), math.Round(panelHeight * 0.5), accent,
				TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	local close = BuildButton(card, {
		label = "groupStyleClose",
		glyph = "plus",
		accent = accent,
		bPrimary = true,
		action = function()
			NETWORK.group.styleMode = false

			menu:RefreshTab()
		end
	})

	close:SetPos(Sc(24), cardHeight - Sc(58))
	close:SetSize(cardWidth - Sc(48), Sc(42))
end

NETWORK.gui.RegisterTab("group", {
	name = "tabGroup",
	order = 27,
	glyph = "group",

	access = function()
		return NETWORK.group.CanAccess()
	end,

	Build = function(page, menu)
		local Sc = NETWORK.util.Scale
		local theme = NETWORK.theme
		local util = NETWORK.util
		local width = page:GetWide()
		local height = page:GetTall()
		local group = NETWORK.group.own

		if (!group) then
			return BuildCreation(page, menu, width, height)
		end

		local bLeader = NETWORK.group.IsOwnLeader()
		local style = NETWORK.group.GetStyle(group)
		local accent = NETWORK.group.GetColor(group)
		local count, online = CountMembers(group)

		local header = page:Add("DPanel")

		header:SetPos(0, 0)
		header:SetSize(width, Sc(84))
		header.Paint = function(panel, panelWidth, panelHeight)
			NETWORK.gui.DrawBlackGlass(panel, 0, 0, panelWidth, panelHeight, 1, Sc(16))

			util.DrawHGradient(Sc(16), 1, math.Round(panelWidth * 0.6), panelHeight - 2,
				ColorAlpha(accent, style.bGradient and 50 or 18), ColorAlpha(accent, 0))

			draw.RoundedBox(math.max(Sc(2), 2), 0, Sc(16), math.max(Sc(3), 2),
				panelHeight - Sc(32), ColorAlpha(accent, 245))

			local box = Sc(48)
			local boxY = math.Round((panelHeight - box) * 0.5)

			util.DrawCircle(Sc(20) + math.Round(box * 0.5), boxY + math.Round(box * 0.5),
				math.Round(box * 0.5), Color(0, 0, 0, 170))
			util.DrawCircle(Sc(20) + math.Round(box * 0.5), boxY + math.Round(box * 0.5),
				math.Round(box * 0.5), ColorAlpha(accent, 40))
			util.DrawArc(Sc(20) + math.Round(box * 0.5), boxY + math.Round(box * 0.5),
				math.Round(box * 0.5), math.max(Sc(2), 2), 1, ColorAlpha(accent, 230), 64)

			surface.SetMaterial(util.GetMaterial(group.icon or
				"icon16/group.png"))
			surface.SetDrawColor(255, 255, 255, 252)
			surface.DrawTexturedRect(Sc(20) + math.Round((box - 16) * 0.5),
				boxY + math.Round((box - 16) * 0.5), 16, 16)

			local textX = Sc(20) + box + Sc(16)

			util.DrawSimpleTextShadow(group.name or "", "nwTitle", textX,
				Sc(30), theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 2)

			draw.SimpleText(L("groupMembers") .. ": " .. count .. "/" ..
				(group.size or 0), "nwHudSmall", textX, Sc(54), theme.textDim,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			surface.SetFont("nwHudSmall")

			local statusX = textX + surface.GetTextSize(L("groupMembers") ..
				": " .. count .. "/" .. (group.size or 0)) + Sc(20)
			local dot = math.max(Sc(5), 4)

			util.DrawCircle(statusX, Sc(54), dot * 0.5,
				ColorAlpha(online > 0 and theme.positive or theme.textFaint, 245))

			draw.SimpleText(L("groupOnline") .. ": " .. online, "nwHudSmall",
				statusX + dot + Sc(6), Sc(54),
				online > 0 and theme.positive or theme.textFaint,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

			local barWidth = math.min(Sc(220), panelWidth * 0.25)
			local barX = panelWidth - Sc(24) - barWidth

			util.DrawTextSpaced(util.Upper(L("groupMembers")), "nwHudSmall",
				barX, Sc(34), ColorAlpha(theme.textFaint, 220), Sc(3),
				TEXT_ALIGN_CENTER)

			util.DrawProgressBar(barX, Sc(52), barWidth, math.max(Sc(4), 3),
				math.Clamp(count / math.max(group.size or 1, 1), 0, 1), accent,
				1, count >= (group.size or 1) * 0.85)
		end

		local bChatFirst = style.layout == "chat"
		local top = Sc(98)
		local gap = Sc(14)
		local listWidth = math.Round((width - gap) * 0.42)
		local chatWidth = width - listWidth - gap
		local listX = bChatFirst and (chatWidth + gap) or 0
		local chatX = bChatFirst and 0 or (listWidth + gap)
		local actionHeight = bLeader and Sc(200) or 0
		local listHeight = height - top - actionHeight -
			(bLeader and gap or 0)

		local listField = BuildField(page, "groupMembers", accent)

		listField:SetPos(listX, top)
		listField:SetSize(listWidth, listHeight)

		local scroll = StyleScroll(listField:Add("DScrollPanel"))

		scroll:SetPos(Sc(10), Sc(38))
		scroll:SetSize(listWidth - Sc(20), listHeight - Sc(48))
		scroll.Paint = function() end

		for _, data in ipairs(SortMembers(group)) do
			local key = data.key
			local member = data.member
			local row = scroll:Add("DButton")

			row:SetText("")
			row:Dock(TOP)
			row:DockMargin(0, 0, Sc(8), Sc(4))
			row:SetTall(Sc(50))
			row:SetCursor(bLeader and key != group.leader and "hand" or "arrow")
			row.hover = 0
			row.Think = function(panel)
				panel.hover = NETWORK.util.Approach(panel.hover,
					panel:IsHovered() and 1 or 0, 12)
			end
			row.DoClick = function(panel)

				panel:DoRightClick()
			end
			row.DoRightClick = function()
				if (!bLeader or key == group.leader) then
					return
				end

				local menuPanel = NETWORK.gui.ContextMenu(accent)

				menuPanel:AddOption(L("groupSetRole"), function()
					NETWORK.gui.Prompt(L("groupSetRole"), L("groupSetRoleHint"),
						member.role or "", function(text)
							NETWORK.group.Send("role", {key = key, role = text})
						end)
				end):SetGlyph("list")

				menuPanel:AddOption(L("groupTransfer"), function()
					NETWORK.gui.Confirm(L("groupTransfer"),
						L("groupTransferAsk", member.name or "?"), function()
							NETWORK.group.Send("transfer", {key = key})
						end)
				end):SetGlyph("shield")

				menuPanel:AddOption(L("groupKick"), function()
					NETWORK.group.Send("kick", {key = key})
				end):SetGlyph("minus"):SetDanger(true)

				menuPanel:Open()
			end
			row.Paint = function(panel, panelWidth, panelHeight)
				local hover = util.EaseInOut(panel.hover)
				local bBoss = data.bLeader
				local bOnline = data.bOnline
				local base = bBoss and accent or theme.textDim
				local radius = math.max(Sc(8), 5)

				draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight, Color(0, 0, 0, 140))

				if (bBoss or hover > 0.01) then
					draw.RoundedBox(radius, 0, 0, panelWidth, panelHeight,
						ColorAlpha(accent, (bBoss and 22 or 0) + 22 * hover))
				end

				draw.RoundedBox(math.max(Sc(3), 2), 0,
					bBoss and Sc(6) or Sc(12), math.max(Sc(3), 2),
					panelHeight - (bBoss and Sc(12) or Sc(24)),
					ColorAlpha(base, bBoss and 245 or (100 + 80 * hover)))

				local dotX = Sc(16)
				local dotY = math.Round(panelHeight * 0.5)

				if (bOnline) then
					util.DrawCircle(dotX, dotY, math.max(Sc(5), 4),
						ColorAlpha(theme.positive, 60))
				end

				util.DrawCircle(dotX, dotY, math.max(Sc(3), 2),
					bOnline and theme.positive or
					ColorAlpha(theme.textFaint, 170))

				local textX = dotX + Sc(14)
				local bRole = member.role and member.role != ""

				draw.SimpleText(member.name or "?", "nwChatSmall", textX,
					dotY - (bRole and Sc(9) or 0),
					bOnline and theme.text or theme.textDim, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)

				if (bRole) then
					surface.SetFont("nwHudSmall")

					local roleWidth = surface.GetTextSize(member.role) + Sc(16)

					draw.RoundedBox(math.max(Sc(4), 3), textX, dotY + Sc(2),
						roleWidth, Sc(16),
						Color(base.r, base.g, base.b, 40))

					draw.SimpleText(member.role, "nwHudSmall",
						textX + math.Round(roleWidth * 0.5), dotY + Sc(10),
						theme.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end

				if (bBoss) then
					draw.SimpleText(util.Upper(L("groupLeader")), "nwHudSmall",
						panelWidth - Sc(14), dotY, accent, TEXT_ALIGN_RIGHT,
						TEXT_ALIGN_CENTER)
				elseif (bLeader and hover > 0.01) then
					draw.SimpleText(util.Upper(L("groupRowHint")), "nwHudSmall",
						panelWidth - Sc(14), dotY,
						ColorAlpha(theme.textFaint, 245 * hover),
						TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
				end
			end
		end

		local chatField = BuildField(page, "groupChatCaption", accent)

		chatField:SetPos(chatX, top)
		chatField:SetSize(chatWidth, height - top)

		local chatLog = StyleScroll(chatField:Add("DScrollPanel"))

		chatLog:SetPos(Sc(10), Sc(38))
		chatLog:SetSize(chatWidth - Sc(20), height - top - Sc(96))
		chatLog.Paint = function() end

		local history = NETWORK.group.chat or {}

		if (#history == 0) then
			local empty = chatLog:Add("DPanel")

			empty:Dock(TOP)
			empty:DockMargin(0, Sc(40), 0, 0)
			empty:SetTall(Sc(44))
			empty.Paint = function(panel, panelWidth, panelHeight)
				draw.SimpleText(L("groupChatEmpty"), "nwChatSmall",
					math.Round(panelWidth * 0.5),
					math.Round(panelHeight * 0.5) - Sc(8), theme.textFaint,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

				draw.SimpleText(L("groupChatEmptyHint"), "nwHudSmall",
					math.Round(panelWidth * 0.5),
					math.Round(panelHeight * 0.5) + Sc(10),
					ColorAlpha(theme.textFaint, 150), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)
			end
		end

		local ownName = LocalPlayer():GetCharacterName()

		for _, entry in ipairs(history) do
			local bOwn = entry.name == ownName
			local bCompact = style.messages == "compact"
			local bPlate = style.messages == "plate"
			local lines = util.WrapText(entry.text, "nwChatSmall",
				chatWidth - Sc(56), 6)
			local line = chatLog:Add("DPanel")

			line:Dock(TOP)
			line:DockMargin(Sc(4), Sc(6), Sc(10), 0)
			line:SetTall(bCompact and Sc(22) or (Sc(22) + #lines * Sc(16)))
			line.Paint = function(panel, panelWidth, panelHeight)
				local padX = Sc(12)

				if (bPlate) then
					draw.RoundedBox(math.max(Sc(8), 5), 0, 0, panelWidth,
						panelHeight, Color(0, 0, 0, 140))

					if (bOwn) then
						draw.RoundedBox(math.max(Sc(8), 5), 0, 0, panelWidth,
							panelHeight, ColorAlpha(accent, 22))
					end
				end

				if (bOwn) then
					draw.RoundedBox(math.max(Sc(2), 2), 0, Sc(3),
						math.max(Sc(2), 2), panelHeight - Sc(6),
						ColorAlpha(accent, 210))
				end

				if (bCompact) then
					surface.SetFont("nwHudSmall")

					local nameText = entry.name .. ":"
					local nameSize = surface.GetTextSize(nameText)

					draw.SimpleText(nameText, "nwHudSmall", padX,
						math.Round(panelHeight * 0.5),
						bOwn and accent or theme.textDim, TEXT_ALIGN_LEFT,
						TEXT_ALIGN_CENTER)

					draw.SimpleText(lines[1] or "", "nwChatSmall",
						padX + nameSize + Sc(8),
						math.Round(panelHeight * 0.5), theme.text,
						TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

					return
				end

				draw.SimpleText(entry.name, "nwHudSmall", padX, Sc(4),
					bOwn and accent or theme.textDim, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_TOP)

				draw.SimpleText(entry.time or "", "nwHudSmall",
					panelWidth - Sc(12), Sc(4), theme.textFaint,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

				local textY = Sc(20)

				for _, text in ipairs(lines) do
					draw.SimpleText(text, "nwChatSmall", padX, textY,
						theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

					textY = textY + Sc(16)
				end
			end
		end

		timer.Simple(0, function()
			if (!IsValid(chatLog)) then
				return
			end

			local children = chatLog:GetCanvas():GetChildren()

			chatLog:ScrollToChild(children[#children] or chatLog)
		end)

		local chatEntry = BuildEntry(chatField, "groupChatPlaceholder")

		chatEntry:SetPos(Sc(10), height - top - Sc(52))
		chatEntry:SetSize(chatWidth - Sc(20), Sc(38))
		chatEntry.OnEnter = function(panel)
			local text = panel:GetValue()

			panel:SetValue("")

			if (string.Trim(text) == "") then
				return
			end

			NETWORK.group.SendChat(text)
			panel:RequestFocus()
		end

		NETWORK.group.unread = 0

		if (!bLeader) then
			return
		end

		local actions = {
			{label = "groupInvite", glyph = "person", accent = accent, action = function()
				NETWORK.gui.Prompt(L("groupInvite"), L("groupInviteHint"), "",
					function(text)
						NETWORK.group.Send("invite", {name = text})
					end)
			end},
			{label = "groupSize", glyph = "sliders", accent = accent, action = function()
				NETWORK.gui.Prompt(L("groupSize"), L("groupSizeHint"),
					tostring(group.size or 0), function(text)
						NETWORK.group.Send("size", {size = tonumber(text)})
					end)
			end},
			{label = "groupShare", glyph = "backpack", accent = accent, action = function()
				NETWORK.group.Send("share")
			end},
			{label = "groupStyle", glyph = "gear", accent = accent, action = function()
				NETWORK.group.styleMode = true

				menu:RefreshTab()
			end},
			{label = "groupDisband", glyph = "minus", action = function()
				NETWORK.gui.Confirm(L("groupDisband"), L("groupDisbandAsk"),
					function()
						NETWORK.group.Send("disband")
					end)
			end, bDanger = true}
		}

		local actionField = BuildField(page, "groupActions", accent)

		actionField:SetPos(listX, top + listHeight + gap)
		actionField:SetSize(listWidth, actionHeight)

		local columnWidth = math.Round((listWidth - Sc(30)) * 0.5)

		for index, data in ipairs(actions) do
			local button = BuildButton(actionField, data)
			local column = (index - 1) % 2
			local row = math.floor((index - 1) / 2)

			button:SetSize(columnWidth, Sc(40))
			button:SetPos(Sc(10) + column * (columnWidth + Sc(10)),
				Sc(38) + row * Sc(48))
		end

		local hint = actionField:Add("DLabel")

		hint:SetPos(Sc(12), actionHeight - Sc(24))
		hint:SetSize(listWidth - Sc(24), Sc(18))
		hint:SetFont("nwHudSmall")
		hint:SetTextColor(theme.textFaint)
		hint:SetText(L("groupShareHint"))

		if (NETWORK.group.styleMode) then
			BuildStyleOverlay(page, menu, style, accent, width, height)
		end
	end
})
