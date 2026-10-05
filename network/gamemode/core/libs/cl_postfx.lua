NETWORK.postfx = NETWORK.postfx or {}

local vignette = CreateClientConVar("network_fx_vignette", "0.55", true, false,
	"Затемнение по краям кадра")
local fogEnabled = CreateClientConVar("network_fx_fog", "1", true, false,
	"Туман по высоте и расстоянию")

local vignetteSize = CreateClientConVar("network_fx_vignette_size", "0.62", true, false,
	"Ширина полосы виньетки: доля меньшей стороны экрана (0.4..1)")
local vignetteColor = CreateClientConVar("network_fx_vignette_color", "black", true, false,
	"Цвет виньетки: black, blue или warm")

NETWORK.postfx.vignetteColors = {
	black = Color(0, 0, 0),
	blue = Color(6, 16, 34),
	warm = Color(34, 16, 4)
}

function NETWORK.postfx.GetVignetteStrength()
	return math.Clamp(vignette:GetFloat(), 0, 1) *
		((GetConVar("network_compact_hud") and GetConVar("network_compact_hud"):GetBool()) and 0.3 or 1)
end

function NETWORK.postfx.GetVignetteColor()
	return NETWORK.postfx.vignetteColors[vignetteColor:GetString()] or
		NETWORK.postfx.vignetteColors.black
end

function NETWORK.postfx.DrawVignette(strength)
	if (strength <= 0.01) then
		return
	end

	local width, height = ScrW(), ScrH()
	local size = math.Clamp(vignetteSize:GetFloat(), 0.4, 1)

	NETWORK.util.DrawVignette(0, 0, width, height,
		math.Round(math.min(width, height) * size), 205 * strength,
		NETWORK.postfx.GetVignetteColor())
end

NETWORK.postfx.fog = NETWORK.postfx.fog or {
	start = 600,
	stop = 6000,
	density = 0.35,
	height = 0,
	color = Color(38, 42, 48)
}

function NETWORK.postfx.SetFog(data)
	for key, value in pairs(data or {}) do
		NETWORK.postfx.fog[key] = value
	end
end

hook.Add("SetupWorldFog", "nwPostFog", function()
	if (!fogEnabled:GetBool()) then
		return
	end

	local fog = NETWORK.postfx.fog

	if ((fog.density or 0) <= 0.001) then
		return
	end

	local lift = math.Clamp((EyePos().z - (fog.height or 0)) / 900, 0, 1.6)

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(fog.start * (1 + lift))
	render.FogEnd(fog.stop * (1 + lift * 0.6))
	render.FogMaxDensity(math.Clamp(fog.density * (1 - lift * 0.4), 0, 1))
	render.FogColor(fog.color.r, fog.color.g, fog.color.b)

	return true
end)

hook.Add("SetupSkyboxFog", "nwPostFog", function(scale)
	if (!fogEnabled:GetBool()) then
		return
	end

	local fog = NETWORK.postfx.fog

	if ((fog.density or 0) <= 0.001) then
		return
	end

	render.FogMode(MATERIAL_FOG_LINEAR)
	render.FogStart(fog.start * scale)
	render.FogEnd(fog.stop * scale)
	render.FogMaxDensity(math.Clamp(fog.density, 0, 1))
	render.FogColor(fog.color.r, fog.color.g, fog.color.b)

	return true
end)

hook.Add("HUDPaintBackground", "nwPostFX", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	if (IsValid(NETWORK.gui.menu)) then
		return
	end

	NETWORK.postfx.DrawVignette(math.Clamp(vignette:GetFloat(), 0, 1))
end)
