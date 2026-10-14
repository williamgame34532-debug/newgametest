-- Low health: blood creeps in from the edges (materials/network2/ui/blood_overlay.png), the
-- picture loses its colour and gets a red tint, and below a third of the health it pulses with a
-- heartbeat you hear. Starts below 70% health.
-- A hit is felt: the whole screen goes red for about a second (stronger for a harder hit), the
-- view shakes and smears, the colour drains. No sound of its own (no thump, no ringing).

local BLOOD = Material("network2/ui/blood_overlay.png", "smooth")
local state = {level = 0, flash = 0, last = nil, beat = 0}
local HEART = "player/heartbeat1.wav"

-- the heartbeat stops at once (healed, dead, in the menu)
local function StopHeart(client)
	if (state.beating and IsValid(client)) then
		client:StopSound(HEART)
	end

	state.beating = false
end

local GRADE = {
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

local function InGame(client)
	return IsValid(client) and client:Alive() and client:GetCharacterID() != 0 and !(NW.menu and NW.menu.active)
end

hook.Add("Think", "nwWounds", function()
	local client = LocalPlayer()

	if (!InGame(client)) then
		state.level = math.Approach(state.level, 0, FrameTime())
		state.last = nil
		StopHeart(client)

		return
	end

	local health = client:Health()
	local max = math.max(client:GetMaxHealth(), 1)

	-- a hit: red, shake, smear
	if (state.last and health < state.last) then
		local damage = state.last - health

		state.flash = math.min(1, state.flash + damage / 25 + math.min(damage, 10) * 0.045)
		state.hitAt = RealTime()
		util.ScreenShake(client:GetPos(), math.Clamp(3 + damage / 3, 3, 18), 30, math.Clamp(0.35 + damage / 60, 0.35, 1),
			64)
	end

	state.last = health
	state.flash = math.Approach(state.flash, 0, FrameTime() * 0.9)

	local want = math.Clamp((0.7 - health / max) / 0.55, 0, 1)

	state.level = math.Approach(state.level, want, FrameTime() * 0.8)

	-- the heartbeat below a third, one beat at a time
	if (health / max >= 0.34) then
		StopHeart(client)
	elseif (CurTime() > state.beat) then
		local rate = Lerp(health / max / 0.34, 0.55, 1.1)

		state.beat = CurTime() + rate
		state.pulseAt = RealTime()
		client:StopSound(HEART)
		client:EmitSound(HEART, 60, 100, math.Clamp(state.level, 0.3, 0.8))
		state.beating = true
	end
end)

hook.Add("RenderScreenspaceEffects", "nwWounds", function()
	local flash = state.flash
	local level = math.max(state.level, flash * 0.8)

	if (level <= 0.01 or !InGame(LocalPlayer())) then
		return
	end

	GRADE["$pp_colour_colour"] = math.max(0, 1 - level * 0.7 - flash * 0.3)
	GRADE["$pp_colour_addr"] = level * 0.035 + flash * 0.12
	GRADE["$pp_colour_mulr"] = flash * 0.6
	GRADE["$pp_colour_contrast"] = 1 + level * 0.08 + flash * 0.15
	GRADE["$pp_colour_brightness"] = -level * 0.03 - flash * 0.05

	DrawColorModify(GRADE)

	-- the hit smears the view
	if (flash > 0.05) then
		DrawMotionBlur(0.25, math.min(flash * 0.9, 0.85), 0.01)
	end
end)

hook.Add("HUDPaintBackground", "nwWounds", function()
	local level = math.max(state.level, state.flash * 0.75)

	if (level <= 0.01 or !InGame(LocalPlayer())) then
		return
	end

	-- the beat: a short swell
	local pulse = 0

	if (state.pulseAt) then
		local t = RealTime() - state.pulseAt

		pulse = math.max(0, 1 - t / 0.35) * 0.25
	end

	local sw, sh = ScrW(), ScrH()

	-- the red of the hit over everything
	if (state.flash > 0.01) then
		local t = state.hitAt and (RealTime() - state.hitAt) or 1
		local spike = math.max(0, 1 - t / 0.15) * 0.35

		surface.SetDrawColor(140, 0, 0, math.Clamp(state.flash * 120 + spike * 255, 0, 200))
		surface.DrawRect(0, 0, sw, sh)
	end

	local grow = (1 - level) * 0.25 - pulse * 0.08

	surface.SetMaterial(BLOOD)
	surface.SetDrawColor(255, 255, 255, math.Clamp(level + pulse, 0, 1) * 255)
	surface.DrawTexturedRect(-sw * grow / 2, -sh * grow / 2, sw * (1 + grow), sh * (1 + grow))
end)
