-- Shared look of the menus: fonts (Jura for titles, Exo 2 for text - resource/fonts), the
-- sounds of the interface, rounded panels drawn from small 9-slice materials with a blurred
-- picture behind them, icons, and a smooth camera spline for the menu flights.

NW.ui = NW.ui or {}

local U = NW.ui

U.color = {
	text = Color(234, 238, 242),
	dim = Color(160, 170, 180),
	hint = Color(244, 206, 92),
	error = Color(236, 98, 86),
	line = Color(205, 210, 215, 150),
	accent = Color(64, 190, 240)
}

-- ------------------------------------------------------------------ fonts --
function U.Fonts()
	local h = ScrH()
	local function F(name, font, size, weight)
		surface.CreateFont(name, {font = font, size = math.max(12, math.Round(h * size)), weight = weight,
			extended = true, antialias = true})
	end

	F("nwTitle", "Jura", 0.046, 700)
	F("nwHeader", "Exo 2", 0.026, 700)
	F("nwText", "Exo 2", 0.021, 400)
	F("nwTextBig", "Exo 2", 0.032, 600)
	F("nwSmall", "Exo 2", 0.017, 400)
	F("nwButton", "Exo 2", 0.022, 600)
end

U.Fonts()
hook.Add("OnScreenSizeChanged", "nwUIFonts", U.Fonts)

