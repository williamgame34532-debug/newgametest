-- Between players, the client side (server: sv_social.lua).
--   the wheel     look at a character close by: under the name and description over the body
--                 "[E] Взаимодействие"; E opens a ring: Познакомиться, Передать токены, Показать
--                 CID-карту, Осмотреть. Click - take, RMB / ESC / E - close.
--   a request     another player wants something: a card on the right with who and what, the time
--                 left and the keys "Принять" / "Отказаться" (F1 / F2 by default, Бинды).
--   the CID card  a window with the card: photo, name, CID number, faction, issue date,
--                 description. Click / ESC closes it.
--   examining     the full description of the character (the name only if you know them).

NW.social = NW.social or {}

local SO = NW.social
local U = NW.ui
local KS = NW.keys
local ACCENT = Color(232, 196, 72)
local MUTED = Color(124, 128, 134)
local RANGE = 110

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwSocialName", "Montserrat SemiBold", 0.024, 600)
	F("nwSocialSmall", "Exo 2", 0.0155, 500)
	F("nwSocialLabel", "Montserrat Medium", 0.0135, 500)
	F("nwSocialText", "Exo 2", 0.019, 500)
	F("nwSocialKey", "Montserrat SemiBold", 0.016, 700)
	F("nwCidTitle", "Jura", 0.022, 700)
	F("nwCidField", "Montserrat Medium", 0.0118, 500)
	F("nwCidValue", "Exo 2", 0.0215, 600)
	F("nwCidNumber", "Jura", 0.034, 700)
	F("nwCidText", "Exo 2", 0.0152, 400)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwSocialFonts", Fonts)

local function Ease(t)
	return 1 - (1 - t) ^ 3
end

local function Arc(cx, cy, r1, r2, a1, a2, color)
	local steps = math.max(2, math.ceil((a2 - a1) / 4))

	draw.NoTexture()
	surface.SetDrawColor(color)

	for i = 0, steps - 1 do
		local s = math.rad(a1 + (a2 - a1) * i / steps)
		local e = math.rad(a1 + (a2 - a1) * (i + 1) / steps)

		surface.DrawPoly({
			{x = cx + math.cos(s) * r1, y = cy + math.sin(s) * r1},
			{x = cx + math.cos(s) * r2, y = cy + math.sin(s) * r2},
			{x = cx + math.cos(e) * r2, y = cy + math.sin(e) * r2},
			{x = cx + math.cos(e) * r1, y = cy + math.sin(e) * r1}
		})
	end
end

local function Disc(cx, cy, r, color)
	Arc(cx, cy, 0, r, 0, 360, color)
end

local function Visible(client, target)
	return NW.char.Knows(client, target) and target:Nick() or "Неизвестный"
end

local function KeyName(id)
	local name = input.GetKeyName(KS.Get(id) or 0)

	return U.Upper(name or "?")
end

-- ---------------------------------------------------------------- knowing --
NW.char.known = NW.char.known or {}

net.Receive("nwKnown", function()
	NW.char.known = {}

	for id in string.gmatch(net.ReadString(), "[^,]+") do
		NW.char.known[id] = true
	end
end)

hook.Add("NWRecognizes", "nwSocial", function(client, target)
	if (client == LocalPlayer() and IsValid(target) and target:GetCharacterID() != 0 and
		NW.char.known[tostring(target:GetCharacterID())]) then
		return true
	end
end)

-- ------------------------------------------------------------------ send --
local function Send(kind, target, amount)
	net.Start("nwSocial")
		net.WriteString(kind)
		net.WriteEntity(target)
		net.WriteUInt(math.Clamp(math.floor(amount or 0), 0, 16000000), 24)
	net.SendToServer()
end

-- the character you look at, close enough to interact
function SO.Aimed()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or client:GetCharacterID() == 0) then
		return
	end

	local trace = client:GetEyeTrace()
	local target = trace.Entity

	if (IsValid(target) and target:IsPlayer() and target:Alive() and target:GetCharacterID() != 0 and
		target:GetPos():DistToSqr(client:GetPos()) < RANGE * RANGE) then
		return target
	end

	-- a body (unconscious or dead, sv_body.lua)
	if (SO.IsBody(target) and trace.HitPos:DistToSqr(client:EyePos()) < RANGE * RANGE) then
		return target
	end
