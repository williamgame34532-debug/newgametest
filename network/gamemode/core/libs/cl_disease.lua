local D = NETWORK.disease

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

D.screen = D.screen or 0

hook.Add("RenderScreenspaceEffects", "nwDiseaseScreen", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local data = client:Alive() and D.GetData(client) or nil
	local target = data and (data.screen or 1) or 0

	D.screen = math.Approach(D.screen, target, FrameTime() * 0.4)

	if (D.screen <= 0.01) then
		return
	end

	modify["$pp_colour_addg"] = 0.025 * D.screen
	modify["$pp_colour_addr"] = -0.01 * D.screen
	modify["$pp_colour_colour"] = 1 - 0.35 * D.screen
	modify["$pp_colour_brightness"] = -0.03 * D.screen

	DrawColorModify(modify)
end)

hook.Add("Think", "nwDiseaseSway", function()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		return
	end

	local data = D.GetData(client)

	if (!data or (D.nextSway or 0) > CurTime()) then
		return
	end

	D.nextSway = CurTime() + math.Rand(6, 9)

	util.ScreenShake(client:GetPos(), 1.2 * (data.screen or 1), 3, 1.5, 64)
end)
