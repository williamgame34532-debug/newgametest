NETWORK.post = NETWORK.post or {}

NETWORK.post.colour = {
	["$pp_colour_addr"] = 0.016,
	["$pp_colour_addg"] = 0.010,
	["$pp_colour_addb"] = 0.002,
	["$pp_colour_brightness"] = -0.010,
	["$pp_colour_contrast"] = 1.08,
	["$pp_colour_colour"] = 1.12,
	["$pp_colour_mulr"] = 0.05,
	["$pp_colour_mulg"] = 0.025,
	["$pp_colour_mulb"] = 0.005
}

NETWORK.post.bloom = {
	darken = 0.58,
	multiply = 0.92,
	sizeX = 7,
	sizeY = 7,
	passes = 1,
	colorMultiply = 1,

	red = 1.10,
	green = 1.00,
	blue = 0.88
}

NETWORK.post.vignetteAlpha = 235
NETWORK.post.vignettePath = "framework/background/vignette.png"

local enabled = CreateClientConVar("network_postprocess", "1", true, false,
	"Цветокоррекция и виньетка Network")

local vignette = Material(NETWORK.post.vignettePath, "smooth")

NETWORK.post.exposure = NETWORK.post.exposure or 1
NETWORK.post.lightLevel = NETWORK.post.lightLevel or 0.5

local nextSample = 0

local function SampleLight()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	if (CurTime() < nextSample) then
		return
	end

	nextSample = CurTime() + 0.25

	local light = render.GetLightColor(client:EyePos())
	local level = math.Clamp((light.x + light.y + light.z) / 3, 0, 1.5)

	NETWORK.post.lightLevel = level
end

hook.Add("RenderScreenspaceEffects", "nwPostProcess", function()
	if (!enabled:GetBool()) then
		return
	end

	SampleLight()

	local target = math.Clamp(1.25 - NETWORK.post.lightLevel * 0.45, 0.85,
		1.25)

	NETWORK.post.exposure = math.Approach(NETWORK.post.exposure, target,
		FrameTime() * 0.25)

	local exposure = NETWORK.post.exposure
	local colour = NETWORK.post.colour

	DrawColorModify({
		["$pp_colour_addr"] = colour["$pp_colour_addr"],
		["$pp_colour_addg"] = colour["$pp_colour_addg"],
		["$pp_colour_addb"] = colour["$pp_colour_addb"],
		["$pp_colour_brightness"] = colour["$pp_colour_brightness"] +
			(exposure - 1) * 0.12,
		["$pp_colour_contrast"] = colour["$pp_colour_contrast"] *
			(2 - exposure) ^ 0.5,
		["$pp_colour_colour"] = colour["$pp_colour_colour"],
		["$pp_colour_mulr"] = colour["$pp_colour_mulr"],
		["$pp_colour_mulg"] = colour["$pp_colour_mulg"],
		["$pp_colour_mulb"] = colour["$pp_colour_mulb"]
	})

	local bloom = NETWORK.post.bloom

	DrawBloom(bloom.darken + (exposure - 1) * 0.25, bloom.multiply,
		bloom.sizeX, bloom.sizeY, bloom.passes, bloom.colorMultiply,
		bloom.red, bloom.green, bloom.blue)
end)

local vignetteStrength

hook.Add("HUDPaintBackground", "nwVignette", function()
	if (!enabled:GetBool() or vignette:IsError()) then
		return
	end

	vignetteStrength = vignetteStrength or GetConVar("network_fx_vignette")

	local strength = vignetteStrength and math.Clamp(vignetteStrength:GetFloat(), 0, 1) or 1

	if (strength <= 0.01) then
		return
	end

	surface.SetDrawColor(255, 255, 255, NETWORK.post.vignetteAlpha * strength)
	surface.SetMaterial(vignette)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)

concommand.Add("network_postprocess_reload", function()
	vignette = Material(NETWORK.post.vignettePath, "smooth")
end)

NETWORK.post.bloodPath = "framework/background/blood.png"
NETWORK.post.bloodStart = 50

local bloodAlpha = 0

hook.Add("HUDPaintBackground", "nwBlood", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:HasCharacter()) then
		return
	end

	local health = client:Alive() and client:Health() or 0
	local target = 1 - math.Clamp(health / NETWORK.post.bloodStart, 0, 1)

	bloodAlpha = Lerp(math.Clamp(FrameTime() * 3, 0, 1), bloodAlpha, target)

	if (bloodAlpha < 0.02) then
		return
	end

	local material = NETWORK.util.GetMaterial(NETWORK.post.bloodPath, "smooth")

	if (material:IsError()) then
		return
	end

	local pulse = 0.82 + math.sin(CurTime() * 2.4) * 0.18

	surface.SetDrawColor(255, 255, 255, 255 * bloodAlpha * pulse)
	surface.SetMaterial(material)
	surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)

hook.Add("RenderScreenspaceEffects", "nwBlood", function()
	if (bloodAlpha < 0.02) then
		return
	end

	DrawColorModify({
		["$pp_colour_addr"] = 0.06 * bloodAlpha,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = -0.03 * bloodAlpha,
		["$pp_colour_contrast"] = 1 + 0.08 * bloodAlpha,
		["$pp_colour_colour"] = 1 - 0.4 * bloodAlpha,
		["$pp_colour_mulr"] = 0.15 * bloodAlpha,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	})
end)