end

function SO.IsBody(entity)
	return IsValid(entity) and entity:GetClass() == "prop_ragdoll" and
		(entity:GetNW2Bool("nwCorpse", false) or IsValid(entity:GetNW2Entity("nwPlayer")))
end

-- standing behind the target (searching)
local function Behind(target)
	local forward = target:EyeAngles():Forward()
	local toMe = LocalPlayer():GetPos() - target:GetPos()

	forward.z = 0
	toMe.z = 0

	return forward:GetNormalized():Dot(toMe:GetNormalized()) < -0.35
end

local function HasMedical()
	local data = NW.inventory and NW.inventory.data

	for _, cell in pairs(data and data.grid or {}) do
		local item = NW.items.Get(cell.id)

		if (NW.medical.IsMedical(item)) then
			return true
		end
	end

	return false
end

-- the name of a body, if you knew them
local function BodyName(body)
	local id = body:GetNW2Int("nwCharID", 0)

	return NW.char.known[tostring(id)] and body:GetNW2String("nwName", "") or "Тело"
end

local function HasCard()
	local data = NW.inventory and NW.inventory.data

	for _, cell in pairs(data and data.grid or {}) do
		if (cell.id == "cid") then
			return true
		end
	end

	return false
end

-- ------------------------------------------------------- the token amount --
local function AskAmount(target)
	if (IsValid(SO.amount)) then
		SO.amount:Remove()
	end

	local sw, sh = ScrW(), ScrH()
	local w, h = math.Round(sh * 0.4), math.Round(sh * 0.22)
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame.appear = 0
	SO.amount = frame

	local box = {x = (sw - w) / 2, y = (sh - h) / 2, w = w, h = h}
	local pad = math.Round(sh * 0.02)
	local entry = frame:Add("DTextEntry")

	entry:SetPos(box.x + pad, box.y + pad + sh * 0.06)
	entry:SetSize(w - pad * 2, math.Round(sh * 0.042))
	entry:SetNumeric(true)
	entry:SetFont("nwSocialName")
	entry:SetPaintBackground(false)
	entry:SetTextColor(U.color.text)
	entry:SetCursorColor(ACCENT)
	entry:SetText("")
	entry:RequestFocus()
	entry.PaintOver = function(self, pw, ph)
		surface.SetDrawColor(255, 255, 255, 40)
		surface.DrawRect(0, ph - 2, pw, 2)
	end

	local function Close()
		if (IsValid(frame)) then
			frame:Remove()
		end
	end

	local function Confirm()
		local amount = tonumber(entry:GetValue() or "") or 0

		if (amount >= 1 and IsValid(target)) then
			Send("tokens", target, amount)
			surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
		end

		Close()
	end

	entry.OnEnter = Confirm

	local bw = math.Round((w - pad * 3) / 2)
	local by = box.y + h - pad - math.Round(sh * 0.042)

	for index, data in ipairs({{"Отмена", Close}, {"Передать", Confirm, true}}) do
		local button = frame:Add("DButton")

		button:SetPos(box.x + pad + (index - 1) * (bw + pad), by)
		button:SetSize(bw, math.Round(sh * 0.042))
		button:SetText("")
		button.DoClick = data[2]
		button.Paint = function(self, pw, ph)
			local hover = self:IsHovered()
			local fill = data[3] and (hover and Color(246, 210, 90) or ACCENT) or
				(hover and Color(56, 60, 66) or Color(32, 35, 39))

			draw.RoundedBox(5, 0, 0, pw, ph, fill)
			draw.SimpleText(data[1], "nwSocialText", pw / 2, ph / 2, data[3] and Color(20, 20, 22) or U.color.text,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	frame.OnMousePressed = function(self, code)
		local mx, my = self:CursorPos()

		if (mx < box.x or mx > box.x + w or my < box.y or my > box.y + h) then
			Close()
		end
	end

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, 1, FrameTime() / 0.15)

		if (!IsValid(target)) then
			Close()
		end
	end

	frame.Paint = function(self, pw, ph)
		local e = Ease(self.appear)

		surface.SetDrawColor(0, 0, 0, 120 * e)
		surface.DrawRect(0, 0, pw, ph)
		draw.RoundedBox(8, box.x, box.y, w, h, Color(14, 16, 19, 240 * e))
		draw.RoundedBox(2, box.x, box.y, w, 3, ColorAlpha(ACCENT, 255 * e))
		draw.SimpleText("Передать токены: " .. (IsValid(target) and Visible(LocalPlayer(), target) or ""),
			"nwSocialName", box.x + pad, box.y + pad, ColorAlpha(U.color.text, 255 * e))
		draw.SimpleText("У вас: " .. LocalPlayer():GetNW2Int("nwTokens", 0) .. " ток. Сколько передать?",
			"nwSocialSmall", box.x + pad, box.y + pad + sh * 0.034, ColorAlpha(MUTED, 255 * e))
	end
