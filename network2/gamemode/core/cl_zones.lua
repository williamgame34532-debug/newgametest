-- Zones, client side (sh_zones.lua, sv_zones.lua):
--   the name     walking into a zone shows its name on the left, in the middle of the screen
--                height: a thin line grows, the letters come in one by one, it stays 7 seconds and
--                goes; no background
--   radiation    green smoke inside the zone, a Geiger counter while in it, a green tint when the
--                body is not protected
--   the editor   /areaedit (admins): LMB - the first corner, LMB - the second corner, then the
--                window: name, kind and its settings. R - the list of zones (change, delete).
--                RMB - drop the corners. /areaedit again - leave the editor.

local Z = NW.zones
local U = NW.ui
local W = NW.widgets

local function Fonts()
	local h = ScrH()

	surface.CreateFont("nwZoneName", {font = "Oswald Light", size = math.max(28, math.Round(h * 0.058)), weight = 300,
		extended = true, antialias = true})
	surface.CreateFont("nwZoneCaption", {font = "Jura", size = math.max(12, math.Round(h * 0.017)), weight = 700,
		extended = true, antialias = true})
	surface.CreateFont("nwZoneEditor", {font = "Exo 2", size = math.max(13, math.Round(h * 0.017)), weight = 500,
		extended = true, antialias = true})
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwZoneFonts", Fonts)

net.Receive("nwZones", function()
	local length = net.ReadUInt(24)
	local data = util.JSONToTable(util.Decompress(net.ReadData(length)) or "") or {}

	Z.list = {}

	for _, zone in ipairs(data) do
		Z.list[zone.id] = zone
	end
end)

-- ------------------------------------------------------------- the name --
local HOLD = 7
local title

local function Show(zone)
	local kind = Z.typeByID[zone.type] or Z.typeByID.plain
	local letters = {}

	for _, code in utf8.codes(U.Upper(zone.name)) do
		letters[#letters + 1] = utf8.char(code)
	end

	title = {letters = letters, caption = U.Upper(kind.caption), start = RealTime(),
		color = zone.type == "radiation" and Color(150, 220, 110) or U.color.text}
end

local current, nextCheck = nil, 0

hook.Add("Think", "nwZoneEnter", function()
	if (RealTime() < nextCheck) then
		return
	end

	nextCheck = RealTime() + 0.25

	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or client:GetNW2Bool("nwInMenu", false) or
		client:GetCharacterID() == 0) then
		current = nil

		return
	end

	local zone = Z.At(Z.Point(client))
	local id = zone and zone.id or nil

	if (id != current) then
		current = id

		if (zone) then
			Show(zone)
		end
	end
end)

local function Ease(x)
	x = math.Clamp(x, 0, 1)

	return 1 - (1 - x) ^ 3
end

