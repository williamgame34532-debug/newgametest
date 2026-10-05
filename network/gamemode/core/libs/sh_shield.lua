NETWORK.shield = NETWORK.shield or {}

NETWORK.shield.class = "wallhammer"

NETWORK.shield.maxEnergy = 100

NETWORK.shield.holdTime = 35
NETWORK.shield.hitCost = 3

NETWORK.shield.minShots = 50
NETWORK.shield.maxShots = 60
NETWORK.shield.regen = 14
NETWORK.shield.breakPenalty = 6
NETWORK.shield.blockDot = 0.26
NETWORK.shield.flashCost = 35
NETWORK.shield.flashDelay = 12
NETWORK.shield.flashRange = 620

function NETWORK.shield.IsUser(client)
	return client:GetNWString("nwClass", "") == NETWORK.shield.class
end

function NETWORK.shield.IsActive(client)
	return client:GetNWBool("nwShieldActive", false)
end

function NETWORK.shield.GetEnergy(client)
	return client:GetNWFloat("nwShieldEnergy", NETWORK.shield.maxEnergy)
end

function NETWORK.shield.IsBroken(client)
	return client:GetNWFloat("nwShieldBroken", 0) > CurTime()
end

function NETWORK.shield.GetOrigin(client)
	return client:GetPos() + Vector(0, 0, 44)
end

function NETWORK.shield.GetForward(client)
	return Angle(0, client:EyeAngles().yaw, 0):Forward()
end

hook.Add("StartCommand", "nwShieldNoFire", function(client, cmd)
	if (NETWORK.shield.IsActive(client)) then
		cmd:RemoveKey(IN_ATTACK)
		cmd:RemoveKey(IN_ATTACK2)
	end
end)
