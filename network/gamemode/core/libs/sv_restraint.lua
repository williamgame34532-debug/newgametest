local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function Progress(client, key, duration)
	net.Start("nwProgress")
		net.WriteString(key or "")
		net.WriteFloat(duration or 0)
	net.Send(client)
end

function NETWORK.restraint.GetTarget(client)
	local trace = client:GetEyeTrace()
	local target = trace.Entity

	if (!IsValid(target) or !target:IsPlayer() or target == client) then
		return
	end

	if (!target:HasCharacter() or !target:Alive()) then
		return
	end

	if (client:GetPos():Distance(target:GetPos()) > NETWORK.restraint.range) then
		return
	end

	return target
end

function NETWORK.restraint.Set(target, bTied)
	target:SetNWBool("nwTied", bTied or false)

	if (!bTied) then
		NETWORK.restraint.SetLeader(target, NULL)
	end

	if (bTied) then
		target:SelectWeapon(NETWORK.weapon.hands)
	end

	hook.Run("NetworkPlayerTied", target, bTied)
end

function NETWORK.restraint.SetLeader(target, leader)
	target:SetNWEntity("nwLeader", IsValid(leader) and leader or NULL)
end

function NETWORK.restraint.Begin(client, target, bUntie)
	if (client.nwTieTask) then
		return
	end

	client.nwTieTask = target

	Progress(client, bUntie and "tieCutting" or "tieProgress",
		NETWORK.restraint.tieTime)

	client:EmitSound("physics/plastic/plastic_barrel_strain" .. math.random(1, 3) ..
		".wav", 55, 110, 0.5)

	timer.Simple(NETWORK.restraint.tieTime, function()
		if (!IsValid(client)) then
			return
		end

		local pending = client.nwTieTask

		client.nwTieTask = nil

		if (pending != target or !IsValid(target) or !client:Alive()) then
			return
		end

		if (client:GetPos():Distance(target:GetPos()) > NETWORK.restraint.range) then
			return Progress(client, "", 0)
		end

		if (bUntie) then
			NETWORK.restraint.Set(target, false)

			NETWORK.inventory.Give(client, "zipties", 1)

			Notice(client, "tieCut")
			Notice(target, "tieFreed")

			return
		end

		NETWORK.restraint.Set(target, true)

		Notice(client, "tieDone")
		Notice(target, "tieTied")
	end)
end

hook.Add("StartCommand", "nwRestraint", function(client, cmd)
	if (client.nwTieTask) then
		cmd:ClearMovement()
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	end

	if (!NETWORK.restraint.IsTied(client)) then
		return
	end

	cmd:ClearMovement()
	cmd:RemoveKey(IN_ATTACK)
	cmd:RemoveKey(IN_ATTACK2)
	cmd:RemoveKey(IN_JUMP)
	cmd:RemoveKey(IN_SPEED)
	cmd:RemoveKey(IN_USE)
end)

hook.Add("PlayerSwitchWeapon", "nwRestraint", function(client, _, weapon)
	if (NETWORK.restraint.IsTied(client) and IsValid(weapon) and
		weapon:GetClass() != NETWORK.weapon.hands) then
		return true
	end
end)

hook.Add("PlayerSpawn", "nwRestraint", function(client)
	client:SetNWBool("nwTied", false)

	NETWORK.restraint.SetLeader(client, NULL)
end)

timer.Create("nwRestraintLead", 0.1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		local leader = NETWORK.restraint.GetLeader(client)

		if (!IsValid(leader)) then
			continue
		end

		if (!client:Alive() or !leader:Alive() or !NETWORK.restraint.IsTied(client)) then
			NETWORK.restraint.SetLeader(client, NULL)

			continue
		end

		local offset = leader:GetPos() - leader:GetForward() * 48
		local distance = client:GetPos():Distance(offset)

		if (distance > 400) then

			NETWORK.restraint.SetLeader(client, NULL)

			Notice(leader, "tieLost")

			continue
		end

		if (distance < 24) then
			continue
		end

		local direction = (offset - client:GetPos()):GetNormalized()

		client:SetVelocity(direction * math.min(distance * 4, 220) -
			client:GetVelocity() * 0.5)
	end
end)

hook.Add("PlayerDeath", "nwRestraint", function(client)
	NETWORK.restraint.SetLeader(client, NULL)
end)

NETWORK.restraint.cuffRange = 90

function NETWORK.restraint.CancelCuff(client, key)
	if (!client.nwCuffTask) then
		return
	end

	client.nwCuffTask = nil
	timer.Remove("nwCuff" .. client:EntIndex())
	Progress(client, "", 0)

	if (key) then
		Notice(client, key)
	end
end

