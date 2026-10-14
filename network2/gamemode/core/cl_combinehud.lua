-- The HUD of the Alliance (Civil Protection and the Combine; sh_zones.lua NW.zones.IsAlliance):
--   the visor      the mask overlay over the picture (materials/network2/overlay/: cmb_overlay for
--                  Civil Protection, soldier_overlay for the Combine, elite_overlay for the commander)
--   top left       "ИНФОРМАЦИЯ :", a bar under it and the system lines typed out in the Combine font
--                  (nw_hud_combine_font, "Combine_Alphabet"): three at a time, then they go and the
--                  next three come, round and round. A fallen member of the Alliance comes up there in
--                  red: "UNIT DOWN AT LOCATION :: <zone>" (the Overwatch voice says it too)
--   top right      Юнит (Civil Protection) / Солдат (the Combine) :: the name, Зона :: the zone,
--                  Социо-статус :: by the health (Зелёный, Жёлтый, Оранжевый, Красный)
--   top centre     the Combine: a compass with the sides of the world in Russian and the degrees
--   teammates      the other members of the Alliance close by are outlined, their name over them
-- Everything sits on a curved visor: the lines bend and tilt towards the edges of the screen and the
-- whole HUD sways with the turns of the head and the steps (it lags behind and springs back).
-- Civil Protection is drawn in blue, the Combine in red. nw_hud_alliance 0 - off.

local Z = NW.zones

local enabled = CreateClientConVar("nw_hud_alliance", "1", true, false, "HUD Альянса")
local combineFont = CreateClientConVar("nw_hud_combine_font", "Combine_Alphabet", true, false,
	"Шрифт строк HUD Альянса (имя шрифта Combine)")

local BLUE = Color(86, 200, 255)
local RED = Color(236, 84, 72)
local WHITE = Color(226, 240, 248)

local OVERLAY = {
	cp = Material("network2/overlay/cmb_overlay"),
	soldier = Material("network2/overlay/soldier_overlay"),
	elite = Material("network2/overlay/elite_overlay")
}

local LINES = {
	"Preparing unit adjactives...",
	"Connecting to overwatch..",
	"Starting boots...",
	"Checks the radial...",
	"Checking visual status...",
	"Connect...",
	"Connect..",
	"Restabilizing"
}

local function Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
		surface.CreateFont(name .. "Glow", {font = font, size = math.max(11, math.Round(h * size)), weight = weight,
			extended = true, antialias = true, blursize = 4})
	end

	F("nwCmbHead", "Jura", 0.024, 700)
	F("nwCmbText", "Jura", 0.019, 700)
	F("nwCmbSmall", "Jura", 0.015, 700)
	F("nwCmbCombine", combineFont:GetString(), 0.018, 500)
end

Fonts()
hook.Add("OnScreenSizeChanged", "nwCombineHud", Fonts)
cvars.AddChangeCallback("nw_hud_combine_font", Fonts, "nwCombineHud")

-- ------------------------------------------------------------------ who --
local function Kind(client)
	if (!IsValid(client) or !Z or !Z.IsAlliance(client)) then
		return
	end

	local model = string.lower(client:GetModel() or "")
	local class = NW.anim.GetModelClass(model)

	if (client:GetFaction() == "combine" or class == "overwatch" or class == "combine_heavy") then
		return string.find(model, "commander", 1, true) and "elite" or "soldier"
	end

	return "cp"
end

local function Active()
	local client = LocalPlayer()

	return enabled:GetBool() and IsValid(client) and client:Alive() and client:GetCharacterID() != 0 and
		!client:GetNW2Bool("nwInMenu", false) and !client:GetNW2Bool("nwKnocked", false) and Kind(client) != nil
end

-- --------------------------------------------------------------- the visor --
hook.Add("RenderScreenspaceEffects", "nwCombineOverlay", function()
	if (!Active()) then
		return
	end

	local material = OVERLAY[Kind(LocalPlayer())]

	if (!material or material:IsError()) then
		return
	end

	render.UpdateScreenEffectTexture()
	render.UpdateRefractTexture()
	material:SetFloat("$alpha", 0.5)
	render.SetMaterial(material)
	render.DrawScreenQuad()
end)

-- ---------------------------------------------------------------- the sway --
local sway = {x = 0, y = 0, vx = 0, vy = 0, yaw = nil, pitch = nil, bob = 0}