end

-- -------------------------------------------------------------- the wheel --
local function BodyItems(body)
	local pulse = NW.body.pulse[body]
	local alive = IsValid(body:GetNW2Entity("nwPlayer"))
	local items = {
		{name = "Проверить пульс", icon = "pulse", hint = pulse == nil and "Сначала — пульс: жив ли человек" or
			(pulse and "Пульс есть" or "Пульса нет"), run = function() Send("pulse", body) end}
	}

	if (pulse == true and alive) then
		local medical = HasMedical()

		items[#items + 1] = {name = "Помочь встать", icon = "helpup", hint = "Поднять человека на ноги",
			run = function() Send("helpup", body) end}
		items[#items + 1] = {name = "Подлечить", icon = "heal", disabled = !medical,
			hint = medical and "Бинт, аптечка или таблетки из вашего инвентаря" or "Нечем лечить",
			run = function() Send("heal", body) end}
	elseif (pulse == false and !alive) then
		items[#items + 1] = {name = "Обыскать", icon = "search", hint = "Что осталось при нём",
			run = function() Send("searchbody", body) end}
	end

	return items
end

-- a door (held E, cl_doors.lua): knock; the Alliance kicks a locked one down
local function DoorItems(door)
	local function Act(action)
		net.Start("nwDoorAction")
			net.WriteString(action)
			net.WriteEntity(door)
		net.SendToServer()
	end

	local items = {
		{name = "Постучать", icon = "door", hint = "Постучать в дверь", run = function() Act("knock") end}
	}

	if (NW.zones.IsAlliance(LocalPlayer())) then
		items[#items + 1] = {name = "Выбить дверь", icon = "kick", hint = "Запертую: удар ногой, замок ломается",
			run = function() Act("kick") end}
	end

	-- a combine lock on the door: its mode (who opens it, the self-locking)
	local lock = NW.LockOf and NW.LockOf(door)

	if (IsValid(lock) and (NW.zones.IsAlliance(LocalPlayer()) or LocalPlayer():IsAdmin())) then
		items[#items + 1] = {name = "Режим замка", icon = "lock", hint = "Кто открывает и самозапирание",
			run = function()
				timer.Simple(0.1, function()
					NW.LockMenu(lock)
				end)
			end}
	end

	return items
end

local function Items(target)
	if (NW.doors.IsDoor(target)) then
		return DoorItems(target)
	end

	if (!target:IsPlayer()) then
		return BodyItems(target)
	end

	local client = LocalPlayer()
	local known = NW.char.Knows(client, target)
	local tokens = client:GetNW2Int("nwTokens", 0)
	local card = HasCard()

	local items = {
		{name = "Познакомиться", icon = "meet", disabled = known,
			hint = known and "Вы уже знакомы" or "Предложить знакомство: после согласия вы будете знать имена друг друга",
			run = function() Send("meet", target) end},
		{name = "Передать токены", icon = "tokens", disabled = tokens < 1,
			hint = tokens < 1 and "У вас нет токенов" or ("У вас " .. tokens .. " ток. Передача — после согласия"),
			run = function() AskAmount(target) end},
		{name = "Показать CID-карту", icon = "cid", disabled = !card,
			hint = card and "Показать свою карту, если согласятся её посмотреть" or "У вас нет CID-карты",
			run = function() Send("cid", target) end},
		{name = "Осмотреть", icon = "examine", hint = "Внешность и приметы", run = function() Send("examine", target) end},
		{name = "Обыскать", icon = "search", disabled = !Behind(target),
			hint = Behind(target) and "Быстро обыскать одежду и карманы" or "Только со спины: зайдите сзади",
			run = function() Send("search", target) end}
	}

	-- other systems add theirs (sh_rebels.lua: recruiting)
	hook.Run("NWSocialItems", target, items)

	return items
