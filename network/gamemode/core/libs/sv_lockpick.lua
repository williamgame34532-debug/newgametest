util.AddNetworkString("nwLockpickStart")
util.AddNetworkString("nwLockpickTry")
util.AddNetworkString("nwLockpickFeedback")
util.AddNetworkString("nwLockpickTurn")
util.AddNetworkString("nwLockpickStage")
util.AddNetworkString("nwLockpickCancel")
util.AddNetworkString("nwLockpickEnd")

local LP = NETWORK.lockpick

LP.sessions = LP.sessions or {}

LP.RESULT_CANCEL = 0
LP.RESULT_SUCCESS = 1
LP.RESULT_BROKEN = 2

local function CountPicks(client)
	local total = 0

	for _, item in pairs(NETWORK.inventory.GetState(client).items or {}) do
		if (istable(item) and item.id == "lockpick") then
			total = total + (item.amount or 1)
		end
	end

	return total
end

local function IsDoorLocked(door)
	local data = NETWORK.door.GetData(door)

	if (NETWORK.door.IsPicked(door)) then
		return false
	end

	return NETWORK.door.IsLocked(data) or door.nwMapLocked == true or
		door:GetInternalVariable("m_bLocked") == true
end

local function CombineTarget(lock)
	if (!IsValid(lock) or !lock:GetLocked()) then
		return nil, "lockpickNotLocked"
	end

	if (!LP.bCombineLocks) then
		return nil, "lockpickCombine"
	end

	return "combine", lock, "extreme"
end

function LP.Resolve(client, entity)
	if (!IsValid(entity)) then
		return nil, "lockpickNoTarget"
	end

	local class = entity:GetClass()

	if (class == "nw_padlock") then
		if (!entity:GetLocked()) then
			return nil, "lockpickNotLocked"
		end

		return "padlock", entity, "easy"
	end

	if (class == "nw_lock") then
		return CombineTarget(entity)
	end

	if (NETWORK.door.IsDoor(entity)) then
		local seal, padlock = NETWORK.barricade and NETWORK.barricade.IsDoorSealed(entity)

		if (seal == "boarded") then
			return nil, "lockpickBoarded"
		end

		if (seal == "padlock" and IsValid(padlock)) then
			return "padlock", padlock, "easy"
		end

		for _, leaf in ipairs(NETWORK.door.GetLeaves(entity)) do
			if (IsValid(leaf.nwLock) and leaf.nwLock:GetLocked()) then
				return CombineTarget(leaf.nwLock)
			end
		end

		if (!IsDoorLocked(entity)) then
			return nil, "lockpickNotLocked"
		end

		local data = NETWORK.door.GetData(entity)

		return "door", entity, (data and data.type == "faction") and "hard" or "medium"
	end

	local answer = hook.Run("NetworkLockpickContainer", client, entity)

	if (answer) then
		return "container", entity, (isstring(answer) and LP.difficulties[answer]) and
			answer or "medium"
	end

	return nil, "lockpickNoTarget"
end

local function IsCandidate(entity)
	local class = entity:GetClass()

	return class == "nw_padlock" or class == "nw_lock" or NETWORK.door.IsDoor(entity) or
		entity.nwLockpickable == true or string.find(class, "container", 1, true) != nil or
		string.find(class, "stash", 1, true) != nil or string.find(class, "cache", 1, true) != nil
end

function LP.FindTarget(client)
	local entity = NETWORK.util.FindLookedAt(client, LP.range, IsCandidate)

	if (!IsValid(entity)) then
		return nil, "lockpickNoTarget"
	end

	return LP.Resolve(client, entity)
end

local function Send(client, name, callback)
	net.Start(name)

	if (callback) then
		callback()
	end

	net.Send(client)
end

function LP.End(client, result, key, tone)
	local session = LP.sessions[client]

	LP.sessions[client] = nil

	if (!IsValid(client) or !session) then
		return
	end

	Send(client, "nwLockpickEnd", function()
		net.WriteUInt(session.token, 32)
		net.WriteUInt(result or LP.RESULT_CANCEL, 2)
	end)

	if (key) then
		NETWORK.notice.Send(client, key, tone or "warn")
	end
end

function LP.Start(client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter() or
		IsValid(client.nwRagdollEntity)) then
		return false
	end

	if (LP.sessions[client] or client.nwBarricadeTask) then
		return false
	end

	if (CountPicks(client) < 1) then
		return false
	end

	local kind, target, difficultyID = LP.FindTarget(client)

	if (!kind) then
		NETWORK.notice.Send(client, target or "lockpickNoTarget", "warn")

		return false
	end

	local difficulty = LP.GetDifficulty(difficultyID)
	local token = math.random(1, 2147483646)

	LP.sessions[client] = {
		kind = kind,
		target = target,
		difficultyID = difficultyID,
		difficulty = difficulty,
		token = token,
		sweet = math.Rand(LP.sweetMin, LP.sweetMax),
		stage = 1,
		wear = 0,
		started = CurTime(),
		nextTry = 0
	}

	Send(client, "nwLockpickStart", function()
		net.WriteEntity(target)
		net.WriteUInt(token, 32)
		net.WriteUInt(difficulty.stages, 3)
		net.WriteString(difficulty.name)
	end)

	NETWORK.chat.Send(client, "me", L(kind == "padlock" and "lockpickMePadlock" or "lockpickMe"))

	target:EmitSound("physics/metal/weapon_impact_soft" .. math.random(1, 3) .. ".wav", 55, 130)

	return true
end

local function ReadSession(client)
	local token = net.ReadUInt(32)
	local session = LP.sessions[client]

	if (!session or session.token != token) then
		return
	end

	return session
end