hook.Add("HUDPaint", "nwZoneName", function()
	if (!title) then
		return
	end

	local t = RealTime() - title.start
	local count = #title.letters
	local reveal = 0.45 + count * 0.045
	local total = reveal + HOLD

	if (t > total + 1.2) then
		title = nil

		return
	end

	local out = Ease((t - total) / 1.2)
	local alpha = 1 - out
	local sw, sh = ScrW(), ScrH()
	local x = math.Round(sw * 0.045) - out * sw * 0.01
	local y = math.Round(sh * 0.5)

	-- the caption over the line
	surface.SetFont("nwZoneCaption")

	local captionAlpha = Ease((t - 0.25) / 0.6) * alpha
	local spacing = math.Round(sh * 0.0035)
	local cx = x

	for _, code in utf8.codes(title.caption) do
		local char = utf8.char(code)

		draw.SimpleText(char, "nwZoneCaption", cx, y - math.Round(sh * 0.012), ColorAlpha(U.color.dim, 220 * captionAlpha),
			TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		cx = cx + surface.GetTextSize(char) + spacing
	end

	-- the line grows to the width of the name
	surface.SetFont("nwZoneName")

	local widths, full = {}, 0
	local gap = math.Round(sh * 0.006)

	for i, char in ipairs(title.letters) do
		widths[i] = surface.GetTextSize(char)
		full = full + widths[i] + gap
	end

	local line = Ease(t / 0.45) * math.max(full, sw * 0.08)

	surface.SetDrawColor(ColorAlpha(title.color, 200 * alpha))
	surface.DrawRect(x, y - math.Round(sh * 0.006), line, math.max(1, math.Round(sh * 0.0016)))

	-- the letters, one by one: they fade in and slide up into place
	local lx = x

	for i, char in ipairs(title.letters) do
		local k = Ease((t - 0.3 - (i - 1) * 0.045) / 0.35)

		if (k > 0) then
			local color = ColorAlpha(title.color, 255 * k * alpha)

			draw.SimpleText(char, "nwZoneName", lx + 1, y + (1 - k) * sh * 0.012 + 1, Color(0, 0, 0, 120 * k * alpha),
				TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(char, "nwZoneName", lx, y + (1 - k) * sh * 0.012, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end

		lx = lx + widths[i] + gap
	end
end)

-- --------------------------------------------------------------- radiation --
local SMOKE = {"particle/particle_smokegrenade", "particle/smokesprites_0001", "particle/smokesprites_0003",
	"particle/smokesprites_0005"}
local emitter
local nextSmoke = 0

hook.Add("Think", "nwZoneSmoke", function()
	if (RealTime() < nextSmoke) then
		return
	end

	nextSmoke = RealTime() + 0.18

	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local eye = client:EyePos()

	for _, zone in pairs(Z.list) do
		if (zone.type == "radiation") then
			local mins, maxs = Z.Bounds(zone)
			-- the part of the zone near the player (smoke far away is not seen anyway)
			local lo = Vector(math.max(mins.x, eye.x - 1400), math.max(mins.y, eye.y - 1400), mins.z)
			local hi = Vector(math.min(maxs.x, eye.x + 1400), math.min(maxs.y, eye.y + 1400), maxs.z)

			if (lo.x < hi.x and lo.y < hi.y) then
				if (!IsValid(emitter)) then
					emitter = ParticleEmitter(eye, false)
				end

				local area = (hi.x - lo.x) * (hi.y - lo.y)
				local puffs = math.Clamp(math.ceil(area / 260000), 1, 4)

				for _ = 1, puffs do
					local x, y = math.Rand(lo.x, hi.x), math.Rand(lo.y, hi.y)
					local down = util.TraceLine({start = Vector(x, y, hi.z - 4), endpos = Vector(x, y, lo.z),
						mask = MASK_SOLID_BRUSHONLY})
					local pos = down.HitPos + Vector(0, 0, math.Rand(10, 60))
					local particle = emitter:Add(SMOKE[math.random(#SMOKE)], pos)

					if (particle) then
						local g = math.random(150, 200)

						particle:SetVelocity(Vector(math.Rand(-8, 8), math.Rand(-8, 8), math.Rand(2, 10)))
						particle:SetDieTime(math.Rand(7, 11))
						particle:SetStartAlpha(0)
						particle:SetEndAlpha(0)
						particle:SetStartSize(math.Rand(50, 90))
						particle:SetEndSize(math.Rand(140, 220))
						particle:SetRoll(math.Rand(0, 360))
						particle:SetRollDelta(math.Rand(-0.15, 0.15))
						particle:SetColor(math.random(70, 110), g, math.random(50, 80))
						particle:SetAirResistance(20)
						particle:SetCollide(true)
						particle:SetBounce(0.1)
						-- fade in and out over the life
						particle:SetNextThink(CurTime())
						particle:SetThinkFunction(function(self)
							local life = self:GetLifeTime() / self:GetDieTime()

							local alpha = math.sin(life * math.pi) * 46

							self:SetStartAlpha(alpha)
							self:SetEndAlpha(alpha)
							self:SetNextThink(CurTime() + 0.1)
						end)
					end
				end
			end
		end
	end
end)

-- the Geiger counter: clicks, faster without protection
local nextClick = 0

hook.Add("Think", "nwZoneGeiger", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive() or !client:GetNW2Bool("nwRadiation", false) or RealTime() < nextClick) then
		return
	end

	local safe = client:GetNW2Bool("nwRadSafe", false)

	client:EmitSound("player/geiger" .. math.random(1, 3) .. ".wav", 60, math.random(95, 105), safe and 0.35 or 0.6)
	nextClick = RealTime() + (safe and math.Rand(0.35, 1.1) or math.Rand(0.06, 0.32))
end)

-- unprotected: the picture goes a little green and dull
local tint = 0

hook.Add("RenderScreenspaceEffects", "nwZoneTint", function()
	local client = LocalPlayer()
	local want = IsValid(client) and client:Alive() and client:GetNW2Bool("nwRadiation", false) and
		!client:GetNW2Bool("nwRadSafe", false) and 1 or 0

	tint = math.Approach(tint, want, FrameTime() * 0.8)

	if (tint <= 0.001) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0,
		["$pp_colour_addg"] = 0.03 * tint,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.02 * tint,
		["$pp_colour_contrast"] = 1 + 0.05 * tint,
		["$pp_colour_colour"] = 1 - 0.3 * tint,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0.4 * tint,
		["$pp_colour_mulb"] = 0
	})
end)

-- ---------------------------------------------------------------- editor --
local ED = {active = false}

Z.editor = ED

net.Receive("nwZoneEditor", function()
	ED.active = net.ReadBool()
	ED.a, ED.b = nil, nil

	surface.PlaySound(ED.active and "network2/ui/char/hls_ui_appear.wav" or "network2/ui/click.wav")
end)

local function Aim()
	local client = LocalPlayer()
	local trace = util.TraceLine({start = client:EyePos(), endpos = client:EyePos() + client:GetAimVector() * 4096,
		filter = client, mask = MASK_SOLID})

	return trace.HitPos
end

-- the box of two corners: when both are about on one floor, the zone gets a default height
local function Box(a, b, height)
	local mins = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
	local maxs = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))

	if (height) then
		maxs.z = mins.z + height
	elseif (maxs.z - mins.z < 64) then
		maxs.z = mins.z + Z.limits.height[3]
	end

	mins.z = mins.z - 4

	return mins, maxs
end

local function Send(action, id, zone)
	net.Start("nwZoneEdit")
		net.WriteString(action)
		net.WriteUInt(id or 0, 16)

		if (zone) then
			net.WriteString(util.TableToJSON(zone))
		end
	net.SendToServer()
end

-- the NPC choices: the spawn menu's NPC list, sorted by name
local function NPCChoices()
	local out = {}

	for name, data in pairs(list.Get("NPC")) do
		out[#out + 1] = {name, (data.Name or name) .. "  (" .. name .. ")"}
	end

	table.sort(out, function(a, b)
		return a[2] < b[2]
	end)

	return out
end

local OpenList

-- the window of one zone: name, kind and the settings of the kind
local function OpenForm(zone)
	if (IsValid(ED.form)) then
		ED.form:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.62), math.Round(sh * 0.62)
	local frame, box = W.Window(zone.id and ("Зона: " .. zone.name) or "Новая зона", w, h, function()
		ED.a, ED.b = nil, nil
	end)

	ED.form = frame

	local pad = math.Round(sh * 0.022)
	local fieldH = math.Round(sh * 0.038)
	local inner = w - pad * 2
	local y = box.top

	W.Label(box, "Название", pad, y)
	y = y + math.Round(sh * 0.02)

	local name = W.Entry(box, zone.name or "", "Например: Канал, Завод, Площадь")

	name:SetPos(pad, y)
	name:SetSize(inner, fieldH)
	y = y + fieldH + math.Round(sh * 0.016)

	W.Label(box, "Тип зоны", pad, y)
	W.Label(box, "Высота зоны", pad + inner * 0.62, y)
	y = y + math.Round(sh * 0.02)

	local kinds = {}

	for _, kind in ipairs(Z.types) do
		kinds[#kinds + 1] = {kind.id, kind.name}
	end

	local kind = W.Combo(box, kinds, zone.type or "plain")

	kind:SetPos(pad, y)
	kind:SetSize(inner * 0.58, fieldH)

	local height = W.Number(box, math.Round(zone.max[3] - zone.min[3]), Z.limits.height[1], Z.limits.height[2])

	height:SetPos(pad + inner * 0.62, y)
	height:SetSize(inner * 0.38, fieldH)
	y = y + fieldH + math.Round(sh * 0.02)

	-- the settings of the kind
	local settings = box:Add("EditablePanel")

	settings:SetPos(pad, y)
	settings:SetSize(inner, h - y - fieldH - pad * 2)

	local fields = {}

	local function Build()
		settings:Clear()
		fields = {}

		local which = kind:GetSelectedValue() or "plain"
		local sy = 0

		if (which == "plain") then
			local note = W.Label(settings, "Только название при входе в зону", 0, 0)

			note:SetTextColor(W.MUTED)
		elseif (which == "radiation") then
			W.Label(settings, "Урон в секунду (без противогаза и не Альянс)", 0, sy)
			sy = sy + math.Round(sh * 0.02)
			fields.damage = W.Number(settings, zone.damage or Z.limits.damage[3], Z.limits.damage[1], Z.limits.damage[2])
			fields.damage:SetPos(0, sy)
			fields.damage:SetSize(inner * 0.38, fieldH)
			sy = sy + fieldH + math.Round(sh * 0.012)

			local note = W.Label(settings, "Внутри — зелёный дым. Противогаз и Альянс защищают", 0, sy)

			note:SetTextColor(W.MUTED)
		else
			if (which == "items") then
				W.Label(settings, "Предметы (один из них, случайно)", 0, sy)
				sy = sy + math.Round(sh * 0.02)

				fields.items = {}

				for _, id in ipairs(zone.items or {}) do
					fields.items[#fields.items + 1] = id
				end

				local chosen = settings:Add("DLabel")

				chosen:SetFont("nwWidget")
				chosen:SetTextColor(U.color.text)
				chosen:SetWrap(true)
				chosen:SetPos(0, sy + fieldH + math.Round(sh * 0.008))
				chosen:SetSize(inner, math.Round(sh * 0.06))
				chosen:SetContentAlignment(7)

				local function Refresh()
					local names = {}

					for _, id in ipairs(fields.items) do
						local item = NW.items.Get(id)

						names[#names + 1] = item and item.name or id
					end

					chosen:SetText(#names > 0 and table.concat(names, ", ") or "— пока ничего —")
				end

				local pick = W.Combo(settings, W.ItemChoices(), nil)

				pick:SetValue("Добавить предмет…")
				pick:SetPos(0, sy)
				pick:SetSize(inner * 0.7, fieldH)
				pick.OnSelect = function(self, _, _, id)
					if (id and #fields.items < 32) then
						fields.items[#fields.items + 1] = id
						Refresh()
					end

					self:SetValue("Добавить предмет…")
				end

				local clear = W.Button(settings, "Очистить", function()
					fields.items = {}
					Refresh()
				end)

				clear:SetPos(inner * 0.72, sy)
				clear:SetSize(inner * 0.28, fieldH)
				Refresh()
				sy = sy + fieldH + math.Round(sh * 0.075)
			else
				W.Label(settings, "NPC (из списка или класс, например npc_zombie)", 0, sy)
				sy = sy + math.Round(sh * 0.02)

				fields.npc = W.Entry(settings, zone.npc or "", "npc_zombie")
				fields.npc:SetPos(0, sy)
				fields.npc:SetSize(inner * 0.45, fieldH)

				local pick = W.Combo(settings, NPCChoices(), nil)

				pick:SetValue("Выбрать из списка…")
				pick:SetPos(inner * 0.47, sy)
				pick:SetSize(inner * 0.53, fieldH)
				pick.OnSelect = function(self, _, _, id)
					if (id) then
						fields.npc:SetText(id)
					end
				end

				sy = sy + fieldH + math.Round(sh * 0.016)
			end

			W.Label(settings, "Сколько одновременно", 0, sy)
			W.Label(settings, "Раз в сколько секунд", inner * 0.5, sy)
			sy = sy + math.Round(sh * 0.02)

			fields.count = W.Number(settings, zone.count or Z.limits.count[3], Z.limits.count[1], Z.limits.count[2])
			fields.count:SetPos(0, sy)
			fields.count:SetSize(inner * 0.46, fieldH)

			fields.interval = W.Number(settings, zone.interval or Z.limits.interval[3], Z.limits.interval[1],
				Z.limits.interval[2])
			fields.interval:SetPos(inner * 0.5, sy)
			fields.interval:SetSize(inner * 0.5, fieldH)
		end
	end

	kind.OnSelect = function()
		Build()
	end

	Build()

	-- the buttons
	local by = h - fieldH - pad
	local save = W.Button(box, zone.id and "Сохранить" or "Создать зону", function()
		local data = {
			name = name:GetValue(),
			type = kind:GetSelectedValue() or "plain",
			min = zone.min,
			max = {zone.max[1], zone.max[2], zone.min[3] + height:GetNumber()}
		}

		if (fields.damage) then
			data.damage = fields.damage:GetNumber()
		end

		if (fields.items) then
			data.items = fields.items
		end

		if (fields.npc) then
			data.npc = string.Trim(fields.npc:GetValue())
		end

		if (fields.count) then
			data.count = fields.count:GetNumber()
			data.interval = fields.interval:GetNumber()
		end

		if (string.Trim(data.name) == "") then
			return NW.notify.Add("Введите название зоны")
		end

		Send("save", zone.id or 0, data)
		frame:Remove()
		ED.a, ED.b = nil, nil
	end, true)

	save:SetPos(w - pad - inner * 0.4, by)
	save:SetSize(inner * 0.4, fieldH)

	local cancel = W.Button(box, zone.id and "К списку" or "Отмена", function()
		frame:Remove()
		ED.a, ED.b = nil, nil

		if (zone.id) then
			OpenList()
		end
	end)

	cancel:SetPos(pad, by)
	cancel:SetSize(inner * 0.28, fieldH)
end

-- the list of zones: change, delete
OpenList = function()
	if (IsValid(ED.form)) then
		ED.form:Remove()
	end

	local sh = ScrH()
	local w, h = math.Round(sh * 0.62), math.Round(sh * 0.66)
	local frame, box = W.Window("Зоны на карте", w, h)

	ED.form = frame

	local pad = math.Round(sh * 0.022)
	local rowH = math.Round(sh * 0.052)
	local scroll = W.Scroll(box)

	scroll:SetPos(pad, box.top)
	scroll:SetSize(w - pad * 2, h - box.top - pad)

	local sorted = {}

	for _, zone in pairs(Z.list) do
		sorted[#sorted + 1] = zone
	end

	table.SortByMember(sorted, "id", true)

	if (#sorted == 0) then
		W.Label(scroll, "Зон пока нет: ЛКМ — первая точка, ЛКМ — вторая", 0, 0)
	end

	for _, zone in ipairs(sorted) do
		local row = scroll:Add("EditablePanel")

		row:Dock(TOP)
		row:DockMargin(0, 0, 8, 6)
		row:SetTall(rowH)
		row.Paint = function(_, rw, rh)
			local kind = Z.typeByID[zone.type] or Z.typeByID.plain

			draw.RoundedBox(4, 0, 0, rw, rh, Color(24, 27, 31))
			draw.SimpleText(zone.name, "nwWidgetBold", 10, rh * 0.32, U.color.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
			draw.SimpleText("#" .. zone.id .. " · " .. kind.name, "nwWidget", 10, rh * 0.7, W.MUTED, TEXT_ALIGN_LEFT,
				TEXT_ALIGN_CENTER)
		end

		local delete = W.Button(row, "Удалить", function()
			Send("delete", zone.id)
			frame:Remove()
		end)

		delete:Dock(RIGHT)
		delete:DockMargin(4, 8, 8, 8)
		delete:SetWide(math.Round(sh * 0.1))

		local edit = W.Button(row, "Изменить", function()
			frame:Remove()
			OpenForm(table.Copy(zone))
		end, true)

		edit:Dock(RIGHT)
		edit:DockMargin(4, 8, 0, 8)
		edit:SetWide(math.Round(sh * 0.1))
	end
end

-- the keys of the editor
hook.Add("PlayerBindPress", "nwZoneEditor", function(_, bind, bPressed)
	if (!ED.active or !bPressed or IsValid(ED.form) or vgui.GetKeyboardFocus()) then
		return
	end

	bind = string.lower(bind)

	if (string.find(bind, "+attack2", 1, true)) then
		if (ED.a) then
			ED.a, ED.b = nil, nil
			surface.PlaySound("network2/ui/click.wav")
		end

		return true
	elseif (string.find(bind, "+attack", 1, true)) then
		local pos = Aim()

		if (!ED.a) then
			ED.a = pos
			surface.PlaySound("network2/ui/hover.wav")
		else
			ED.b = pos

			local mins, maxs = Box(ED.a, ED.b)

			surface.PlaySound("network2/ui/char/hls_ui_affirm.wav")
			OpenForm({min = {mins.x, mins.y, mins.z}, max = {maxs.x, maxs.y, maxs.z}, type = "plain"})
		end

		return true
	elseif (string.find(bind, "+reload", 1, true)) then
		OpenList()

		return true
	end
end)

-- the zones in the world while editing: boxes and names
local FILL = {plain = Color(120, 170, 230), radiation = Color(120, 220, 90), items = Color(232, 196, 72),
	npcs = Color(230, 110, 90)}

hook.Add("PostDrawTranslucentRenderables", "nwZoneEditor", function(bDepth, bSkybox)
	if (!ED.active or bSkybox) then
		return
	end

	for _, zone in pairs(Z.list) do
		local mins, maxs = Z.Bounds(zone)
		local color = FILL[zone.type] or FILL.plain

		render.SetColorMaterial()
		render.DrawBox(vector_origin, angle_zero, mins, maxs, ColorAlpha(color, 18))
		render.DrawWireframeBox(vector_origin, angle_zero, mins, maxs, ColorAlpha(color, 230), true)
	end

	if (ED.a) then
		local mins, maxs = Box(ED.a, ED.b or Aim())

		render.SetColorMaterial()
		render.DrawBox(vector_origin, angle_zero, mins, maxs, Color(255, 255, 255, 14))
		render.DrawWireframeBox(vector_origin, angle_zero, mins, maxs, Color(255, 255, 255, 240), true)
		render.DrawWireframeSphere(ED.a, 4, 8, 8, W.ACCENT, true)
	end

	render.DrawWireframeSphere(Aim(), 3, 8, 8, Color(255, 255, 255, 200), true)
end)

hook.Add("HUDPaint", "nwZoneEditor", function()
	if (!ED.active) then
		return
	end

	-- names over the zones
	for _, zone in pairs(Z.list) do
		local mins, maxs = Z.Bounds(zone)
		local screen = ((mins + maxs) / 2):ToScreen()

		if (screen.visible) then
			local kind = Z.typeByID[zone.type] or Z.typeByID.plain

			draw.SimpleTextOutlined(zone.name, "nwZoneEditor", screen.x, screen.y, FILL[zone.type] or FILL.plain,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 200))
			draw.SimpleTextOutlined(kind.name, "nwZoneEditor", screen.x, screen.y, U.color.dim, TEXT_ALIGN_CENTER,
				TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
		end
	end

	-- what to do
	local text = ED.a and "ЛКМ — вторая точка   ·   ПКМ — сбросить" or
		"ЛКМ — первая точка   ·   R — список зон   ·   /areaedit — выйти"
	local sw, sh = ScrW(), ScrH()

	surface.SetFont("nwZoneEditor")

	local tw, th = surface.GetTextSize(text)
	local bw, bh = tw + sh * 0.04, th + sh * 0.02
	local x, y = (sw - bw) / 2, sh * 0.06

	draw.RoundedBox(6, x, y, bw, bh, Color(14, 16, 19, 220))
	surface.SetDrawColor(W.ACCENT)
	surface.DrawRect(x, y + bh - 2, bw, 2)
	draw.SimpleText("РЕДАКТОР ЗОН", "nwWidgetLabel", sw / 2, y - sh * 0.004, W.ACCENT, TEXT_ALIGN_CENTER,
		TEXT_ALIGN_BOTTOM)
	draw.SimpleText(text, "nwZoneEditor", sw / 2, y + bh / 2, U.color.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
