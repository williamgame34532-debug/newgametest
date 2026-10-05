NETWORK.mechanic = NETWORK.mechanic or {}

NETWORK.mechanic.kits = {toolkit = true, mechanic_toolkit = true}

util.AddNetworkString("nwMechanicStart")
util.AddNetworkString("nwMechanicRound")

function NETWORK.mechanic.StartFault(entity)
	if (!IsValid(entity) or entity.nwFaultLoop) then
		return
	end

	entity.nwFaultLoop = CreateSound(entity,
		"ambient/levels/labs/electric_explosion5.wav")

	entity.nwFaultLoop:SetSoundLevel(62)
	entity.nwFaultLoop:PlayEx(0.35, 40)
end

function NETWORK.mechanic.StopFault(entity)
	if (!IsValid(entity) or !entity.nwFaultLoop) then
		return
	end

	entity.nwFaultLoop:Stop()

	entity.nwFaultLoop = nil
end

function NETWORK.mechanic.Break(entity, client)
	if (NETWORK.cmbterm and NETWORK.cmbterm.Journal) then
		NETWORK.cmbterm.Journal(client, "journalBreak", entity)
	end

	entity:SetNWBool("nwBroken", true)
	entity:SetNWString("nwBreakOwner", "")

	entity:EmitSound("ambient/machines/machine_whine1.wav", 60, 80)

	NETWORK.mechanic.StartFault(entity)

	local effect = EffectData()

	effect:SetOrigin(entity:WorldSpaceCenter())
	util.Effect("ManhackSparks", effect)
end

function NETWORK.mechanic.FindKit(client)
	local state = NETWORK.inventory.GetState(client)

	for _, list in ipairs({"items", "storage", "clothes", "equipped"}) do
		for _, item in pairs(state[list] or {}) do
			if (istable(item) and NETWORK.mechanic.kits[item.id]) then
				return item
			end
		end
	end
end

function NETWORK.mechanic.CanService(client)
	if (!IsValid(client) or !client:HasCharacter()) then
		return false
	end

	return client:GetNWString("nwClass", "") == "mechanic" or
		client:IsAdmin() or NETWORK.factions.IsAlliance(client) or
		NETWORK.factions.IsCWU(client)
end

function NETWORK.mechanic.TryRepair(client, entity)
	local electrician = client:GetNWString("nwClass", "") == "factory_electrician" and entity:GetClass() == "nw_breaker"
	if (client:GetNWString("nwClass", "") != "mechanic" and !electrician and
		!client:IsAdmin()) then
		return NETWORK.chat.Notice(client, "mechanicOnly")
	end

	if (!NETWORK.mechanic.FindKit(client)) then
		return NETWORK.chat.Notice(client, "mechanicNeedKit")
	end

	local owner = entity:GetNWString("nwBreakOwner", "")
	if (electrician and owner == "") then
		owner = client:GetCharacterName()
		entity:SetNWString("nwBreakOwner", owner)
	end

	if (owner == "" and !client:IsAdmin()) then
		return NETWORK.chat.Notice(client, "mechanicNeedClaim")
	end

	if (owner != "" and owner != client:GetCharacterName() and !client:IsAdmin()) then
		return NETWORK.notice.Send(client, "mechanicClaimedBy", "warn", owner)
	end

	if (IsValid(client.nwMechTarget)) then
		return
	end

	client.nwMechTarget = entity
	client.nwMechMaint = nil
	client.nwMechRounds = 0
	client.nwMechNeed = math.random(4, 6)

	if (NETWORK.skills) then
		local intellect = NETWORK.skills.Get(client, "intellect")

		for _, threshold in ipairs(NETWORK.skills.Effect("intellect", "repairAt") or {}) do
			if (intellect >= threshold) then
				client.nwMechNeed = math.max(client.nwMechNeed - 1, 2)
			end
		end
	end
	client.nwMechNextRound = 0

	net.Start("nwMechanicStart")
		net.WriteEntity(entity)
		net.WriteUInt(client.nwMechNeed, 4)
		net.WriteUInt(math.random(4), 3)
	net.Send(client)
end

