-- NPC windows (server: sv_npc.lua, config: sh_npc.lua).
--   dialogue   the camera turns to the NPC's face, black bars top and bottom; at the bottom a
--              panel (materials/network2/ui/npc/): the name on a gold plate, the line typed out
--              (a click shows it whole), the answers - click or keys 1-9
--   trade      Купить / Продать: cards with the model of the thing, its price (tokens and/or
--              another item), what is left; what you cannot afford is dimmed
--   quest      what to bring (how many you have), the reward, Принять / Сдать / Отказаться
--   professions  cards of the factions the NPC hires into: the logo, the description, what it
--              takes (free, a whitelist, tokens, an item) and Вступить; then where to appear -
--              the faction's spawn points (by their zone) or Остаться здесь
--   editor     admins: Редактировать (top right) → Общее, Диалог, Торговля, Задания, Профессии
-- ESC: back from trade / quest to the talk, from the talk out.

NW.npcUI = NW.npcUI or {}

local NP = NW.npcUI
local NPC = NW.npc
local U = NW.ui
local I = NW.items
local INV = NW.inventory
local ACCENT = Color(232, 196, 72)
local MUTED = Color(124, 128, 134)
local GOOD = Color(150, 214, 138)
local BAD = Color(226, 104, 92)
local MAT = "network2/ui/npc/"

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwNpcName", "Montserrat SemiBold", 0.022, 700)
	F("nwNpcDesc", "Exo 2", 0.015, 400)
	F("nwNpcText", "Exo 2", 0.0215, 500)
	F("nwNpcAnswer", "Montserrat Medium", 0.018, 500)
	F("nwNpcKey", "Montserrat SemiBold", 0.015, 700)
	F("nwNpcTitle", "Montserrat SemiBold", 0.03, 600)
	F("nwNpcCardName", "Montserrat SemiBold", 0.018, 600)
	F("nwNpcSmall", "Montserrat Medium", 0.0135, 500)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwNpcFonts", Fonts)

local function Ease(t)
	return 1 - (1 - t) ^ 3
end

local function Plate(name, x, y, w, h, corner, alpha, r, g, b)
	U.Slice(U.Material(MAT .. name .. ".png"), x, y, w, h, corner, r or 255, g or 255, b or 255, 255 * (alpha or 1))
end

local function Have(id)
	return NPC.Count(INV.data.grid, id)
end

local function Tokens()
	return LocalPlayer():GetNW2Int("nwTokens", 0)
end

local function Action(action, arg)
	net.Start("nwNpcAction")
		net.WriteEntity(NP.entity)
		net.WriteString(action)
		net.WriteString(tostring(arg or ""))
	net.SendToServer()
end

-- ----------------------------------------------------------------- camera --
NP.weight = 0

hook.Add("CalcView", "nwNpc", function(client, origin, angles, fov)
	local entity = NP.entity
	local open = IsValid(NP.frame) and !NP.frame.closing and IsValid(entity)

	NP.weight = math.Approach(NP.weight, open and 1 or 0, FrameTime() / 0.6)

	if (NP.weight <= 0 or !IsValid(entity)) then
		return
	end

	local bone = entity:LookupBone("ValveBiped.Bip01_Head1")
	local head = bone and entity:GetBonePosition(bone) or (entity:GetPos() + Vector(0, 0, 64))
	local forward, right = entity:GetForward(), entity:GetRight()
	-- the face a little to the left of the middle, seen from slightly to the side
	local pos = head + forward * 62 + right * 20 + Vector(0, 0, 1)
	local look = (head + right * 12 - pos):Angle()
	local w = Ease(NP.weight)

	return {origin = LerpVector(w, origin, pos), angles = LerpAngle(w, angles, look), fov = Lerp(w, fov, 48),
		drawviewer = true}
end)

-- ----------------------------------------------------------------- state --
function NP.Close()
	if (IsValid(NP.frame) and !NP.frame.closing) then
		NP.frame.closing = true
		NP.frame:SetMouseInputEnabled(false)
		NP.frame:SetKeyboardInputEnabled(false)
	end
end

local function QuestState(id)
	return NP.quests and NP.quests[id]
end

local function CanHandIn(quest)
	for _, need in ipairs(quest.need) do
		if (Have(need.item) < need.count) then
			return false
		end
	end

	return true
end

local Rebuild

local function GoNode(id)
	local node = NPC.Node(NP.config, id)

	if (!node) then
		return NP.Close()
	end

	NP.node = node
	NP.view = "dialog"
	NP.typedAt = RealTime()
	Rebuild()
end

local function Choose(answer)
	surface.PlaySound("network2/ui/click.wav")

	if (answer.action == "goto") then
		GoNode(answer.target)
	elseif (answer.action == "trade") then
		NP.view = "trade"
		NP.tab = NP.tab or "buy"
		Rebuild()
	elseif (answer.action == "quest" and NPC.Quest(NP.config, answer.target)) then
		NP.view = "quest"
		NP.questID = answer.target
		Rebuild()
	elseif (answer.action == "profession") then
		NP.view = "professions"
		Rebuild()
	elseif (answer.action == "callsign") then
		-- the server answers with the list (nwNpcCallsigns)
		Action("callsigns")
	elseif (answer.action == "factory") then
		-- the office window (cl_cwu.lua) opens over the talk
		Action("factory")
	else
		NP.Close()
	end
end

