local function Palette(panel)
	return NETWORK.cmbterm.GetPalette(panel.entity)
end

local function Kind(entity)
	return IsValid(entity) and entity:GetClass() == "nw_cwuterminal" and "cwu" or "alliance"
end

local function Draft(panel, key, value)
	panel.svcDraft = panel.svcDraft or {}

	if (value != nil) then
		panel.svcDraft[key] = value
	end

	return panel.svcDraft[key]
end

local function Entry(panel, key, x, y, width, height, placeholder, onEnter)
	local entry = panel:AddEntry(x, y, width, height, placeholder, onEnter or function() end)

	entry:SetValue(Draft(panel, key) or "")
	entry.OnChange = function(self)
		Draft(panel, key, self:GetValue())
	end

	return entry
end

local function Row(panel, x, y, width, height, paint, click)
	local button = panel:Add("DButton")

	button:SetText("")
	button:SetPos(x, y)
	button:SetSize(width, height)
	button:SetCursor(click and "hand" or "arrow")
	button.hover = 0
	button.Paint = function(self, rowWidth, rowHeight)
		self.hover = NETWORK.util.Approach(self.hover, self:IsHovered() and 1 or 0, 14)

		local palette = Palette(panel)
		local accent = palette.accent

		if (palette.bRounded) then
			draw.RoundedBox(NETWORK.util.Scale(8), 0, 0, rowWidth, rowHeight,
				ColorAlpha(accent, 10 + 22 * self.hover))
		else
			surface.SetDrawColor(accent.r, accent.g, accent.b, 8 + 20 * self.hover)
			surface.DrawRect(0, 0, rowWidth, rowHeight)

			surface.SetDrawColor(accent.r, accent.g, accent.b, 180)
			surface.DrawRect(0, 0, math.max(NETWORK.util.Scale(3), 2), rowHeight)
		end

		paint(self, rowWidth, rowHeight, palette)
	end

	if (click) then
		button.DoClick = function()
			surface.PlaySound(NETWORK.cmbterm.sounds.select)
			click()
		end
	end

	panel.pageItems[#panel.pageItems + 1] = button

	return button
end

local function Toggle(panel, key, label, x, y, width, default)
	local Sc = NETWORK.util.Scale

	if (Draft(panel, key) == nil) then
		Draft(panel, key, default and true or false)
	end

	return Row(panel, x, y, width, Sc(30), function(self, rowWidth, rowHeight, palette)
		local box = Sc(16)
		local boxY = math.Round((rowHeight - box) * 0.5)

		surface.SetDrawColor(palette.accent.r, palette.accent.g, palette.accent.b, 200)
		surface.DrawOutlinedRect(Sc(10), boxY, box, box, 1)

		if (Draft(panel, key)) then
			surface.DrawRect(Sc(13), boxY + Sc(3), box - Sc(6), box - Sc(6))
		end

		draw.SimpleText(label, "nwTermCaption", Sc(36), math.Round(rowHeight * 0.5),
			palette.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end, function()
		Draft(panel, key, !Draft(panel, key))
	end)
end

local function Combo(panel, x, y, width, height, choices, key)
	local Sc = NETWORK.util.Scale
	local combo = panel:Add("DComboBox")
	local palette = Palette(panel)

	combo:SetPos(x, y)
	combo:SetSize(width, height)
	combo:SetFont("nwTermBody")
	combo:SetTextColor(palette.text)
	combo.Paint = function(self, comboWidth, comboHeight)
		surface.SetDrawColor(palette.accent.r, palette.accent.g, palette.accent.b, 14)
		surface.DrawRect(0, 0, comboWidth, comboHeight)
		surface.SetDrawColor(palette.accent.r, palette.accent.g, palette.accent.b, 110)
		surface.DrawOutlinedRect(0, 0, comboWidth, comboHeight, 1)
	end

	local current = Draft(panel, key)

	for index, choice in ipairs(choices) do
		combo:AddChoice(choice[1], choice[2], current == choice[2] or
			(current == nil and index == 1))
	end

	combo.OnSelect = function(_, _, _, data)
		Draft(panel, key, data)
	end

	if (current == nil and choices[1]) then
		Draft(panel, key, choices[1][2])
	end

	panel.pageItems[#panel.pageItems + 1] = combo

	return combo
end

local function Label(text, font, x, y, color, align)
	draw.SimpleText(text, font or "nwHudSmall", x, y, color, align or TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end

NETWORK.cmbterm.RegisterExtension("idcards", {
	name = "cmbNavIDCards",
	glyph = "person",
	caption = "cmbTileIDCards",
	access = function(client, entity)
		return Kind(entity) == "alliance"
	end,
	Build = function(panel, x, y, width, bottom)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()
		local listWidth = math.floor(width * 0.4)
		local formX = x + listWidth + Sc(24)
		local formWidth = width - listWidth - Sc(24)
		local rowY = y + Sc(26)

		for _, entry in ipairs(data.list or {}) do
			if (rowY + Sc(40) > bottom) then
				break
			end

			Row(panel, x, rowY, listWidth, Sc(40), function(self, rowWidth, rowHeight, palette)
				local bSelected = data.selected == entry.index

				draw.SimpleText(entry.name, "nwTermBody", Sc(14), Sc(13),
					bSelected and palette.accent or palette.text, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
				draw.SimpleText("#" .. entry.cid .. "  ·  " .. entry.faction, "nwHudSmall",
					Sc(14), Sc(30), palette.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

				if (entry.cid != entry.default) then
					draw.SimpleText(L("idOverridden"), "nwHudSmall", rowWidth - Sc(10),
						math.Round(rowHeight * 0.5), palette.accent, TEXT_ALIGN_RIGHT,
						TEXT_ALIGN_CENTER)
				end
			end, function()
				Draft(panel, "idName", entry.name)
				Draft(panel, "idCID", entry.cid)

				panel:Send("idcards", tostring(entry.index))
			end)

			rowY = rowY + Sc(46)
		end

		if (data.selected) then
			local formY = y + Sc(26)

			Entry(panel, "idName", formX, formY + Sc(18), formWidth, Sc(36), L("idFieldName"))

			formY = formY + Sc(66)

			local cid = Entry(panel, "idCID", formX, formY + Sc(18), math.floor(formWidth * 0.4),
				Sc(36), L("idFieldCID"))

			cid:SetNumeric(true)

			formY = formY + Sc(64)

			Toggle(panel, "idRegistry", L("idRegistry"), formX, formY, formWidth, true)
			Toggle(panel, "idRevoke", L("idRevoke"), formX, formY + Sc(34), formWidth, true)

			formY = formY + Sc(80)

			panel:AddAction(L("idIssue"), formX, formY, math.floor(formWidth * 0.55), Sc(38),
				function()
					panel:Send("id_issue", util.TableToJSON({
						target = data.selected,
						name = Draft(panel, "idName") or "",
						cid = Draft(panel, "idCID") or "",
						bRegistry = Draft(panel, "idRegistry") == true,
						bRevoke = Draft(panel, "idRevoke") == true
					}))
				end)

			panel:AddAction(L("idReset"), formX + math.floor(formWidth * 0.55) + Sc(10), formY,
				formWidth - math.floor(formWidth * 0.55) - Sc(10), Sc(38), function()
					panel:Send("id_reset", tostring(data.selected))
				end, Color(232, 84, 76))
		end

		local checkY = bottom - Sc(40)

		Entry(panel, "idCheck", formX, checkY, math.floor(formWidth * 0.6), Sc(36),
			L("idCheckPlaceholder"), function(value)
				panel:Send("id_check", value)
			end)

		panel:AddAction(L("idCheck"), formX + math.floor(formWidth * 0.6) + Sc(10), checkY,
			formWidth - math.floor(formWidth * 0.6) - Sc(10), Sc(36), function()
				panel:Send("id_check", Draft(panel, "idCheck") or "")
			end)
	end,
	Paint = function(panel, x, y, width, bottom, alpha)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()
		local palette = Palette(panel)
		local listWidth = math.floor(width * 0.4)
		local formX = x + listWidth + Sc(24)

		Label(NETWORK.util.Upper(L("idListTitle")), "nwHudSmall", x, y - Sc(8),
			ColorAlpha(palette.dim, 240 * alpha))

		if (!data.selected) then
			Label(L("idSelectHint"), "nwTermBody", formX, y + Sc(40),
				ColorAlpha(palette.dim, 230 * alpha))
		else
			Label(NETWORK.util.Upper(L("idFieldName")), "nwHudSmall", formX, y + Sc(34),
				ColorAlpha(palette.dim, 240 * alpha))
			Label(NETWORK.util.Upper(L("idFieldCID")), "nwHudSmall", formX, y + Sc(100),
				ColorAlpha(palette.dim, 240 * alpha))

			local cardsY = y + Sc(260)

			Label(NETWORK.util.Upper(L("idCardsTitle")), "nwHudSmall", formX, cardsY,
				ColorAlpha(palette.dim, 240 * alpha))

			for index, card in ipairs(data.cards or {}) do
				local lineY = cardsY + Sc(8) + index * Sc(20)

				if (lineY > bottom - Sc(90) or index > 6) then
					break
				end

				Label(string.format("%s  ·  %s  ·  #%s  ·  %s", card.serial, card.issued,
					card.cid, card.name), "nwHudSmall", formX, lineY,
					ColorAlpha(card.valid and palette.text or Color(232, 84, 76), 235 * alpha))
			end
		end

		local check = data.check

		if (check) then
			local text, color

			if (check.missing) then
				text, color = L("idCheckMissing", check.serial), Color(232, 84, 76)
			elseif (check.valid) then
				text, color = L("idCheckValid", check.serial, check.name, check.cid,
					check.issued), Color(108, 220, 150)
			else
				text, color = L("idCheckRevoked", check.serial, check.name),
					Color(232, 190, 96)
			end

			Label(text, "nwHudSmall", formX, bottom - Sc(56), ColorAlpha(color, 245 * alpha))
		end
	end
})

local STATUS_COLORS = {
	valid = Color(108, 220, 150),
	expired = Color(232, 190, 96),
	revoked = Color(232, 84, 76),
	missing = Color(232, 84, 76)
}

NETWORK.cmbterm.RegisterExtension("documents", {
	name = "cmbNavDocuments",
	glyph = "list",
	caption = "cmbTileDocuments",
	Build = function(panel, x, y, width, bottom)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()
		local formWidth = math.floor(width * 0.5)
		local rightX = x + formWidth + Sc(24)
		local rightWidth = width - formWidth - Sc(24)
		local formY = y + Sc(26)
		local choices = {}

		for _, entry in ipairs(data.types or {}) do
			choices[#choices + 1] = {L(entry.name), entry.id}
		end

		Combo(panel, x, formY + Sc(16), formWidth, Sc(34), choices, "docType")

		formY = formY + Sc(60)

		local cid = Entry(panel, "docCID", x, formY + Sc(16), math.floor(formWidth * 0.35),
			Sc(34), L("idFieldCID"))

		cid:SetNumeric(true)

		local hours = Entry(panel, "docHours", x + math.floor(formWidth * 0.35) + Sc(10),
			formY + Sc(16), formWidth - math.floor(formWidth * 0.35) - Sc(10), Sc(34),
			L("docHoursPlaceholder"))

		hours:SetNumeric(true)

		formY = formY + Sc(60)

		Entry(panel, "docHolder", x, formY + Sc(16), formWidth, Sc(34), L("docHolderPlaceholder"))

		formY = formY + Sc(60)

		local text = Entry(panel, "docText", x, formY + Sc(16), formWidth,
			bottom - formY - Sc(16) - Sc(56), L("docFieldText"))

		text:SetMultiline(true)

		panel:AddAction(L("docIssue"), x, bottom - Sc(40), formWidth, Sc(38), function()
			panel:Send("doc_issue", util.TableToJSON({
				type = Draft(panel, "docType"),
				cid = Draft(panel, "docCID") or "",
				hours = Draft(panel, "docHours"),
				holder = Draft(panel, "docHolder") or "",
				text = Draft(panel, "docText") or ""
			}))

			Draft(panel, "docText", "")
		end)

		Entry(panel, "docCheck", rightX, y + Sc(42), math.floor(rightWidth * 0.62), Sc(34),
			L("idCheckPlaceholder"), function(value)
				panel:Send("doc_check", value)
			end)

		panel:AddAction(L("idCheck"), rightX + math.floor(rightWidth * 0.62) + Sc(10),
			y + Sc(42), rightWidth - math.floor(rightWidth * 0.62) - Sc(10), Sc(34), function()
				panel:Send("doc_check", Draft(panel, "docCheck") or "")
			end)

		if (!data.bCanRevoke) then
			return
		end

		local rowY = y + Sc(176)

		for _, entry in ipairs(data.recent or {}) do
			if (rowY + Sc(34) > bottom) then
				break
			end

			if (!entry.revoked) then
				panel:AddAction(L("docRevokeShort"), rightX + rightWidth - Sc(110), rowY + Sc(3),
					Sc(110), Sc(28), function()
						panel:Send("doc_revoke", entry.serial)
					end, Color(232, 84, 76))
			end

			rowY = rowY + Sc(38)
		end
	end,
	Paint = function(panel, x, y, width, bottom, alpha)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()
		local palette = Palette(panel)
		local formWidth = math.floor(width * 0.5)
		local rightX = x + formWidth + Sc(24)
		local dim = ColorAlpha(palette.dim, 240 * alpha)

		Label(NETWORK.util.Upper(L("docFieldType")), "nwHudSmall", x, y + Sc(10), dim)
		Label(NETWORK.util.Upper(L("docCIDAndHours")), "nwHudSmall", x, y + Sc(70), dim)
		Label(NETWORK.util.Upper(L("docFieldHolder")), "nwHudSmall", x, y + Sc(130), dim)
		Label(NETWORK.util.Upper(L("docFieldText")), "nwHudSmall", x, y + Sc(190), dim)
		Label(NETWORK.util.Upper(L("docCheckTitle")), "nwHudSmall", rightX, y + Sc(10), dim)

		local check = data.check

		if (check) then
			local color = STATUS_COLORS[check.status] or palette.text

			Label(L("docStatus_" .. check.status, check.serial), "nwTermBody", rightX,
				y + Sc(98), ColorAlpha(color, 250 * alpha))

			if (check.status != "missing") then
				Label(string.format("%s  ·  %s #%s  ·  %s", L(check.type), check.holder,
					check.cid, check.issuer), "nwHudSmall", rightX, y + Sc(120),
					ColorAlpha(palette.text, 230 * alpha))
			end
		end

		Label(NETWORK.util.Upper(L("docRecentTitle")), "nwHudSmall", rightX, y + Sc(156), dim)

		local rowY = y + Sc(176)

		for _, entry in ipairs(data.recent or {}) do
			if (rowY + Sc(34) > bottom) then
				break
			end

			local docType = NETWORK.documents.GetType(entry.type)
			local color = entry.revoked and Color(232, 84, 76) or
				(entry.expired and Color(232, 190, 96) or palette.text)

			Label(entry.serial .. "  ·  " .. (docType and L(docType.name) or "?"), "nwTermCaption",
				rightX, rowY + Sc(9), ColorAlpha(color, 245 * alpha))
			Label(entry.holder .. " #" .. entry.cid .. "  ·  " .. entry.issued, "nwHudSmall",
				rightX, rowY + Sc(26), ColorAlpha(palette.dim, 235 * alpha))

			rowY = rowY + Sc(38)
		end
	end
})

local ORDER_COLORS = {
	pending = Color(232, 190, 96),
	assigned = Color(120, 170, 255),
	transit = Color(120, 170, 255),
	delivered = Color(108, 220, 150),
	opened = Color(140, 150, 160),
	lost = Color(232, 84, 76),
	cancelled = Color(140, 150, 160)
}

local function PaintOrder(order, x, y, width, palette, alpha)
	local Sc = NETWORK.util.Scale
	local color = ORDER_COLORS[order.status] or palette.text

	Label(L(order.name), "nwTermBody", x, y + Sc(10), ColorAlpha(palette.text, 250 * alpha))
	Label(NETWORK.util.Upper(L(NETWORK.supply.statuses[order.status] or order.status)) ..
		(order.worker != "" and ("  ·  " .. order.worker) or ""), "nwHudSmall", x, y + Sc(28),
		ColorAlpha(color, 245 * alpha))

	if (order.status == "pending") then
		Label(L("supplyAutoIn", string.format("%d:%02d", math.floor(order.wait / 60),
			order.wait % 60)), "nwHudSmall", x + width, y + Sc(28),
			ColorAlpha(palette.dim, 230 * alpha), TEXT_ALIGN_RIGHT)
	end
end

NETWORK.cmbterm.RegisterExtension("supply", {
	name = "cmbNavSupply",
	glyph = "stack",
	caption = "cmbTileSupply",
	access = function(client, entity)
		if (Kind(entity) == "cwu") then
			return NETWORK.factions.IsCWU(client) or client:IsAdmin()
		end

		return true
	end,
	Build = function(panel, x, y, width, bottom)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()

		if (data.kind == "alliance") then
			local listWidth = math.floor(width * 0.52)
			local rowY = y + Sc(40)

			for _, entry in ipairs(data.catalog or {}) do
				if (rowY + Sc(44) > bottom) then
					break
				end

				if (data.bCanOrder) then
					panel:AddAction(L("supplyOrder") .. "  " .. entry.cost,
						x + listWidth - Sc(130), rowY + Sc(6), Sc(130), Sc(32), function()
							panel:Send("supply_order", entry.id)
						end)
				end

				rowY = rowY + Sc(48)
			end

			local ordersX = x + listWidth + Sc(24)
			local ordersWidth = width - listWidth - Sc(24)

			rowY = y + Sc(40)

			for _, order in ipairs(data.orders or {}) do
				if (rowY + Sc(44) > bottom) then
					break
				end

				if (order.status == "pending" and data.bCanOrder) then
					panel:AddAction(L("supplyCancel"), ordersX + ordersWidth - Sc(100),
						rowY + Sc(6), Sc(100), Sc(28), function()
							panel:Send("supply_cancel", tostring(order.id))
						end, Color(232, 84, 76))
				end

				rowY = rowY + Sc(48)
			end

			return
		end

		local rowY = y + Sc(40)

		for _, order in ipairs(data.orders or {}) do
			if (rowY + Sc(44) > bottom) then
				break
			end

			if (order.status == "pending") then
				panel:AddAction(L("supplyTake"), x + width - Sc(160), rowY + Sc(6), Sc(160),
					Sc(32), function()
						panel:Send("supply_take", tostring(order.id))
					end)
			elseif (order.status == "assigned" and order.bMine) then
				panel:AddAction(L("supplyRoute"), x + width - Sc(200), rowY + Sc(6), Sc(160),
					Sc(32), function()
						panel:Send("supply_route", tostring(order.id))
					end)

				panel:AddAction("✕", x + width - Sc(34), rowY + Sc(6), Sc(30),
					Sc(32), function()
						panel:Send("supply_drop", tostring(order.id))
					end, Color(232, 84, 76))
			end

			rowY = rowY + Sc(48)
		end
	end,
	Paint = function(panel, x, y, width, bottom, alpha)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()
		local palette = Palette(panel)
		local dim = ColorAlpha(palette.dim, 240 * alpha)

		if (data.kind == "alliance") then
			local listWidth = math.floor(width * 0.52)
			local ordersX = x + listWidth + Sc(24)
			local ordersWidth = width - listWidth - Sc(24)
			local fraction = (data.fund or 0) / math.max(data.fundMax or 1, 1)

			Label(NETWORK.util.Upper(L("supplyFund", data.fund or 0, data.fundMax or 0)),
				"nwHudSmall", x, y + Sc(4), dim)

			if (!data.bCanOrder) then
				draw.SimpleText(L("supplyOnlyCmdHint"), "nwHudSmall", x + listWidth, y + Sc(4),
					ColorAlpha(Color(232, 190, 96), 240 * alpha), TEXT_ALIGN_RIGHT,
					TEXT_ALIGN_CENTER)
			end
			NETWORK.util.DrawProgressBar(x, y + Sc(16), listWidth, math.max(Sc(4), 3),
				fraction, palette.accent, alpha)

			local rowY = y + Sc(40)

			for _, entry in ipairs(data.catalog or {}) do
				if (rowY + Sc(44) > bottom) then
					break
				end

				Label(L(entry.name), "nwTermBody", x, rowY + Sc(12),
					ColorAlpha(palette.text, 250 * alpha))
				Label(NETWORK.util.TruncateWidth(entry.contents, "nwHudSmall",
					listWidth - Sc(150)), "nwHudSmall", x, rowY + Sc(30), dim)

				rowY = rowY + Sc(48)
			end

			Label(NETWORK.util.Upper(L("supplyOrdersTitle")), "nwHudSmall", ordersX,
				y + Sc(4), dim)

			rowY = y + Sc(40)

			if (#(data.orders or {}) == 0) then
				Label(L("supplyNoOrders"), "nwTermBody", ordersX, rowY + Sc(12), dim)
			end

			for _, order in ipairs(data.orders or {}) do
				if (rowY + Sc(44) > bottom) then
					break
				end

				PaintOrder(order, ordersX, rowY, ordersWidth - Sc(110), palette, alpha)

				rowY = rowY + Sc(48)
			end

			return
		end

		Label(L("supplyCWUHint"), "nwHudSmall", x, y + Sc(4), dim)

		local rowY = y + Sc(40)

		if (#(data.orders or {}) == 0) then
			Label(L("supplyNoOrders"), "nwTermBody", x, rowY + Sc(12), dim)
		end

		for _, order in ipairs(data.orders or {}) do
			if (rowY + Sc(44) > bottom) then
				break
			end

			PaintOrder(order, x, rowY, width - Sc(180), palette, alpha)

			rowY = rowY + Sc(48)
		end
	end
})

NETWORK.cmbterm.RegisterExtension("channels", {
	name = "cmbNavChannels",
	glyph = "radio",
	caption = "cmbTileChannels",
	Build = function(panel, x, y, width, bottom)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()
		local tabX = x

		for _, channel in ipairs(data.channels or {}) do
			surface.SetFont("nwHudSmall")

			local tabWidth = surface.GetTextSize(NETWORK.util.Upper(L(channel.name))) + Sc(34)
			local color = Color(channel.color[1], channel.color[2], channel.color[3])

			if (channel.id == data.current) then
				color = Color(255, 255, 255)
			end

			panel:AddAction(L(channel.name), tabX, y - Sc(4), tabWidth, Sc(30), function()
				panel:Send("channels", channel.id)
			end, color)

			tabX = tabX + tabWidth + Sc(8)
		end

		local current

		for _, channel in ipairs(data.channels or {}) do
			if (channel.id == data.current) then
				current = channel
			end
		end

		if (!current or !current.bWrite) then
			return
		end

		local send = function()
			local text = Draft(panel, "chanText") or ""

			if (string.Trim(text) == "") then
				return
			end

			Draft(panel, "chanText", "")
			panel:Send("chan_post", text, current.id)
		end

		local entry = Entry(panel, "chanText", x, bottom - Sc(38), width - Sc(170), Sc(36),
			L("chanPlaceholder"), send)

		entry:RequestFocus()

		panel:AddAction(L("chanSend"), x + width - Sc(160), bottom - Sc(38), Sc(160), Sc(36),
			send)
	end,
	Paint = function(panel, x, y, width, bottom, alpha)
		local Sc = NETWORK.util.Scale
		local data = panel:GetData()
		local palette = Palette(panel)
		local messages = data.messages or {}
		local listBottom = bottom - Sc(52)
		local listTop = y + Sc(22)
		local cursor = listBottom

		if (#messages == 0) then
			Label(L("chanEmpty"), "nwTermBody", x, listTop + Sc(20),
				ColorAlpha(palette.dim, 230 * alpha))

			return
		end

		for index = #messages, 1, -1 do
			local message = messages[index]
			local faction = NETWORK.factions.Get(message.faction or "")
			local color = faction and faction.color or palette.accent
			local lines = NETWORK.util.WrapText(message.text or "", "nwTermCaption",
				width - Sc(20), 4)
			local height = Sc(22) + #lines * Sc(17)

			cursor = cursor - height

			if (cursor < listTop) then
				break
			end

			surface.SetDrawColor(color.r, color.g, color.b, 200 * alpha)
			surface.DrawRect(x, cursor + Sc(2), math.max(Sc(2), 2), height - Sc(6))

			Label(message.author or "?", "nwTermNav", x + Sc(12), cursor + Sc(9),
				ColorAlpha(color, 245 * alpha))
			Label(message.time or "", "nwHudSmall", x + width, cursor + Sc(9),
				ColorAlpha(palette.dim, 220 * alpha), TEXT_ALIGN_RIGHT)

			for lineIndex, line in ipairs(lines) do
				Label(line, "nwTermCaption", x + Sc(12), cursor + Sc(12) + lineIndex * Sc(17),
					ColorAlpha(palette.text, 245 * alpha))
			end
		end
	end
})
