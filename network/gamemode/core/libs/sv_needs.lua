NETWORK.needs.staminaStep = 1

function NETWORK.needs.GetExact(client)
	return client.nwStaminaExact or client:GetNWFloat("nwStamina",
		NETWORK.stamina.GetMax(client))
end

function NETWORK.needs.PushStamina(client, value, bForce)
	local maximum = NETWORK.stamina.GetMax(client)

	value = math.Clamp(value, 0, maximum)

	client.nwStaminaExact = value

	local sent = client.nwStaminaSent

	if (!bForce and sent and math.abs(sent - value) < NETWORK.needs.staminaStep and
		value > 0 and value < maximum) then
		return value
	end

	client.nwStaminaSent = value

	client:SetNWFloat("nwStamina", value)

	return value
end

function NETWORK.needs.PushBool(client, key, value)
	if (client:GetNWBool(key, false) == value) then
		return
	end

	client:SetNWBool(key, value)
end

function NETWORK.needs.Reset(client)
	NETWORK.needs.PushStamina(client, NETWORK.stamina.GetMax(client), true)
	client:SetNWFloat("nwHunger", 100)
	client:SetNWFloat("nwThirst", 100)
	client:SetNWBool("nwExhausted", false)

	client.nwStaminaDelay = 0
end

NETWORK.needs.respawnMin = 50
NETWORK.needs.respawnMax = 60

function NETWORK.needs.Respawn(client)
	NETWORK.needs.PushStamina(client, NETWORK.stamina.GetMax(client), true)
	client:SetNWBool("nwExhausted", false)

	client.nwStaminaDelay = 0

	for _, key in ipairs({"nwHunger", "nwThirst"}) do
		local floor = math.random(NETWORK.needs.respawnMin,
			NETWORK.needs.respawnMax)

		client:SetNWFloat(key, math.max(client:GetNWFloat(key, 100), floor))
	end
end

function NETWORK.needs.Add(client, key, amount)
	local current = client:GetNWFloat(key, 100)

	client:SetNWFloat(key, math.Clamp(current + amount, 0, 100))
end

hook.Add("NetworkCharacterLoaded", "nwNeeds", function(client)
	if (NETWORK.persistence and NETWORK.persistence.Get(client:GetCharacter())) then
		return
	end

	NETWORK.needs.Reset(client)
end)

hook.Add("PlayerSpawn", "nwNeeds", function(client)

	if (client:GetNWFloat("nwStamina", -1) < 0) then
		NETWORK.needs.Reset(client)
	elseif (client.nwDied) then
		client.nwDied = nil

		NETWORK.needs.Respawn(client)
	end

	client:SetNWBool("nwExhausted", false)
	client.nwStaminaDelay = 0
end)

hook.Add("PlayerDeath", "nwNeeds", function(client)
	client.nwDied = true
end)

hook.Add("KeyPress", "nwStamina", function(client, key)
	if (key != IN_JUMP or !client:HasCharacter() or !client:IsOnGround()) then
		return
	end

	local jumpCost = NETWORK.stamina.jumpCost * math.Clamp(1 -
		(NETWORK.skills and NETWORK.skills.Get(client, "agility") or 0) *
		NETWORK.skills.Effect("agility", "jump"), 0.4, 1)
	local stamina = math.max(NETWORK.needs.GetExact(client) - jumpCost, 0)

	NETWORK.needs.PushStamina(client, stamina, true)

	client.nwStaminaDelay = CurTime() + NETWORK.stamina.regenDelay

	if (stamina <= 0) then
		client:SetNWBool("nwExhausted", true)
	end
end)

hook.Add("PlayerTick", "nwStamina", function(client, mv)
	if (!client:Alive() or !client:HasCharacter()) then
		return
	end

	local config = NETWORK.stamina
	local delta = FrameTime()
	local stamina = NETWORK.needs.GetExact(client)
	local speed = client:GetVelocity():Length2D()
	local bGround = client:IsOnGround()
	local bSprinting = client:KeyDown(IN_SPEED) and bGround and
		speed > NETWORK.movement.walkSpeed * 0.8 and !client:Crouching()

	if (speed < config.moveThreshold) then
		client.nwStillSince = client.nwStillSince or CurTime()
	else
		client.nwStillSince = nil
	end

	local bCalm = client.nwStillSince != nil and
		CurTime() - client.nwStillSince >= config.calmTime

	local bStraining = client:IsExhausted() and bGround and !bCalm and
		speed > NETWORK.movement.walkSpeed * 1.05

	NETWORK.needs.PushBool(client, "nwStraining", bStraining)

	if (!bStraining and client.nwHeartbeat) then
		client.nwHeartbeat = nil

		client:StopSound(config.heartSound)
	end

	if (bStraining) then
		client.nwStaminaDelay = CurTime() + config.regenDelay * 2

		local strain = math.min((client.nwStrain or 0) + delta, 6)

		client.nwStrain = strain

		if ((client.nwNextHeart or 0) < CurTime()) then
			local rate = Lerp(strain / 6, config.heartMax, config.heartMin)

			client.nwNextHeart = CurTime() + rate
			client.nwHeartbeat = true

			client:EmitSound(config.heartSound, config.heartVolume,
				100 + strain * 4)
		end
	else
		client.nwStrain = math.max((client.nwStrain or 0) - delta * 2, 0)
	end

	local endurance = NETWORK.skills and NETWORK.skills.Get(client, "endurance") or 0

	if (bSprinting and !client:IsExhausted()) then
		stamina = stamina - config.sprintDrain * delta *
			math.Clamp(1 - endurance * NETWORK.skills.Effect("endurance", "drain"), 0.5, 1)
		client.nwStaminaDelay = CurTime() + config.regenDelay
	elseif (bGround and (client.nwStaminaDelay or 0) < CurTime()) then

		local rate = config.regen * (1 + endurance * NETWORK.skills.Effect("endurance", "regen"))

		if (speed >= config.moveThreshold) then
			rate = rate * config.walkRegen
		end

		stamina = stamina + rate * delta
	end

	stamina = NETWORK.needs.PushStamina(client, stamina)

	if (stamina <= 0) then
		NETWORK.needs.PushBool(client, "nwExhausted", true)
	elseif (client:IsExhausted() and stamina >= config.recoverAt) then
		NETWORK.needs.PushBool(client, "nwExhausted", false)
	end
end)

timer.Create("nwNeeds", 6, 0, function()
	local hunger = 100 / NETWORK.needs.hungerTime * 6
	local thirst = 100 / NETWORK.needs.thirstTime * 6

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:HasCharacter()) then
			continue
		end

		local faction = NETWORK.factions.Get(client:GetCharacterFaction())

		if (faction and faction.bCombine) then
			NETWORK.needs.Add(client, "nwHunger", 100)
			NETWORK.needs.Add(client, "nwThirst", 100)

			continue
		end

		NETWORK.needs.Add(client, "nwHunger", -hunger)
		NETWORK.needs.Add(client, "nwThirst", -thirst)

		if (client:GetHunger() <= 0) then
			client:TakeDamage(2, client, client)
		end
	end
end)

concommand.Add("network_needs_fill", function(client)
	if (IsValid(client) and !client:IsAdmin()) then
		return
	end

	for _, target in ipairs(player.GetAll()) do
		NETWORK.needs.Reset(target)
	end
end)
