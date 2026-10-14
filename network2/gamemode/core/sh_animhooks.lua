-- Animation engine: picks the main sequence of every player from its model's animation class
-- (sh_anims.lua) - NPC-style models (citizens, Civil Protection, Overwatch, vortigaunts) get
-- their own activities and the build's living idles, player models (m_anm / f_anm) the stock
-- sandbox animations. Missing activities are repaired per model (RepairSet): a similar stock
-- activity or a sequence found by name, so a model never T-poses.

-- one of a list of sequences per player, changing every `period` seconds; nil if none exist
function NW.anim.ResolveRotating(client, list, period)
	local available = {}

	for _, name in ipairs(list or {}) do
		local sequence = client:LookupSequence(name)

		if (sequence and sequence > 0) then
			available[#available + 1] = sequence
		end
	end

	if (#available <= 1) then
		return available[1]
	end

	local index = client:EntIndex()
	local slot = math.floor((CurTime() + index * 13.7) / period)

	return available[(slot * 7 + index) % #available + 1]
end

local HOLDTYPE_TRANSLATOR = {
	[""] = "normal",
	physgun = "smg",
	ar2 = "smg",
	crossbow = "shotgun",
	rpg = "shotgun",
	slam = "normal",
	grenade = "grenade",
	-- raised fists: the melee ready stance
	fist = "melee",
	melee2 = "melee",
	passive = "normal",
	knife = "melee",
	duel = "pistol",
	camera = "smg",
	magic = "normal",
	revolver = "pistol"
}

local PLAYER_HOLDTYPE_TRANSLATOR = {
	[""] = "normal",
	fist = "normal",
	pistol = "normal",
	grenade = "normal",
	melee = "normal",
	slam = "normal",
	melee2 = "normal",
	passive = "normal",
	knife = "normal",
	duel = "normal",
	bugbait = "normal"
}

local animationFixOffset = Vector(16.5438, -0.1642, -20.5493)

local function LookupCached(client, name)
	local cache = client.nwSeqLookup

	if (!cache or cache.model != client.nwAnimModel) then
		cache = {model = client.nwAnimModel}
		client.nwSeqLookup = cache
	end

	local sequence = cache[name]

	if (sequence == nil) then
		sequence = client:LookupSequence(name)
		cache[name] = sequence
	end

	return sequence
end

local function UpdateHoldType(client, weapon)
	weapon = weapon or client:GetActiveWeapon()

	local holdType = "normal"

	if (IsValid(weapon)) then
		holdType = weapon.HoldType or weapon:GetHoldType()
		holdType = HOLDTYPE_TRANSLATOR[holdType] or holdType

		local special = NW.anim.weaponHold and
			NW.anim.weaponHold[weapon:GetClass()]
		local base = special and NW.anim[client.nwAnimClass or ""]

		if (special and istable(base) and base[special]) then
			holdType = special
		end
	end

	client.nwAnimHoldType = holdType
	client.nwAnimWeapon = IsValid(weapon) and weapon:GetClass() or ""
	client.nwAnimRawHold = IsValid(weapon) and (weapon.HoldType or weapon:GetHoldType()) or ""
end

local repaired = {}

local function FindSequence(entity, keywords, avoid)
	local count = entity:GetSequenceCount() or 0

	for index = 0, count - 1 do
		local name = entity:GetSequenceName(index)

		if (!name) then
			continue
		end

		local lower = string.lower(name)
		local bSkip = false

		for _, word in ipairs(avoid or {}) do
			if (string.find(lower, word, 1, true)) then
				bSkip = true

				break
			end
		end

		if (bSkip) then
			continue
		end

		for _, word in ipairs(keywords) do
			if (string.find(lower, word, 1, true)) then
				return name
			end
		end
	end
end

-- stock activity used when none of a sequence list exists on the model
local REPAIR_FALLBACK = {[ACT_MP_STAND_IDLE] = ACT_IDLE}

local REPAIR = {
	[ACT_MP_STAND_IDLE] = {
		acts = {ACT_IDLE, ACT_IDLE_ANGRY, ACT_HL2MP_IDLE},
		keywords = {"idle"},
		avoid = {"crouch", "swim", "sit", "to_"}
	},
	[ACT_MP_CROUCH_IDLE] = {
		acts = {ACT_COVER_LOW, ACT_CROUCHIDLE, ACT_COVER_PISTOL_LOW,
			ACT_COVER_SMG1_LOW, ACT_RANGE_AIM_SMG1_LOW, ACT_HL2MP_IDLE_CROUCH},
		keywords = {"crouch", "duck", "cidle"},
		avoid = {"walk", "run", "move", "to_stand", "stand_to", "to_"}
	},
	[ACT_MP_WALK] = {
		acts = {ACT_WALK, ACT_WALK_RIFLE, ACT_WALK_PISTOL, ACT_WALK_ANGRY,
			ACT_HL2MP_WALK},
		keywords = {"walk"},
		avoid = {"crouch", "to_"}
	},
	[ACT_MP_CROUCHWALK] = {
		acts = {ACT_WALK_CROUCH, ACT_WALK_CROUCH_RIFLE, ACT_WALK_CROUCH_AIM_RIFLE,
			ACT_RUN_CROUCH, ACT_RUN_CROUCH_RIFLE, ACT_HL2MP_WALK_CROUCH},
		keywords = {"crouch_walk", "crouchwalk", "walk_crouch", "cwalk",
			"crouchrun", "crouch_run", "run_crouch", "crouchmove", "duck_walk",
			"duckwalk"},
		avoid = {"to_stand", "stand_to", "idle"},
		last = ACT_MP_WALK
	},
	[ACT_MP_RUN] = {
		acts = {ACT_RUN, ACT_RUN_RIFLE, ACT_RUN_PISTOL, ACT_HL2MP_RUN},
		keywords = {"run", "sprint"},
		avoid = {"crouch", "to_"}
	}
}

local function HasAction(entity, action)
	if (isstring(action)) then
		return (entity:LookupSequence(action) or -1) > 0
	end

	if (isnumber(action)) then
		return (entity:SelectWeightedSequence(action) or -1) >= 0
	end

	return true
end

local function FindReplacement(entity, key, depth)
	local rule = REPAIR[key]

	if (!rule) then
		return
	end

	for _, act in ipairs(rule.acts or {}) do
		if (isnumber(act) and HasAction(entity, act)) then
			return act
		end
	end

	local name = FindSequence(entity, rule.keywords or {}, rule.avoid)

	if (name) then
		return name
	end

	if (rule.last and (depth or 0) < 2) then
		return FindReplacement(entity, rule.last, (depth or 0) + 1)
	end
end

local function RepairSet(entity, set)
	local fixed = {}

	for key, value in pairs(set) do

		if (istable(value) and REPAIR[key]) then
			local copy = {}
			local replacement

			for index, action in ipairs(value) do
				if (HasAction(entity, action)) then
					copy[index] = action
				else
					replacement = replacement or FindReplacement(entity, key)

					if (!replacement) then
						for _, other in ipairs(value) do
							if (other != action and HasAction(entity, other)) then
								replacement = other

								break
							end
						end
					end

					copy[index] = replacement or action
				end
			end

			fixed[key] = copy
		else
			fixed[key] = value
		end
	end

	return fixed
end

local function RepairTable(client, base)
	local model = string.lower(client:GetModel() or "")

	if (model == "") then
		return base
	end

	if (repaired[model]) then
		return repaired[model]
	end

	if ((client:GetSequenceCount() or 0) < 2) then
		return base
	end

	local result = {}

	for holdType, set in pairs(base) do
		if (istable(set)) then
			result[holdType] = RepairSet(client, set)
		else
			result[holdType] = set
		end
	end

	setmetatable(result, getmetatable(base))

	repaired[model] = result

	return result
end

concommand.Add("network_anim_reload", function()
	repaired = {}
end)

local function UpdateAnimTable(client, vehicle)
	local base = NW.anim[client.nwAnimClass or "citizen_male"] or {}

	base = RepairTable(client, base)

	if (IsValid(vehicle)) then
		local class = vehicle:IsChair() and "chair" or vehicle:GetClass()

		if (base.vehicle and base.vehicle[class]) then
			client.nwAnimTable = base.vehicle[class]
		elseif (base.normal) then
			client.nwAnimTable = base.normal[ACT_MP_CROUCH_IDLE]
		end
	else
		client.nwAnimTable = base[client.nwAnimHoldType or "normal"] or base.normal

	end

	local tree = client.nwAnimTable

	client.nwAnimGlide = (istable(tree) and tree.glide) or base.glide
end

function NW.anim.Refresh(client, vehicle)
	client.nwAnimModel = client:GetModel()
	client.nwAnimClass = NW.anim.GetModelClass(client.nwAnimModel)

	UpdateHoldType(client)
	UpdateAnimTable(client, vehicle)
end

function GM:PlayerModelChanged(client, model)
	client.nwAnimClass = NW.anim.GetModelClass(model)

	UpdateHoldType(client)
	UpdateAnimTable(client)
end

function GM:PlayerWeaponChanged(client, weapon)
	UpdateHoldType(client, weapon)
	UpdateAnimTable(client)
end

function GM:PlayerSwitchWeapon(client, oldWeapon, weapon)
	if (!IsFirstTimePredicted()) then
		return
	end

	timer.Simple(0, function()
		if (IsValid(client)) then
			hook.Run("PlayerWeaponChanged", client, client:GetActiveWeapon())
		end
	end)
end

function GM:PlayerEnteredVehicle(client, vehicle)
	UpdateAnimTable(client, vehicle)
end

function GM:PlayerLeaveVehicle(client, vehicle)
	UpdateAnimTable(client)
end

-- names of falling / gliding sequences on HL2 humans, Combine and player models, best first
local AIR_NAMES = {"jump_holding_glide", "glide", "jump_holding_jump", "jump", "fall", "jump_shotgun_glide",
	"swim_idle_all"}

local Valid

Valid = function(client, action)
	if (isstring(action)) then
		local sequence = LookupCached(client, action)

		return (sequence and sequence > 0) and sequence or nil
	end

	if (isnumber(action)) then
		local sequence = client:SelectWeightedSequence(action)

		return (sequence and sequence > 0) and sequence or nil
	end

	if (istable(action)) then
		for _, value in ipairs(action) do
			if (!isstring(value)) then
				-- candidates: the first one that exists
				for _, candidate in ipairs(action) do
					local sequence = Valid(client, candidate)

					if (sequence) then
						return sequence
					end
				end

				return
			end
		end

		return NW.anim.ResolveRotating(client, action, 20)
	end
end

local function AirSequence(client, tree, bRaised)
	local cache = client.nwAirCache

	if (!cache or cache.model != client.nwAnimModel) then
		cache = {model = client.nwAnimModel}
		client.nwAirCache = cache
	end

	if (cache.sequence == nil) then
		local found = Valid(client, client.nwAnimGlide) or Valid(client, ACT_GLIDE) or Valid(client, ACT_JUMP)

		if (!found) then
			for _, name in ipairs(AIR_NAMES) do
				found = Valid(client, name)

				if (found) then
					break
				end
			end
		end

		cache.sequence = found or false
	end

	if (cache.sequence) then
		return cache.sequence
	end

	local idle = tree[ACT_MP_STAND_IDLE]

	return idle and (Valid(client, idle[bRaised and 2 or 1]) or Valid(client, idle[1])) or
		Valid(client, ACT_IDLE)
end

-- standing pose for anything a model cannot play
local function FallbackIdle(client, tree, bRaised)
	local idle = tree and tree[ACT_MP_STAND_IDLE]

	return idle and (Valid(client, idle[bRaised and 2 or 1]) or Valid(client, idle[1])) or
		Valid(client, ACT_IDLE) or Valid(client, ACT_IDLE_ANGRY)
end


-- An action list: either sequence names (one per player, changing over time) or candidates
-- tried in order - a list of sequence names, a sequence name or an activity - the first one the
-- model has wins. Returns "sequence", id / "activity", act / nil.
local function Choose(client, action)
	local bNames = true

	for _, value in ipairs(action) do
		if (!isstring(value)) then
			bNames = false

			break
		end
	end

	if (bNames) then
		local sequence = NW.anim.ResolveRotating(client, action, 20)

		return sequence and "sequence" or nil, sequence
	end

	for _, candidate in ipairs(action) do
		if (istable(candidate)) then
			local sequence = NW.anim.ResolveRotating(client, candidate, 20)

			if (sequence) then
				return "sequence", sequence
			end
		elseif (isstring(candidate)) then
			local sequence = Valid(client, candidate)

			if (sequence) then
				return "sequence", sequence
			end
		elseif (isnumber(candidate) and Valid(client, candidate)) then
			return "activity", candidate
		end
	end
end

-- walk / run sets made for four directions: <name> forward, <name>_b back, <name>_l left,
-- <name>_r right; picked from the movement relative to where the player looks
NW.anim.directional = NW.anim.directional or {}

function NW.anim.Directional(client, name)
	local velocity = client:GetVelocity()

	if (velocity:Length2DSqr() < 100) then
		return name
	end

	local diff = math.NormalizeAngle(velocity:Angle().yaw - client:EyeAngles().yaw)
	local suffix = ""

	if (diff > 135 or diff < -135) then
		suffix = "_b"
	elseif (diff > 45) then
		suffix = "_l"
	elseif (diff < -45) then
		suffix = "_r"
	end

	local full = name .. suffix

	return Valid(client, full) and full or name
end

function GM:TranslateActivity(client, act)
	local class = client.nwAnimClass

	if (!class) then
		NW.anim.Refresh(client)

		class = client.nwAnimClass
	end

	local bRaised = client:IsWeaponRaised()

	if (class == "player") then
		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and !bRaised and client:OnGround()) then
			local holdType = weapon.HoldType or weapon:GetHoldType()

			holdType = PLAYER_HOLDTYPE_TRANSLATOR[holdType] or "passive"

			local tree = NW.anim.player[holdType]

			if (tree and tree[act]) then
				if (isstring(tree[act])) then
					client.CalcSeqOverride = LookupCached(client, tree[act])

					return
				end

				return tree[act]
			end
		end

		return self.BaseClass:TranslateActivity(client, act)
	end

	local tree = client.nwAnimTable

	if (!tree) then
		return self.BaseClass:TranslateActivity(client, act)
	end

	if (client:InVehicle()) then
		local action = tree[1]

		if (isvector(tree[2])) then
			client:SetLocalPos(animationFixOffset)
		end

		if (isstring(action)) then
			client.CalcSeqOverride = LookupCached(client, action)

			return
		end

		return action
	end

	local bGrounded = client:OnGround()

	if (bGrounded) then
		client.nwAnimGroundTime = CurTime()
	elseif ((client.nwAnimGroundTime or 0) > CurTime() - 0.18) then
		bGrounded = true
	end

	-- the jump start and the landing frames are ACT_MP_JUMP while still on the ground
	if (act == ACT_MP_JUMP) then
		bGrounded = false
	end

	if (bGrounded) then
		local entry = tree[act]

		if (entry) then
			local action = entry[bRaised and 2 or 1]

			-- directional sets (nw_*_walk -> _b / _l / _r by the way the player moves)
			if (isstring(action) and NW.anim.directional[action]) then
				action = NW.anim.Directional(client, action)
			end

			if (istable(action)) then
				local kind, value = Choose(client, action)

				if (kind == "sequence") then
					client.CalcSeqOverride = value

					return
				end

				action = value or REPAIR_FALLBACK[act]
			end

			if (isstring(action)) then
				client.CalcSeqOverride = LookupCached(client, action)

				return
			end

			return action
		end

		return
	end

	-- in the air: the model's own glide / jump pose; never an activity the model lacks (that
	-- is the T-pose), at worst the standing idle
	local sequence = AirSequence(client, tree, bRaised)

	if (sequence) then
		client.CalcSeqOverride = sequence

		return
	end

	return ACT_MP_JUMP
end

local GESTURE_SLOTS = {
	attack = GESTURE_SLOT_ATTACK_AND_RELOAD,
	reload = GESTURE_SLOT_ATTACK_AND_RELOAD,
	jump = GESTURE_SLOT_JUMP,
	shield = GESTURE_SLOT_CUSTOM,
	flinch = GESTURE_SLOT_FLINCH
}

local gestureMoving = CreateConVar("network_gesture_moving", "0",
	{FCVAR_ARCHIVE, FCVAR_REPLICATED},
	"Проигрывать жесты на ходу (1 — да, если модель это позволяет)")

local ALWAYS = {attack = true, flinch = true}

local function PlayGesture(client, action, kind, tree)

	local bLayered = istable(tree) and tree.bLayered and gestureMoving:GetBool()

	if (!bLayered and !ALWAYS[kind or "attack"] and !gestureMoving:GetBool()) then
		local velocity = client:GetVelocity()

		if (velocity.x * velocity.x + velocity.y * velocity.y > 400) then
			return
		end
	end

	if (istable(action)) then
		local index = (client:EntIndex() + math.floor(CurTime() * 2)) % #action + 1

		action = action[index]
	end

	local slot = GESTURE_SLOTS[kind or "attack"] or GESTURE_SLOT_ATTACK_AND_RELOAD

	if (isstring(action)) then
		local sequence = LookupCached(client, action)

		if (sequence and sequence >= 0) then
			client:AddVCDSequenceToGestureSlot(slot, sequence, 0, true)
		end

		return
	end

	client:AnimRestartGesture(slot, action, true)
end

function GM:DoAnimationEvent(client, event, data)

	if (client.IsInSequence and client:IsInSequence()) then
		return ACT_INVALID
	end

	if (client.nwAnimClass == "player") then
		return self.BaseClass:DoAnimationEvent(client, event, data)
	end

	local tree = client.nwAnimTable or {}

	if (event == PLAYERANIMEVENT_ATTACK_PRIMARY) then
		PlayGesture(client, tree.attack or ACT_GESTURE_RANGE_ATTACK_SMG1,
			"attack", tree)

		return ACT_VM_PRIMARYATTACK
	end

	if (event == PLAYERANIMEVENT_ATTACK_SECONDARY) then
		PlayGesture(client, tree.attack or ACT_GESTURE_RANGE_ATTACK_SMG1,
			"attack", tree)

		return ACT_VM_SECONDARYATTACK
	end

	if (event == PLAYERANIMEVENT_RELOAD) then

		local action = tree.reload or ACT_GESTURE_RELOAD_SMG1

		local hold = client.nwAnimHoldType

		if (tree.reloadSMG and (hold == "smg" or hold == "pistol" or
			hold == "revolver")) then
			action = tree.reloadSMG
		end

		if (client:Crouching() and tree.reloadLow) then
			action = tree.reloadLow
		end

		PlayGesture(client, action, "reload", tree)

		return ACT_INVALID
	end

	if (event == PLAYERANIMEVENT_JUMP) then

		if (tree.jump) then
			PlayGesture(client, tree.jump, "jump", tree)
		end

		client.m_bJumping = true
		client.m_bFirstJumpFrame = true
		client.m_flJumpStartTime = CurTime()

		client:AnimRestartMainSequence()

		return ACT_INVALID
	end

	if (event == PLAYERANIMEVENT_CANCEL_RELOAD) then
		client:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)

		return ACT_INVALID
	end