local function WearFor(client, session, fraction)
	local agility = NETWORK.skills and NETWORK.skills.Get and
		NETWORK.skills.Get(client, "agility") or 0
	local care = math.Clamp(1 - agility * 0.035, 0.65, 1)

	return (0.1 + (1 - fraction) * 0.22) * session.difficulty.wear * care
end

local function Break(client, session)
	NETWORK.inventory.Take(client, "lockpick", 1)

	if (IsValid(session.target)) then
		session.target:EmitSound("physics/metal/metal_solid_impact_bullet" ..
			math.random(1, 4) .. ".wav", 60, 150)
	end

	LP.End(client, LP.RESULT_BROKEN, CountPicks(client) > 0 and "lockpickBroken" or
		"lockpickBrokenLast", "warn")
end

net.Receive("nwLockpickTry", function(_, client)
	local session = ReadSession(client)
	local angle = math.Clamp(net.ReadFloat() or 0, 0, 180)

	if (!session or session.nextTry > CurTime()) then
		return
	end

	session.nextTry = CurTime() + LP.tryInterval * 0.75

	local fraction = LP.Fraction(angle, session.sweet, session.difficulty)

	session.lastTry = {time = CurTime(), fraction = fraction, stage = session.stage}

	if (fraction < 1) then
		session.wear = session.wear + WearFor(client, session, fraction)

		local chance = 0.04 * (1 - fraction) * session.difficulty.wear

		if (session.wear >= 1 or math.Rand(0, 1) < chance) then
			return Break(client, session)
		end
	end

	Send(client, "nwLockpickFeedback", function()
		net.WriteUInt(session.token, 32)
		net.WriteFloat(fraction)
		net.WriteFloat(math.Clamp(session.wear, 0, 1))
	end)
end)

local function Succeed(client, session)
	local kind, target = session.kind, session.target

	LP.End(client, LP.RESULT_SUCCESS, "lockpickSuccess", "good")

	if (kind == "padlock") then
		target:SetState(false)

		NETWORK.padlock.NotifyCharacter(target:GetOwnerChar(), "lockpickOwner", "warn")

		local door = target:GetDoor()

		if (IsValid(door)) then
			hook.Run("NetworkLockOpened", client, door, "отмычка, навесной замок")
		end
	elseif (kind == "door") then
		NETWORK.door.Pick(client, target)

		local data = NETWORK.door.GetData(target)

		for steamID in pairs(NETWORK.door.GetOwners(data)) do
			for _, other in ipairs(player.GetAll()) do
				if (other != client and other:SteamID64() == steamID) then
					NETWORK.notice.Send(other, "lockpickOwner", "warn")
				end
			end
		end
	elseif (kind == "combine") then
		target.nwHacked = true
		target:Apply(false)

		hook.Run("NetworkLockOpened", client, IsValid(target.door) and target.door or target,
			"отмычка, замок Альянса")
	end

	if (NETWORK.log and NETWORK.log.Add and kind == "container") then
		NETWORK.log.Add("lock", string.format("%s вскрыл отмычкой %s",
			NETWORK.log.Name(client), target:GetClass()), target:GetPos())
	end

	if (NETWORK.skills and NETWORK.skills.AddXP) then
		NETWORK.skills.AddXP(client, "agility", 5 * session.difficulty.stages)
	end

	hook.Run("NetworkLockpicked", client, target, kind)
end

net.Receive("nwLockpickTurn", function(_, client)
	local session = ReadSession(client)

	if (!session) then
		return
	end

	local try = session.lastTry

	if (!try or try.fraction < 1 or try.stage != session.stage or
		CurTime() - try.time < LP.turnTime * 0.8) then
		return
	end

	session.lastTry = nil

	if (session.stage >= session.difficulty.stages) then
		if (CurTime() - session.started < session.difficulty.minTime) then
			return LP.End(client, LP.RESULT_CANCEL, "lockpickTooFast", "warn")
		end

		return Succeed(client, session)
	end

	session.stage = session.stage + 1
	session.sweet = math.Rand(LP.sweetMin, LP.sweetMax)

	if (IsValid(session.target)) then
		session.target:EmitSound("doors/door_latch1.wav", 50, 150, 0.5)
	end

	Send(client, "nwLockpickStage", function()
		net.WriteUInt(session.token, 32)
		net.WriteUInt(session.stage - 1, 3)
	end)
end)

net.Receive("nwLockpickCancel", function(_, client)
	local session = ReadSession(client)

	if (session) then
		LP.End(client, LP.RESULT_CANCEL)
	end
end)

timer.Create("nwLockpickWatch", 0.25, 0, function()
	for client, session in pairs(LP.sessions) do
		if (!IsValid(client)) then
			LP.sessions[client] = nil

			continue
		end

		local target = session.target
		local bBroken = !client:Alive() or IsValid(client.nwRagdollEntity) or
			!IsValid(target) or CurTime() - session.started > LP.maxTime or
			client:GetShootPos():Distance(target:NearestPoint(client:GetShootPos())) > LP.cancelRange

		if (!bBroken) then
			if (session.kind == "padlock" and !target:GetLocked()) then
				bBroken = true
			elseif (session.kind == "door" and !IsDoorLocked(target)) then
				bBroken = true
			elseif (session.kind == "combine" and !target:GetLocked()) then
				bBroken = true
			end
		end

		if (bBroken) then
			LP.End(client, LP.RESULT_CANCEL, "lockpickInterrupted", "warn")
		end
	end
end)

hook.Add("PlayerDeath", "nwLockpick", function(client)
	LP.End(client, LP.RESULT_CANCEL)
end)

hook.Add("PlayerDisconnected", "nwLockpick", function(client)
	LP.sessions[client] = nil
end)