hook.Add("Think", "nwCombineHudSway", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local frame = math.min(FrameTime(), 0.05)
	local angles = client:EyeAngles()

	if (sway.yaw) then
		-- the HUD lags behind the turn of the head ...
		local dyaw = math.AngleDifference(angles.y, sway.yaw)
		local dpitch = math.AngleDifference(angles.p, sway.pitch)

		sway.vx = sway.vx + dyaw * 2.2
		sway.vy = sway.vy - dpitch * 2.2
	end

	sway.yaw, sway.pitch = angles.y, angles.p

	-- ... and walks with the steps
	local speed = client:OnGround() and client:GetVelocity():Length2D() or 0

	sway.bob = sway.bob + frame * (speed / 26)

	local target = math.sin(sway.bob) * math.min(speed / 200, 1) * ScrH() * 0.004

	-- a damped spring back to the middle (small steps: steady at any frame rate)
	local steps = math.ceil(frame / 0.005)
	local dt = frame / steps

	for _ = 1, steps do
		sway.vx = sway.vx + (-sway.x * 90 - sway.vx * 13) * dt
		sway.vy = sway.vy + ((target - sway.y) * 90 - sway.vy * 13) * dt
		sway.x = math.Clamp(sway.x + sway.vx * dt, -ScrW() * 0.03, ScrW() * 0.03)
		sway.y = math.Clamp(sway.y + sway.vy * dt, -ScrH() * 0.03, ScrH() * 0.03)
	end
end)

-- ------------------------------------------------------------- the curve --
-- where a point of the flat HUD lies on the curved visor: the sides bend down and turn, and shrink
-- a little (they are farther away)
local BEND = 0.045

local function Curve(x, y)
	local sw, sh = ScrW(), ScrH()
	local cx = sw / 2
	local nx = (x - cx) / cx
	local top = 1 - math.Clamp(y / (sh * 0.5), 0, 1)
	local dy = BEND * sh * nx * nx * top
	local slope = 2 * BEND * sh * nx * top / cx

	return x + sway.x, y + dy + sway.y, math.deg(math.atan(slope)), 1 - 0.07 * nx * nx
end

-- text on the visor: placed at (x, y) of the flat HUD, bent and tilted by the curve
local function Text(text, font, x, y, color, align, glow)
	local px, py, angle, scale = Curve(x, y)
	local matrix = Matrix()

	matrix:Translate(Vector(px, py, 0))
	matrix:Rotate(Angle(0, angle, 0))
	matrix:Scale(Vector(scale, scale, 1))

	cam.PushModelMatrix(matrix, true)
		if (glow != false) then
			draw.SimpleText(text, font .. "Glow", 0, 0, ColorAlpha(color, (color.a or 255) * 0.55), align,
				TEXT_ALIGN_TOP)
		end

		draw.SimpleText(text, font, 1, 1, Color(0, 0, 0, (color.a or 255) * 0.6), align, TEXT_ALIGN_TOP)
		draw.SimpleText(text, font, 0, 0, color, align, TEXT_ALIGN_TOP)
	cam.PopModelMatrix()
end

-- a straight bar on the visor (drawn tilted where it sits)
local function Bar(x, y, w, h, color)
	local px, py, angle, scale = Curve(x + w / 2, y)
	local matrix = Matrix()

	matrix:Translate(Vector(px, py, 0))
	matrix:Rotate(Angle(0, angle, 0))
	matrix:Scale(Vector(scale, scale, 1))

	cam.PushModelMatrix(matrix, true)
		surface.SetDrawColor(color)
		surface.DrawRect(-w / 2, 0, w, h)
	cam.PopModelMatrix()
end

-- ------------------------------------------------------------ the lines --
local typer = {group = 0, start = 0}
local events = {}

local CHAR_TIME = 0.045
local HOLD = 2.6
local FADE = 0.45