end

do
	local vectorAngle = FindMetaTable("Vector").Angle
	local normalizeAngle = math.NormalizeAngle

	function GM:CalcMainActivity(client, velocity)
		client:SetPoseParameter("move_yaw",
			normalizeAngle(vectorAngle(velocity)[2] - client:EyeAngles()[2]))

		local forced = client.GetForcedSequence and client:GetForcedSequence()

		if (forced) then
			client.CalcIdeal = ACT_MP_STAND_IDLE
			client.CalcSeqOverride = forced

			local since = CurTime() - (client.nwSeqBlendStart or 0)

			if (since < 0.15) then
				client:SetPlaybackRate(math.max(since / 0.15, 0.15))
			elseif (client:GetPlaybackRate() != 1) then
				client:SetPlaybackRate(1)
			end

			return client.CalcIdeal, forced
		end

		if (client.nwSeqBlendStart) then
			client.nwSeqBlendStart = nil

			client:SetPlaybackRate(1)
		end

		client.CalcSeqOverride = -1
		client.CalcIdeal = ACT_MP_STAND_IDLE

		local BaseClass = self.BaseClass

		if (BaseClass:HandlePlayerNoClipping(client, velocity) or
			BaseClass:HandlePlayerDriving(client) or
			BaseClass:HandlePlayerVaulting(client, velocity) or
			BaseClass:HandlePlayerJumping(client, velocity) or
			BaseClass:HandlePlayerSwimming(client, velocity) or
			BaseClass:HandlePlayerDucking(client, velocity)) then
		else
			local length = velocity:Length2DSqr()

			local bMoving = client.nwAnimMoving and length > 100 or length > 900

			client.nwAnimMoving = bMoving

			if (length > 22500) then
				client.CalcIdeal = ACT_MP_RUN
			elseif (bMoving) then
				client.CalcIdeal = ACT_MP_WALK
			end
		end

		if (client.CalcIdeal == ACT_MP_CROUCHWALK or
			client.CalcIdeal == ACT_MP_CROUCH_IDLE) then
			local length = velocity:Length2DSqr()
			local bMoving = client.nwAnimCrouchMoving and length > 36 or length > 400

			client.nwAnimCrouchMoving = bMoving
			client.CalcIdeal = bMoving and ACT_MP_CROUCHWALK or ACT_MP_CROUCH_IDLE
		end

		client.m_bWasOnGround = client:OnGround()
		client.m_bWasNoclipping = client:GetMoveType() == MOVETYPE_NOCLIP and !client:InVehicle()

		local translated = self:TranslateActivity(client, client.CalcIdeal)

		-- safety net against the T-pose: whatever was chosen must exist on this model (the jump
		-- start / landing frames, a missing activity, a sequence name the model lacks)
		if (client.nwAnimClass and client.nwAnimClass != "player") then
			local override = client.CalcSeqOverride or -1

			if (override <= 0) then
				local act = isnumber(translated) and translated or client.CalcIdeal
				local sequence = client:SelectWeightedSequence(act)

				if (!sequence or sequence <= 0) then
					local tree = client.nwAnimTable or {}

					client.CalcSeqOverride = (!client:OnGround() or client.CalcIdeal == ACT_MP_JUMP) and
						AirSequence(client, tree, client:IsWeaponRaised()) or
						FallbackIdle(client, tree, client:IsWeaponRaised()) or -1
				end
			end
		end

		return client.CalcIdeal, client.CalcSeqOverride or -1
	end
