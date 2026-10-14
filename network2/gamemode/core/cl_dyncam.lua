-- Dynamic camera (first and third person): the view lives with the body.
--   steps        walking and running sway the view up-down and side to side, in step with the pace
--   strafing     the view leans into the side the character moves to
--   turning      a quick turn of the mouse rolls the view a little after it
--   landing      a jump or a fall dips the view and it springs back (the harder, the deeper)
--   running      the field of view opens a little
--   standing     a slow breathing sway
-- None of it moves the aim: shots still go where the player really looks; only the picture moves,
-- and the sway of the view stays within a degree or two. Off: nw_dyncam 0; nw_dyncam_scale 0..2 -
-- how strong (Настройки in the Q menu → Камера).

NW.dyncam = NW.dyncam or {}

local DC = NW.dyncam
local enabled = CreateClientConVar("nw_dyncam", "1", true, false, "Динамичная камера")
local scale = CreateClientConVar("nw_dyncam_scale", "1", true, false, "Сила динамичной камеры", 0, 2)

local state = {phase = 0, amp = 0, roll = 0, turn = 0, fov = 0, dip = 0, dipSpeed = 0, kick = 0,
	ground = true, fall = 0, lastYaw = nil}

local function Approach(current, target, rate, frame)
	return Lerp(math.Clamp(frame * rate, 0, 1), current, target)
end

-- per frame: the pace, the lean, the landing spring
hook.Add("Think", "nwDynCam", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		return
	end

	local frame = math.min(FrameTime(), 0.1)
	local velocity = client:GetVelocity()
	local onGround = client:OnGround()
	local speed = onGround and velocity:Length2D() or 0
	local run = math.max(client:GetRunSpeed(), 150)

	-- steps: the phase runs with the speed, the strength follows it smoothly
	state.amp = Approach(state.amp, math.Clamp(speed / run, 0, 1.25), 6, frame)
	state.phase = state.phase + frame * (4.2 + speed / run * 6.5)

	-- lean into the side of movement (the speed to the right of the view)
	local yaw = Angle(0, client:EyeAngles().y, 0)
	local side = velocity:Dot(yaw:Right()) / run

	state.roll = Approach(state.roll, math.Clamp(side, -1, 1) * 1.8, 5, frame)

	-- the turn of the mouse
	local eyeYaw = client:EyeAngles().y

	if (state.lastYaw) then
		local rate = math.AngleDifference(eyeYaw, state.lastYaw) / math.max(frame, 0.001)

		state.turn = Approach(state.turn, math.Clamp(-rate / 400, -1, 1) * 1.4, 7, frame)
	end

	state.lastYaw = eyeYaw

	-- running opens the field of view
	local sprinting = client:KeyDown(IN_SPEED) and speed > client:GetWalkSpeed() * 1.15

	state.fov = Approach(state.fov, sprinting and 4 or 0, 3, frame)

	-- landing: a dip by the speed of the fall, then a spring back
	if (!onGround) then
		state.fall = math.max(state.fall, -velocity.z)
	elseif (!state.ground and onGround) then
		local hit = math.Clamp((state.fall - 120) / 520, 0, 1)

		if (hit > 0) then
			state.dipSpeed = state.dipSpeed - (110 + hit * 260)
			state.kick = state.kick + hit * 2.4
		end

		state.fall = 0
	end

	state.ground = onGround

	-- a damped spring brings the dip back to zero (small steps: steady at any frame rate)
	local steps = math.ceil(frame / 0.008)
	local dt = frame / steps

	for _ = 1, steps do
		state.dipSpeed = state.dipSpeed + (-state.dip * 140 - state.dipSpeed * 16) * dt
		state.dip = math.Clamp(state.dip + state.dipSpeed * dt, -14, 6)
	end
	state.kick = Approach(state.kick, 0, 5, frame)
end)

-- applied to the finished view (cl_thirdperson.lua calls it)
function DC.Apply(client, view, bThirdPerson)
	if (!enabled:GetBool() or !IsValid(client) or !client:Alive() or client:InVehicle() or
		client:GetMoveType() == MOVETYPE_NOCLIP or (client.GetAct and client:GetAct())) then
		return view
	end

	local k = scale:GetFloat()

	if (k <= 0) then
		return view
	end

	local angles = view.angles
	local origin = view.origin

	if (!angles or !origin) then
		return view
	end

	local t = RealTime()
	local amp = state.amp * k
	local away = bThirdPerson and 0.55 or 1

	-- steps: up-down twice per stride, side to side once
	local bobUp = math.abs(math.sin(state.phase)) * 2 - 1
	local bobSide = math.sin(state.phase)

	-- breathing when standing
	local breath = (1 - math.min(state.amp, 1)) * k

	origin = origin + angles:Up() * (bobUp * 1.1 * amp * away + state.dip * 0.45 * k + math.sin(t * 1.6) * 0.35 * breath)
		+ angles:Right() * (bobSide * 0.75 * amp * away)

	angles = Angle(angles.p, angles.y, angles.r)
	angles.p = angles.p + bobUp * 0.35 * amp + state.kick * k + math.sin(t * 0.8) * 0.12 * breath
	angles.y = angles.y + bobSide * 0.25 * amp + math.cos(t * 0.6) * 0.1 * breath
	angles.r = angles.r + (state.roll + state.turn) * k + bobSide * 0.45 * amp

	view.origin = origin
	view.angles = angles
	view.fov = (view.fov or 75) + state.fov * k

	return view
end