local function Group(index)
	local out = {}

	for i = 0, 2 do
		out[#out + 1] = LINES[(index * 3 + i) % #LINES + 1]
	end

	return out
end

local function TypedLines()
	local t = RealTime() - typer.start
	local lines = Group(typer.group)
	local total = 0

	for _, line in ipairs(lines) do
		total = total + #line * CHAR_TIME + 0.25
	end

	if (t > total + HOLD + FADE) then
		typer.group = typer.group + 1
		typer.start = RealTime()

		return {}, 1
	end

	local out, used = {}, t

	for _, line in ipairs(lines) do
		local count = math.Clamp(math.floor(used / CHAR_TIME), 0, #line)

		out[#out + 1] = string.sub(line, 1, count) .. ((count < #line and count > 0 and math.floor(RealTime() * 6) % 2 == 0)
			and "_" or "")
		used = used - #line * CHAR_TIME - 0.25

		if (used < 0) then
			break
		end
	end

	return out, 1 - math.Clamp((t - total - HOLD) / FADE, 0, 1)
end

-- a fallen member of the Alliance (sv_combinehud.lua)
net.Receive("nwUnitDown", function()
	local name = net.ReadString()
	local zone = net.ReadString()

	table.insert(events, 1, {text = "UNIT DOWN AT LOCATION :: " .. NW.terminal.Upper(zone), name = name,
		born = RealTime()})

	while (#events > 3) do
		table.remove(events)
	end

	if (Active()) then
		surface.PlaySound("npc/overwatch/radiovoice/lostbiosignalforunit.wav")
	end
end)

-- -------------------------------------------------------------- statuses --
local STATUSES = {
	{0.75, "ЗЕЛЁНЫЙ", Color(110, 232, 132)},
	{0.5, "ЖЁЛТЫЙ", Color(240, 214, 90)},
	{0.25, "ОРАНЖЕВЫЙ", Color(244, 150, 64)},
	{0, "КРАСНЫЙ", Color(240, 76, 66)}
}

local function SocioStatus(client)
	local ratio = client:Health() / math.max(client:GetMaxHealth(), 1)

	for _, status in ipairs(STATUSES) do
		if (ratio >= status[1]) then
			return status[2], status[3]
		end
	end

	return STATUSES[#STATUSES][2], STATUSES[#STATUSES][3]
end

-- ------------------------------------------------------------ the compass --
local SIDES = {[0] = "С", [45] = "СВ", [90] = "В", [135] = "ЮВ", [180] = "Ю", [225] = "ЮЗ", [270] = "З", [315] = "СЗ"}

local function Compass(color)
	local client = LocalPlayer()
	local sw, sh = ScrW(), ScrH()
	-- the map's north is +Y (yaw 90): heading 0 there, clockwise
	local heading = (90 - client:EyeAngles().y) % 360
	local width = sw * 0.36
	local cx = sw / 2
	local y = sh * 0.022
	local span = 90
	local step = width / span

	for degree = math.floor(heading - span / 2), math.ceil(heading + span / 2) do
		local wrapped = degree % 360

		if (wrapped % 5 == 0) then
			local x = cx + (degree - heading) * step
			local edge = 1 - math.abs(degree - heading) / (span / 2)
			local alpha = 255 * math.Clamp(edge * 1.6, 0, 1)
			local side = SIDES[wrapped]

			if (side) then
				Bar(x - 1, y, 2, sh * 0.012, ColorAlpha(color, alpha))
				Text(side, "nwCmbText", x, y + sh * 0.014, ColorAlpha(wrapped % 90 == 0 and WHITE or color, alpha), TEXT_ALIGN_CENTER)
			elseif (wrapped % 15 == 0) then
				Bar(x - 1, y, 2, sh * 0.008, ColorAlpha(color, alpha * 0.9))
				Text(tostring(wrapped), "nwCmbSmall", x, y + sh * 0.014, ColorAlpha(color, alpha * 0.8), TEXT_ALIGN_CENTER,
					false)
			else
				Bar(x, y, 1, sh * 0.005, ColorAlpha(color, alpha * 0.6))
			end
		end
	end

	-- the marker and the degrees
	Bar(cx - 1, y - sh * 0.008, 3, sh * 0.006, WHITE)
	Text(string.format("%03d", math.Round(heading) % 360), "nwCmbSmall", cx, y + sh * 0.036, WHITE, TEXT_ALIGN_CENTER)

	NW.notify.offset = sh * 0.06
end

-- --------------------------------------------------------------- the HUD --
hook.Add("HUDPaint", "nwCombineHud", function()
	if (NW.notify) then
		NW.notify.offset = nil
	end

	if (!Active()) then
		return
	end

	local client = LocalPlayer()
	local kind = Kind(client)
	local color = kind == "cp" and BLUE or RED
	local sw, sh = ScrW(), ScrH()

	render.PushFilterMag(TEXFILTER.ANISOTROPIC)
	render.PushFilterMin(TEXFILTER.ANISOTROPIC)

	-- top left: the information
	local x, y = sw * 0.03, sh * 0.045

	Text("ИНФОРМАЦИЯ :", "nwCmbHead", x, y, color, TEXT_ALIGN_LEFT)
	y = y + sh * 0.034

	local pulse = 0.6 + 0.4 * math.abs(math.sin(RealTime() * 1.4))

	Bar(x, y, sw * 0.2, 2, ColorAlpha(color, 230))
	Bar(x, y + 4, sw * 0.2 * pulse, 1, ColorAlpha(color, 120))
	y = y + sh * 0.014

	-- the red news first: the fallen
	for index = #events, 1, -1 do
		if (RealTime() - events[index].born > 14) then
			table.remove(events, index)
		end
	end

	for _, event in ipairs(events) do
		local age = RealTime() - event.born
		local alpha = 255 * math.Clamp(age / 0.2, 0, 1) * math.Clamp((14 - age) / 1, 0, 1)
		local length = utf8.len(event.text) or #event.text
		local shown = math.Clamp(math.floor(age / 0.03), 0, length)
		local cut = shown < length and string.sub(event.text, 1, (utf8.offset(event.text, shown + 1) or 1) - 1) or event.text
		local blink = age < 3 and math.floor(age * 4) % 2 == 0

		Text(cut, "nwCmbText", x, y, ColorAlpha(blink and WHITE or RED, alpha),
			TEXT_ALIGN_LEFT)
		Text(event.name, "nwCmbSmall", x, y + sh * 0.022, ColorAlpha(RED, alpha * 0.85), TEXT_ALIGN_LEFT, false)
		y = y + sh * 0.046
	end

	-- the system lines in the Combine font, three at a time
	local lines, fade = TypedLines()

	for _, line in ipairs(lines) do
		Text(line, "nwCmbCombine", x, y, ColorAlpha(color, 235 * fade), TEXT_ALIGN_LEFT)
		y = y + sh * 0.026
	end

	-- top right: who, where, how
	local rx, ry = sw * 0.97, sh * 0.045
	local zone = Z.At(Z.Point(client))
	local status, statusColor = SocioStatus(client)

	Text((kind == "cp" and "ЮНИТ" or "СОЛДАТ") .. " :: " .. NW.terminal.Upper(client:Nick()), "nwCmbText", rx, ry, color,
		TEXT_ALIGN_RIGHT)
	Text("ЗОНА :: " .. NW.terminal.Upper(zone and zone.name or "вне зон"), "nwCmbText", rx, ry + sh * 0.028, color,
		TEXT_ALIGN_RIGHT)

	surface.SetFont("nwCmbText")

	local sw2 = surface.GetTextSize(status)

	Text(status, "nwCmbText", rx, ry + sh * 0.056, statusColor, TEXT_ALIGN_RIGHT)
	Text("СОЦИО-СТАТУС :: ", "nwCmbText", rx - sw2, ry + sh * 0.056, color, TEXT_ALIGN_RIGHT)
	Bar(rx - sw * 0.16, ry + sh * 0.088, sw * 0.16, 2, ColorAlpha(color, 200))

	-- the Combine: the compass
	if (kind != "cp") then
		Compass(color)
	end

	render.PopFilterMin()
	render.PopFilterMag()
end)

-- ---------------------------------------------------------------- teammates --
local function Teammates()
	local me = LocalPlayer()
	local out = {}

	for _, other in ipairs(player.GetAll()) do
		if (other != me and other:Alive() and !other:GetNoDraw() and Kind(other) and
			other:GetPos():DistToSqr(me:GetPos()) < 1400 * 1400) then
			out[#out + 1] = other
		end
	end

	return out
end

hook.Add("PreDrawHalos", "nwCombineHud", function()
	if (!Active()) then
		return
	end

	local list = Teammates()

	if (#list > 0) then
		halo.Add(list, Kind(LocalPlayer()) == "cp" and BLUE or RED, 1, 1, 1, true, true)
	end
end)

hook.Add("HUDPaint", "nwCombineHudMates", function()
	if (!Active()) then
		return
	end

	local color = Kind(LocalPlayer()) == "cp" and BLUE or RED

	for _, other in ipairs(Teammates()) do
		local screen = (other:EyePos() + Vector(0, 0, 10)):ToScreen()

		if (screen.visible) then
			draw.SimpleTextOutlined("+ " .. NW.terminal.Upper(other:Nick()), "nwCmbSmall", screen.x, screen.y, color,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 180))
		end
	end
end)