function NETWORK.restraint.BeginCuff(client, target, time)
	if (client.nwCuffTask) then
		return
	end

	if (NETWORK.restraint.IsTied(target) and !target:GetNWBool("nwCuffed", false)) then

		time = time * 0.5
	end

	client.nwCuffTask = {target = target, finish = CurTime() + time}

	Progress(client, "cuffProgress", time)
	client:EmitSound(NETWORK.restraint.Sound("framework/cuffs/tying.wav",
		"physics/plastic/plastic_barrel_strain1.wav"), 60)
	NETWORK.chat.Send(client, "me", L("cuffMe"))

	timer.Create("nwCuff" .. client:EntIndex(), 0.1, 0, function()
		if (!IsValid(client) or !client.nwCuffTask) then
			return
		end

		local task = client.nwCuffTask
		local looking = IsValid(target) and client:GetEyeTrace().Entity == target

		if (!IsValid(target) or !target:Alive() or !client:Alive() or !looking or
			client:GetPos():Distance(target:GetPos()) > NETWORK.restraint.cuffRange or
			!IsValid(client:GetActiveWeapon()) or
			client:GetActiveWeapon():GetClass() != "weapon_nwhandcuffs") then
			return NETWORK.restraint.CancelCuff(client, "cuffLost")
		end

		if (CurTime() < task.finish) then
			return
		end

		NETWORK.restraint.CancelCuff(client)

		target:SetNWBool("nwCuffed", true)
		NETWORK.restraint.SetCuffPose(target, true)
		NETWORK.restraint.Set(target, true)
		target:EmitSound(NETWORK.restraint.Sound("framework/cuffs/handcuffs_open.mp3",
		"vehicles/atv_ammo_close.wav"), 65)

		Notice(client, "cuffDone")
		Notice(target, "cuffCuffed")

		NETWORK.log.Add("restraint", string.format("%s надел наручники на %s",
			NETWORK.log.Name(client), NETWORK.log.Name(target)), client:GetPos())
	end)
end

NETWORK.restraint.uncuffTime = 5

function NETWORK.restraint.CancelUncuff(client, key)
	if (!client.nwUncuffTask) then
		return
	end

	client.nwUncuffTask = nil
	timer.Remove("nwUncuff" .. client:EntIndex())
	Progress(client, "", 0)

	if (key) then
		Notice(client, key)
	end
end

function NETWORK.restraint.BeginUncuff(client, target, time)
	if (client.nwUncuffTask or client.nwCuffTask) then
		return
	end

	time = time or NETWORK.restraint.uncuffTime

	client.nwUncuffTask = {target = target, finish = CurTime() + time}

	Progress(client, "uncuffProgress", time)
	client:EmitSound(NETWORK.restraint.Sound("framework/cuffs/tying.wav",
		"physics/plastic/plastic_barrel_strain1.wav"), 60)
	NETWORK.chat.Send(client, "me", L("uncuffMe"))

	timer.Create("nwUncuff" .. client:EntIndex(), 0.1, 0, function()
		if (!IsValid(client) or !client.nwUncuffTask) then
			return
		end

		local task = client.nwUncuffTask
		local looking = IsValid(target) and client:GetEyeTrace().Entity == target

		if (!IsValid(target) or !target:Alive() or !client:Alive() or !looking or
			!target:GetNWBool("nwCuffed", false) or
			client:GetPos():Distance(target:GetPos()) > NETWORK.restraint.cuffRange or
			!IsValid(client:GetActiveWeapon()) or
			client:GetActiveWeapon():GetClass() != "weapon_nwhandcuffs") then
			return NETWORK.restraint.CancelUncuff(client, "uncuffLost")
		end

		if (CurTime() < task.finish) then
			return
		end

		NETWORK.restraint.CancelUncuff(client)
		NETWORK.restraint.Uncuff(client, target)
	end)
end

function NETWORK.restraint.Uncuff(client, target)
	if (!target:GetNWBool("nwCuffed", false)) then
		return
	end

	target:SetNWBool("nwCuffed", false)
	NETWORK.restraint.SetCuffPose(target, false)
	NETWORK.restraint.Set(target, false)
	target:EmitSound(NETWORK.restraint.Sound("framework/cuffs/handcuffs_open.mp3",
		"vehicles/atv_ammo_close.wav"), 65)

	Notice(client, "cuffRemoved")
	Notice(target, "cuffFreed")
end

function NETWORK.restraint.SetCuffPose(target, bCuffed)
	if (!IsValid(target)) then
		return
	end

	for name, angle in pairs(NETWORK.restraint.cuffPose) do
		local bone = target:LookupBone(name)

		if (bone) then
			target:ManipulateBoneAngles(bone, bCuffed and angle or angle_zero)
		end
	end
end

hook.Add("PlayerSpawn", "nwCuffReset", function(client)
	client:SetNWBool("nwCuffed", false)
	NETWORK.restraint.SetCuffPose(client, false)
end)

hook.Add("PlayerDeath", "nwCuffReset", function(client)
	if (client:GetNWBool("nwCuffed", false)) then
		client:SetNWBool("nwCuffed", false)
		NETWORK.restraint.SetCuffPose(client, false)
	end
end)

hook.Add("PlayerDisconnected", "nwCuffCancel", function(client)
	NETWORK.restraint.CancelCuff(client)
	NETWORK.restraint.CancelUncuff(client)
end)

hook.Add("NetworkCanUntie", "nwCuffs", function(client, target)
	if (target:GetNWBool("nwCuffed", false)) then
		Notice(client, "cuffNeedKey")

		return false
	end
end)
