NETWORK.emp = NETWORK.emp or {}

local E = NETWORK.emp

E.range = 96
E.duration = 20
E.cooldown = 20
E.hitsNeeded = 3
E.missesAllowed = 3

E.terminals = {
	nw_terminal = "empKindCivic",
	nw_cmbterminal = "empKindCmb",
	nw_cwuterminal = "empKindCwu",
	nw_jailterminal = "empKindJail",
	nw_admin_computer = "empKindAdmin",
	nw_council_computer = "empKindCouncil"
}

local function Classify(entity)
	if (!IsValid(entity)) then
		return
	end

	if (entity:IsPlayer()) then
		return (entity:Alive() and entity:HasCharacter() and
			entity:GetNWString("nwClass", "") == "vortslave") and "vortigaunt" or nil
	end

	local class = entity:GetClass()

	if (class == "nw_forcefield") then
		return entity.IsWorking and entity:IsWorking() and "field" or nil
	end

	if (class == "nw_lock") then
		return !entity.nwHacked and "lock" or nil
	end

	if (E.terminals[class]) then
		return !entity:GetNWBool("nwBroken", false) and "terminal" or nil
	end

	if (NETWORK.door.IsDoor(entity)) then
		local data = NETWORK.door.GetData(entity)

		return (data and NETWORK.door.IsLocked(data)) and "door" or nil
	end
end

E.Classify = Classify

function E.GetTarget(client)
	local entity = NETWORK.util.FindLookedAt(client, E.range, function(candidate)
		return Classify(candidate) != nil
	end)

	if (!IsValid(entity)) then
		return
	end

	return entity, Classify(entity)
end

if (CLIENT) then
	return
end

local function Fail(client)
	if (!IsValid(client)) then
		return
	end

	client.nwEmpTarget = nil
	client.nwEmpCooldown = CurTime() + E.cooldown
	client:EmitSound("weapons/stunstick/spark" .. math.random(1, 3) .. ".wav", 60)

	NETWORK.notice.Send(client, "empFailed", "bad")
end

function E.TryHack(client)
	if (!IsValid(client)) then
		return
	end

	if (client.nwEmpTarget and NETWORK.pipe.active[client]) then
		return
	end

	client.nwEmpTarget = nil

	if ((client.nwEmpCooldown or 0) > CurTime()) then
		return NETWORK.notice.Send(client, "empCooldown", "warn")
	end

	local entity, kind = E.GetTarget(client)

	if (!entity) then
		return NETWORK.notice.Send(client, "empNoTarget", "warn")
	end

	client.nwEmpTarget = entity
	client:EmitSound("weapons/stunstick/alyx_stunner1.wav", 60, 90)

	NETWORK.pipe.Start(client, entity, function(hacker, target)
		hacker.nwEmpTarget = nil

		if (!IsValid(target) or hacker:GetPos():Distance(target:GetPos()) > E.range + 60) then
			return Fail(hacker)
		end

		local weapon = hacker:GetActiveWeapon()

		if (!IsValid(weapon) or weapon:GetClass() != "weapon_nwemp") then
			return Fail(hacker)
		end

		local current = Classify(target)

		if (!current) then
			hacker.nwEmpTarget = nil

			return NETWORK.notice.Send(hacker, "empNoTarget", "warn")
		end

		E.Apply(hacker, target, current)
		NETWORK.notice.Send(hacker, "empSuccess", "good")
	end, function(hacker)
		Fail(hacker)
	end, "emp")
end

local function ZoneName(entity)
	local zone = NETWORK.zone and NETWORK.zone.At(entity:GetPos())

	return zone and zone.name or L("owUnknownZone")
end

local function Dispatch(key, entity, ...)
	if (NETWORK.dispatch and NETWORK.dispatch.SendRadio) then
		NETWORK.dispatch.SendRadio(L(key, ZoneName(entity), ...), Color(240, 96, 86))
	end
end

