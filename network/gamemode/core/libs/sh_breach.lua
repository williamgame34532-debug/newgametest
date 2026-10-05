NETWORK.breach = NETWORK.breach or {}

NETWORK.breach.chance = 0.5
NETWORK.breach.range = 110
NETWORK.breach.cooldown = 3
NETWORK.breach.sequence = "kickdoorbaton"

NETWORK.breach.impact = 0.65
NETWORK.breach.reseal = 45

function NETWORK.breach.CanKick(client)
	if (!IsValid(client) or !client:Alive() or !client:HasCharacter()) then
		return false
	end

	if (client:GetNWBool("nwActing", false) or client:InVehicle()) then
		return false
	end

	return NETWORK.factions.IsAlliance(client)
end

function NETWORK.breach.GetDoor(client)
	if (!NETWORK.breach.CanKick(client)) then
		return
	end

	local trace = client:GetEyeTrace()
	local entity = trace.Entity

	if (!NETWORK.door.IsDoor(entity)) then
		return
	end

	if (trace.HitPos:Distance(client:GetShootPos()) > NETWORK.breach.range) then
		return
	end

	return entity
end