net.Receive("nwMechanicRound", function(_, client)
	local entity = client.nwMechTarget

	local role = client:GetNWString("nwClass", "")
	if (!IsValid(entity) or !client:Alive() or !client:HasCharacter() or
		(!(client.nwMechMaint and NETWORK.mechanic.CanService(client)) and !client:IsAdmin() and role != "mechanic" and
		 !(role == "factory_electrician" and entity:GetClass() == "nw_breaker")) or
		!NETWORK.mechanic.FindKit(client) or client:GetPos():Distance(entity:GetPos()) > 160) then
		client.nwMechTarget = nil
		client.nwMechMaint = nil

		return
	end

	if ((client.nwMechNextRound or 0) > CurTime()) then
		return
	end

	client.nwMechNextRound = CurTime() + 0.4
	client.nwMechRounds = (client.nwMechRounds or 0) + 1

	if (client.nwMechRounds >= (client.nwMechNeed or 5)) then
		client.nwMechTarget = nil

		if (client.nwMechMaint) then
			client.nwMechMaint = nil

			return NETWORK.mechanic.FinishMaintenance(client, entity)
		end

		entity:SetNWBool("nwBroken", false)
		entity:SetNWString("nwBreakOwner", "")
		entity:EmitSound("buttons/lever5.wav", 65)

		NETWORK.mechanic.StopFault(entity)

		if (NETWORK.cmbterm and NETWORK.cmbterm.Journal) then
			NETWORK.cmbterm.Journal(client, "journalRepair", entity)
		end

		local reward = math.random(1, 2)

		NETWORK.currency.Add(client, reward)
		NETWORK.chat.Notice(client, "mechanicPaid")

		hook.Run("NetworkMechanicRepaired", client, entity)
	end
end)

NETWORK.mechanic.randomInterval = 90
NETWORK.mechanic.randomChance = 0.35
NETWORK.mechanic.maxBroken = 4

local function MechanicOnline()
	for _, client in ipairs(player.GetAll()) do
		if (client:HasCharacter() and client:GetNWString("nwClass", "") == "mechanic") then
			return true
		end
	end

	return false
end

