local P = NETWORK.padlock
local B = NETWORK.barricade

P.useRange = 110

function P.NewCode()
	return string.format("%04d%04d", math.random(0, 9999), math.random(0, 9999))
end

function P.Serial(code)
	return string.sub(tostring(code or ""), -4)
end

function P.FindKey(client, code)
	if (!IsValid(client) or !code or code == "") then
		return
	end

	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({"items", "storage", "equipped"}) do
		for _, item in pairs(state[list] or {}) do
			if (istable(item) and item.id == "padlock_key" and istable(item.data) and
				item.data.code == code) then
				return item
			end
		end
	end
end

function P.HasKey(client, code)
	return P.FindKey(client, code) != nil
end

function P.NotifyCharacter(charID, key, tone, ...)
	if (!charID or charID == 0) then
		return
	end

	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and client:GetCharacterID() == charID) then
			NETWORK.notice.Send(client, key, tone or "warn", ...)

			return client
		end
	end
end

local function TraceDoor(client)
	local start = client:GetShootPos()
	local trace = util.TraceLine({
		start = start,
		endpos = start + client:GetAimVector() * P.range,
		filter = client
	})

	local door = trace.Entity

	if (IsValid(door) and door:GetClass() == "nw_padlock") then
		return nil, trace, door
	end

	if (!NETWORK.door.IsDoor(door)) then
		return nil, trace
	end

	return door, trace
end

local function TakePadlockItem(client, code)
	local state = NETWORK.inventory.GetState(client)

	for index, item in pairs(state.items or {}) do
		if (!istable(item) or item.id != "padlock") then
			continue
		end

		local itemCode = istable(item.data) and item.data.code or nil

		if (itemCode != code) then
			continue
		end

		if ((item.amount or 1) > 1) then
			item.amount = item.amount - 1
		else
			NETWORK.inventory.Put(state, "items", index, nil, nil)
		end

		NETWORK.inventory.Sync(client)

		return true
	end

	return false
end

local function GiveOrDrop(client, id, data)
	if (NETWORK.inventory.Give(client, id, 1, data)) then
		return true
	end

	NETWORK.item.Spawn(id, client:GetPos() + client:GetForward() * 24 + Vector(0, 0, 16),
		nil, 1, data)

	return false
end

local function FinishPlace(client, task)
	local door = task.door

	if (!IsValid(door)) then
		return NETWORK.notice.Send(client, "barricadeGone", "warn")
	end

	if (IsValid(B.GetPadlock(door))) then
		return NETWORK.notice.Send(client, "padlockAlready", "warn")
	end

	if (NETWORK.door.IsOpen(door)) then
		return NETWORK.notice.Send(client, "padlockDoorOpen", "warn")
	end

	if (!TakePadlockItem(client, task.code)) then
		return NETWORK.notice.Send(client, "padlockNoItem", "warn")
	end

	local padlock = ents.Create("nw_padlock")

	if (!IsValid(padlock)) then
		GiveOrDrop(client, "padlock", task.code and {code = task.code} or nil)

		return
	end

	padlock:SetPos(door:LocalToWorld(task.localPos))
	padlock:Spawn()
	padlock:Activate()

	if (!padlock:Attach(door, door:LocalToWorld(task.localPos),
		door:LocalToWorldAngles(task.localAngles))) then
		GiveOrDrop(client, "padlock", task.code and {code = task.code} or nil)

		return
	end

	local bNewCode = task.code == nil

	padlock.code = task.code or P.NewCode()
	padlock.nwOwner = client

	padlock:SetOwnerChar(client:GetCharacterID() or 0)
	padlock:SetState(true)

	client:SetAnimation(PLAYER_ATTACK1)

	if (bNewCode) then
		local data = NETWORK.door.GetData(door)
		local title = data and NETWORK.door.GetTitle(data) or ""

		GiveOrDrop(client, "padlock_key", {
			code = padlock.code,
			label = title != "" and title or L("padlockKeyDefault"),
			serial = P.Serial(padlock.code)
		})

		NETWORK.notice.Send(client, "padlockPlacedKey", "good", P.Serial(padlock.code))
	else
		NETWORK.notice.Send(client, "padlockPlaced", "good")
	end

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("lock", string.format("%s повесил навесной замок №%s",
			NETWORK.log.Name(client), P.Serial(padlock.code)), door:GetPos())
	end
