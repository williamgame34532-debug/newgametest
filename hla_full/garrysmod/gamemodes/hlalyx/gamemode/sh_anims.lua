-- Players with unit models (Combine NPC models) are animated with the Combine soldier NPC activities:
-- idle / walk / run / crouch with the rifle when armed, unarmed ones with the hands, firing and
-- reloading as gestures, aiming with the model's aim_pitch / aim_yaw, legs with move_yaw.
local M = HLA.Menu

local function isUnit(p) return IsValid(p) and M.Class(p:GetModel()) ~= nil end
HLA.IsUnit = isUnit

-- activity lists: the first one the model has wins (models differ a little)
local SETS = {
	armed = {
		idle = {ACT_IDLE_ANGRY_SMG1, ACT_IDLE_ANGRY, ACT_IDLE_SMG1, ACT_IDLE},
		walk = {ACT_WALK_AIM_RIFLE, ACT_WALK_RIFLE, ACT_WALK},
		run = {ACT_RUN_AIM_RIFLE, ACT_RUN_RIFLE, ACT_RUN},
		cidle = {ACT_RANGE_AIM_SMG1_LOW, ACT_CROUCHIDLE, ACT_COVER_LOW, ACT_IDLE},
		cwalk = {ACT_WALK_CROUCH_AIM_RIFLE, ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH, ACT_WALK},
		air = {ACT_GLIDE, ACT_JUMP, ACT_IDLE_ANGRY_SMG1, ACT_IDLE},
		swim = {ACT_SWIM, ACT_GLIDE, ACT_IDLE},
	},
	-- the weapon on safety (Shift + E + R): lowered, relaxed — the «at ease» activities of the Combine
	safe = {
		idle = {ACT_IDLE_SMG1_RELAXED, ACT_IDLE_AR2_RELAXED, ACT_IDLE_RIFLE, ACT_IDLE_RELAXED, ACT_IDLE_SMG1, ACT_IDLE},
		walk = {ACT_WALK_RIFLE_RELAXED, ACT_WALK_AR2_RELAXED, ACT_WALK_RELAXED, ACT_WALK_RIFLE, ACT_WALK},
		run = {ACT_RUN_RIFLE_RELAXED, ACT_RUN_AR2_RELAXED, ACT_RUN_RELAXED, ACT_RUN_RIFLE, ACT_RUN},
		cidle = {ACT_CROUCHIDLE, ACT_COVER_LOW, ACT_IDLE},
		cwalk = {ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH, ACT_WALK},
		air = {ACT_GLIDE, ACT_JUMP, ACT_IDLE},
		swim = {ACT_SWIM, ACT_GLIDE, ACT_IDLE},
	},
	unarmed = {
		idle = {ACT_IDLE, ACT_IDLE_RELAXED, ACT_IDLE_ANGRY},
		walk = {ACT_WALK, ACT_WALK_RELAXED, ACT_WALK_RIFLE},
		run = {ACT_RUN, ACT_RUN_RELAXED, ACT_RUN_RIFLE},
		cidle = {ACT_CROUCHIDLE, ACT_COVER_LOW, ACT_IDLE},
		cwalk = {ACT_WALK_CROUCH, ACT_WALK_CROUCH_RIFLE, ACT_WALK},
		air = {ACT_GLIDE, ACT_JUMP, ACT_IDLE},
		swim = {ACT_SWIM, ACT_GLIDE, ACT_IDLE},
	},
}
local GESTURES = {
	fire = {ACT_GESTURE_RANGE_ATTACK_SMG1, ACT_GESTURE_RANGE_ATTACK_AR2, ACT_GESTURE_RANGE_ATTACK1},
	reload = {ACT_GESTURE_RELOAD_SMG1, ACT_GESTURE_RELOAD, ACT_GESTURE_RELOAD_SHOTGUN},
}

-- sequence for an activity, looked up once per model
local cache = {}
local function pick(p, acts)
	local mdl = p:GetModel()
	local c = cache[mdl]
	if not c then c = {} cache[mdl] = c end
	for _, act in ipairs(acts) do
		local seq = c[act]
		if seq == nil then
			seq = p:SelectWeightedSequence(act) or -1
			c[act] = seq
		end
		if seq > 0 then return act, seq end
	end
end

