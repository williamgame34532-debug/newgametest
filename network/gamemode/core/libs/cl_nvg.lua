NETWORK.nvg.colors = {
	cp = Color(96, 170, 255),
	cmb = Color(255, 84, 70),
	worker = Color(255, 200, 90),
	disinfector = Color(255, 200, 90)
}

NETWORK.nvg.lightSize = 720
NETWORK.nvg.lightBrightness = 3.4
NETWORK.nvg.bodyLightSize = 420
NETWORK.nvg.bodyLightBrightness = 2.2

function NETWORK.nvg.GetColor(client)
	local faction = IsValid(client) and client:GetCharacterFaction() or nil

	return NETWORK.nvg.colors[faction or ""] or NETWORK.nvg.colors.cp
end

local function LightOrigin(client)
	if (client == LocalPlayer() and NETWORK.thirdperson and !NETWORK.thirdperson.IsEnabled()) then
		return EyePos() + EyeAngles():Forward() * 24
	end

	return client:GetShootPos() + client:GetAimVector() * 24
end

local nvgGrain = CreateClientConVar("network_nvg_grain", "0", true, false,
	"Зерно трубки ПНВ (по умолчанию выключено)")

local nvgBloom = CreateClientConVar("network_nvg_bloom", "0", true, false,
	"Свечение источников света в ПНВ")
local nvgFullbright = CreateClientConVar("network_nvg_fullbright", "0", true, false,
	"Полный засвет сцены в ПНВ (видно в темноте)")

local screenFrac = 0
local bLit = false

local noiseMaterial = Material("effects/tvscreen_noise002a")
local binocMaterial = Material("effects/combine_binocoverlay")

if (noiseMaterial:IsError()) then
	noiseMaterial = Material("effects/tvscreen_noise001a")
end

local function IsOn()
	local client = LocalPlayer()

	return IsValid(client) and NETWORK.nvg.IsActive(client) and client:Alive()
end

hook.Add("PreDrawOpaqueRenderables", "nwNVGLighting", function(bDepth, bSkybox)
	if (bDepth or bSkybox or !nvgFullbright:GetBool() or !IsOn() or screenFrac < 0.6) then
		return
	end

	render.SetLightingMode(1)
	bLit = true
end)

hook.Add("PostDrawTranslucentRenderables", "nwNVGLighting", function(bDepth, bSkybox)
	if (bLit) then
		render.SetLightingMode(0)
		bLit = false
	end
end)

hook.Add("PreDrawHUD", "nwNVGLightingReset", function()
	if (bLit) then
		render.SetLightingMode(0)
		bLit = false
	end
end)

NETWORK.nvg.clientBuild = "tube-2026-09-21"

hook.Add("RenderScreenspaceEffects", "nwNVGScreen", function()
	local bActive = IsOn()

	if (bActive and !NETWORK.nvg.bAnnounced) then
		NETWORK.nvg.bAnnounced = true

		print("[Network] ПНВ: клиентская сборка " .. NETWORK.nvg.clientBuild .. " (круглый окуляр, без зерна)")
	elseif (!bActive) then
		NETWORK.nvg.bAnnounced = nil
	end

	screenFrac = NETWORK.util.Approach(screenFrac, bActive and 1 or 0, 5)

	if (screenFrac < 0.01) then
		return
	end

	local client = LocalPlayer()
	local color = NETWORK.nvg.GetColor(client)
	local frac = screenFrac

	if (nvgBloom:GetBool()) then
		DrawBloom(0.62, 1.4 * frac, 5, 5, 1, 1, 1, 1, 1)
	end

	local flicker = 1 + math.sin(RealTime() * 31) * 0.01
	local gain = (nvgFullbright:GetBool() and 1.05 or 0.92) * flicker

	DrawColorModify({
		["$pp_colour_addr"] = color.r / 255 * 0.02 * frac,
		["$pp_colour_addg"] = color.g / 255 * 0.02 * frac,
		["$pp_colour_addb"] = color.b / 255 * 0.02 * frac,
		["$pp_colour_brightness"] = (nvgFullbright:GetBool() and 0.02 or -0.01) * frac,
		["$pp_colour_contrast"] = 1 + 0.15 * frac,
		["$pp_colour_colour"] = 1 - frac,
		["$pp_colour_mulr"] = Lerp(frac, 1, color.r / 255 * gain),
		["$pp_colour_mulg"] = Lerp(frac, 1, color.g / 255 * gain),
		["$pp_colour_mulb"] = Lerp(frac, 1, color.b / 255 * gain)
	})
end)