end

-- own walk / run sequences: playback speed from the player's speed (NW.anim.groundSpeed)
function GM:UpdateAnimation(client, velocity, maxSeqGroundSpeed)
	self.BaseClass.UpdateAnimation(self, client, velocity, maxSeqGroundSpeed)

	local speeds = NW.anim.groundSpeed

	if (!speeds) then
		return
	end

	local name = client:GetSequenceName(client:GetSequence())
	local ground = name and speeds[name]

	-- the walk / run cycle follows the speed, smoothed (the local player's velocity jumps from
	-- frame to frame with prediction, a raw rate makes the steps stutter)
	if (ground and client:OnGround()) then
		local wanted = math.Clamp(velocity:Length2D() / ground, 0.4, 2.6)

		client.nwRate = Lerp(math.Clamp(FrameTime() * 6, 0, 1), client.nwRate or wanted, wanted)
		client:SetPlaybackRate(client.nwRate)
	else
		client.nwRate = nil
	end
end

hook.Add("NWWeaponRaised", "nwAnim", function(client)
	local previous = client.nwAnimHoldType

	NW.anim.Refresh(client, client:GetVehicle())

	if (client.IsInSequence and client:IsInSequence()) then
		return
	end

	client:AnimRestartMainSequence()
end)

hook.Add("Think", "nwAnimModelWatch", function()

	if ((NW.anim.nextWatch or 0) > CurTime()) then
		return
	end

	NW.anim.nextWatch = CurTime() + 0.1

	for _, client in ipairs(player.GetAll()) do
		if (client.nwAnimModel != client:GetModel()) then
			NW.anim.Refresh(client, client:GetVehicle())

			continue
		end

		-- safety toggled: switch the stance at once (clients learn it from the networked flag)
		local bRaised = client:IsWeaponRaised()

		if (client.nwAnimRaised != bRaised) then
			client.nwAnimRaised = bRaised
			client:AnimRestartMainSequence()
		end

		local weapon = client:GetActiveWeapon()
		local class = IsValid(weapon) and weapon:GetClass() or ""
		local rawHold = IsValid(weapon) and (weapon.HoldType or weapon:GetHoldType()) or ""

		if (client.nwAnimWeapon != class or client.nwAnimRawHold != rawHold) then
			client.nwAnimRawHold = rawHold

			UpdateHoldType(client, weapon)
			UpdateAnimTable(client, client:GetVehicle())
		end
	end
end)