end

function P.BeginPlace(client, item)
	if (!B.CanUse(client) or client.nwBarricadeTask) then
		return false
	end

	local door, trace, hitPadlock = TraceDoor(client)

	if (IsValid(hitPadlock)) then
		NETWORK.notice.Send(client, "padlockAlready", "warn")

		return false
	end

	if (!door) then
		NETWORK.notice.Send(client, "padlockNoDoor", "warn")

		return false
	end

	if (IsValid(B.GetPadlock(door))) then
		NETWORK.notice.Send(client, "padlockAlready", "warn")

		return false
	end

	for _, leaf in ipairs(B.GetLeaves(door)) do
		if (IsValid(leaf.nwLock)) then
			NETWORK.notice.Send(client, "padlockCombine", "warn")

			return false
		end
	end

	if (NETWORK.door.IsOpen(door)) then
		NETWORK.notice.Send(client, "padlockDoorOpen", "warn")

		return false
	end

	local code = istable(item) and istable(item.data) and item.data.code or nil
	local position, angles = P.ComputePosition(door, trace.HitPos, trace.HitNormal)

	B.StartTask(client, {
		door = door,
		bDoor = true,
		code = code,
		localPos = door:WorldToLocal(position),
		localAngles = door:WorldToLocalAngles(angles),
		OnFinish = FinishPlace,
		Check = function(_, task)
			local current = TraceDoor(client)

			return IsValid(current) and IsValid(task.door) and
				(current == task.door or table.HasValue(B.GetLeaves(task.door), current))
		end
	}, "padlockProgress", P.placeTime)

	NETWORK.chat.Send(client, "me", L("padlockMe"))

	client:EmitSound("physics/metal/chain_impact_soft" .. math.random(1, 3) .. ".wav", 60)

	return true
end

function P.Use(client, padlock)
	if (!IsValid(client) or !client:IsPlayer() or !client:HasCharacter()) then
		return
	end

	if ((client.nwNextPadlockUse or 0) > CurTime()) then
		return
	end

	client.nwNextPadlockUse = CurTime() + 0.8

	if (client:GetShootPos():Distance(padlock:GetPos()) > P.useRange) then
		return
	end

	local bKey = P.HasKey(client, padlock.code) or
		(client:IsAdmin() and client:KeyDown(IN_SPEED))

	if (!bKey) then
		padlock:EmitSound("physics/metal/chain_impact_soft" .. math.random(1, 3) .. ".wav",
			60, 110)

		return NETWORK.notice.Send(client, padlock:GetLocked() and "padlockNoKey" or
			"padlockNoKeyOpen", "warn")
	end

	if (!padlock:GetLocked() and client:KeyDown(IN_DUCK)) then
		local code = padlock.code

		padlock.bRemoving = true
		padlock:EmitSound("physics/metal/chain_impact_hard" .. math.random(1, 3) .. ".wav", 60)
		padlock:Remove()

		GiveOrDrop(client, "padlock", {code = code})

		return NETWORK.notice.Send(client, "padlockRemoved", "good")
	end

	local bLock = !padlock:GetLocked()

	padlock:SetState(bLock)

	client:SetAnimation(PLAYER_ATTACK1)

	NETWORK.notice.Send(client, bLock and "padlockLocked" or "padlockUnlocked",
		bLock and "info" or "good")
end

function P.TryKey(client, door)
	local padlock = B.GetPadlock(door)

	if (!IsValid(padlock) or !P.HasKey(client, padlock.code)) then
		return false
	end

	P.Use(client, padlock)

	return true
end

function P.OnBroken(padlock, attacker)
	local door = padlock:GetDoor()

	P.NotifyCharacter(padlock:GetOwnerChar(), "padlockBrokenOwner", "warn")

	if (NETWORK.log and NETWORK.log.Add) then
		NETWORK.log.Add("lock", string.format("%s сломал навесной замок №%s",
			NETWORK.log.Name(attacker), P.Serial(padlock.code)),
			IsValid(door) and door:GetPos() or padlock:GetPos())
	end

	if (IsValid(attacker) and attacker:IsPlayer() and IsValid(door)) then
		hook.Run("NetworkLockOpened", attacker, door, "навесной замок сломан")
	end
end