-- upper case for Latin and Cyrillic (string.upper only knows ASCII)
function U.Upper(text)
	local out = {}

	for _, code in utf8.codes(text or "") do
		if (code >= 0x430 and code <= 0x44F) then
			code = code - 0x20
		elseif (code == 0x451) then
			code = 0x401
		elseif (code >= 97 and code <= 122) then
			code = code - 32
		end

		out[#out + 1] = utf8.char(code)
	end

	return table.concat(out)
end

-- ----------------------------------------------------------------- sounds --
U.sound = {
	appear = "network2/ui/char/hls_ui_appear.wav",
	affirm = "network2/ui/char/hls_ui_affirm.wav"
}

function U.Play(name)
	surface.PlaySound(U.sound[name] or name)
end

-- key presses, button clicks
function U.Tick()
	surface.PlaySound("network2/ui/char/textline_" .. math.random(1, 5) .. ".wav")
end

-- -------------------------------------------------------------- drawing --
local materials = {}

function U.Material(path)
	materials[path] = materials[path] or Material(path, "smooth mips")

	return materials[path]
end

function U.Icon(name)
	return U.Material("network2/ui/icons/" .. name .. ".png")
end

-- 9-slice plates are sampled without mipmaps (no blurred seams at the slice borders)
local plates = {}

local function Plate(material)
	local name = material:GetName()

	if (!plates[name]) then
		plates[name] = Material(name .. ".png", "smooth")

		if (plates[name]:IsError()) then
			plates[name] = material
		end
	end

	return plates[name]
end

-- 9-slice: corners keep their size, edges and centre stretch; UVs half a texel inside so the
-- slices meet without a seam
function U.Slice(material, x, y, w, h, corner, r, g, b, a)
	material = Plate(material)

	x, y, w, h = math.Round(x), math.Round(y), math.Round(w), math.Round(h)

	local tw = material:Width()
	local c = math.Round(math.min(corner, w / 2, h / 2))
	local uc = math.min(corner, tw / 2) / tw
	local half = 0.5 / tw

	surface.SetMaterial(material)
	surface.SetDrawColor(r or 255, g or 255, b or 255, a or 255)

	local xs = {x, x + c, x + w - c}
	local ws = {c, w - 2 * c, c}
	local ys = {y, y + c, y + h - c}
	local hs = {c, h - 2 * c, c}
	local us = {half, uc, 1 - uc, 1 - half}

	for i = 1, 3 do
		for j = 1, 3 do
			if (ws[i] > 0 and hs[j] > 0) then
				surface.DrawTexturedRectUV(xs[i], ys[j], ws[i], hs[j], us[i], us[j], us[i + 1], us[j + 1])
			end
		end
	end
end

local blur = Material("pp/blurscreen")

-- rounded rectangle as a polygon (for the stencil mask), cached by size
local polys = {}

local function RoundedPoly(x, y, w, h, r)
	local key = string.format("%d:%d:%d:%d:%d", x, y, w, h, r)
	local poly = polys[key]

	if (poly) then
		return poly
	end

	poly = {}

	local corners = {{x + w - r, y + r, -90}, {x + w - r, y + h - r, 0}, {x + r, y + h - r, 90}, {x + r, y + r, 180}}

	for _, corner in ipairs(corners) do
		for step = 0, 6 do
			local angle = math.rad(corner[3] + step * 15)

			poly[#poly + 1] = {x = corner[1] + math.cos(angle) * r, y = corner[2] + math.sin(angle) * r}
		end
	end

	if (table.Count(polys) > 64) then
		polys = {}
	end

	polys[key] = poly

	return poly
end

U.RoundedPoly = RoundedPoly

-- the scene behind a rounded rectangle, blurred. x, y are in the coordinates of the panel being
-- painted (pass it as `panel`). A stencil mask in the panel's exact rounded shape keeps the blur
-- inside the corners.
function U.Blur(x, y, w, h, amount, alpha, panel, radius)
	local sx, sy = x, y

	if (IsValid(panel)) then
		sx, sy = panel:LocalToScreen(x, y)
	end

	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(255)
	render.SetStencilTestMask(255)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)

	-- the mask: the panel's shape, inset a little, drawn into the stencil only
	render.OverrideColorWriteEnable(true, false)
		draw.NoTexture()
		surface.SetDrawColor(255, 255, 255, 255)
		-- the same corner the plate gets (U.Slice caps it at half the size), 3 px inside its rim
		local r = math.min(radius or 24, w / 2, h / 2)
		local inset = 3

		surface.DrawPoly(RoundedPoly(math.Round(x + inset), math.Round(y + inset), math.Round(w - inset * 2),
			math.Round(h - inset * 2), math.max(math.Round(r - inset), 1)))
	render.OverrideColorWriteEnable(false, false)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilPassOperation(STENCIL_KEEP)

		surface.SetMaterial(blur)
		surface.SetDrawColor(255, 255, 255, alpha or 255)

		for i = 1, 3 do
			blur:SetFloat("$blur", (i / 3) * (amount or 5))
			blur:Recompute()
			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(x - sx, y - sy, ScrW(), ScrH())
		end

	render.SetStencilEnable(false)
end

-- a glass panel: blurred scene + translucent rounded plate (panel = the panel being painted)
function U.Panel(x, y, w, h, alpha, panel)
	alpha = alpha or 1

	if (alpha > 0.05) then
		U.Blur(x, y, w, h, 6, 255 * alpha, panel)
	end

	U.Slice(U.Material("network2/ui/panel.png"), x, y, w, h, 24, 255, 255, 255, 255 * alpha)
end

-- glass with another plate material (the chat's darker one, ...)
function U.Glass(x, y, w, h, alpha, panel, material, corner)
	alpha = alpha or 1

	if (alpha > 0.05) then
		U.Blur(x, y, w, h, 5, 255 * alpha, panel, corner)
	end

	U.Slice(U.Material(material), x, y, w, h, corner or 20, 255, 255, 255, 255 * alpha)
end

function U.Button(x, y, w, h, alpha, bOutline, hover)
	alpha = alpha or 1
	U.Slice(U.Material("network2/ui/button.png"), x, y, w, h, 16, 255, 255, 255, 255 * alpha)

	if (hover and hover > 0) then
		U.Slice(U.Material("network2/ui/button.png"), x, y, w, h, 16, 255, 255, 255, 120 * hover * alpha)
	end

	if (bOutline) then
		U.Slice(U.Material("network2/ui/outline.png"), x, y, w, h, 16, 255, 255, 255, 255 * alpha)
	end
end

function U.DrawIcon(name, x, y, size, color, alpha)
	color = color or color_white
	surface.SetMaterial(U.Icon(name))
	surface.SetDrawColor(color.r, color.g, color.b, 255 * (alpha or 1))
	surface.DrawTexturedRect(x, y, size, size)
end

-- ------------------------------------------------------------- camera spline --
-- A smooth, never stopping flight through points: Catmull-Rom on positions and on the view
-- direction, time spread by distance so the speed stays even through every key point.
local function CR(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t

	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

function U.CameraPath(points, speed)
	local path = {points = points, lengths = {}, total = 0}

	for index = 1, #points do
		local length = math.max(points[index].pos:Distance(points[index % #points + 1].pos), 1)

		path.lengths[index] = length
		path.total = path.total + length
	end

	path.duration = math.max(path.total / math.max(speed, 5), #points * 3)

	return path
end

function U.CameraAt(path, time)
	local points = path.points
	local count = #points

	if (count == 1) then
		local point = points[1]
		local drift = Vector(math.sin(time * 0.2) * 6, math.cos(time * 0.15) * 6, math.sin(time * 0.3) * 2)

		return point.pos + drift, point.ang + Angle(math.sin(time * 0.25) * 1.2, math.sin(time * 0.17) * 2, 0)
	end

	local distance = (time % path.duration) / path.duration * path.total
	local index = 1

	while (distance > path.lengths[index] and index < count) do
		distance = distance - path.lengths[index]
		index = index + 1
	end

	local f = math.Clamp(distance / path.lengths[index], 0, 1)
	local function P(k)
		return points[(k - 1) % count + 1]
	end

	local pos = CR(P(index - 1).pos, P(index).pos, P(index + 1).pos, P(index + 2).pos, f)
	local dir = CR(P(index - 1).ang:Forward(), P(index).ang:Forward(), P(index + 1).ang:Forward(),
		P(index + 2).ang:Forward(), f)

	return pos, dir:Angle()
end

-- ------------------------------------------------------------------- fade --
U.fade = U.fade or {alpha = 0, target = 0, speed = 1}

hook.Add("DrawOverlay", "nwUIFade", function()
	local fade = U.fade

	fade.alpha = math.Approach(fade.alpha, fade.target, FrameTime() * fade.speed * 255)

	if (fade.alpha > 0) then
		surface.SetDrawColor(0, 0, 0, fade.alpha)
		surface.DrawRect(0, 0, ScrW(), ScrH())
	end
end)

function U.FadeTo(target, seconds)
	U.fade.target = target
	U.fade.speed = 1 / math.max(seconds or 0.5, 0.05)
end

-- fade out, run, fade in
function U.Transition(callback, outTime, inTime, hold)
	U.FadeTo(255, outTime or 0.45)

	timer.Simple((outTime or 0.45) + 0.02, function()
		callback()

		timer.Simple(hold or 0.1, function()
			U.FadeTo(0, inTime or 0.6)
		end)
	end)
end