local tubeSize = CreateClientConVar("network_nvg_tube_size", "1.0", true, false,
	"ПНВ: размер круга окуляра (0.6..1.3, 1 — почти во всю высоту)")
local tubeSoft = CreateClientConVar("network_nvg_tube_soft", "0.14", true, false,
	"ПНВ: мягкость края круга (0.02..0.5 от радиуса)")

local function DrawTube(width, height, tint, frac)
	local centerX, centerY = width * 0.5, height * 0.5
	local size = math.Clamp(tubeSize:GetFloat(), 0.6, 1.3)
	local radius = math.min(width, height) * 0.5 * 1.04 * size
	local soft = radius * math.Clamp(tubeSoft:GetFloat(), 0.02, 0.5)
	local far = math.sqrt(width * width + height * height) * 0.5 + 4
	local segments = 72
	local bands = 8
	local r, g, b = math.Round(tint.r * 0.1), math.Round(tint.g * 0.1), math.Round(tint.b * 0.1)

	draw.NoTexture()

	local softRatio = math.Clamp(tubeSoft:GetFloat(), 0.02, 0.5)
	local preset = 14

	for _, candidate in ipairs({5, 14, 25, 45}) do
		if (math.abs(candidate / 100 - softRatio) < math.abs(preset / 100 - softRatio)) then
			preset = candidate
		end
	end

	local tube = NETWORK.util.GetTexture(string.format("framework/fx/tube%02d.png", preset),
		"smooth")

	if (tube) then
		local side = math.ceil(radius * (1 + preset / 100) * 2)
		local left = math.Round(centerX - side * 0.5)
		local top = math.Round(centerY - side * 0.5)
		local right, bottom = left + side, top + side

		surface.SetMaterial(tube)
		surface.SetDrawColor(r, g, b, 255 * frac)
		surface.DrawTexturedRect(left, top, side, side)
		draw.NoTexture()

		if (top > 0) then
			surface.DrawRect(0, 0, width, top)
		end

		if (bottom < height) then
			surface.DrawRect(0, bottom, width, height - bottom)
		end

		if (left > 0) then
			surface.DrawRect(0, top, left, side)
		end

		if (right < width) then
			surface.DrawRect(right, top, width - right, side)
		end

		local rim = NETWORK.util.GetTexture("framework/fx/ring.png", "smooth")

		if (rim) then
			local size = math.Round(radius * 2 / 0.98)

			surface.SetMaterial(rim)
			surface.SetDrawColor(tint.r, tint.g, tint.b, 26 * frac)
			surface.DrawTexturedRect(math.Round(centerX - size * 0.5),
				math.Round(centerY - size * 0.5), size, size)
			draw.NoTexture()

			return
		end

		bands = 0
		far = 0
	end

	local function Ring(innerR, outerR, alpha)
		if (alpha <= 0 or outerR <= innerR) then
			return
		end

		surface.SetDrawColor(r, g, b, alpha)

		for i = 0, segments - 1 do
			local a0 = (i / segments) * math.pi * 2
			local a1 = ((i + 1) / segments) * math.pi * 2
			local c0, s0 = math.cos(a0), math.sin(a0)
			local c1, s1 = math.cos(a1), math.sin(a1)

			surface.DrawPoly({
				{x = centerX + c0 * innerR, y = centerY + s0 * innerR},
				{x = centerX + c1 * innerR, y = centerY + s1 * innerR},
				{x = centerX + c1 * outerR, y = centerY + s1 * outerR},
				{x = centerX + c0 * outerR, y = centerY + s0 * outerR}
			})
		end
	end

	for band = 0, bands - 1 do
		local t0 = band / bands
		local t1 = (band + 1) / bands
		local alpha = 255 * frac * (t0 * t0 * 0.35 + t0 * 0.65)

		Ring(radius + soft * t0, radius + soft * t1 + 1, alpha)
	end

	if (radius + soft < far) then
		Ring(radius + soft, far, 255 * frac)
	end

	surface.SetDrawColor(tint.r, tint.g, tint.b, 26 * frac)

	for i = 0, segments - 1 do
		local a0 = (i / segments) * math.pi * 2
		local a1 = ((i + 1) / segments) * math.pi * 2

		surface.DrawPoly({
			{x = centerX + math.cos(a0) * (radius - 2), y = centerY + math.sin(a0) * (radius - 2)},
			{x = centerX + math.cos(a1) * (radius - 2), y = centerY + math.sin(a1) * (radius - 2)},
			{x = centerX + math.cos(a1) * (radius + 2), y = centerY + math.sin(a1) * (radius + 2)},
			{x = centerX + math.cos(a0) * (radius + 2), y = centerY + math.sin(a0) * (radius + 2)}
		})
	end
