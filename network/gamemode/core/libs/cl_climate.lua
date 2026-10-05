local C = NETWORK.climate

local modify = {
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

C.screen = C.screen or 0

hook.Add("RenderScreenspaceEffects", "nwClimateCold", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local cold = client:Alive() and client:GetCold() or 0
	local target = math.Clamp((cold - 50) / 50, 0, 1)

	C.screen = math.Approach(C.screen, target, FrameTime() * 0.5)

	if (C.screen <= 0.01) then
		return
	end

	modify["$pp_colour_addb"] = 0.03 * C.screen
	modify["$pp_colour_colour"] = 1 - 0.4 * C.screen
	modify["$pp_colour_brightness"] = -0.04 * C.screen

	DrawColorModify(modify)
end)

hook.Add("Think", "nwClimateShiver", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local cold = client:GetCold()

	if (cold < 70) then
		return
	end

	if ((C.nextShiver or 0) > CurTime()) then
		return
	end

	local strength = math.Clamp((cold - 70) / 30, 0, 1)

	C.nextShiver = CurTime() + math.Rand(2.5, 5) - strength * 1.5

	util.ScreenShake(client:GetPos(), 0.6 + strength * 1.2, 24, 0.35, 64)
end)
