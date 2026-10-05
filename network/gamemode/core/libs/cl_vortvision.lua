local VORT = NETWORK.vort

NETWORK.vort.visionPath = "framework/background/blood_vignette_xen.png"

local vision = Material(NETWORK.vort.visionPath, "smooth")

local enabled = CreateClientConVar("network_vort_vision", "1", true, false,
	"Ксенское зрение: виньетка и зелёный оттенок у вортигонтов")

NETWORK.option.Register("network_vort_vision", {
	name = "optVortVision",
	description = "optVortVisionDesc",
	category = "view",
	type = "bool",
	convar = "network_vort_vision"
})

local power = 0

local function Target()
	local client = LocalPlayer()

	if (!enabled:GetBool() or !IsValid(client) or !VORT.IsVort(client)) then
		return 0
	end

	if (!client:Alive()) then
		return 0
	end

	local base = VORT.IsHigh(client) and 0.65 or 0.5

	return VORT.GetAura(client) != "none" and 1 or base
end

hook.Add("Think", "nwVortVision", function()
	power = NETWORK.util.Approach(power, Target(), 1.5)
end)

local tint = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

hook.Add("RenderScreenspaceEffects", "nwVortVision", function()
	if (power < 0.01) then
		return
	end

	tint["$pp_colour_addg"] = 0.022 * power
	tint["$pp_colour_addr"] = -0.012 * power
	tint["$pp_colour_addb"] = -0.010 * power

	tint["$pp_colour_colour"] = 1 - 0.14 * power
	tint["$pp_colour_contrast"] = 1 + 0.05 * power

	DrawColorModify(tint)
end)

hook.Add("HUDPaintBackground", "nwVortVision", function()
	if (power < 0.01 or vision:IsError()) then
		return
	end

	local scale = 1.35
	local width, height = ScrW() * scale, ScrH() * scale

	surface.SetDrawColor(255, 255, 255, 215 * power)
	surface.SetMaterial(vision)
	surface.DrawTexturedRect(math.Round((ScrW() - width) * 0.5),
		math.Round((ScrH() - height) * 0.5), width, height)
end)

concommand.Add("network_vort_vision_reload", function()
	vision = Material(NETWORK.vort.visionPath, "smooth")
end)