local UNARMED = {hla_hands = true, weapon_physcannon = true}
local function armed(p)
	local w = p:GetActiveWeapon()
	return IsValid(w) and not UNARMED[w:GetClass()]
end

local SEQ_NAMES = {
	safe = {idle = 'idle1', walk = 'walkeasy_all', run = 'runall'},
	armed = {idle = 'combatidle1', walk = 'walk_aiming_all', run = 'runaimall1'},
}
local namedCache = {}
local function named(p, name)
	local mdl = p:GetModel()
	local c = namedCache[mdl]
	if not c then c = {} namedCache[mdl] = c end
	if c[name] == nil then
		local id = p:LookupSequence(name)
		c[name] = (id and id >= 0) and id or false
	end
	return c[name] or nil
end

hook.Add('CalcMainActivity', 'HLAUnitAnims', function(p, vel)
	if not isUnit(p) or p:InVehicle() then return end
	local setName = armed(p) and (p:GetNW2Bool('hla_safe') and 'safe' or 'armed') or 'unarmed'
	local set = SETS[setName]
	local speed = vel:Length2D()
	local kind
	if p:WaterLevel() >= 2 then kind = 'swim'
	elseif not p:IsOnGround() and p:GetMoveType() ~= MOVETYPE_NOCLIP then kind = 'air'
	elseif p:Crouching() then kind = speed > 4 and 'cwalk' or 'cidle'
	-- running: Shift held and really faster than a walk (the speed alone sat on the line between them)
	elseif (p:KeyDown(IN_SPEED) and speed > p:GetWalkSpeed() * 1.1) or speed > (p:GetWalkSpeed() + p:GetRunSpeed()) * 0.5 then kind = 'run'
	elseif speed > 4 then kind = 'walk'
	else kind = 'idle' end
	-- sequences by name first (the HL:A Combine models: safety — idle1 / walkeasy_all / runall,
	-- weapon up — combatidle1 / walk_aiming_all / runaimall1), when the model has them
	local byName = SEQ_NAMES[setName] and SEQ_NAMES[setName][kind]
	if byName then
		local seq = named(p, byName)
		if seq then
			local act = kind == 'run' and ACT_RUN or kind == 'walk' and ACT_WALK or ACT_IDLE
			p.CalcIdeal, p.CalcSeqOverride = act, seq
			return act, seq
		end
	end
	local act, seq = pick(p, set[kind])
	if not act then return end
	p.CalcIdeal, p.CalcSeqOverride = act, seq
	return act, seq
end)

-- turning on the spot (as Barney and the HL2 humans do it, male_shared.mdl): standing, the body keeps its
-- direction while the head and the weapon follow the view; past 50° it turns with a turn gesture
-- (ACT_GESTURE_TURN_LEFT45 / 90, RIGHT45 / 90 — when the model has them), moving it simply faces the view
local TURN = {left45 = ACT_GESTURE_TURN_LEFT45, left90 = ACT_GESTURE_TURN_LEFT90, right45 = ACT_GESTURE_TURN_RIGHT45, right90 = ACT_GESTURE_TURN_RIGHT90}
local function bodyYaw(p, vel)
	local eye = p:EyeAngles().y
	local now = CurTime()
	local dt = FrameTime()
	p.HLABody = p.HLABody or eye
	local moving = vel:Length2D() > 10 or not p:IsOnGround()
	if moving then
		p.HLATurnTo = nil
		p.HLABody = math.ApproachAngle(p.HLABody, eye, math.max(360, math.abs(math.AngleDifference(eye, p.HLABody)) * 10) * dt)
		return p.HLABody
	end
	if p.HLATurnTo then
		p.HLABody = math.ApproachAngle(p.HLABody, p.HLATurnTo, p.HLATurnSpeed * dt)
		if math.abs(math.AngleDifference(p.HLATurnTo, p.HLABody)) < 1 or now > (p.HLATurnUntil or 0) then p.HLATurnTo = nil end
		return p.HLABody
	end
	local diff = math.AngleDifference(eye, p.HLABody)
	if math.abs(diff) > 50 then
		local big = math.abs(diff) > 75
		local act = diff > 0 and (big and TURN.left90 or TURN.left45) or (big and TURN.right90 or TURN.right45)
		local seq = act and p:SelectWeightedSequence(act)
		if seq and seq > 0 then p:AnimRestartGesture(GESTURE_SLOT_CUSTOM, act, true) end
		p.HLATurnTo = eye
		p.HLATurnSpeed = math.abs(diff) / 0.45
		p.HLATurnUntil = now + 0.6
	end
	return p.HLABody
