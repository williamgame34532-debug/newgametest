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

hook.Add('CalcMainActivity', 'HLAUnitAnims', function(p, vel)
	if not isUnit(p) or p:InVehicle() then return end
	local set = SETS[armed(p) and (p:GetNW2Bool('hla_safe') and 'safe' or 'armed') or 'unarmed']
	local speed = vel:Length2D()
	local kind
	if p:WaterLevel() >= 2 then kind = 'swim'
	elseif not p:IsOnGround() and p:GetMoveType() ~= MOVETYPE_NOCLIP then kind = 'air'
	elseif p:Crouching() then kind = speed > 4 and 'cwalk' or 'cidle'
	elseif speed > (p:GetWalkSpeed() + p:GetRunSpeed()) * 0.5 then kind = 'run'
	elseif speed > 4 then kind = 'walk'
	else kind = 'idle' end
	local act, seq = pick(p, set[kind])
	if not act then return end
	p.CalcIdeal, p.CalcSeqOverride = act, seq
	return act, seq
end)

hook.Add('UpdateAnimation', 'HLAUnitAnims', function(p, vel, maxSeqSpeed)
	if not isUnit(p) then return end
	local body = CLIENT and p:GetRenderAngles().y or p:GetAngles().y
	local speed = vel:Length2D()
	local rate = 1
	if speed > 4 then
		p:SetPoseParameter('move_yaw', math.NormalizeAngle(vel:Angle().y - body))
		local gs = p:GetSequenceGroundSpeed(p:GetSequence())
		if gs and gs > 1 then rate = math.Clamp(speed / gs, 0.5, 2) end
	end
	if not p:IsOnGround() then rate = 1 end
	p:SetPlaybackRate(rate)
	local eye = p:EyeAngles()
	local safe = p:GetNW2Bool('hla_safe') and armed(p)
	p:SetPoseParameter('aim_pitch', safe and 0 or math.Clamp(eye.p, -60, 60))
	p:SetPoseParameter('aim_yaw', safe and 0 or math.Clamp(math.NormalizeAngle(eye.y - body), -60, 60))
	p:SetPoseParameter('head_pitch', 0)
	p:SetPoseParameter('head_yaw', 0)
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