function E.Apply(client, entity, kind)
	entity:EmitSound("framework/emp/unlock.mp3", 75)
	entity:EmitSound("ambient/energy/zap" .. math.random(1, 9) .. ".wav", 65)

	local effect = EffectData()

	effect:SetOrigin(entity:WorldSpaceCenter())
	util.Effect("cball_explode", effect)

	if (kind == "field") then

		entity:Shutdown()
	elseif (kind == "lock") then
		entity.nwHacked = true
		entity:Apply(false)
		entity:SetError(true)

		timer.Simple(2, function()
			if (IsValid(entity)) then
				entity:SetError(false)
			end
		end)

		if (NETWORK.mechanic and NETWORK.mechanic.StartFault) then
			NETWORK.mechanic.StartFault(entity)
		end

		Dispatch("dispatchLockBroken", entity)
	elseif (kind == "terminal") then
		if (NETWORK.cmbterm and NETWORK.cmbterm.Break) then
			NETWORK.cmbterm.Break(entity, client)
		else
			entity:SetNWBool("nwBroken", true)
		end

		local user = entity.GetUser and entity:GetUser()

		if (IsValid(user)) then
			if (entity:GetClass() == "nw_jailterminal" and NETWORK.jail and NETWORK.jail.Close) then
				NETWORK.jail.Close(user)
			elseif (NETWORK.cmbterm and NETWORK.cmbterm.Close) then
				NETWORK.cmbterm.Close(user)
			end
		end

		Dispatch("dispatchTerminalBroken", entity, L(E.terminals[entity:GetClass()] or "empKindCivic"))
	elseif (kind == "vortigaunt") then
		E.FreeVortigaunt(client, entity)
	elseif (kind == "door") then
		NETWORK.door.SetLocked(entity, false)
		entity:Fire("Open")

		timer.Simple(E.duration, function()
			if (IsValid(entity)) then
				NETWORK.door.SetLocked(entity, true)
			end
		end)

		Dispatch("dispatchDoorBroken", entity)
	end

	NETWORK.log.Add("emp", string.format("%s сломал ЭМИ: %s (%s)", NETWORK.log.Name(client),
		entity:GetClass(), ZoneName(entity)), entity:GetPos())
end

function E.FreeVortigaunt(client, target)
	if (!IsValid(target) or !target:HasCharacter() or !NETWORK.classes) then
		return
	end

	local character = target:GetCharacter()
	local old = NETWORK.classes.GetAssigned(character)

	for _, weaponClass in ipairs(old and old.weapons or {}) do
		target:StripWeapon(weaponClass)
	end

	NETWORK.classes.assigned = NETWORK.classes.assigned or {}
	NETWORK.classes.assigned[tostring(character:GetID())] = {id = "vortigaunt"}
	NETWORK.classes.SaveAll()

	if (target:IsInSequence()) then
		target:LeaveSequence()
	end

	NETWORK.classes.Apply(target, character)
	NETWORK.inventory.RefreshAppearance(target)
	NETWORK.anim.Refresh(target)
	NETWORK.character.Refresh(target)

	NETWORK.notice.Send(target, "vortFreed", "good")
	NETWORK.notice.Send(client, "vortFreedBy", "good", target:GetCharacterName())
	NETWORK.chat.Send(target, "it", L("vortFreedAction"))

	Dispatch("dispatchVortFreed", target)
end

timer.Create("nwEmpPipeWatch", 0.5, 0, function()
	for client, entry in pairs(NETWORK.pipe.active) do
		if (!IsValid(client) or client.nwEmpTarget == nil or entry.entity != client.nwEmpTarget) then
			continue
		end

		local weapon = client:GetActiveWeapon()

		if (!IsValid(entry.entity) or client:GetPos():Distance(entry.entity:GetPos()) > E.range + 60 or
			!IsValid(weapon) or weapon:GetClass() != "weapon_nwemp") then
			net.Start("nwPipeClose")
			net.Send(client)

			NETWORK.pipe.Cancel(client)
		end
	end
end)

hook.Add("PlayerDisconnected", "nwEmp", function(client)
	client.nwEmpTarget = nil
end)