end

hook.Add('UpdateAnimation', 'HLAUnitAnims', function(p, vel, maxSeqSpeed)
	if not isUnit(p) then return end
	local body = bodyYaw(p, vel)
	if CLIENT then p:SetRenderAngles(Angle(0, body, 0)) end
	local speed = vel:Length2D()
	local rate = 1
	if speed > 4 then
		p:SetPoseParameter('move_yaw', math.NormalizeAngle(vel:Angle().y - body))
		local gs = p:GetSequenceGroundSpeed(p:GetSequence())
		-- the run is never slowed down into a walk, the walk never sped up into a run
		local running = p.CalcIdeal == ACT_RUN or (p.CalcIdeal and string.find(tostring(p:GetSequenceActivityName(p:GetSequence()) or ''), 'RUN', 1, true))
		if gs and gs > 1 then rate = math.Clamp(speed / gs, running and 0.85 or 0.6, running and 1.6 or 1.3) end
	end
	if not p:IsOnGround() then rate = 1 end
	p:SetPlaybackRate(rate)
	local eye = p:EyeAngles()
	local safe = p:GetNW2Bool('hla_safe') and armed(p)
	p:SetPoseParameter('aim_pitch', safe and 0 or math.Clamp(eye.p, -60, 60))
	p:SetPoseParameter('aim_yaw', safe and 0 or math.Clamp(math.NormalizeAngle(eye.y - body), -60, 60))
	p:SetPoseParameter('head_yaw', math.Clamp(math.NormalizeAngle(eye.y - body), -50, 50) * 0.5)
	p:SetPoseParameter('head_pitch', 0)
	if CLIENT then
		GAMEMODE:MouthMoveAnimation(p)
	end
	return true
end)

hook.Add('DoAnimationEvent', 'HLAUnitAnims', function(p, event, data)
	if not isUnit(p) then return end
	if event == PLAYERANIMEVENT_ATTACK_PRIMARY or event == PLAYERANIMEVENT_ATTACK_SECONDARY then
		local act = pick(p, GESTURES.fire)
		if act then p:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true) end
		return ACT_VM_PRIMARYATTACK
	elseif event == PLAYERANIMEVENT_RELOAD then
		local act = pick(p, GESTURES.reload)
		if act then p:AnimRestartGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, act, true) end
		return ACT_INVALID
	elseif event == PLAYERANIMEVENT_JUMP then
		p:AnimRestartMainSequence()
		return ACT_INVALID
	end
end)

---------------------------------------------------------------------------------------------------
-- Safety: Shift + E + R together puts the weapon on safety (lowered, relaxed animations, it does not
-- fire) and takes it off again. Read from the movement command, so client and server agree; the E and R of
-- the combo do not use or reload.
local HELD = IN_SPEED + IN_USE + IN_RELOAD
hook.Add('StartCommand', 'HLASafety', function(p, cmd)
	local b = cmd:GetButtons()
	local combo = bit.band(b, HELD) == HELD
	if combo then
		cmd:SetButtons(bit.band(b, bit.bnot(bit.bor(IN_RELOAD, IN_USE))))
		if not p.HLASafeHeld and SERVER and armed(p) then
			local on = not p:GetNW2Bool('hla_safe')
			p:SetNW2Bool('hla_safe', on)
			p:EmitSound(on and 'weapons/smg1/switch_single.wav' or 'weapons/smg1/switch_burst.wav', 55, on and 95 or 105, 0.7)
		end
	end
	p.HLASafeHeld = combo
	if p:GetNW2Bool('hla_safe') and armed(p) then
		cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(bit.bor(IN_ATTACK, IN_ATTACK2))))
	end
end)
HLA.IsSafe = function(p) return IsValid(p) and p:GetNW2Bool('hla_safe') and armed(p) end

-- the body direction also when the model is drawn (other code may set the render angles back)
if CLIENT then
	hook.Add('PrePlayerDraw', 'HLAUnitBodyYaw', function(p)
		if p.HLABody and isUnit(p) then p:SetRenderAngles(Angle(0, p.HLABody, 0)) end
	end)
end
