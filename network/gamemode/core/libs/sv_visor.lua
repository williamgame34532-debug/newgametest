util.AddNetworkString("nwVisorCrack")
util.AddNetworkString("nwVisorReset")

NETWORK.visor = NETWORK.visor or {}

NETWORK.visor.minDamage = 6

function NETWORK.visor.Reset(client)
	client.nwVisorFrac = 0

	net.Start("nwVisorReset")
	net.Send(client)
end

function NETWORK.visor.Repair(client)
	if (!IsValid(client) or !client:HasCharacter() or !client:IsCombine()) then
		return false
	end

	if ((client.nwVisorFrac or 0) <= 0.01) then
		net.Start("nwChatMessage")
			net.WriteString("notice")
			net.WriteEntity(NULL)
			net.WriteString("")
			net.WriteString("visorIntact")
		net.Send(client)

		return false
	end

	NETWORK.visor.Reset(client)

	client:EmitSound("items/battery_pickup.wav", 60, 120, 0.6)

	net.Start("nwChatMessage")
		net.WriteString("notice")
		net.WriteEntity(NULL)
		net.WriteString("")
		net.WriteString("visorFixed")
	net.Send(client)

	return true
end

hook.Add("PlayerHurt", "nwVisor", function(client, attacker, remaining, taken)
	if (!client:HasCharacter() or !client:IsCombine() or remaining <= 0) then
		return
	end

	if ((taken or 0) < NETWORK.visor.minDamage) then
		return
	end

	local fraction = 1 - math.Clamp(remaining / math.max(client:GetMaxHealth(), 1), 0, 1)

	client.nwVisorFrac = math.max(client.nwVisorFrac or 0, fraction)

	net.Start("nwVisorCrack")
		net.WriteFloat(math.Rand(0.2, 0.8))
		net.WriteFloat(math.Rand(0.22, 0.72))
		net.WriteFloat(math.Clamp(taken / 25, 0.5, 2))
		net.WriteFloat(client.nwVisorFrac)
	net.Send(client)
end)

hook.Add("Think", "nwVisorHeal", function()
	if ((NETWORK.visor.nextHeal or 0) > CurTime()) then
		return
	end

	NETWORK.visor.nextHeal = CurTime() + 1

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter() or !client:IsCombine()) then
			continue
		end

		local target = 1 - math.Clamp(client:Health() /
			math.max(client:GetMaxHealth(), 1), 0, 1)

		if ((client.nwVisorFrac or 0) <= target + 0.01) then
			continue
		end

		client.nwVisorFrac = target

		net.Start("nwVisorCrack")
			net.WriteFloat(-1)
			net.WriteFloat(-1)
			net.WriteFloat(0.5)
			net.WriteFloat(target)
		net.Send(client)
	end
end)

hook.Add("PlayerSpawn", "nwVisor", function(client)
	NETWORK.visor.Reset(client)
end)

hook.Add("NetworkCharacterLoaded", "nwVisor", function(client)
	NETWORK.visor.Reset(client)
end)
