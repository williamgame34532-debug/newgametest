NETWORK.needs = NETWORK.needs or {}

NETWORK.needs.eatSounds = {
	"framework/need/hunger_eat_01.wav",
	"framework/need/hunger_eat_02.wav",
	"framework/need/hunger_eat_03.wav"
}

NETWORK.needs.drinkSounds = {
	"framework/need/thrist_drink_01.wav",
	"framework/need/thrist_drink_02.wav",
	"framework/need/thrist_drink_03.wav"
}

NETWORK.needs.eatFallback = {
	"physics/flesh/flesh_squishy_impact_hard1.wav",
	"physics/flesh/flesh_squishy_impact_hard2.wav",
	"physics/flesh/flesh_squishy_impact_hard3.wav"
}

NETWORK.needs.drinkFallback = {
	"npc/barnacle/barnacle_gulp1.wav",
	"npc/barnacle/barnacle_gulp2.wav"
}

local resolved

local function Resolve()
	if (resolved) then
		return resolved
	end

	resolved = {}

	for _, key in ipairs({"eat", "drink"}) do
		local list = key == "eat" and NETWORK.needs.eatSounds or
			NETWORK.needs.drinkSounds
		local available = {}

		for _, path in ipairs(list) do
			if (file.Exists("sound/" .. path, "GAME")) then
				available[#available + 1] = path
			end
		end

		if (#available == 0) then
			available = key == "eat" and NETWORK.needs.eatFallback or
				NETWORK.needs.drinkFallback
		end

		resolved[key] = available
	end

	return resolved
end

function NETWORK.needs.PlayConsume(client, bDrink)
	if (!IsValid(client)) then
		return
	end

	local list = Resolve()[bDrink and "drink" or "eat"]

	client:EmitSound(list[math.random(#list)], 65, math.random(96, 104), 0.85,
		CHAN_ITEM)
end

NETWORK.needs.hungerTime = 60 * 240
NETWORK.needs.thirstTime = 60 * 150

NETWORK.stamina = NETWORK.stamina or {}

NETWORK.stamina.max = 160

NETWORK.stamina.factionMax = {
	cp = 320,
	combine = 100000,
	cmb = 100000
}

function NETWORK.stamina.GetMax(client)
	if (!IsValid(client)) then
		return NETWORK.stamina.max
	end

	local faction = client.GetCharacterFaction and client:GetCharacterFaction() or ""

	return NETWORK.stamina.factionMax[faction] or NETWORK.stamina.max
end
NETWORK.stamina.sprintDrain = 14
NETWORK.stamina.jumpCost = 10
NETWORK.stamina.regen = 18

NETWORK.stamina.walkRegen = 0.55
NETWORK.stamina.regenDelay = 0.8
NETWORK.stamina.recoverAt = 45
NETWORK.stamina.moveThreshold = 12

NETWORK.stamina.overDrain = 6
NETWORK.stamina.heartSound = "player/heartbeat1.wav"
NETWORK.stamina.heartMin = 0.55
NETWORK.stamina.heartMax = 1.1
NETWORK.stamina.heartVolume = 55

NETWORK.stamina.calmTime = 1.5

local PLAYER = FindMetaTable("Player")

function PLAYER:GetStamina()
	return self:GetNWFloat("nwStamina", NETWORK.stamina.GetMax(self))
end

function PLAYER:GetStaminaFraction()
	return math.Clamp(self:GetStamina() / NETWORK.stamina.GetMax(self), 0, 1)
end

function PLAYER:IsExhausted()
	return self:GetNWBool("nwExhausted", false)
end

function PLAYER:GetHunger()
	return self:GetNWFloat("nwHunger", 100)
end

function PLAYER:GetThirst()
	return self:GetNWFloat("nwThirst", 100)
end