end

SO.Send = Send

function SO.IsOpen()
	return IsValid(SO.wheel)
end

function SO.Close()
	if (IsValid(SO.wheel)) then
		SO.wheel.closing = true
		SO.wheel:SetMouseInputEnabled(false)
	end
end

function SO.Open(target)
	if (SO.IsOpen() or !IsValid(target)) then
		return
	end

	local sw, sh = ScrW(), ScrH()
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.appear = 0
	frame.target = target
	frame.items = Items(target)
	frame.inner = math.Round(sh * 0.085)
	frame.outer = math.Round(sh * 0.19)
	frame.opened = RealTime()
	SO.wheel = frame

	input.SetCursorPos(sw / 2, sh / 2)

	local function Hovered()
		local mx, my = input.GetCursorPos()
		local dx, dy = mx - sw / 2, my - sh / 2

		if (math.sqrt(dx * dx + dy * dy) < frame.inner * 0.55) then
			return
		end

		local count = #frame.items
		local angle = (math.deg(math.atan2(dy, dx)) + 90 + 360 / count / 2) % 360

		return math.floor(angle / (360 / count)) + 1
	end

	frame.OnMousePressed = function(self, code)
		if (code == MOUSE_LEFT) then
			local item = self.hover and self.items[self.hover]

			if (item and !item.disabled) then
				item.run()
				surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
				SO.Close()
			elseif (!item) then
				SO.Close()
			end
		else
			SO.Close()
		end
	end

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.closing and 0 or 1, FrameTime() / 0.16)

		if (self.closing) then
			if (self.appear <= 0) then
				self:Remove()
			end

			return
		end

		local client = LocalPlayer()

		-- walked away, died...
		if (!IsValid(target) or (target:IsPlayer() and !target:Alive()) or !client:Alive() or
			target:GetPos():DistToSqr(client:GetPos()) > (RANGE * 1.6) ^ 2) then
			SO.Close()

			return
		end

		local index = Hovered()

		if (index != self.hover) then
			self.hover = index

			if (index) then
				surface.PlaySound("network2/ui/hover.wav")
			end
		end
	end

	frame.Paint = function(self, w, h)
		local e = Ease(self.appear)
		local items = self.items
		local cx, cy = w / 2, h / 2
		local inner = self.inner * (0.85 + 0.15 * e)
		local outer = self.outer * (0.85 + 0.15 * e)
		local span = 360 / #items
		local gap = 1.6

		Disc(cx, cy, outer + h * 0.03, Color(0, 0, 0, 70 * e))

		for index, item in ipairs(items) do
			local a1 = -90 - span / 2 + (index - 1) * span + gap / 2
			local a2 = a1 + span - gap
			local hovered = self.hover == index and !item.disabled

			Arc(cx, cy, inner, outer, a1, a2, hovered and Color(46, 50, 56, 235 * e) or Color(16, 18, 21, 215 * e))
			Arc(cx, cy, outer - 3, outer, a1, a2, hovered and ColorAlpha(ACCENT, 255 * e) or Color(255, 255, 255, 22 * e))

			local mid = math.rad((a1 + a2) / 2)
			local r = (inner + outer) / 2
			local ix, iy = cx + math.cos(mid) * r, cy + math.sin(mid) * r
			local is = math.Round(h * 0.036 * (hovered and 1.12 or 1))
			local color = item.disabled and Color(90, 92, 96) or (hovered and U.color.text or U.color.dim)

			U.DrawIcon(item.icon, ix - is / 2, iy - is / 2 - h * 0.01, is, color, e)
			draw.SimpleText(item.name, "nwSocialLabel", ix, iy + is / 2 - h * 0.002, ColorAlpha(color, 255 * e),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end

		-- the centre: who, and what is pointed at
		Disc(cx, cy, inner - h * 0.008, Color(10, 12, 14, 235 * e))

		local item = self.hover and items[self.hover]
		local title = item and item.name or (IsValid(self.target) and (self.target:IsPlayer() and
			Visible(LocalPlayer(), self.target) or (NW.doors.IsDoor(self.target) and
			(self.target:GetNW2String("nwDoorName", "") != "" and self.target:GetNW2String("nwDoorName", "") or "Дверь") or
			BodyName(self.target))) or "")
		local hint = item and item.hint or "Выберите действие"

		draw.SimpleText(title, "nwSocialName", cx, cy - h * 0.014, ColorAlpha(U.color.text, 255 * e),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		for i, line in ipairs(NW.inventory.WrapText(hint, "nwSocialSmall", inner * 1.6)) do
			if (i > 3) then
				break
			end

			draw.SimpleText(line, "nwSocialSmall", cx, cy + h * 0.01 + (i - 1) * h * 0.018,
				ColorAlpha(MUTED, 255 * e), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	U.Play("appear")
end

-- E on a character close by: the wheel instead of +use
hook.Add("PlayerBindPress", "nwSocial", function(client, bind, bPressed)
	if (!bPressed or !string.find(bind, "+use", 1, true)) then
		return
	end

	if (SO.IsOpen()) then
		SO.Close()

		return true
	end

	local target = SO.Aimed()

	if (target and !vgui.CursorVisible()) then
		SO.Open(target)

		return true
	end
end)

-- the hint under the name over the body (cl_overhead.lua calls it with the bottom of its text)
function SO.DrawHint(target, x, y, alpha)
	if (target != SO.Aimed() or SO.IsOpen()) then
		return
	end

	NW.interact.DrawKey(input.LookupBinding("+use", true) or "E", "Взаимодействие", x, y + ScrH() * 0.03, alpha)
end

-- -------------------------------------------------------------- requests --
SO.requests = SO.requests or {}

local TEXTS = {
	meet = "хочет познакомиться с вами",
	tokens = "хочет передать вам %d ток.",
	cid = "показывает вам свою CID-карту"
}

-- other systems add the texts of their requests
SO.requestTexts = TEXTS

net.Receive("nwRequest", function()
	local id = net.ReadUInt(16)
	local from = net.ReadEntity()
	local kind = net.ReadString()
	local amount = net.ReadUInt(24)
	local wait = net.ReadUInt(8)

	SO.request = {id = id, from = from, kind = kind, amount = amount, born = RealTime(), expires = RealTime() + wait,
		alpha = 0}
	surface.PlaySound("network2/ui/hls_hint.wav")
end)

local function Answer(yes)
	local request = SO.request

	if (!request or request.answered) then
		return false
	end

	request.answered = true
	request.expires = math.min(request.expires, RealTime() + 0.3)

	net.Start("nwRequestAnswer")
		net.WriteUInt(request.id, 16)
		net.WriteBool(yes)
	net.SendToServer()

	surface.PlaySound(yes and "network2/ui/char/hls_ui_affirm.wav" or "network2/ui/click.wav")

	return true
end

hook.Add("NWKey", "nwSocial", function(id)
	if (id == "accept") then
		Answer(true)
	elseif (id == "decline") then
		Answer(false)
	end
end)

-- the F1 / F2 binds of the game open nothing now
hook.Add("PlayerBindPress", "nwSocialHelp", function(client, bind)
	if (string.find(bind, "gm_showhelp", 1, true) or string.find(bind, "gm_showteam", 1, true)) then
		return true
	end
end)

local function DrawKeyCap(key, x, y, size, alpha)
	surface.SetMaterial(U.Material("network2/ui/key.png"))
	surface.SetDrawColor(255, 255, 255, 255 * alpha)
	surface.DrawTexturedRect(x, y - size / 2, size, size)
	draw.SimpleText(key, "nwSocialKey", x + size / 2, y - 1, ColorAlpha(U.color.text, 255 * alpha), TEXT_ALIGN_CENTER,
		TEXT_ALIGN_CENTER)
end

hook.Add("HUDPaint", "nwSocialRequest", function()
	local request = SO.request

	if (!request) then
		return
	end

	local now = RealTime()
	local live = now < request.expires and IsValid(request.from)

	request.alpha = math.Approach(request.alpha, live and 1 or 0, FrameTime() * 5)

	if (!live and request.alpha <= 0) then
		SO.request = nil

		return
	end

	local sw, sh = ScrW(), ScrH()
	local a = Ease(request.alpha)
	local w = math.Round(sh * 0.36)
	local pad = math.Round(sh * 0.016)
	local x = sw - w - sh * 0.03 + (1 - a) * sh * 0.04
	local y = math.Round(sh * 0.3)
	local who = IsValid(request.from) and Visible(LocalPlayer(), request.from) or "Неизвестный"
	local text = string.format(TEXTS[request.kind] or "что-то предлагает", request.amount)
	local lines = NW.inventory.WrapText(who .. " " .. text, "nwSocialText", w - pad * 2)
	local lh = sh * 0.024
	local ks = math.Round(sh * 0.032)
	local h = pad * 2 + sh * 0.02 + #lines * lh + sh * 0.012 + ks + sh * 0.01

	draw.RoundedBox(6, x, y, w, h, Color(12, 14, 17, 225 * a))
	draw.RoundedBox(2, x, y, 3, h, ColorAlpha(ACCENT, 255 * a))
	draw.SimpleText("ЗАПРОС", "nwSocialLabel", x + pad, y + pad, ColorAlpha(ACCENT, 255 * a))

	local ty = y + pad + sh * 0.022

	for _, line in ipairs(lines) do
		draw.SimpleText(line, "nwSocialText", x + pad, ty, ColorAlpha(U.color.text, 255 * a))
		ty = ty + lh
	end

	-- the keys
	local ky = ty + sh * 0.012 + ks / 2

	DrawKeyCap(KeyName("accept"), x + pad, ky, ks, a)
	draw.SimpleText("Принять", "nwSocialSmall", x + pad + ks + sh * 0.007, ky, ColorAlpha(U.color.text, 255 * a),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	local half = x + w / 2

	DrawKeyCap(KeyName("decline"), half, ky, ks, a)
	draw.SimpleText("Отказаться", "nwSocialSmall", half + ks + sh * 0.007, ky, ColorAlpha(U.color.text, 255 * a),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

	-- the time left
	local left = math.Clamp((request.expires - now) / math.max(request.expires - request.born, 0.01), 0, 1)

	surface.SetDrawColor(255, 255, 255, 20 * a)
	surface.DrawRect(x + 3, y + h - 3, w - 3, 3)
	surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 200 * a)
	surface.DrawRect(x + 3, y + h - 3, (w - 3) * left, 3)
end)

-- --------------------------------------------------------------- the card --
local function CloseCard()
	if (IsValid(SO.card)) then
		SO.card.closing = true
		SO.card:SetMouseInputEnabled(false)

		return true
	end
end

-- a barcode drawn from the number (the same number - the same stripes)
local function Barcode(number, x, y, w, h, alpha)
	local seed = tonumber(number) or 0
	local px = x

	surface.SetDrawColor(220, 224, 228, 200 * alpha)

	while (px < x + w) do
		seed = (seed * 1103515245 + 12345) % 2147483648

		local bar = 1 + seed % 3
		local space = 1 + math.floor(seed / 8) % 3

		surface.DrawRect(math.Round(px), y, bar, h)
		px = px + bar + space
	end
end

function SO.ShowCard(data)
	if (IsValid(SO.card)) then
		SO.card:Remove()
	end

	local sw, sh = ScrW(), ScrH()
	local w = math.Round(sh * 0.66)
	local h = math.Round(w * 0.6)
	local x, y = math.Round((sw - w) / 2), math.Round((sh - h) / 2)
	local pad = math.Round(h * 0.06)
	local photoW = math.Round(h * 0.48)
	local photoH = math.Round(photoW * 1.25)
	local header = math.Round(h * 0.16)
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.appear = 0
	SO.card = frame

	-- the photo: the head of the model the card was issued with
	local photo = frame:Add("DModelPanel")

	photo:SetPos(x + pad, y + header + pad * 0.6)
	photo:SetSize(photoW, photoH)
	photo:SetModel(data.model or "models/player/kleiner.mdl")
	photo:SetFOV(24)
	photo:SetMouseInputEnabled(false)
	photo:SetAmbientLight(Color(70, 74, 80))
	photo:SetDirectionalLight(BOX_FRONT, Color(255, 246, 232))
	photo:SetDirectionalLight(BOX_TOP, Color(120, 124, 130))

	local entity = photo:GetEntity()

	if (IsValid(entity)) then
		entity:SetSkin(tonumber(data.skin) or 0)

		local idle = entity:SelectWeightedSequence(ACT_IDLE)

		entity:ResetSequence(idle and idle > 0 and idle or 0)
		entity:SetCycle(0)
	end

	photo.LayoutEntity = function(self, ent)
		ent:SetAngles(Angle(0, 0, 0))

		local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
		local pos = bone and ent:GetBonePosition(bone) or (ent:GetPos() + Vector(0, 0, 64))

		pos = pos + Vector(0, 0, -1)
		self:SetLookAt(pos)
		self:SetCamPos(pos + Vector(34, 4, 1))
	end

	photo.PreDrawModel = function(self)
		local e = Ease(frame.appear)

		render.SetBlend(e)
	end

	photo.PostDrawModel = function()
		render.SetBlend(1)
	end

	frame.OnMousePressed = function()
		CloseCard()
	end

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.closing and 0 or 1, FrameTime() / 0.2)

		if (self.closing and self.appear <= 0) then
			self:Remove()
		end
	end

	local faction = NW.char.factions[data.faction or ""]

	frame.Paint = function(self, pw, ph)
		local e = Ease(self.appear)
		local oy = math.Round((1 - e) * sh * 0.03)

		photo:SetPos(x + pad, y + oy + header + pad * 0.6)

		surface.SetDrawColor(0, 0, 0, 150 * e)
		surface.DrawRect(0, 0, pw, ph)

		local cy = y + oy

		-- the card: cold grey-blue plastic, a dark band on top
		draw.RoundedBox(10, x - 2, cy - 2, w + 4, h + 4, Color(0, 0, 0, 120 * e))
		draw.RoundedBox(10, x, cy, w, h, Color(176, 186, 192, 255 * e))
		draw.RoundedBoxEx(10, x, cy, w, header, Color(30, 38, 46, 255 * e), true, true, false, false)
		surface.SetDrawColor(ACCENT.r, ACCENT.g, ACCENT.b, 255 * e)
		surface.DrawRect(x, cy + header, w, 3)

		-- faint stripes across the plastic
		for i = 0, 7 do
			surface.SetDrawColor(255, 255, 255, 14 * e)
			surface.DrawRect(x, cy + header + 3 + i * (h - header) / 8, w, math.Round((h - header) / 16))
		end

		if (faction and faction.logo) then
			local ls = header - pad * 0.8

			surface.SetMaterial(U.Material("network2/factions/" .. faction.logo .. ".png"))
			surface.SetDrawColor(230, 232, 236, 230 * e)
			surface.DrawTexturedRect(x + pad * 0.7, cy + pad * 0.4, ls, ls)
		end

		draw.SimpleText("ГРАЖДАНСКОЕ УДОСТОВЕРЕНИЕ", "nwCidTitle", x + pad * 0.7 + header, cy + header / 2 - 1,
			Color(232, 236, 240, 255 * e), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("C-I-D", "nwCidTitle", x + w - pad, cy + header / 2 - 1, ColorAlpha(ACCENT, 255 * e),
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

		-- the photo frame
		local px, py = x + pad, cy + header + pad * 0.6

		surface.SetDrawColor(46, 52, 58, 255 * e)
		surface.DrawRect(px - 3, py - 3, photoW + 6, photoH + 6)
		surface.SetDrawColor(120, 132, 140, 255 * e)
		surface.DrawRect(px, py, photoW, photoH)

		-- the fields
		local fx = px + photoW + pad
		local fy = py
		local dark = Color(26, 30, 34, 255 * e)
		local label = Color(70, 78, 86, 255 * e)

		local function Field(name, value, font)
			draw.SimpleText(name, "nwCidField", fx, fy, label)
			fy = fy + sh * 0.016
			draw.SimpleText(value, font or "nwCidValue", fx, fy, dark)
			fy = fy + (font == "nwCidNumber" and sh * 0.042 or sh * 0.031)
		end

		Field("НОМЕР", "#" .. tostring(data.number or "00000"), "nwCidNumber")
		Field("ИМЯ", data.name or "—")
		Field("ПОЛ", data.gender == "female" and "Женский" or "Мужской")
		Field("ВЫДАНО", data.issued or "—")

		-- the description under it all
		local dy = py + photoH + pad * 0.5
		local width = w - pad * 2

		draw.SimpleText("ПРИМЕТЫ", "nwCidField", x + pad, dy, label)
		dy = dy + sh * 0.016

		for i, line in ipairs(NW.inventory.WrapText(data.description or "", "nwCidText", width * 0.7)) do
			if (i > 3) then
				break
			end

			draw.SimpleText(line, "nwCidText", x + pad, dy, dark)
			dy = dy + sh * 0.018
		end

		Barcode(data.number, x + w - pad - width * 0.26, cy + h - pad - sh * 0.04, width * 0.26, sh * 0.04, e)

		draw.SimpleText("Клик или ESC — закрыть", "nwSocialSmall", pw / 2, cy + h + sh * 0.025,
			Color(200, 204, 210, 200 * e), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end

	U.Play("appear")
end

net.Receive("nwCidShow", function()
	local data = util.JSONToTable(net.ReadString()) or {}

	SO.ShowCard(data)
end)

-- -------------------------------------------------------------- examining --
net.Receive("nwExamine", function()
	local target = net.ReadEntity()
	local text = net.ReadString()

	if (!IsValid(target)) then
		return
	end

	if (IsValid(SO.examine)) then
		SO.examine:Remove()
	end

	local sw, sh = ScrW(), ScrH()
	local w = math.Round(sh * 0.5)
	local pad = math.Round(sh * 0.02)
	local name = Visible(LocalPlayer(), target)
	local lines = NW.inventory.WrapText(text, "nwSocialText", w - pad * 2)
	local lh = math.Round(sh * 0.025)
	local h = pad * 2 + sh * 0.04 + #lines * lh + sh * 0.03
	local frame = vgui.Create("EditablePanel")

	frame:SetSize(sw, sh)
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	frame.appear = 0
	SO.examine = frame

	frame.OnMousePressed = function(self)
		self.closing = true
		self:SetMouseInputEnabled(false)
	end

	frame.Think = function(self)
		self.appear = math.Approach(self.appear, self.closing and 0 or 1, FrameTime() / 0.18)

		if (self.closing and self.appear <= 0) then
			self:Remove()
		end
	end

	frame.Paint = function(self, pw, ph)
		local e = Ease(self.appear)
		local x, y = (pw - w) / 2, (ph - h) / 2 + (1 - e) * sh * 0.02

		surface.SetDrawColor(0, 0, 0, 120 * e)
		surface.DrawRect(0, 0, pw, ph)
		draw.RoundedBox(8, x, y, w, h, Color(14, 16, 19, 240 * e))
		draw.RoundedBox(2, x, y, w, 3, ColorAlpha(ACCENT, 255 * e))
		draw.SimpleText(name, "nwSocialName", x + pad, y + pad, ColorAlpha(U.color.text, 255 * e))

		local ty = y + pad + sh * 0.04

		for _, line in ipairs(lines) do
			draw.SimpleText(line, "nwSocialText", x + pad, ty, Color(196, 200, 206, 255 * e))
			ty = ty + lh
		end

		draw.SimpleText("Клик или ESC — закрыть", "nwSocialSmall", pw / 2, y + h + sh * 0.02,
			Color(200, 204, 210, 200 * e), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end
end)

-- ESC closes these first (cl_pausemenu.lua)
hook.Add("NWEscape", "nwSocial", function()
	if (IsValid(SO.amount)) then
		SO.amount:Remove()

		return true
	end

	if (SO.IsOpen() and !SO.wheel.closing) then
		SO.Close()

		return true
	end

	if (IsValid(SO.examine) and !SO.examine.closing) then
		SO.examine.closing = true

		return true
	end

	if (IsValid(SO.card) and !SO.card.closing) then
		return CloseCard()
	end
end)
