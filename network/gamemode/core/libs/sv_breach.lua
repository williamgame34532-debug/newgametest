util.AddNetworkString("nwDoorKick")

local function Notice(client, key)
	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString(key)
	net.Send(client)
end

local function Open(entity, client)

	hook.Run("NetworkLockOpened", client, entity, "взлом")

	local data = NETWORK.door.GetData(entity)
	local bSealed = NETWORK.door.IsSealed(entity, data)

	NETWORK.door.EachLeaf(entity, function(leaf)
		leaf:Fire("unlock")
		leaf:Fire("open")
	end)

	entity:EmitSound("physics/wood/wood_plank_break" .. math.random(2, 4) .. ".wav",
		85, math.random(95, 105))
	entity:EmitSound("doors/door_squeek" .. math.random(1, 2) .. ".wav", 75, 100)

	if (NETWORK.breach.reseal <= 0 or !bSealed) then
		return
	end

	entity.nwBreached = CurTime()

	timer.Simple(NETWORK.breach.reseal, function()
		if (!IsValid(entity) or entity.nwBreached == nil) then
			return
		end

		entity.nwBreached = nil

		local current = NETWORK.door.GetData(entity)

		if ((current and current.bLocked) or entity.nwMapLocked) then
			NETWORK.door.EachLeaf(entity, function(leaf)
				leaf:Fire("close")
				leaf:Fire("lock")
			end)
		end
	end)
end

NETWORK.breach.kickSequences = {
	NETWORK.breach.sequence,
	"kickdoor",
	"kickdoorfist"
}

function NETWORK.breach.PlayKick(client, repeats, interval)
	if (!IsValid(client) or client:IsInSequence()) then
		return
	end

	local sequence

	for _, name in ipairs(NETWORK.breach.kickSequences) do
		if (name and client:LookupSequence(name) > 0) then
			sequence = name

			break
		end
	end

	if (!sequence) then
		return
	end

	client:ForceSequence(sequence, function()
		if (IsValid(client)) then
			client:LeaveSequence()
		end
	end, nil, true)

	repeats = math.max(math.Round(repeats or 1), 1)

	if (repeats <= 1) then
		return
	end

	interval = interval or 1.3

	for index = 1, repeats - 1 do
		timer.Simple(interval * index, function()
			if (!IsValid(client) or !client:Alive()) then
				return
			end

			client:ForceSequence(sequence, function()
				if (IsValid(client)) then
					client:LeaveSequence()
				end
			end, nil, true)
		end)
	end
end

function NETWORK.breach.Kick(client)
	local entity = NETWORK.breach.GetDoor(client)

	if (!IsValid(entity)) then
		return Notice(client, "breachNoDoor")
	end

	if ((client.nwNextKick or 0) > CurTime()) then
		return
	end

	client.nwNextKick = CurTime() + NETWORK.breach.cooldown

	NETWORK.breach.PlayKick(client)

	client:EmitSound("npc/metropolice/vo/overhere.wav", 60, 100, 0.4)

	local bBroken = math.Rand(0, 1) < NETWORK.breach.chance

	timer.Simple(NETWORK.breach.impact, function()
		if (!IsValid(client) or !IsValid(entity)) then
			return
		end

		entity:EmitSound("physics/wood/wood_crate_impact_hard" ..
			math.random(2, 3) .. ".wav", 85, math.random(90, 100))

		if (hook.Run("NetworkDoorBreach", client, entity, bBroken) == false) then
			return
		end

		if (!bBroken) then
			entity:EmitSound("doors/door_locked2.wav", 75, 100)

			return Notice(client, "breachFailed")
		end

		Open(entity, client)

		Notice(client, "breachOpened")

		hook.Run("NetworkDoorBreached", client, entity)
	end)
end

net.Receive("nwDoorKick", function(_, client)
	if (!NETWORK.breach.CanKick(client)) then
		return
	end

	NETWORK.breach.Kick(client)
end)

util.AddNetworkString("nwWallhammerKnock")

NETWORK.breach.knockTime = 20
NETWORK.breach.knockCooldown = 5
NETWORK.breach.knockRange = 100

function NETWORK.breach.Knock(client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return
	end

	if (!NETWORK.shield or !NETWORK.shield.IsUser or !NETWORK.shield.IsUser(client)) then
		return Notice(client, "knockOnlyWallhammer")
	end

	if ((client.nwNextKnock or 0) > CurTime()) then
		return Notice(client, "knockCooldown")
	end

	local trace = client:GetEyeTrace()
	local target = trace.Entity

	if (!IsValid(target) or !target:IsPlayer() or !target:Alive() or !target:HasCharacter() or
		client:GetPos():Distance(target:GetPos()) > NETWORK.breach.knockRange) then
		return Notice(client, "knockNoTarget")
	end

	if (target:IsUnconscious() or target:IsDowned()) then
		return Notice(client, "knockAlready")
	end

	client.nwNextKnock = CurTime() + NETWORK.breach.knockCooldown

	NETWORK.breach.PlayKick(client)

	client:EmitSound("npc/combine_soldier/vo/prepforcontact.wav", 60, 100, 0.5)
	NETWORK.chat.Send(client, "me", L("knockActionMe", target:GetRecognisedName(client)))

	timer.Simple(NETWORK.breach.impact or 0.6, function()
		if (!IsValid(client) or !IsValid(target) or !target:Alive() or
			client:GetPos():Distance(target:GetPos()) > NETWORK.breach.knockRange + 30) then
			return
		end

		target:EmitSound("physics/body/body_medium_impact_hard" .. math.random(1, 6) .. ".wav",
			75, 95)
		target:ViewPunch(Angle(-12, math.random(-8, 8), 0))

		local downTime = NETWORK.medical.downTime

		NETWORK.medical.downTime = NETWORK.breach.knockTime
		NETWORK.medical.SetUnconscious(target, true)
		NETWORK.medical.downTime = downTime

		NETWORK.notice.Send(target, "knockedOut", "bad", client:GetRecognisedName(target))
		NETWORK.notice.Send(client, "knockDone", "good", target:GetRecognisedName(client))

		hook.Run("NetworkPlayerKnockedOut", client, target)
	end)
end

net.Receive("nwWallhammerKnock", function(_, client)
	NETWORK.breach.Knock(client)
end)