if (SERVER) then
	hook.Add("PlayerSpawn", "nwAnim", function(client)
		timer.Simple(0.1, function()
			if (IsValid(client)) then
				NW.anim.Refresh(client)
			end
		end)
	end)
end

if (CLIENT) then
	hook.Add("UpdateAnimation", "nwSmoothTurn", function(client)
		if (client:InVehicle()) then

			client:SetRenderAngles(client:GetAngles())

			return
		end

		-- in a pose (sh_acts.lua) the body keeps the pose's direction, the view looks around freely
		if (client.GetAct and client:GetAct()) then
			local yaw = client:GetNW2Float("nwActYaw", client:EyeAngles().yaw)

			client.nwSmoothYaw = yaw
			client:SetRenderAngles(Angle(0, yaw, 0))

			return
		end

		local target = client:EyeAngles().yaw
		local current = client.nwSmoothYaw or target

		local speed = client:GetVelocity():Length2D() > 24 and 720 or 320

		current = math.ApproachAngle(current, target,
			speed * FrameTime() * math.min(3,
				math.abs(math.AngleDifference(target, current)) / 45 + 0.6))

		client.nwSmoothYaw = current
		client:SetRenderAngles(Angle(0, current, 0))

		-- safety switched: the old stance stays on a layer and fades out, so the weapon comes
		-- up (or goes down) instead of snapping
		local bNowRaised = client:IsWeaponRaised()

		if (client.nwFadeRaised != nil and client.nwFadeRaised != bNowRaised and client.nwFadeSeq
			and client.nwFadeSeq >= 0) then
			client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_VCD, client.nwFadeSeq, client.nwFadeCycle or 0, false)
			client.nwFadeStart = CurTime()
		end

		client.nwFadeRaised = bNowRaised

		if (client.nwFadeStart) then
			local t = (CurTime() - client.nwFadeStart) / 0.42

			if (t >= 1) then
				client:AnimResetGestureSlot(GESTURE_SLOT_VCD)
				client.nwFadeStart = nil
			else
				local ease = 1 - t * t * (3 - 2 * t)

				client:AnimSetGestureWeight(GESTURE_SLOT_VCD, ease)
			end
		end

		client.nwFadeSeq = client:GetSequence()
		client.nwFadeCycle = client:GetCycle()

		-- NPC-style models look and aim with pose parameters the player animation state does
		-- not drive: the head follows the view, the weapon follows it when raised
		if (client.nwAnimClass and client.nwAnimClass != "player") then
			local eye = client:EyeAngles()
			local yaw = math.NormalizeAngle(eye.yaw - current)
			local pitch = math.NormalizeAngle(eye.pitch)
			local bRaised = client:IsWeaponRaised()

			client:SetPoseParameter("head_yaw", math.Clamp(yaw, -60, 60))
			client:SetPoseParameter("head_pitch", math.Clamp(pitch, -40, 40))
			client:SetPoseParameter("aim_yaw", bRaised and math.Clamp(yaw, -60, 60) or 0)
			client:SetPoseParameter("aim_pitch", bRaised and math.Clamp(pitch, -60, 60) or 0)
		end
	end)
