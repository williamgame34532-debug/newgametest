-- Out of breath. With the stamina at zero the character gasps for air: heavy breathing that
-- quietens as the stamina comes back. Keep trying to run while exhausted (Shift and moving) and the
-- picture clouds over: it blurs, smears and darkens more the longer you push, and clears slowly
-- once you stop.

local BREATH = "player/breathe1.wav"
local BLUR = Material("pp/blurscreen")
local state = {breath = 0, strain = 0}

local function InGame(client)
	return IsValid(client) and client:Alive() and client:GetCharacterID() != 0 and !(NW.menu and NW.menu.active)
end

local function StopBreath()
	if (state.sound) then
		state.sound:Stop()
		state.sound = nil
	end
end

hook.Add("Think", "nwExhaust", function()
	local client = LocalPlayer()
	local dt = FrameTime()

	if (!InGame(client)) then
		state.breath = 0
		state.strain = 0
		StopBreath()

		return
	end

	local exhausted = client:IsExhausted()
	local stamina = client:GetStamina()

	-- gasping: full at zero, fading out by 30
	local want = exhausted and math.Clamp(1 - stamina / 30, 0.25, 1) or 0

	state.breath = math.Approach(state.breath, want, dt * (want > state.breath and 2 or 0.4))

	if (state.breath > 0.01) then
		if (!state.sound) then
			state.sound = CreateSound(client, BREATH)
			state.sound:PlayEx(0, 100)
		end

		state.sound:ChangeVolume(state.breath * 0.9, 0)
		state.sound:ChangePitch(95 + state.breath * 12, 0)
	else
		StopBreath()
	end

	-- pushing on while exhausted
	local pushing = exhausted and client:KeyDown(IN_SPEED) and client:GetVelocity():Length2D() > 20

	state.strain = math.Approach(state.strain, pushing and 1 or 0, dt * (pushing and 0.3 or 0.2))
end)

hook.Add("RenderScreenspaceEffects", "nwExhaust", function()
	if (state.strain > 0.01) then
		DrawMotionBlur(0.15, state.strain * 0.85, 0.01)
		DrawColorModify({
			["$pp_colour_addr"] = 0,
			["$pp_colour_addg"] = 0,
			["$pp_colour_addb"] = 0,
			["$pp_colour_brightness"] = -0.06 * state.strain,
			["$pp_colour_contrast"] = 1 - 0.15 * state.strain,
			["$pp_colour_colour"] = 1 - 0.5 * state.strain,
			["$pp_colour_mulr"] = 0,
			["$pp_colour_mulg"] = 0,
			["$pp_colour_mulb"] = 0
		})
	end
end)

hook.Add("HUDPaintBackground", "nwExhaust", function()
	local amount = state.strain

	if (amount <= 0.01) then
		return
	end

	-- the picture clouds over, breathing with the gasps
	local pulse = 0.85 + math.sin(RealTime() * 3.2) * 0.15

	surface.SetMaterial(BLUR)
	surface.SetDrawColor(255, 255, 255, 255)

	for i = 1, 3 do
		BLUR:SetFloat("$blur", i / 3 * amount * pulse * 7)
		BLUR:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
	end

	surface.SetDrawColor(8, 8, 10, 110 * amount * pulse)
	surface.DrawRect(0, 0, ScrW(), ScrH())
end)