end

hook.Add("HUDPaintBackground", "nwNVGVignette", function()
	if (screenFrac < 0.01) then
		return
	end

	local client = LocalPlayer()
	local color = NETWORK.nvg.GetColor(client)
	local width, height = ScrW(), ScrH()
	local frac = screenFrac

	DrawTube(width, height, color, frac)
end)

hook.Add("Think", "nwNVGLight", function()
	for _, client in ipairs({LocalPlayer()}) do
		if (!IsValid(client) or !client:Alive() or !NETWORK.nvg.IsActive(client)) then
			continue
		end

		local light = DynamicLight(client:EntIndex())

		if (!light) then
			continue
		end

		local color = NETWORK.nvg.GetColor(client)
		local r = math.Round(Lerp(0.85, 255, color.r))
		local g = math.Round(Lerp(0.85, 255, color.g))
		local b = math.Round(Lerp(0.85, 255, color.b))

		light.pos = LightOrigin(client)
		light.r = r
		light.g = g
		light.b = b
		light.brightness = NETWORK.nvg.lightBrightness
		light.decay = 900
		light.size = NETWORK.nvg.lightSize
		light.dietime = CurTime() + 0.1
		light.noworld = false
		light.nomodel = false

		local body = DynamicLight(client:EntIndex() + 4096)

		if (body) then
			body.pos = client:GetPos() + Vector(0, 0, 40)
			body.r = r
			body.g = g
			body.b = b
			body.brightness = NETWORK.nvg.bodyLightBrightness
			body.decay = 900
			body.size = NETWORK.nvg.bodyLightSize
			body.dietime = CurTime() + 0.1
			body.noworld = false
			body.nomodel = false
		end
	end
end)

hook.Add("NetworkDrawHUD", "nwNVG", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !NETWORK.nvg.CanUse(client) or NETWORK.hud.IsHidden()) then
		return
	end

	local Sc = NETWORK.util.Scale
	local bActive = NETWORK.nvg.IsActive(client)
	local charge = NETWORK.nvg.GetCharge(client)

	if (!bActive and charge >= 0.999) then
		return
	end

	local label = NETWORK.util.Upper(L("nvgLabel"))
	local time = NETWORK.nvg.FormatTime(NETWORK.nvg.GetTimeLeft(client))
	local color = bActive and NETWORK.nvg.GetColor(client) or NETWORK.theme.textFaint
	local x = math.Round(ScrW() * 0.5)
	local y = Sc(84)
	local barWidth = Sc(240)
	local barHeight = math.max(Sc(5), 4)
	local shadow = math.max(Sc(1), 1)

	surface.SetFont("nwHudPlayer")

	local timeWidth = surface.GetTextSize(time)

	surface.SetFont("nwHudLabel")

	local labelWidth = surface.GetTextSize(label)
	local gap = Sc(12)
	local totalWidth = labelWidth + gap + timeWidth
	local startX = x - math.Round(totalWidth * 0.5)

	NETWORK.util.DrawSimpleTextShadow(label, "nwHudLabel", startX, y, ColorAlpha(color, 235),
		TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, shadow)
	NETWORK.util.DrawSimpleTextShadow(time, "nwHudPlayer", startX + labelWidth + gap, y,
		ColorAlpha(NETWORK.theme.text, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, shadow)

	local barX = x - math.Round(barWidth * 0.5)
	local barY = y + Sc(18)

	surface.SetDrawColor(0, 0, 0, 120)
	surface.DrawRect(barX - 1, barY - 1, barWidth + 2, barHeight + 2)
	surface.SetDrawColor(255, 255, 255, 28)
	surface.DrawRect(barX, barY, barWidth, barHeight)
	surface.SetDrawColor(color.r, color.g, color.b, 235)
	surface.DrawRect(barX, barY, math.Round(barWidth * charge), barHeight)
	surface.SetDrawColor(255, 255, 255, 40)
	surface.DrawOutlinedRect(barX, barY, barWidth, barHeight, 1)

	if (bActive) then
		NETWORK.util.DrawSimpleTextShadow(L("nvgActive"), "nwHudSmall", x, barY + barHeight + Sc(9),
			ColorAlpha(color, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, shadow)
	end
end)