timer.Create("nwMechanicRandomBreak", NETWORK.mechanic.randomInterval, 0, function()
	if (!NETWORK.cmbterm or !NETWORK.cmbterm.breakClasses or !MechanicOnline()) then
		return
	end

	if (math.Rand(0, 1) > NETWORK.mechanic.randomChance) then
		return
	end

	local candidates = {}
	local broken = 0

	for class in pairs(NETWORK.cmbterm.breakClasses) do
		for _, entity in ipairs(ents.FindByClass(class)) do
			if (entity:GetNWBool("nwBroken", false)) then
				broken = broken + 1
			elseif (!entity.bNoRandomBreak) then
				candidates[#candidates + 1] = entity
			end
		end
	end

	if (broken >= NETWORK.mechanic.maxBroken or #candidates == 0) then
		return
	end

	NETWORK.mechanic.Break(candidates[math.random(#candidates)])
end)

NETWORK.mechanic.diagClasses = {
	nw_forcefield = true, nw_lock = true, nw_cmbterminal = true,
	nw_cwuterminal = true, npc_combine_camera = true, nw_terminal = true,
	nw_jailterminal = true, nw_admin_computer = true, nw_council_computer = true, nw_breaker = true,
	nw_fridge = true, nw_vending = true, nw_factory_terminal = true
}

function NETWORK.mechanic.IsBroken(entity)
	if (!IsValid(entity)) then
		return false
	end

	local class = entity:GetClass()

	if (class == "nw_forcefield") then
		return entity.GetMode and entity:GetMode() == entity.MODE_SHUTDOWN
	end

	if (class == "nw_lock") then
		return entity.nwHacked == true
	end

	return entity:GetNWBool("nwBroken", false)
end

function NETWORK.mechanic.DescribeEntity(entity)
	local class = entity:GetClass()
	local key = NETWORK.cmbterm and NETWORK.cmbterm.breakClasses and
		NETWORK.cmbterm.breakClasses[class]

	if (key) then
		return L(key)
	end

	if (isstring(entity.PrintName) and entity.PrintName != "") then
		return entity.PrintName
	end

	return class
end

function NETWORK.mechanic.Diagnose(client, entity, kit)
	if (!IsValid(entity) or !NETWORK.mechanic.diagClasses[entity:GetClass()]) then
		return NETWORK.chat.Notice(client, "toolkitNoTarget")
	end

	local bBroken = NETWORK.mechanic.IsBroken(entity)
	local parts = {L(bBroken and "diagBroken" or "diagOk")}

	if (!bBroken and entity:GetClass() == "nw_breaker" and entity.nextBreak) then
		parts[#parts + 1] = L("diagNextBreak",
			math.max(1, math.ceil((entity.nextBreak - CurTime()) / 60)))
	end

	if (!bBroken and (entity.nwMaintainedUntil or 0) > CurTime()) then
		parts[#parts + 1] = L("diagMaintained",
			math.max(1, math.ceil((entity.nwMaintainedUntil - CurTime()) / 60)))
	end

	kit = kit or NETWORK.mechanic.FindKit(client)

	if (istable(kit)) then
		local base = NETWORK.item.Get(kit.id)
		local maxUses = base and base.maxUses or 10

		parts[#parts + 1] = L("diagKitCharge", kit.uses or maxUses, maxUses)
	end

	NETWORK.notice.Send(client, "diagResult", bBroken and "warn" or "good",
		NETWORK.mechanic.DescribeEntity(entity), table.concat(parts, ", "))

	client:EmitSound("buttons/blip1.wav", 50, 110)
end

NETWORK.command.Register("diag", {
	description = "cmdDiag",
	usage = "/diag",
	example = "/diag",
	OnRun = function(command, client)
		if (!NETWORK.mechanic.CanService(client)) then
			return NETWORK.chat.Notice(client, "mechanicOnly")
		end

		if (!NETWORK.mechanic.FindKit(client)) then
			return NETWORK.chat.Notice(client, "mechanicNeedKit")
		end

		local target = NETWORK.util.FindLookedAt(client, 128, function(entity)
			return NETWORK.mechanic.diagClasses[entity:GetClass()] == true
		end)

		NETWORK.mechanic.Diagnose(client, target)
	end
})

NETWORK.mechanic.maintainClasses = {
	nw_breaker = true, nw_fridge = true, nw_vending = true
}

NETWORK.mechanic.maintainCooldown = 600
NETWORK.mechanic.maintainRounds = 3

function NETWORK.mechanic.TryMaintain(client, entity)
	if (!IsValid(entity) or !NETWORK.mechanic.maintainClasses[entity:GetClass()]) then
		return false
	end

	if (!NETWORK.mechanic.CanService(client)) then
		return false
	end

	if (entity:GetNWBool("nwBroken", false)) then
		return false
	end

	if (!NETWORK.mechanic.FindKit(client)) then
		NETWORK.chat.Notice(client, "mechanicNeedKit")

		return true
	end

	if ((entity.nwMaintCooldown or 0) > CurTime()) then
		NETWORK.notice.Send(client, "maintCooldown", "warn",
			math.max(1, math.ceil((entity.nwMaintCooldown - CurTime()) / 60)))

		return true
	end

	if (IsValid(client.nwMechTarget)) then
		return true
	end

	client.nwMechTarget = entity
	client.nwMechMaint = true
	client.nwMechRounds = 0
	client.nwMechNeed = NETWORK.mechanic.maintainRounds
	client.nwMechNextRound = 0

	entity:EmitSound("buttons/lever5.wav", 55, 110)

	net.Start("nwMechanicStart")
		net.WriteEntity(entity)
		net.WriteUInt(client.nwMechNeed, 4)
		net.WriteUInt(math.random(4), 3)
	net.Send(client)

	return true
end

function NETWORK.mechanic.FinishMaintenance(client, entity)
	if (!IsValid(entity)) then
		return
	end

	local class = entity:GetClass()

	if (class == "nw_breaker") then
		entity.nextBreak = math.max(entity.nextBreak or CurTime(), CurTime()) + 300
	else
		entity.nwMaintainedUntil = CurTime() + 600
	end

	entity.nwMaintCooldown = CurTime() + NETWORK.mechanic.maintainCooldown

	entity:EmitSound("buttons/lever5.wav", 65)

	local effect = EffectData()

	effect:SetOrigin(entity:WorldSpaceCenter())
	util.Effect("cball_bounce", effect)

	if (NETWORK.cmbterm and NETWORK.cmbterm.Journal) then
		NETWORK.cmbterm.Journal(client, "journalRepair", entity)
	end

	NETWORK.currency.Add(client, 1)
	NETWORK.chat.Notice(client, "maintDone")

	hook.Run("NetworkMechanicRepaired", client, entity)
end

hook.Add("PlayerDisconnected", "nwMechanicMaint", function(client)
	client.nwMechTarget = nil
	client.nwMechMaint = nil
end)