-- -------------------------------------------------------------- dialogue --
local function BuildDialog(frame, sw, sh)
	local node = NP.node
	local x, w = math.Round(sw * 0.17), math.Round(sw * 0.66)
	local pad = math.Round(sh * 0.022)
	local lines = INV.WrapText(node.text, "nwNpcText", w - pad * 2)
	local lh = math.Round(sh * 0.03)
	local ah = math.Round(sh * 0.044)
	local answers = node.answers
	local h = pad * 2 + #lines * lh + sh * 0.02 + #answers * (ah + 6)
	local y = math.Round(sh * 0.9 - h)
	local panel = frame:Add("EditablePanel")

	panel:SetPos(x, y)
	panel:SetSize(w, h)
	panel.Paint = function(self, pw, ph)
		Plate("panel", 0, 0, pw, ph, 14)

		-- the line, typed out
		local total = utf8.len(node.text) or #node.text
		local shown = math.floor((RealTime() - (NP.typedAt or 0)) * 70)
		local left = shown
		local ty = pad

		for _, line in ipairs(lines) do
			local len = utf8.len(line) or #line
			local part = line

			if (left < len) then
				part = string.sub(line, 1, (utf8.offset(line, math.max(left, 0) + 1) or (#line + 1)) - 1)
			end

			draw.SimpleText(part, "nwNpcText", pad, ty, Color(232, 230, 226))
			ty = ty + lh
			left = left - len

			if (left <= 0) then
				break
			end
		end

		self.typing = shown < total
	end

	panel.OnMousePressed = function(self)
		NP.typedAt = RealTime() - 1000
	end

	-- the answers
	local ay = pad + #lines * lh + sh * 0.02

	for index, answer in ipairs(answers) do
		local row = panel:Add("DButton")
		local label = answer.text

		if (answer.action == "quest") then
			local quest = NPC.Quest(NP.config, answer.target)
			local state = quest and QuestState(quest.id)

			if (state == "active") then
				label = label .. (CanHandIn(quest) and "  [сдать]" or "  [в процессе]")
			elseif (state == "done" and quest and !quest.repeatable) then
				label = label .. "  [выполнено]"
			end
		elseif (answer.action == "trade") then
			label = label .. "  [торговля]"
		elseif (answer.action == "profession") then
			label = label .. "  [профессии]"
		elseif (answer.action == "callsign") then
			label = label .. "  [позывной]"
		elseif (answer.action == "factory") then
			label = label .. "  [завод]"
		end

		row:SetPos(pad, ay)
		row:SetSize(w - pad * 2, ah)
		row:SetText("")
		row.DoClick = function()
			Choose(answer)
		end
		row.OnCursorEntered = function()
			surface.PlaySound("network2/ui/hover.wav")
		end
		row.Paint = function(self, rw, rh)
			local hover = self:IsHovered()

			Plate(hover and "answer_hover" or "answer", 0, 0, rw, rh, 8)

			local ks = rh - 12

			draw.RoundedBox(4, 6, 6, ks, ks, hover and ACCENT or Color(255, 255, 255, 22))
			draw.SimpleText(index, "nwNpcKey", 6 + ks / 2, rh / 2, hover and Color(20, 20, 22) or U.color.text,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(label, "nwNpcAnswer", ks + 18, rh / 2, hover and Color(255, 244, 214) or U.color.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		ay = ay + ah + 6
	end

	-- the name over the panel
	local plate = frame:Add("EditablePanel")

	surface.SetFont("nwNpcName")

	local nw = surface.GetTextSize(U.Upper(NP.config.name)) + sh * 0.03

	plate:SetPos(x, y - sh * 0.05)
	plate:SetSize(w, sh * 0.042)
	plate:SetMouseInputEnabled(false)
	plate.Paint = function(_, pw, ph)
		Plate("plate", 0, 0, nw, ph, 6)
		draw.SimpleText(U.Upper(NP.config.name), "nwNpcName", nw / 2, ph / 2, Color(22, 20, 16), TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER)
		draw.SimpleText(NP.config.description, "nwNpcDesc", nw + sh * 0.014, ph / 2, Color(200, 204, 210),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
end

-- ----------------------------------------------------------------- trade --
local function Price(parent, line, x, y, h)
	local row = parent:Add("EditablePanel")

	row:SetPos(x, y)
	row:SetSize(parent:GetWide() - x - 8, h)
	row:SetMouseInputEnabled(false)
	row.Paint = function(_, w, rh)
		local px = 0
		local is = rh - 4

		if (line.price > 0 or line.priceItem == "") then
			local ok = Tokens() >= NPC.Price(LocalPlayer(), line)

			U.DrawIcon("tokens", px, 2, is, ACCENT)
			surface.SetFont("nwNpcAnswer")

			local text = NPC.Price(LocalPlayer(), line) .. " ток."

			draw.SimpleText(text, "nwNpcAnswer", px + is + 4, rh / 2, ok and U.color.text or BAD, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
			px = px + is + 12 + surface.GetTextSize(text)
		end

		if (line.priceItem != "") then
			local item = I.Get(line.priceItem)
			local ok = Have(line.priceItem) >= line.priceCount

			if (line.price > 0) then
				draw.SimpleText("+", "nwNpcAnswer", px, rh / 2, MUTED, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
				px = px + 14
			end

			surface.SetMaterial(U.Material("network2/items/" .. (item and item.icon or "bag") .. ".png"))
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(px, 2, is, is)
			draw.SimpleText((item and item.name or "?") .. " ×" .. line.priceCount .. "  (у вас " ..
				Have(line.priceItem) .. ")", "nwNpcAnswer", px + is + 4, rh / 2, ok and U.color.text or BAD,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end
end

local function Box(frame, sw, sh, title, w, h)
	local box = frame:Add("EditablePanel")

	box:SetSize(w, h)
	box:SetPos((sw - w) / 2, sh * 0.11 + (sh * 0.78 - h) / 2)
	box.Paint = function(_, bw, bh)
		Plate("panel", 0, 0, bw, bh, 14)
		draw.SimpleText(title, "nwNpcTitle", sh * 0.025, sh * 0.035, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		-- your tokens, top right
		local text = Tokens() .. " ток."
		local is = sh * 0.024

		surface.SetFont("nwNpcAnswer")

		local tw = surface.GetTextSize(text)

		draw.SimpleText(text, "nwNpcAnswer", bw - sh * 0.025, sh * 0.035, U.color.text, TEXT_ALIGN_RIGHT,
			TEXT_ALIGN_CENTER)
		U.DrawIcon("tokens", bw - sh * 0.025 - tw - is - 6, sh * 0.035 - is / 2, is, ACCENT)
	end

	return box
end

local function BuildTrade(frame, sw, sh)
	local W = NW.widgets
	local w, h = math.Round(math.min(sw * 0.66, sh * 1.3)), math.Round(sh * 0.74)
	local box = Box(frame, sw, sh, NP.config.name .. " — торговля", w, h)
	local pad = math.Round(sh * 0.025)
	local tabH = math.Round(sh * 0.04)

	-- Купить / Продать
	for index, tab in ipairs({{"buy", "Купить"}, {"sell", "Продать"}}) do
		local button = W.Button(box, tab[2], function()
			NP.tab = tab[1]
			Rebuild()
		end, NP.tab == tab[1])

		button:SetPos(pad + (index - 1) * (sh * 0.15 + 8), sh * 0.07)
		button:SetSize(sh * 0.15, tabH)
	end

	local scroll = W.Scroll(box)

	scroll:SetPos(pad, sh * 0.07 + tabH + pad * 0.6)
	scroll:SetSize(w - pad * 2, h - (sh * 0.07 + tabH + pad * 0.6) - sh * 0.08)

	local list = scroll:Add("DIconLayout")

	list:Dock(TOP)
	list:SetSpaceX(10)
	list:SetSpaceY(10)

	local cardW = math.floor((w - pad * 2 - 20) / 2)
	local cardH = math.Round(sh * 0.12)
	local any = false

	for index, line in ipairs(NP.config.shop) do
		local item = I.Get(line.item)
		local selling = NP.tab == "sell"

		if (!item or (selling and line.sell <= 0)) then
			continue
		end

		any = true

		local card = list:Add("EditablePanel")
		local stock = NP.stock and NP.stock[index] or line.stock

		card:SetSize(cardW, cardH)
		card.Paint = function(_, cw, ch)
			Plate("card", 0, 0, cw, ch, 10)

			local cat = I.categories[item.category] or I.categories.misc

			surface.SetDrawColor(cat.color)
			surface.DrawRect(ch, ch - 14, cw * 0.12, 2)
			draw.SimpleText(item.name, "nwNpcCardName", ch, ch * 0.12, U.color.text)

			if (selling) then
				draw.SimpleText("У вас: " .. Have(line.item), "nwNpcSmall", ch, ch * 0.62, MUTED)
			else
				draw.SimpleText(stock < 0 and "В наличии: много" or ("В наличии: " .. stock), "nwNpcSmall", ch,
					ch * 0.62, stock == 0 and BAD or MUTED)
			end
		end

		local view = INV.ItemView(card)

		view:SetPos(6, 6)
		view:SetSize(cardH - 12, cardH - 12)
		view:SetItem(item)

		if (selling) then
			local row = card:Add("EditablePanel")

			row:SetPos(cardH, cardH * 0.36)
			row:SetSize(cardW - cardH, cardH * 0.22)
			row:SetMouseInputEnabled(false)
			row.Paint = function(_, rw, rh)
				U.DrawIcon("tokens", 0, 2, rh - 4, ACCENT)
				draw.SimpleText("+" .. line.sell .. " ток. за штуку", "nwNpcAnswer", rh + 2, rh / 2, GOOD, TEXT_ALIGN_LEFT,
					TEXT_ALIGN_CENTER)
			end
		else
			Price(card, line, cardH, cardH * 0.36, cardH * 0.22)
		end

		local button = W.Button(card, selling and "Продать" or "Купить", function()
			Action(selling and "sell" or "buy", index)
		end, true)

		button:SetSize(cardW * 0.26, cardH * 0.3)
		button:SetPos(cardW - cardW * 0.26 - 10, cardH - cardH * 0.3 - 10)
		button.Think = function(self)
			local ok

			if (selling) then
				ok = Have(line.item) > 0
			else
				ok = stock != 0 and Tokens() >= NPC.Price(LocalPlayer(), line) and
					(line.priceItem == "" or Have(line.priceItem) >= line.priceCount)
			end

			self:SetEnabled(ok)
		end
	end

	if (!any) then
		local empty = scroll:Add("DLabel")

		empty:Dock(TOP)
		empty:SetTall(sh * 0.05)
		empty:SetFont("nwNpcAnswer")
		empty:SetTextColor(MUTED)
		empty:SetText(NP.tab == "sell" and "Этот торговец ничего не покупает." or "Сейчас нечего предложить.")
	end

	local back = W.Button(box, "Назад", function()
		GoNode(NP.node and NP.node.id or NP.config.start)
	end)

	back:SetPos(pad, h - sh * 0.065)
	back:SetSize(sh * 0.16, sh * 0.042)
end

-- ------------------------------------------------------------ professions --
local function Whitelisted(faction)
	return NP.whitelist and NP.whitelist[faction] == true
end

-- what a profession takes, a line for the card, and whether the player has it now
local function Access(entry)
	if (entry.access == "whitelist") then
		local ok = Whitelisted(entry.faction)

		return ok and "Вайтлист: есть" or "Нужен вайтлист", ok
	elseif (entry.access == "tokens") then
		return entry.price .. " ток.", Tokens() >= entry.price
	elseif (entry.access == "item") then
		local item = I.Get(entry.item)
		local have = Have(entry.item)

		return (item and item.name or entry.item) .. " ×" .. entry.count .. " (у вас " .. have .. ")" ..
			(entry.consume and "" or " — показать"), have >= entry.count
	end

	return "Бесплатно", true
end

local function BuildProfessions(frame, sw, sh)
	local W = NW.widgets
	local w, h = math.Round(math.min(sw * 0.7, sh * 1.36)), math.Round(sh * 0.74)
	local box = Box(frame, sw, sh, NP.config.name .. " — профессии", w, h)
	local pad = math.Round(sh * 0.025)
	local scroll = W.Scroll(box)

	scroll:SetPos(pad, sh * 0.075)
	scroll:SetSize(w - pad * 2, h - sh * 0.075 - sh * 0.085)

	local cardH = math.Round(sh * 0.13)
	local list = NP.config.professions or {}

	if (#list == 0) then
		local empty = scroll:Add("DLabel")

		empty:Dock(TOP)
		empty:SetTall(sh * 0.05)
		empty:SetFont("nwNpcAnswer")
		empty:SetTextColor(MUTED)
		empty:SetText("Здесь сейчас никого не нанимают.")
	end

	for index, entry in ipairs(list) do
		local faction = NW.char.factions[entry.faction]

		if (!faction) then
			continue
		end

		local title = entry.title != "" and entry.title or faction.name
		local description = entry.description != "" and entry.description or faction.description or ""
		local current = NP.faction == entry.faction
		local card = scroll:Add("EditablePanel")

		card:Dock(TOP)
		card:DockMargin(0, 0, 8, 10)
		card:SetTall(cardH)
		card.Paint = function(_, cw, ch)
			Plate("card", 0, 0, cw, ch, 10)

			local color = faction.color or U.color.text
			local logo = U.Material("network2/factions/" .. (faction.logo or "citizen_logo") .. ".png")
			local ls = ch - 24

			surface.SetDrawColor(color.r, color.g, color.b, 40)
			surface.DrawRect(12, 12, ls, ls)
			surface.SetMaterial(logo)
			surface.SetDrawColor(color)
			surface.DrawTexturedRect(12 + ls * 0.12, 12 + ls * 0.12, ls * 0.76, ls * 0.76)
			surface.SetDrawColor(color)
			surface.DrawRect(ch, ch - 16, cw * 0.1, 2)

			draw.SimpleText(title, "nwNpcCardName", ch, ch * 0.1, U.color.text)

			local lines = INV.WrapText(description, "nwNpcSmall", cw - ch - cw * 0.3)

			for i = 1, math.min(#lines, 3) do
				draw.SimpleText(lines[i], "nwNpcSmall", ch, ch * 0.32 + (i - 1) * sh * 0.018, Color(196, 200, 206))
			end

			local text, ok = Access(entry)

			if (current) then
				text, ok = "Вы уже в этой фракции", true
			end

			draw.SimpleText(text, "nwNpcAnswer", cw - 14, ch * 0.2, ok and GOOD or BAD, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end

		local button = W.Button(card, current and "Текущая" or "Вступить", function()
			Action("profession", index)
		end, !current)

		button:SetSize(w * 0.17, cardH * 0.3)
		button:SetPos(w - pad * 2 - 8 - w * 0.17 - 12, cardH - cardH * 0.3 - 12)
		button.Think = function(self)
			local _, ok = Access(entry)

			self:SetEnabled(ok and NP.faction != entry.faction)
		end
	end

	local back = W.Button(box, "Назад", function()
		GoNode(NP.node and NP.node.id or NP.config.start)
	end)

	back:SetPos(pad, h - sh * 0.065)
	back:SetSize(sh * 0.16, sh * 0.042)
end

-- after joining: where to appear (the faction's points; the choice stays for respawns)
local function BuildSpawns(frame, sw, sh)
	local W = NW.widgets
	local data = NP.spawnChoice or {points = {}}
	local rowH = math.Round(sh * 0.05)
	local w = math.Round(sh * 0.62)
	local h = math.Round(sh * 0.2 + math.max(1, math.min(#data.points, 7)) * (rowH + 8) + sh * 0.06)
	local box = Box(frame, sw, sh, (data.title or "Профессия") .. " — где появиться", w, h)
	local pad = math.Round(sh * 0.025)
	local y = sh * 0.075

	local hint = box:Add("DLabel")

	hint:SetPos(pad, y)
	hint:SetSize(w - pad * 2, sh * 0.03)
	hint:SetFont("nwNpcSmall")
	hint:SetTextColor(MUTED)
	hint:SetText(#data.points > 0 and "Выберите точку: вы перейдёте туда и будете появляться там после смерти." or
		"У этой фракции ещё нет точек появления (/spawnadd).")
	y = y + sh * 0.04

	local scroll = W.Scroll(box)

	scroll:SetPos(pad, y)
	scroll:SetSize(w - pad * 2, h - y - sh * 0.08)

	for _, point in ipairs(data.points) do
		local button = W.Button(scroll, point.name, function()
			Action("spawnat", point.index)
			NP.Close()
		end, false, "door")

		button:Dock(TOP)
		button:DockMargin(0, 0, 8, 8)
		button:SetTall(rowH)
	end

	local stay = W.Button(box, "Остаться здесь", function()
		NP.spawnChoice = nil
		GoNode(NP.node and NP.node.id or NP.config.start)
	end)

	stay:SetPos(pad, h - sh * 0.065)
	stay:SetSize(sh * 0.2, sh * 0.042)
end

-- ---------------------------------------------------------------- callsign --
-- The words of the side in rows, the numbers 1..9 in each: taken ones are dark, yours is lit.
local CALLSIGN_COLOR = {cp = Color(96, 200, 255), ota = Color(240, 92, 80)}

local function BuildCallsign(frame, sw, sh)
	local W = NW.widgets
	local data = NP.callsigns or {}
	local side = data.side or "cp"
	local list = NW.units.callsigns[side] or {}
	local color = CALLSIGN_COLOR[side] or ACCENT
	local rowH = math.Round(sh * 0.042)
	local pad = math.Round(sh * 0.025)
	local w = math.Round(sh * 0.86)
	local listH = math.min(#list, 10) * (rowH + 6)
	local h = math.Round(sh * 0.2 + listH)
	local box = Box(frame, sw, sh, "Позывной юнита", w, h)
	local y = sh * 0.07

	local hint = box:Add("DLabel")

	hint:SetPos(pad, y)
	hint:SetSize(w - pad * 2, sh * 0.03)
	hint:SetFont("nwNpcSmall")
	hint:SetTextColor(MUTED)
	hint:SetText(data.unit and ("Сейчас: " .. LocalPlayer():Nick() .. ". Выберите слово и номер — занятые " ..
		"другими юнитами недоступны.") or "Позывные выдаются только юнитам Альянса.")
	y = y + sh * 0.04

	local scroll = W.Scroll(box)

	scroll:SetPos(pad, y)
	scroll:SetSize(w - pad * 2, h - y - sh * 0.08)

	local nameW = math.Round(w * 0.24)

	for _, entry in ipairs(list) do
		local row = scroll:Add("EditablePanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, 8, 6)
		row:SetTall(rowH)
		row.Paint = function(_, rw, rh)
			draw.SimpleText(entry.name, "nwNpcAnswer", 4, rh / 2, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local cell = math.Round((w - pad * 2 - nameW - 8 - 9 * 4) / 9)

		for number = 1, 9 do
			local key = entry.id .. ":" .. number
			local taken = data.taken and data.taken[key]
			local mine = data.current and data.current.id == entry.id and tonumber(data.current.num) == number
			local button = row:Add("DButton")

			button:SetPos(nameW + (number - 1) * (cell + 4), 0)
			button:SetSize(cell, rowH)
			button:SetText("")
			button:SetEnabled(data.unit == true and !taken and !mine)
			button.Paint = function(self, bw, bh)
				local hover = self:IsHovered() and self:IsEnabled()
				local fill = mine and ColorAlpha(color, 200) or (hover and ColorAlpha(color, 70) or
					Color(255, 255, 255, taken and 4 or 12))

				draw.RoundedBox(4, 0, 0, bw, bh, fill)
				draw.SimpleText(number, "nwNpcAnswer", bw / 2, bh / 2, mine and Color(10, 14, 18) or
					(taken and Color(90, 92, 96) or U.color.text), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			button.DoClick = function()
				surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
				Action("callsign", key)
			end
			button.OnCursorEntered = function(self)
				if (self:IsEnabled()) then
					surface.PlaySound("network2/ui/hover.wav")
				end
			end
		end
	end

	local back = W.Button(box, "Назад", function()
		GoNode(NP.node and NP.node.id or NP.config.start)
	end)

	back:SetPos(pad, h - sh * 0.065)
	back:SetSize(sh * 0.2, sh * 0.042)
end

net.Receive("nwNpcCallsigns", function()
	local entity = net.ReadEntity()
	local data = util.JSONToTable(net.ReadString() or "") or {}

	if (entity == NP.entity and IsValid(NP.frame)) then
		NP.callsigns = data
		NP.view = "callsign"
		Rebuild()
	end
end)

net.Receive("nwNpcSpawns", function()
	local entity = net.ReadEntity()
	local data = util.JSONToTable(net.ReadString() or "") or {}

	if (entity == NP.entity and IsValid(NP.frame)) then
		NP.spawnChoice = data
		NP.faction = data.faction
		NP.view = "spawns"
		surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
		Rebuild()
	end
end)

-- ------------------------------------------------------ the new profession --
-- The screen goes dark (the faction changes on the server in the dark: the model, the clothes),
-- "НОВАЯ ПРОФЕССИЯ" and the title in the colour of the faction come up letter by letter over a
-- line that grows from the middle, then the dark lifts. Drawn over everything (the NPC window too).
local shift
local SHIFT_IN, SHIFT_HOLD, SHIFT_OUT = 0.7, 1.5, 0.9

local function ShiftFonts()
	local h = ScrH()

	surface.CreateFont("nwShiftTitle", {font = "Jura", size = math.max(26, math.Round(h * 0.052)), weight = 700,
		extended = true, antialias = true})
	surface.CreateFont("nwShiftSmall", {font = "Exo 2", size = math.max(13, math.Round(h * 0.019)), weight = 500,
		extended = true, antialias = true})
end

ShiftFonts()
hook.Add("OnScreenSizeChanged", "nwShiftFonts", ShiftFonts)

net.Receive("nwProfessionShift", function()
	shift = {title = net.ReadString(), color = net.ReadColor(false), start = RealTime(), shown = 0}
	surface.PlaySound("network2/ui/char/hls_ui_appear.wav")
end)

-- letters of text up to n (UTF-8)
local function Letters(text, n)
	local out = {}

	for _, code in utf8.codes(text) do
		if (#out >= n) then
			break
		end

		out[#out + 1] = utf8.char(code)
	end

	return table.concat(out), #out
end

hook.Add("DrawOverlay", "nwProfessionShift", function()
	if (!shift) then
		return
	end

	local t = RealTime() - shift.start
	local total = SHIFT_IN + SHIFT_HOLD + SHIFT_OUT

	if (t >= total) then
		shift = nil

		return
	end

	local sw, sh = ScrW(), ScrH()
	local dark

	if (t < SHIFT_IN) then
		dark = Ease(t / SHIFT_IN)
	elseif (t < SHIFT_IN + SHIFT_HOLD) then
		dark = 1
	else
		dark = 1 - Ease((t - SHIFT_IN - SHIFT_HOLD) / SHIFT_OUT)
	end

	surface.SetDrawColor(4, 5, 6, 255 * dark)
	surface.DrawRect(0, 0, sw, sh)

	local into = t - SHIFT_IN * 0.8

	if (into <= 0) then
		return
	end

	local cy = sh * 0.47
	local color = shift.color
	local line = Ease(math.Clamp(into / 0.6, 0, 1)) * sh * 0.32

	surface.SetDrawColor(color.r, color.g, color.b, 200 * dark)
	surface.DrawRect(sw / 2 - line / 2, cy + sh * 0.042, line, 2)

	draw.SimpleText("НОВАЯ ПРОФЕССИЯ", "nwShiftSmall", sw / 2, cy - sh * 0.05, ColorAlpha(MUTED, 255 * dark *
		math.Clamp(into / 0.3, 0, 1)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local n = math.floor(math.max(0, into - 0.15) * 28)
	local text, count = Letters(shift.title, n)

	if (count > shift.shown) then
		surface.PlaySound("network2/ui/char/textline_" .. math.random(1, 8) .. ".wav")
	end

	shift.shown = count

	-- the whole title is measured once: the letters appear in place, nothing shifts
	surface.SetFont("nwShiftTitle")

	local tw = surface.GetTextSize(shift.title)

	draw.SimpleText(text, "nwShiftTitle", sw / 2 - tw / 2, cy, ColorAlpha(color, 255 * dark), TEXT_ALIGN_LEFT,
		TEXT_ALIGN_CENTER)
end)

-- ----------------------------------------------------------------- quest --
local function BuildQuest(frame, sw, sh)
	local W = NW.widgets
	local quest = NPC.Quest(NP.config, NP.questID)

	if (!quest) then
		return GoNode(NP.config.start)
	end

	local state = QuestState(quest.id)
	local w = math.Round(math.min(sw * 0.5, sh * 0.95))
	local pad = math.Round(sh * 0.025)
	local lines = INV.WrapText(quest.description, "nwNpcText", w - pad * 2)
	local lh = math.Round(sh * 0.028)
	local rowH = math.Round(sh * 0.034)
	local rewards = #quest.rewardItems + (quest.rewardTokens > 0 and 1 or 0)
	local h = sh * 0.08 + #lines * lh + sh * 0.05 + #quest.need * rowH + sh * 0.05 + rewards * rowH + sh * 0.1
	local box = Box(frame, sw, sh, quest.name, w, h)

	box.PaintOver = function(_, bw, bh)
		local y = sh * 0.075

		for _, line in ipairs(lines) do
			draw.SimpleText(line, "nwNpcText", pad, y, Color(214, 216, 220))
			y = y + lh
		end

		y = y + sh * 0.02
		draw.SimpleText("НУЖНО ПРИНЕСТИ", "nwNpcSmall", pad, y, ACCENT)
		y = y + sh * 0.026

		for _, need in ipairs(quest.need) do
			local item = I.Get(need.item)
			local have = Have(need.item)

			surface.SetMaterial(U.Material("network2/items/" .. item.icon .. ".png"))
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(pad, y + 2, rowH - 4, rowH - 4)
			draw.SimpleText(item.name, "nwNpcAnswer", pad + rowH + 4, y + rowH / 2, U.color.text, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
			draw.SimpleText(math.min(have, need.count) .. " / " .. need.count, "nwNpcAnswer", bw - pad, y + rowH / 2,
				have >= need.count and GOOD or MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
			y = y + rowH
		end

		y = y + sh * 0.02
		draw.SimpleText("НАГРАДА", "nwNpcSmall", pad, y, ACCENT)
		y = y + sh * 0.026

		if (quest.rewardTokens > 0) then
			U.DrawIcon("tokens", pad, y + 2, rowH - 4, ACCENT)
			draw.SimpleText(quest.rewardTokens .. " ток.", "nwNpcAnswer", pad + rowH + 4, y + rowH / 2, U.color.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			y = y + rowH
		end

		for _, reward in ipairs(quest.rewardItems) do
			local item = I.Get(reward.item)

			surface.SetMaterial(U.Material("network2/items/" .. item.icon .. ".png"))
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRect(pad, y + 2, rowH - 4, rowH - 4)
			draw.SimpleText(item.name .. " ×" .. reward.count, "nwNpcAnswer", pad + rowH + 4, y + rowH / 2, U.color.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			y = y + rowH
		end

		if (state == "done" and !quest.repeatable) then
			draw.SimpleText("Выполнено", "nwNpcCardName", bw - pad, bh - sh * 0.045, GOOD, TEXT_ALIGN_RIGHT,
				TEXT_ALIGN_CENTER)
		end
	end

	local by = h - sh * 0.065
	local bw = sh * 0.16

	local back = W.Button(box, "Назад", function()
		GoNode(NP.node and NP.node.id or NP.config.start)
	end)

	back:SetPos(pad, by)
	back:SetSize(bw, sh * 0.042)

	if (state == "active") then
		local turnin = W.Button(box, "Сдать", function()
			Action("turnin", quest.id)
		end, true)

		turnin:SetPos(w - pad - bw, by)
		turnin:SetSize(bw, sh * 0.042)
		turnin.Think = function(self)
			self:SetEnabled(CanHandIn(quest))
		end

		local abandon = W.Button(box, "Отказаться", function()
			Action("abandon", quest.id)
		end)

		abandon:SetPos(w - pad - bw * 2 - 8, by)
		abandon:SetSize(bw, sh * 0.042)
	elseif (state != "done" or quest.repeatable) then
		local accept = W.Button(box, "Принять", function()
			Action("accept", quest.id)
		end, true)

		accept:SetPos(w - pad - bw, by)
		accept:SetSize(bw, sh * 0.042)
	end
end

-- ---------------------------------------------------------------- window --
Rebuild = function()
	local frame = NP.frame

	if (!IsValid(frame)) then
		return
	end

	for _, child in ipairs(frame:GetChildren()) do
		child:Remove()
	end

	local sw, sh = ScrW(), ScrH()

	if (NP.view == "trade") then
		BuildTrade(frame, sw, sh)
	elseif (NP.view == "quest") then
		BuildQuest(frame, sw, sh)
	elseif (NP.view == "professions") then
		BuildProfessions(frame, sw, sh)
	elseif (NP.view == "spawns") then
		BuildSpawns(frame, sw, sh)
	elseif (NP.view == "callsign") then
		BuildCallsign(frame, sw, sh)
	else
		BuildDialog(frame, sw, sh)
	end

	-- admins: the editor
	if (NP.admin) then
		local edit = NW.widgets.Button(frame, "Редактировать", function()
			NP.Editor(NP.entity, table.Copy(NP.config))
		end, false, "edit")

		edit:SetSize(sh * 0.2, sh * 0.042)
		edit:SetPos(sw - sh * 0.23, sh * 0.02)
	end

	local close = NW.widgets.Button(frame, "✕", NP.Close)

	close:SetSize(sh * 0.042, sh * 0.042)
	close:SetPos(sw - sh * 0.065 - (NP.admin and sh * 0.23 or 0), sh * 0.02)
end

function NP.Open()
	if (IsValid(NP.frame)) then
		NP.frame:Remove()
	end

	if (INV.IsOpen and INV.IsOpen()) then
		INV.Close()
	end

	local frame = vgui.Create("EditablePanel")

	frame:SetSize(ScrW(), ScrH())
	frame:MakePopup()
	frame.appear = 0
	NP.frame = frame

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.closing and 0 or 1, FrameTime() / 0.35)

		if (self.closing and self.appear <= 0) then
			self:Remove()

			return
		end

		local client = LocalPlayer()

		if (!self.closing and (!IsValid(NP.entity) or !client:Alive() or
			client:GetPos():DistToSqr(NP.entity:GetPos()) > 200 * 200)) then
			NP.Close()
		end
	end

	-- the bars top and bottom, the shade under the dialogue
	frame.Paint = function(self, w, h)
		local e = Ease(self.appear)
		local bar = h * 0.09 * e

		surface.SetMaterial(U.Material(MAT .. "shade.png"))
		surface.SetDrawColor(255, 255, 255, 255 * e)
		surface.DrawTexturedRect(0, h * 0.45, w, h * 0.55)
		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, w, bar)
		surface.DrawRect(0, h - bar, w, bar)
	end

	frame.OnKeyCodePressed = function(_, code)
		if (NP.view == "dialog" and NP.node and code >= KEY_1 and code <= KEY_9) then
			local answer = NP.node.answers[code - KEY_1 + 1]

			if (answer) then
				Choose(answer)
			end
		end
	end

	GoNode(NP.config.start)
	U.Play("appear")
end

net.Receive("nwNpcOpen", function()
	local entity = net.ReadEntity()
	local length = net.ReadUInt(32)
	local config = util.JSONToTable(util.Decompress(net.ReadData(length)) or "")
	local state = util.JSONToTable(net.ReadString()) or {}
	local admin = net.ReadBool()

	if (!IsValid(entity) or !config) then
		return
	end

	NP.entity = entity
	NP.config = config
	NP.quests = state.quests or {}
	NP.stock = state.stock or {}
	NP.whitelist = state.whitelist or {}
	NP.faction = state.faction
	NP.admin = admin
	NP.view = "dialog"

	if (IsValid(NP.frame) and !NP.frame.closing) then
		GoNode(NP.node and NPC.Node(config, NP.node.id) and NP.node.id or config.start)
	else
		NP.Open()
	end
end)

net.Receive("nwNpcState", function()
	local entity = net.ReadEntity()
	local state = util.JSONToTable(net.ReadString()) or {}

	if (entity == NP.entity) then
		NP.quests = state.quests or {}
		NP.stock = state.stock or {}
		NP.whitelist = state.whitelist or {}
		NP.faction = state.faction

		-- the quest view may change its buttons, the stock its numbers (not the choice of a spawn)
		if (NP.view != "spawns") then
			timer.Simple(0.1, Rebuild)
		end
	end
end)

hook.Add("NWEscape", "nwNpc", function()
	if (IsValid(NP.editor)) then
		NP.editor:Remove()

		return true
	end

	if (IsValid(NP.frame) and !NP.frame.closing) then
		if (NP.view != "dialog") then
			GoNode(NP.node and NP.node.id or NP.config.start)
		else
			NP.Close()
		end

		return true
	end
end)

-- ----------------------------------------------------------------- editor --
local function Sequences(model)
	local out = {{"", "— стандартная (idle) —"}}

	if (!util.IsValidModel(model or "")) then
		return out
	end

	local entity = ClientsideModel(model)

	if (IsValid(entity)) then
		for index, name in pairs(entity:GetSequenceList() or {}) do
			if (#out < 400) then
				out[#out + 1] = {name, name}
			end
		end

		entity:Remove()
	end

	return out
end

function NP.Editor(entity, cfg)
	local W = NW.widgets
	local sw, sh = ScrW(), ScrH()
	local w, h = math.Round(math.min(sw * 0.86, sh * 1.6)), math.Round(sh * 0.86)
	local frame, box = W.Window("Редактор NPC", w, h)
	local pad = math.Round(sh * 0.02)
	local fh = math.Round(sh * 0.036)
	local tabW = math.Round(sh * 0.18)
	local area = box:Add("EditablePanel")

	NP.editor = frame
	area:SetPos(tabW + pad * 2, box.top)
	area:SetSize(w - tabW - pad * 3, h - box.top - sh * 0.08)

	cfg.nodes = cfg.nodes or {}
	cfg.shop = cfg.shop or {}
	cfg.quests = cfg.quests or {}
	cfg.professions = cfg.professions or {}

	local tabs = {}
	local Show

	local function Field(parent, label, x, y, width, value, onChange, multiline, height)
		W.Label(parent, label, x, y)

		local entry = W.Entry(parent, value, nil, multiline)

		entry:SetPos(x, y + sh * 0.018)
		entry:SetSize(width, height or fh)
		entry.OnChange = function(self)
			onChange(self:GetValue())
		end

		return entry
	end

	local function NumberField(parent, label, x, y, width, value, min, max, onChange)
		W.Label(parent, label, x, y)

		local entry = W.Number(parent, value, min, max)

		entry:SetPos(x, y + sh * 0.018)
		entry:SetSize(width, fh)
		entry.OnChange = function(self)
			onChange(self:GetNumber())
		end

		return entry
	end

	local function ComboField(parent, label, x, y, width, choices, value, onSelect)
		if (label) then
			W.Label(parent, label, x, y)
			y = y + sh * 0.018
		end

		local combo = W.Combo(parent, choices, value)

		combo:SetPos(x, y)
		combo:SetSize(width, fh)
		combo.OnSelect = function(self, _, _, data)
			onSelect(data)
		end

		return combo
	end

	local function NodeChoices()
		local out = {}

		for _, node in ipairs(cfg.nodes) do
			out[#out + 1] = {node.id, node.id .. ":  " .. string.sub(node.text, 1, 40)}
		end

		return out
	end

	local function QuestChoices()
		local out = {}

		for _, quest in ipairs(cfg.quests) do
			out[#out + 1] = {quest.id, quest.id .. ":  " .. quest.name}
		end

		return out
	end

	-- --------------------------------------------------------------- Общее --
	local function General()
		local aw = area:GetWide()
		local y = 0

		Field(area, "Имя", 0, y, aw * 0.48, cfg.name, function(v) cfg.name = v end)
		Field(area, "Модель", aw * 0.5, y, aw * 0.5, cfg.model, function(v) cfg.model = v end)
		y = y + sh * 0.07
		Field(area, "Описание (под именем в диалоге)", 0, y, aw, cfg.description, function(v) cfg.description = v end)
		y = y + sh * 0.07
		NumberField(area, "Скин", 0, y, aw * 0.12, cfg.skin or 0, 0, 63, function(v) cfg.skin = v end)
		ComboField(area, "Анимация (стойка)", aw * 0.14, y, aw * 0.4, Sequences(cfg.model), cfg.sequence or "",
			function(v) cfg.sequence = v end)
		ComboField(area, "Первая реплика", aw * 0.56, y, aw * 0.44, NodeChoices(), cfg.start, function(v)
			cfg.start = v
		end)
		y = y + sh * 0.08

		local hint = area:Add("DLabel")

		hint:SetPos(0, y)
		hint:SetSize(aw, sh * 0.2)
		hint:SetWrap(true)
		hint:SetContentAlignment(7)
		hint:SetFont("nwWidget")
		hint:SetTextColor(MUTED)
		hint:SetText("Модель — путь к .mdl (например models/humans/group01/female_02.mdl). После смены модели " ..
			"сохраните и откройте редактор снова, чтобы увидеть её анимации.\nДиалог — реплики NPC и ответы игрока. " ..
			"Торговля — товары за токены и/или за другой предмет. Задания — принести предметы за награду.")

		-- the type: a ready dialogue for a metrocop who gives the callsigns of units
		local template = W.Button(area, "Тип: метрокоп (позывные)", function()
			cfg.nodes = {
				{id = "start", text = "Юнит. Назовись по форме или проходи.", answers = {
					{text = "Мне нужен позывной.", action = "callsign", target = ""},
					{text = "Ничего. Конец связи.", action = "close", target = ""}
				}}
			}
			cfg.start = "start"

			if (cfg.name == "" or cfg.name == "Торговец" or cfg.name == "NPC") then
				cfg.name = "Диспетчер участка"
			end

			if (string.find(string.lower(cfg.model or ""), "humans/", 1, true)) then
				cfg.model = "models/police.mdl"
			end

			surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
			Show("general")
		end)

		template:SetPos(0, y + sh * 0.13)
		template:SetSize(aw * 0.4, sh * 0.042)
	end

	-- -------------------------------------------------------------- Диалог --
	local selectedNode = 1

	local function Dialog()
		local aw, ah = area:GetWide(), area:GetTall()
		local listW = math.Round(aw * 0.26)
		local scroll = W.Scroll(area)

		scroll:SetPos(0, 0)
		scroll:SetSize(listW, ah - fh - 8)

		for index, node in ipairs(cfg.nodes) do
			local button = W.Button(scroll, node.id, function()
				selectedNode = index
				Show("dialog")
			end, index == selectedNode)

			button:Dock(TOP)
			button:DockMargin(0, 0, 8, 6)
			button:SetTall(fh)
		end

		local add = W.Button(area, "+ Реплика", function()
			local id = "line" .. (#cfg.nodes + 1)

			cfg.nodes[#cfg.nodes + 1] = {id = id, text = "…", answers = {}}
			selectedNode = #cfg.nodes
			Show("dialog")
		end)

		add:SetPos(0, ah - fh)
		add:SetSize(listW - 8, fh)

		local node = cfg.nodes[selectedNode]

		if (!node) then
			return
		end

		local x = listW + pad
		local fw = aw - x
		local y = 0

		Field(area, "ID реплики (латиница)", x, y, fw * 0.4, node.id, function(v) node.id = v end)

		local remove = W.Button(area, "Удалить реплику", function()
			table.remove(cfg.nodes, selectedNode)
			selectedNode = 1
			Show("dialog")
		end)

		remove:SetPos(x + fw * 0.42, y + sh * 0.018)
		remove:SetSize(fw * 0.25, fh)

		y = y + sh * 0.065
		Field(area, "Текст NPC", x, y, fw, node.text, function(v) node.text = v end, true, sh * 0.12)
		y = y + sh * 0.15

		W.Label(area, "Ответы игрока: текст, действие, цель (реплика или задание)", x, y)
		y = y + sh * 0.022

		node.answers = node.answers or {}

		for index, answer in ipairs(node.answers) do
			local entry = W.Entry(area, answer.text)

			entry:SetPos(x, y)
			entry:SetSize(fw * 0.38, fh)
			entry.OnChange = function(self)
				answer.text = self:GetValue()
			end

			ComboField(area, nil, x + fw * 0.39, y, fw * 0.22, NPC.ACTIONS, answer.action or "close", function(v)
				answer.action = v
				Show("dialog")
			end)

			if (answer.action == "goto" or answer.action == "quest") then
				ComboField(area, nil, x + fw * 0.62, y, fw * 0.26, answer.action == "goto" and NodeChoices() or
					QuestChoices(), answer.target, function(v) answer.target = v end)
			end

			local del = W.Button(area, "✕", function()
				table.remove(node.answers, index)
				Show("dialog")
			end)

			del:SetPos(x + fw * 0.9, y)
			del:SetSize(fw * 0.1, fh)

			y = y + fh + 6
		end

		if (#node.answers < 9) then
			local addAnswer = W.Button(area, "+ Ответ", function()
				node.answers[#node.answers + 1] = {text = "…", action = "close", target = ""}
				Show("dialog")
			end)

			addAnswer:SetPos(x, y + 4)
			addAnswer:SetSize(fw * 0.25, fh)
		end
	end

	-- ------------------------------------------------------------ Торговля --
	local function Trade()
		local aw, ah = area:GetWide(), area:GetTall()

		W.Label(area, "Предмет · цена в токенах · или/и предмет-цена и сколько · в наличии (-1 — бесконечно) · " ..
			"скупает за (0 — не скупает)", 0, 0)

		local scroll = W.Scroll(area)

		scroll:SetPos(0, sh * 0.024)
		scroll:SetSize(aw, ah - sh * 0.024 - fh - 8)

		local items = W.ItemChoices()
		local itemsNone = W.ItemChoices(true)

		for index, line in ipairs(cfg.shop) do
			local row = scroll:Add("EditablePanel")

			row:Dock(TOP)
			row:DockMargin(0, 0, 8, 6)
			row:SetTall(fh)

			local function Place(panel, width, margin)
				panel:Dock(LEFT)
				panel:DockMargin(margin or 6, 0, 0, 0)
				panel:SetWide(width)
			end

			local item = W.Combo(row, items, line.item)

			item.OnSelect = function(_, _, _, data) line.item = data end
			Place(item, aw * 0.25, 0)

			local price = W.Number(row, line.price or 0, 0, 1000000)

			price.OnChange = function(self) line.price = self:GetNumber() end
			Place(price, aw * 0.09)

			local priceItem = W.Combo(row, itemsNone, line.priceItem or "")

			priceItem.OnSelect = function(_, _, _, data) line.priceItem = data end
			Place(priceItem, aw * 0.22)

			local count = W.Number(row, line.priceCount or 0, 0, 50)

			count.OnChange = function(self) line.priceCount = self:GetNumber() end
			Place(count, aw * 0.07)

			local stock = W.Entry(row, tostring(line.stock or -1))

			stock.OnChange = function(self) line.stock = math.floor(tonumber(self:GetValue()) or -1) end
			Place(stock, aw * 0.08)

			local sell = W.Number(row, line.sell or 0, 0, 1000000)

			sell.OnChange = function(self) line.sell = self:GetNumber() end
			Place(sell, aw * 0.08)

			local del = W.Button(row, "✕", function()
				table.remove(cfg.shop, index)
				Show("trade")
			end)

			Place(del, aw * 0.06)
		end

		local add = W.Button(area, "+ Товар", function()
			cfg.shop[#cfg.shop + 1] = {item = "water", price = 5, priceItem = "", priceCount = 0, stock = -1, sell = 0}
			Show("trade")
		end)

		add:SetPos(0, ah - fh)
		add:SetSize(aw * 0.2, fh)
	end

	-- ------------------------------------------------------------- Задания --
	local selectedQuest = 1

	local function Quests()
		local aw, ah = area:GetWide(), area:GetTall()
		local listW = math.Round(aw * 0.26)
		local scroll = W.Scroll(area)

		scroll:SetPos(0, 0)
		scroll:SetSize(listW, ah - fh - 8)

		for index, quest in ipairs(cfg.quests) do
			local button = W.Button(scroll, quest.name or quest.id, function()
				selectedQuest = index
				Show("quests")
			end, index == selectedQuest)

			button:Dock(TOP)
			button:DockMargin(0, 0, 8, 6)
			button:SetTall(fh)
		end

		local add = W.Button(area, "+ Задание", function()
			cfg.quests[#cfg.quests + 1] = {id = "quest" .. (#cfg.quests + 1), name = "Новое задание", description = "",
				need = {}, rewardTokens = 0, rewardItems = {}, repeatable = false}
			selectedQuest = #cfg.quests
			Show("quests")
		end)

		add:SetPos(0, ah - fh)
		add:SetSize(listW - 8, fh)

		local quest = cfg.quests[selectedQuest]

		if (!quest) then
			return
		end

		local x = listW + pad
		local fw = aw - x
		local y = 0

		Field(area, "ID (латиница)", x, y, fw * 0.22, quest.id, function(v) quest.id = v end)
		Field(area, "Название", x + fw * 0.24, y, fw * 0.46, quest.name, function(v) quest.name = v end)

		local remove = W.Button(area, "Удалить", function()
			table.remove(cfg.quests, selectedQuest)
			selectedQuest = 1
			Show("quests")
		end)

		remove:SetPos(x + fw * 0.72, y + sh * 0.018)
		remove:SetSize(fw * 0.28, fh)

		y = y + sh * 0.065
		Field(area, "Описание", x, y, fw, quest.description, function(v) quest.description = v end, true, sh * 0.09)
		y = y + sh * 0.12

		local items = W.ItemChoices()

		local function ItemRows(list, label, kind)
			W.Label(area, label, x, y)
			y = y + sh * 0.022

			for index, entry in ipairs(list) do
				local combo = W.Combo(area, items, entry.item)

				combo:SetPos(x, y)
				combo:SetSize(fw * 0.6, fh)
				combo.OnSelect = function(_, _, _, data) entry.item = data end

				local count = W.Number(area, entry.count or 1, 1, 50)

				count:SetPos(x + fw * 0.62, y)
				count:SetSize(fw * 0.14, fh)
				count.OnChange = function(self) entry.count = self:GetNumber() end

				local del = W.Button(area, "✕", function()
					table.remove(list, index)
					Show("quests")
				end)

				del:SetPos(x + fw * 0.78, y)
				del:SetSize(fw * 0.08, fh)
				y = y + fh + 6
			end

			local addItem = W.Button(area, "+ Предмет", function()
				list[#list + 1] = {item = "can_empty", count = 1}
				Show("quests")
			end)

			addItem:SetPos(x, y)
			addItem:SetSize(fw * 0.2, fh)
			y = y + fh + sh * 0.02
		end

		quest.need = quest.need or {}
		quest.rewardItems = quest.rewardItems or {}

		ItemRows(quest.need, "Нужно принести", "need")
		NumberField(area, "Награда: токены", x, y, fw * 0.2, quest.rewardTokens or 0, 0, 1000000, function(v)
			quest.rewardTokens = v
		end)

		local repeatable = W.Check(area, "Можно повторять", quest.repeatable)

		repeatable:SetPos(x + fw * 0.24, y + sh * 0.018)
		repeatable:SetSize(fw * 0.4, fh)
		repeatable.Think = function(self)
			quest.repeatable = self.value
		end

		y = y + sh * 0.07
		ItemRows(quest.rewardItems, "Награда: предметы", "reward")
	end

	-- professions: the factions this NPC hires into and what each takes
	local selectedProfession = 1

	local function Professions()
		local aw, ah = area:GetWide(), area:GetTall()
		local listW = math.Round(aw * 0.26)
		local scroll = W.Scroll(area)

		scroll:SetPos(0, 0)
		scroll:SetSize(listW, ah - fh - 8)

		for index, entry in ipairs(cfg.professions) do
			local faction = NW.char.factions[entry.faction or ""]
			local label = (entry.title or "") != "" and entry.title or (faction and faction.name or "?")
			local button = W.Button(scroll, label, function()
				selectedProfession = index
				Show("professions")
			end, index == selectedProfession)

			button:Dock(TOP)
			button:DockMargin(0, 0, 8, 6)
			button:SetTall(fh)
		end

		local add = W.Button(area, "+ Профессия", function()
			local first

			for id in SortedPairs(NW.char.factions) do
				first = first or id
			end

			cfg.professions[#cfg.professions + 1] = {faction = first, title = "", description = "", access = "free",
				price = 0, item = "", count = 1, consume = true}
			selectedProfession = #cfg.professions
			Show("professions")
		end)

		add:SetPos(0, ah - fh)
		add:SetSize(listW - 8, fh)

		local entry = cfg.professions[selectedProfession]

		if (!entry) then
			local note = W.Label(area, "Добавьте профессию и дайте реплике ответ с действием «Профессии»", listW + pad, 0)

			note:SetTextColor(MUTED)

			return
		end

		local x = listW + pad
		local fw = aw - x
		local y = 0
		local factions = {}

		for id, faction in SortedPairsByMemberValue(NW.char.factions, "name") do
			factions[#factions + 1] = {id, faction.name .. "  (" .. id .. ")"}
		end

		ComboField(area, "Фракция", x, y, fw * 0.44, factions, entry.faction, function(v)
			entry.faction = v
			Show("professions")
		end)
		Field(area, "Название (пусто — как у фракции)", x + fw * 0.46, y, fw * 0.3, entry.title or "",
			function(v) entry.title = v end)

		local remove = W.Button(area, "Удалить", function()
			table.remove(cfg.professions, selectedProfession)
			selectedProfession = 1
			Show("professions")
		end)

		remove:SetPos(x + fw * 0.78, y + sh * 0.018)
		remove:SetSize(fw * 0.22, fh)

		y = y + sh * 0.065
		Field(area, "Описание (пусто — описание фракции)", x, y, fw, entry.description or "",
			function(v) entry.description = v end, true, sh * 0.08)
		y = y + sh * 0.115

		ComboField(area, "Как получить", x, y, fw * 0.44, NPC.ACCESS, entry.access or "free", function(v)
			entry.access = v
			Show("professions")
		end)
		y = y + sh * 0.065

		if (entry.access == "tokens") then
			NumberField(area, "Цена, токены", x, y, fw * 0.2, entry.price or 0, 0, 1000000, function(v)
				entry.price = v
			end)
		elseif (entry.access == "item") then
			ComboField(area, "Предмет", x, y, fw * 0.5, W.ItemChoices(), entry.item, function(v)
				entry.item = v
			end)
			NumberField(area, "Сколько", x + fw * 0.52, y, fw * 0.14, entry.count or 1, 1, 50, function(v)
				entry.count = v
			end)

			local consume = W.Check(area, "Забирать предмет", entry.consume != false)

			consume:SetPos(x + fw * 0.68, y + sh * 0.018)
			consume:SetSize(fw * 0.32, fh)
			consume.Think = function(self)
				entry.consume = self.value
			end
		elseif (entry.access == "whitelist") then
			local note = W.Label(area, "Вайтлист выдаётся командой /whitelist <имя> <фракция>", x, y)

			note:SetTextColor(MUTED)
		else
			local note = W.Label(area, "Профессия бесплатная — ничего не нужно", x, y)

			note:SetTextColor(MUTED)
		end

		y = y + sh * 0.08

		local faction = NW.char.factions[entry.faction or ""]
		local note = W.Label(area, "После вступления игрок выбирает точку появления фракции" ..
			(faction and (" «" .. faction.name .. "»") or "") .. " (точки: /spawnadd)", x, y)

		note:SetTextColor(MUTED)
	end

	local VIEWS = {general = General, dialog = Dialog, trade = Trade, quests = Quests, professions = Professions}

	Show = function(id)
		for _, child in ipairs(area:GetChildren()) do
			child:Remove()
		end

		for key, button in pairs(tabs) do
			button.accent = key == id
		end

		NP.editorTab = id
		VIEWS[id]()
	end

	for index, tab in ipairs({{"general", "Общее"}, {"dialog", "Диалог"}, {"trade", "Торговля"},
		{"quests", "Задания"}, {"professions", "Профессии"}}) do
		local button = W.Button(box, tab[2], function()
			Show(tab[1])
		end)

		button:SetPos(pad, box.top + (index - 1) * (fh + 8))
		button:SetSize(tabW, fh)

		-- the open tab is gold
		local paint = button.Paint

		button.Paint = function(self, bw, bh)
			if (self.accent) then
				draw.RoundedBox(4, 0, 0, bw, bh, ACCENT)
				draw.SimpleText(self.label, "nwWidgetBold", bw / 2, bh / 2, Color(20, 20, 22), TEXT_ALIGN_CENTER,
					TEXT_ALIGN_CENTER)

				return
			end

			paint(self, bw, bh)
		end

		tabs[tab[1]] = button
	end

	local save = W.Button(box, "Сохранить", function()
		local data = util.Compress(util.TableToJSON(cfg))

		net.Start("nwNpcSave")
			net.WriteEntity(entity)
			net.WriteUInt(#data, 32)
			net.WriteData(data, #data)
		net.SendToServer()
		frame:Remove()
	end, true)

	save:SetPos(w - pad - sh * 0.2, h - sh * 0.06)
	save:SetSize(sh * 0.2, fh)

	local cancel = W.Button(box, "Отмена", function()
		frame:Remove()
	end)

	cancel:SetPos(w - pad * 2 - sh * 0.4, h - sh * 0.06)
	cancel:SetSize(sh * 0.2, fh)

	Show(NP.editorTab or "general")
end