end

hook.Add("DoPlayerDeath", "nwAnimDeath", function(client)
	local tree = client.nwAnimTable

	if (!istable(tree) or !tree.death) then
		return
	end

	local list = istable(tree.death) and tree.death or {tree.death}
	local name = list[math.random(#list)]
	local sequence = client:LookupSequence(tostring(name))

	if (sequence and sequence > 0) then
		client:SetCycle(0)
		client:SetPlaybackRate(1)
		client:ResetSequence(sequence)
	end
end)

if (CLIENT) then
	concommand.Add("nw_gesture_test", function(client, _, arguments)
		local name = arguments[1]

		if (!name) then
			print("[nw_gesture_test] Укажите имя кадра, например: " ..
				"nw_gesture_test act_reload_low")

			return
		end

		local sequence = client:LookupSequence(name)

		if (!sequence or sequence < 1) then
			print("[nw_gesture_test] На модели нет кадра «" .. name .. "».")

			return
		end

		client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD,
			sequence, 0, true)

		print("[nw_gesture_test] Играю «" .. name .. "». Идите и смотрите " ..
			"на ноги: шагают — кадр накладывается, замерли — заменяет.")
	end)
end

-- no hand-to-ear gesture while typing in the chat
function GM:GrabEarAnimation(client)
	client.ChatGestureWeight = 0
end
