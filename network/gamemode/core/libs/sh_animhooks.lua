local HOLDTYPE_TRANSLATOR = {
	[""] = "normal",
	physgun = "smg",
	ar2 = "smg",
	crossbow = "shotgun",
	rpg = "shotgun",
	slam = "normal",
	grenade = "grenade",
	fist = "normal",
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

		local special = NETWORK.anim.weaponHold and
			NETWORK.anim.weaponHold[weapon:GetClass()]
		local base = special and NETWORK.anim[client.nwAnimClass or ""]

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
	local base = NETWORK.anim[client.nwAnimClass or "citizen_male"] or {}

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

		local sequenced = NETWORK.anim.GetSequenceTree and
			NETWORK.anim.GetSequenceTree(client, client.nwAnimHoldType or "normal",
				base)

		if (sequenced) then
			client.nwAnimTable = sequenced
		end
	end

	if (NETWORK.shield and NETWORK.shield.IsActive(client) and
		istable(base.shield)) then
		client.nwAnimTable = base.shield
	end

	local tree = client.nwAnimTable

	client.nwAnimGlide = (istable(tree) and tree.glide) or base.glide
end

function NETWORK.anim.Refresh(client, vehicle)
	client.nwAnimModel = client:GetModel()
	client.nwAnimClass = NETWORK.anim.GetModelClass(client.nwAnimModel)

	UpdateHoldType(client)
	UpdateAnimTable(client, vehicle)
end

function GM:PlayerModelChanged(client, model)
	client.nwAnimClass = NETWORK.anim.GetModelClass(model)

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

function GM:TranslateActivity(client, act)
	local class = client.nwAnimClass

	if (!class) then
		NETWORK.anim.Refresh(client)

		class = client.nwAnimClass
	end

	local bRaised = client:IsWeaponRaised()

	if (class == "player") then
		local weapon = client:GetActiveWeapon()

		if (IsValid(weapon) and !bRaised and client:OnGround()) then
			local holdType = weapon.HoldType or weapon:GetHoldType()

			holdType = PLAYER_HOLDTYPE_TRANSLATOR[holdType] or "passive"

			local tree = NETWORK.anim.player[holdType]

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

	if (bGrounded) then
		local entry = tree[act]

		if (entry) then
			local action = entry[bRaised and 2 or 1]

			if (isstring(action)) then
				client.CalcSeqOverride = LookupCached(client, action)

				return
			end

			return action
		end

		return
	end

	local glide = client.nwAnimGlide

	if (glide) then
		if (isstring(glide)) then
			client.CalcSeqOverride = LookupCached(client, glide)

			return
		end

		return glide
	end

	for _, name in ipairs({"jump", "fall", "glide", "swim"}) do
		local sequence = LookupCached(client, name)

		if (sequence and sequence > 0) then
			client.nwAnimGlide = name
			client.CalcSeqOverride = sequence

			return
		end
	end

	local idle = tree[ACT_MP_STAND_IDLE]
	local action = idle and idle[bRaised and 2 or 1]

	if (isstring(action)) then
		client.CalcSeqOverride = LookupCached(client, action)

		return
	end

	return action or ACT_MP_JUMP
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

	local bMine = CLIENT and client == LocalPlayer() and NETWORK.legs and NETWORK.legs.Gesture

	if (isstring(action)) then
		local sequence = LookupCached(client, action)

		if (sequence and sequence >= 0) then
			client:AddVCDSequenceToGestureSlot(slot, sequence, 0, true)

			if (bMine) then
				NETWORK.legs:Gesture(slot, action)
			end
		end

		return
	end

	client:AnimRestartGesture(slot, action, true)

	if (bMine) then
		NETWORK.legs:GestureActivity(slot, action)
	end
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

		local forced = client:GetForcedSequence()

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

		local mood = NETWORK.act and NETWORK.act.GetMoodSequence(client, velocity)

		if (mood) then
			client.CalcIdeal = mood.activity
			client.CalcSeqOverride = mood.sequence

			return client.CalcIdeal, mood.sequence
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

		self:TranslateActivity(client, client.CalcIdeal)

		return client.CalcIdeal, client.CalcSeqOverride or -1
	end
end

hook.Add("NetworkWeaponRaised", "nwAnim", function(client)
	local previous = client.nwAnimHoldType

	NETWORK.anim.Refresh(client, client:GetVehicle())

	if (client.IsInSequence and client:IsInSequence()) then
		return
	end

	if (client.nwAnimHoldType != previous) then
		client:AnimRestartMainSequence()
	end
end)

hook.Add("Think", "nwAnimModelWatch", function()

	if (!NETWORK.util.Throttle("anim.watch", 0.1)) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (client.nwAnimModel != client:GetModel()) then
			NETWORK.anim.Refresh(client, client:GetVehicle())

			continue
		end

		local weapon = client:GetActiveWeapon()
		local class = IsValid(weapon) and weapon:GetClass() or ""
		local rawHold = IsValid(weapon) and (weapon.HoldType or weapon:GetHoldType()) or ""

		local bShield = NETWORK.shield and NETWORK.shield.IsActive(client) or false

		if (client.nwAnimShield != bShield) then
			client.nwAnimShield = bShield

			UpdateAnimTable(client, client:GetVehicle())

			if (!client:IsInSequence()) then
				client:AnimRestartMainSequence()
			end
		end

		if (client.nwAnimWeapon != class or client.nwAnimRawHold != rawHold) then
			client.nwAnimRawHold = rawHold

			UpdateHoldType(client, weapon)
			UpdateAnimTable(client, client:GetVehicle())
		end
	end
end)

if (SERVER) then
	hook.Add("NetworkCharacterLoaded", "nwAnim", function(client)
		timer.Simple(0.1, function()
			if (IsValid(client)) then
				NETWORK.anim.Refresh(client)
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

		local target = client:EyeAngles().yaw
		local current = client.nwSmoothYaw or target

		local speed = client:GetVelocity():Length2D() > 24 and 720 or 320

		current = math.ApproachAngle(current, target,
			speed * FrameTime() * math.min(3,
				math.abs(math.AngleDifference(target, current)) / 45 + 0.6))

		client.nwSmoothYaw = current
		client:SetRenderAngles(Angle(0, current, 0))
	end)
end

hook.Add("NetworkShieldToggled", "nwAnimShieldGesture", function(client, bUp)
	local tree = client.nwAnimTable

	if (!istable(tree)) then
		return
	end

	local action = bUp and tree.shieldUp or tree.shieldDown

	if (action) then
		PlayGesture(client, action, "shield", tree)
	end
end)

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
